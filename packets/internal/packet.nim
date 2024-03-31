import std/[macros, tables, strutils, sets, options]
import ./util/crc32


type
  TCacheItem = object
    basenames: seq[string]
    allFields: OrderedTable[string, (seq[NimNode], NimNode, string)]
    exportedFields: seq[string]
    requiredFields: seq[string]


var packetCache {.compiletime, global.}: Table[string, TCacheItem]


proc concatBases(bases: openArray[string]): seq[string] {.compiletime.} =
  result = @[]
  for base in bases:
    result.add(concatBases(packetCache[base].basenames))
    result.add(base)


proc generateId(name, bases: openArray[string]): int32 {.compiletime.} =
  var basesSeq: seq[string] = concatBases(bases)
  basesSeq.add(name)
  var hash = join(basesSeq, "__")
  let packetId = BiggestInt(crc32(hash))
  result = 
    if packetId >= int32.high:
      int32(packetId - 1.shl(32))
    else:
      int32(packetId)


proc genFieldNode(field: NimNode): NimNode {.compiletime.} =
  case field.kind
  of nnkPostfix:
    # var field*: type
    result = nnkPostfix.newTree(
      ident "*",
      field[1]
    )
  of nnkIdent:
    # var field: type
    result = field
  else:
    error("Unknown var section " & $field.kind, field)


proc genFieldaccessor(allIdents: openArray[NimNode], prefix: Option[NimNode] = NimNode.none): NimNode =
  if prefix.isSome:
    result = newDotExpr(prefix.get, allIdents[0])
  else:
    result = allIdents[0]
  if allIdents.len > 1:
    for idx in 1 .. allIdents.high:
      result = newDotExpr(result, allIdents[idx])


proc createType(
  packetIdent: NimNode, basenames: seq[string], 
  body: NimNode,
  isArray = false
): (NimNode, seq[string], seq[string], OrderedTable[string, (seq[NimNode], NimNode, string)], NimNode) {.compiletime.} =
  let packetname = $packetIdent
  if packetCache.hasKey(packetname):
    error("Redefining the " & packetname, body)
  var reclist = newNimNode(nnkRecList)
  var requiredFields: seq[string]
  var exportedFields: seq[string]
  var allFields: OrderedTable[string, (seq[NimNode], NimNode, string)]
  var baseFunctions = newStmtList()
  var allFieldsHash: HashSet[string]
  let tIdent = ident "t"
  let xIdent = ident "x"
  for basename in basenames:
    let t = packetCache[basename]
    requiredFields.add(t.requiredFields)
    exportedFields.add(t.exportedFields)
    let basenameident = ident(basename.normalize())
    for fname, fdata in t.allFields.pairs:
      var newData = fdata
      let ftype = newData[1]
      if fname in allFieldsHash or newData[2] in allFieldsHash:
        error("Duplicate field " & fname, newData[0][^1])
      newData[0].insert(basenameident, 0)
      allFields[fname] = newData
      allFieldsHash.incl(fname)
      allFieldsHash.incl(newData[2])
      let fpath = genFieldaccessor(newData[0], tIdent.option)
      let fieldIdent = ident fname
      baseFunctions.add(
        quote do:
          proc `fieldIdent`*(`tIdent`: `packetIdent`): `ftype` = `fpath`
      )
      let fieldIdentEq = newTree(nnkAccQuoted, ident(fname & "="))
      baseFunctions.add(
        quote do:
          proc `fieldIdentEq`*(`tIdent`: var `packetIdent`, `xIdent`: `ftype`) = `fpath` = x
      )
    let bnNormal = basename.normalize()
    reclist.add(
      nnkIdentDefs.newTree(
        ident(bnNormal),
        ident(basename),
        newEmptyNode()
      )
    )

  for elem in body.children:
    if elem.kind != nnkVarSection:
      error("Failed to parse packet var", elem)
    else:
      let trueElem = elem[0]
      var typeNode: NimNode
      case trueElem[0].kind
      of nnkPostfix, nnkIdent:
        # simple exportable fields
        let fieldNode = genFieldNode(trueElem[0])
        typeNode = nnkIdentDefs.newTree(
          fieldNode,
          trueElem[1],
          trueElem[2]
        )
        if trueElem[0].kind == nnkPostFix:
          # adding to required fields and all fields
          if $fieldNode[1] in allFieldsHash:
            error("Redefinition of field " & $fieldNode[1], trueElem)
          if trueElem[1].kind != nnkBracketExpr or trueElem[1][0] != ident "Option":
            requiredFields.add($fieldNode[1])
          elif isArray:
            error("Array packets can't contain optional fields", trueElem)
          allFields[$fieldNode[1]] = (@[fieldNode[1]], trueElem[1], $fieldNode[1])
          allFieldsHash.incl($fieldNode[1])
          exportedFields.add($fieldNode[1])
        else:
          # adding only to all fieldsHash
          if $fieldNode in allFieldsHash:
            error("Redefinition of field " & $fieldNode, trueElem)
          allFieldsHash.incl($trueElem[0])
      of nnkPragmaExpr:
        # added some pragmas
        let fieldNode = genFieldNode(trueElem[0][0])
        typeNode = nnkIdentDefs.newTree(
          fieldNode,
          trueElem[1],
          trueElem[2]
        )
        var asName = $fieldNode[1]
        for pelem in trueElem[0][1]:
          if pelem.kind == nnkExprColonExpr and pelem[0] == ident "asName":
            asName = $pelem[1]
        if $fieldNode[1] in allFieldsHash or asName in allFieldsHash:
          error("Redefinition of field " & $fieldNode[1], trueElem)
        if trueElem[0][0].kind == nnkPostFix:
          if trueElem[1].kind != nnkBracketExpr or trueElem[1][0] != ident "Option":
            requiredFields.add(asName)
          elif isArray:
            error("Array packets can't contain optional fields", trueElem)
          exportedFields.add($fieldNode[1])
        allFields[$fieldNode[1]] = (@[fieldNode[1]], trueElem[1], asName)
        allFieldsHash.incl($fieldNode[1])
        allFieldsHash.incl(asName)
      else:
        error("Unknown var section", elem)
      typeNode.setLineInfo(elem.lineInfoObj)
      reclist.add(typeNode)
  let theType = nnkTypeSection.newTree(
    nnkTypeDef.newTree(
      nnkPostfix.newTree(
        ident "*",
        ident packetname
      ),
      newEmptyNode(),
      nnkObjectTy.newTree(
        newEmptyNode(),
        nnkOfInherit.newTree(
          if isArray:
            ident "TArrayPacket"
          else:
            ident "TPacket"
        ),
        reclist
      )
    )
  )  
  result = (theType, requiredFields, exportedFields, allFields, baseFunctions)
  packetCache[packetname] = TCacheItem(
    basenames: basenames,
    allFields: allFields,
    exportedFields: exportedFields,
    requiredFields: requiredFields
  )


proc genDeserNode(nameIdent: NimNode, cases: openArray[NimNode], isArray = false): NimNode {.compiletime.} =
  var caseStmt = nnkCaseStmt.newTree(
    ident "n"
  )
  for c in cases:
    caseStmt.add(c)
  caseStmt.add(
    nnkElse.newTree(
      nnkStmtList.newTree(
        nnkAsgn.newTree(
          ident "result",
          newIntLitNode(-1)
        )
      )
    )
  )
  result = nnkProcDef.newTree(
    nnkPostfix.newTree(
      ident "*",
      ident "load"
    ),
    newEmptyNode(),
    newEmptyNode(),
    nnkFormalParams.newTree(
      ident "int8",
      nnkIdentDefs.newTree(
        ident "n",
        (if isArray: ident "int" else: ident "string"),
        newEmptyNode()
      ),
      nnkIdentDefs.newTree(
        ident "p",
        nnkVarTy.newTree(
          nameIdent
        ),
        newEmptyNode()
      ),
      nnkIdentDefs.newTree(
        ident "s",
        nnkVarTy.newTree(
          ident "TPacketDataSource"
        ),
        newEmptyNode()
      )
    ),
    newEmptyNode(),
    newEmptyNode(),
    nnkStmtList.newTree(
      caseStmt
    )
  )


proc genDeserCase(cn: NimNode, fn: openArray[NimNode], isRequired: bool): NimNode {.compiletime.} =
  let dotexpr = genFieldaccessor(fn, (ident "p").option)
  result = nnkOfBranch.newTree(
    cn,
    nnkStmtList.newTree(
      nnkCall.newTree(
        nnkDotExpr.newTree(
          ident "s",
          ident "load"
        ),
        dotexpr
      ),
      nnkAsgn.newTree(
        ident "result",
        (if isRequired: newIntLitNode(1) else: newIntLitNode(0))
      )
    )
  )


proc createDeserData(
  name: string,
  exportedFields: openArray[string],
  fields: OrderedTable[string, (seq[NimNode], NimNode, string)], 
  requiredFields: openArray[string]
): NimNode {.compiletime.} =
  result = newStmtList()
  let nameIdent = ident(name)
  var cases: seq[NimNode]
  for fn in exportedFields:
    let (fieldIdents, _, fieldName) = fields[fn]
    cases.add(
      genDeserCase(newStrLitNode(fieldName), fieldIdents, fieldName in requiredFields)
    )
  result.add(
    genDeserNode(nameIdent, cases, false)
  )

  let amount = newIntLitNode(requiredFields.len)

  result.add(
    quote do:
      proc requiredFields*(_: typedesc[`nameIdent`]): int = `amount`
      proc requiredFields*(_: `nameIdent`): int = `amount`
  )


proc createArrayDeserData(
  name: string, 
  exportedFields: openArray[string],
  fields: OrderedTable[string, (seq[NimNode], NimNode, string)], 
  requiredFieldsAmount: int
): NimNode {.compiletime.} =
  result = newStmtList()
  let nameIdent = ident(name)
  var cases: seq[NimNode]
  var idx = 0
  for fn in exportedFields:
    let (fieldIdents, _, _) = fields[fn]
    cases.add(
      genDeserCase(newIntLitNode(idx), fieldIdents, true)
    )
    idx.inc()
  result.add(
    genDeserNode(nameIdent, cases, true)
  )
  let amount = newIntLitNode(requiredFieldsAmount)
  result.add(
    quote do:
      proc requiredFields*(_: typedesc[`nameIdent`]): int = `amount`
      proc requiredFields*(_: `nameIdent`): int = `amount`
  )


proc genSerCase(cn: NimNode, fn: openArray[NimNode]): NimNode {.compiletime.} =
  let dotexpr = genFieldaccessor(fn, (ident "p").option)
  result = nnkOfBranch.newTree(
    cn,
    nnkStmtList.newTree(
      nnkCall.newTree(
        nnkDotExpr.newTree(
          dotexpr,
          ident "dump"
        ),
        ident "d"
      )
    )
  )


proc genSerNode(name: string, cases: openArray[NimNode], isArray = false): NimNode {.compiletime.} =
  var caseStmt = nnkCaseStmt.newTree(
    ident "n"
  )
  for c in cases:
    caseStmt.add(c)
  caseStmt.add(
    nnkElse.newTree(
      nnkStmtList.newTree(
        nnkDiscardStmt.newTree(
          newEmptyNode()
        )
      )
    )
  )
  result = nnkProcDef.newTree(
    nnkPostfix.newTree(
      ident "*",
      ident "dump"
    ),
    newEmptyNode(),
    newEmptyNode(),
    nnkFormalParams.newTree(
      newEmptyNode(),
      nnkIdentDefs.newTree(
        ident "n",
        (if isArray: ident "int" else: ident "string"),
        newEmptyNode()
      ),
      nnkIdentDefs.newTree(
        ident "p",
        ident(name),
        newEmptyNode()
      ),
      nnkIdentDefs.newTree(
        ident "d",
        nnkVarTy.newTree(
          ident "string"
        ),
        newEmptyNode()
      )
    ),
    newEmptyNode(),
    newEmptyNode(),
    nnkStmtList.newTree(
      caseStmt
    )
  )


proc buildYield(fn: string, isRequired: bool): NimNode =
  result = nnkYieldStmt.newTree(
    nnkTupleConstr.newTree(
      newStrLitNode(fn),
      (if isRequired: ident "true" else: ident "false")
    )
  )


proc createSerData(
  name: string,
  exportedFields: openArray[string],
  fields: OrderedTable[string, (seq[NimNode], NimNode, string)], 
  requiredFields: openArray[string]
): NimNode {.compiletime.} =
  result = newStmtList()
  var allYields = newStmtList()
  var cases: seq[NimNode]
  for fn in exportedFields:
    let (field, _, fname) = fields[fn]
    allYields.add(
      buildYield(fname, fname in requiredFields)
    )
    cases.add(
      genSerCase(newStrLitNode(fname), field)
    )
  result.add(
    nnkIteratorDef.newTree(
      nnkPostfix.newTree(
        ident "*",
        ident "fields"
      ),
      newEmptyNode(),
      newEmptyNode(),
      nnkFormalParams.newTree(
        nnkTupleConstr.newTree(
          ident "string",
          ident "bool"
        ),
        nnkIdentDefs.newTree(
          ident "p",
          ident(name),
          newEmptyNode()
        )
      ),
      newEmptyNode(),
      newEmptyNode(),
      allYields
    )
  )
  result.add(
    genSerNode(name, cases)
  )


proc createArraySerData(
  name: string,
  exportedFields: openArray[string],
  fields: OrderedTable[string, (seq[NimNode], NimNode, string)]
): NimNode {.compiletime.} =
  result = newStmtList()
  var idx = 0
  var cases: seq[NimNode]
  for fn in exportedFields:
    let (field, _, _) = fields[fn]
    cases.add(
      genSerCase(newIntLitNode(idx), field)
    )
    idx.inc()
  result.add(
    genSerNode(name, cases, true)
  )


proc getNameAndBases(head: NimNode): (NimNode, seq[string]) {.compiletime.} =
  var packetname: NimNode
  var basenames: seq[string]
  case head.kind
  of nnkIdent:
    packetname = head
  of nnkInfix:
    if eqIdent(head[0], "of"):
      packetname = head[1]
      case head[2].kind
      of nnkTupleConstr:
        for item in head[2].children:
          if item.kind == nnkIdent:
            basenames.add($item)
          else:
            error("Error in packet parents", item)
      of nnkIdent:
        basenames.add($head[2])
      else:
        error("Error in packet parents", head[2])
    else:
      packetname = head[1]
  else:
    error("Error in packet header", head)
  
  for basename in basenames:
    if not packetCache.hasKey(basename):
      error("No such base type " & basename, head)
  result = (packetname, basenames)


macro packet*(head, body: untyped): untyped =
  let (packetname, basenames) = getNameAndBases(head)
  result = newStmtList()
  let (typeNode, requiredFields, exportedFields, allFields, baseFunctions) = createType(packetname, basenames, body)
  typeNode.setLineInfo(head.lineInfoObj)
  result.add(typeNode)
  result.add(baseFunctions)
  let deserData = createDeserData($packetname, exportedFields, allFields, requiredFields)
  result.add(deserData)
  let serData = createSerData($packetname, exportedFields, allFields, requiredFields)
  result.add(serData)


macro arrayPacket*(head, body: untyped): untyped =
  let (packetname, basenames) = getNameAndBases(head)
  result = newStmtList()
  let (typeNode, requiredFields, exportedFields, allFields, baseFunctions) = createType(packetname, basenames, body, true)
  typeNode.setLineInfo(head.lineInfoObj)
  result.add(typeNode)
  result.add(baseFunctions)
  let deserData = createArrayDeserData($packetname, exportedFields, allFields, requiredFields.len())
  result.add(deserData)
  let serData = createArraySerData($packetname, exportedFields, allFields)
  result.add(serData)
