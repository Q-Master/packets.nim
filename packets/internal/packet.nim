import std/[macros, tables, strutils, sets, options]
import ./util/crc32


type
  TFieldItem* = ref object
    names: seq[NimNode]
    fType: NimNode
    defaultValue: NimNode
    nameAs: string
    required: bool
    optional: bool

  TCacheItem = ref object
    basenames: seq[string]
    allFields: OrderedTable[string, TFieldItem]
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


proc genFieldNode(field: NimNode): (NimNode, NimNode, string) {.compiletime.} =
  case field.kind
  of nnkPostfix:
    # var field*: type
    let fname = field[1].copy
    fname.copyLineInfo(field[1])
    let f = nnkPostfix.newTree(
      ident "*",
      fname
    )
    f.copyLineInfo(field)
    result = (f, fname, $fname)
  of nnkIdent:
    # var field: type
    let f = field.copy
    f.copyLineInfo(field)
    result = (f, f, $f)
  of nnkPragmaExpr:
    #var with pragma
    var (fNode, fName, asName) = genFieldNode(field[0])
    for pelem in field[1]:
      if pelem.kind == nnkExprColonExpr and pelem[0] == ident "asName":
        asName = $pelem[1]
    result = (fNode, fName, asName)
  else:
    error("Unknown var section " & $field.kind, field)


proc genFieldaccessor(allIdents: openArray[NimNode], prefix: Option[NimNode] = NimNode.none): NimNode =
  if prefix.isSome:
    result = newDotExpr(prefix.get.copy, allIdents[0].copy)
  else:
    result = allIdents[0].copy
  if allIdents.len > 1:
    for idx in 1 .. allIdents.high:
      result = newDotExpr(result, allIdents[idx].copy)


proc createType*(
  packetIdent: NimNode, basenames: seq[string], 
  body: NimNode,
  isArray = false
): (NimNode, seq[string], seq[string], OrderedTable[string, TFieldItem], seq[NimNode]) {.compiletime.} =
  let packetname = $packetIdent
  if packetCache.hasKey(packetname):
    when defined(nimsuggest):
      packetCache.del(packetname)
    else:
      error("Redefining the " & packetname, packetIdent)
  var reclist = newNimNode(nnkRecList)
  var requiredFields: seq[string]
  var exportedFields: seq[string]
  var allFields: OrderedTable[string, TFieldItem]
  var baseFunctions: seq[NimNode]
  var allFieldsHash: HashSet[string]
  if basenames.len > 0:
    for basename in basenames:
      let t = packetCache[basename]
      requiredFields.add(t.requiredFields)
      exportedFields.add(t.exportedFields)
      let bnNormal = basename.normalize()
      let basenameident = ident bnNormal
      for fname, fdata in t.allFields.pairs:
        var newData = fdata
        if fname in allFieldsHash or newData.nameAs in allFieldsHash:
          error("Duplicate field " & fname, newData.names[^1])
        newData.names.insert(basenameident, 0)
        allFields[fname] = newData
        allFieldsHash.incl(fname)
        allFieldsHash.incl(newData.nameAs)
        let fpath = genFieldaccessor(newData.names, "self".ident.option)
        let fieldIdent = ident fname
        let fieldIdentEq = nnkAccQuoted.newTree(fieldIdent, ident "=")
        fieldIdent.copyLineInfo(newData.names[^1])
        fieldIdentEq.copyLineInfo(newData.names[^1])
        let ftype = newData.fType
        let accessor =
          nnkFuncDef.newTree(
            nnkPostfix.newTree(
              ident "*",
              fieldIdent
            ),
            newEmptyNode(),
            newEmptyNode(),
            nnkFormalParams.newTree(
              ftype.copy,
              nnkIdentDefs.newTree(
                ident "self",
                ident packetname,
                newEmptyNode()
              )
            ),
            nnkPragma.newTree(
              ident "inline"
            ),
            newEmptyNode(),
            nnkStmtList.newTree(
              fpath.copy
            )
          )
        let setter =
          nnkFuncDef.newTree(
            nnkPostfix.newTree(
              ident "*",
              fieldIdentEq,
            ),
            newEmptyNode(),
            newEmptyNode(),
            nnkFormalParams.newTree(
              newEmptyNode(),
              nnkIdentDefs.newTree(
                ident "self",
                ident packetname,
                newEmptyNode()
              ),
              nnkIdentDefs.newTree(
                ident "val",
                ftype,
                newEmptyNode()
              )
            ),
            nnkPragma.newTree(
              ident "inline"
            ),
            newEmptyNode(),
            nnkStmtList.newTree(
              nnkAsgn.newTree(
                fpath.copy,
                ident "val"
              )
            )
          )
        accessor.copyLineInfo(newData.names[^1])
        setter.copyLineInfo(newData.names[^1])
        baseFunctions.add(accessor)
        baseFunctions.add(setter)
      reclist.add(
        nnkIdentDefs.newTree(
          ident bnNormal,
          ident basename,
          newEmptyNode()
        )
      )

  for elem in body.children:
    if elem.kind != nnkVarSection:
      error("Failed to parse packet var", elem)
    else:
      let trueElem = elem[0]
      let (fieldNode, fieldNodeName, asName) = genFieldNode(trueElem[0])
      if $fieldNodeName in allFieldsHash or asName in allFieldsHash:
          error("Redefinition of field " & $fieldNodeName, trueElem)
      let fieldElem = TFieldItem(names: @[fieldNodeName], fType: trueElem[1], defaultValue: trueElem[2], nameAs: asName, required: false, optional: false)
      let typeNode = nnkIdentDefs.newTree(
        fieldNode,
        fieldElem.fType,
        fieldElem.defaultValue
      )
      typeNode.copyLineInfo(elem)

      if fieldNode.kind == nnkPostfix:
        if fieldElem.fType.kind != nnkBracketExpr or fieldElem.fType[0] != ident "Option":
          requiredFields.add(asName)
          fieldElem.required = true
        elif isArray:
          error("Array packets can't contain optional fields", trueElem)
        else:
          #optional field
          fieldElem.optional = true
          if fieldElem.defaultValue.kind == nnkEmpty:
            #optional field with no default value - setting to `ftype.none`
            fieldElem.defaultValue = newDotExpr(
              fieldElem.fType[1],
              ident "none"
            )
        exportedFields.add($fieldNodeName)

      allFieldsHash.incl($fieldNodeName)
      allFieldsHash.incl(asName)
      allFields[$fieldNodeName] = fieldElem
      reclist.add(typeNode)

  let theType = nnkTypeSection.newTree(
    nnkTypeDef.newTree(
      nnkPostfix.newTree(
        ident "*",
        packetIdent
      ),
      newEmptyNode(),
      nnkRefTy.newTree(
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
        ident "TPacketDataSource"
        ,
        newEmptyNode()
      )
    ),
    newEmptyNode(),
    newEmptyNode(),
    nnkStmtList.newTree(
      caseStmt
    )
  )


proc genDeserCase(cn: NimNode, fn: openArray[NimNode], ft: NimNode, isRequired: bool): NimNode {.compiletime.} =
  let dotexpr = genFieldaccessor(fn, (ident "p").option)
  let loadStmt = quote do:
    `dotexpr` = `ft`.load(s)
  result = nnkOfBranch.newTree(
    cn,
    nnkStmtList.newTree(
      loadStmt,
      nnkAsgn.newTree(
        ident "result",
        (if isRequired: newIntLitNode(1) else: newIntLitNode(0))
      )
    )
  )


proc createDeserData*(
  name: string,
  exportedFields: openArray[string],
  fields: OrderedTable[string, TFieldItem]
): seq[NimNode] {.compiletime.} =
  let nameIdent = ident(name)
  var cases: seq[NimNode]
  var currField: TFieldItem
  for fn in exportedFields:
    currField = fields[fn]
    cases.add(
      genDeserCase(newStrLitNode(currField.nameAs), currField.names, currField.fType, currField.required)
    )
  result.add(
    genDeserNode(nameIdent, cases, false)
  )


proc createArrayDeserData*(
  name: string, 
  exportedFields: openArray[string],
  fields: OrderedTable[string, TFieldItem]
): seq[NimNode] {.compiletime.} =
  let nameIdent = ident(name)
  var cases: seq[NimNode]
  var idx = 0
  var currField: TFieldItem
  for fn in exportedFields:
    currField = fields[fn]
    cases.add(
      genDeserCase(newIntLitNode(idx), currField.names, currField.fType, true)
    )
    idx.inc()
  result.add(
    genDeserNode(nameIdent, cases, true)
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


proc createSerData*(
  name: string,
  exportedFields: openArray[string],
  fields: OrderedTable[string, TFieldItem],
  requiredFields: openArray[string]
): seq[NimNode] {.compiletime.} =
  var allYields = newStmtList()
  var cases: seq[NimNode]
  var currField: TFieldItem
  for fn in exportedFields:
    currField = fields[fn]
    allYields.add(
      buildYield(currField.nameAs, currField.required)
    )
    cases.add(
      genSerCase(newStrLitNode(currField.nameAs), currField.names)
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


proc createArraySerData*(
  name: string,
  exportedFields: openArray[string],
  fields: OrderedTable[string, TFieldItem]
): seq[NimNode] {.compiletime.} =
  var idx = 0
  var cases: seq[NimNode]
  for fn in exportedFields:
    cases.add(
      genSerCase(newIntLitNode(idx), fields[fn].names)
    )
    idx.inc()
  result.add(
    genSerNode(name, cases, true)
  )


proc getNameAndBases*(head: NimNode): (NimNode, seq[string]) {.compiletime.} =
  var packetname: NimNode
  var basenames: seq[string]
  case head.kind
  of nnkIdent:
    packetname = head.copy
  of nnkInfix:
    if eqIdent(head[0], "of"):
      packetname = head[1].copy
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
      packetname = head[1].copy
  else:
    error("Error in packet header", head)
  
  for basename in basenames:
    if not packetCache.hasKey(basename):
      error("No such base type " & basename, head)
  result = (packetname, basenames)


proc genRequiredFieldsAmount*(packetIdent: NimNode, amount: int): NimNode {.compiletime.} =
  let pcopy = packetIdent.copy
  result =
    quote do:
      proc requiredFields*(_: typedesc[`pcopy`]): int = `amount`
      proc requiredFields*(_: `pcopy`): int = `amount`


proc createNewInit*(packetIdent: NimNode): seq[NimNode] {.compiletime.}=
  let packetname = $packetIdent
  let cacheData = packetCache[packetname]
  var allInits = nnkStmtList.newTree()
  var dumbNewInits = nnkStmtList.newTree(
    nnkCall.newTree(
      nnkDotExpr.newTree(
        ident "system",
        ident "new"
      ),
      ident "self"
    )
  )
  # generate bases init
  var usedParams: seq[string]
  if cacheData.basenames.len > 0:
    for basename in cacheData.basenames:
      let baseCacheData = packetCache[basename]
      let baseNormalName = basename.normalize()
      let baseInit = nnkCall.newTree(
          nnkDotExpr.newTree(
            ident basename,
            ident "new"
          )
        )
      for paramname in baseCacheData.allFields.keys:
        usedParams.add(paramname)
        baseInit.add(
          ident paramname
        )
      allInits.add(
        nnkAsgn.newTree(
          nnkDotExpr.newTree(
            ident "self",
            ident baseNormalName
          ),
          baseInit
        )
      )
      dumbNewInits.add(
        nnkDotExpr.newTree(
          nnkDotExpr.newTree(
            ident "self",
            ident baseNormalName
          ),
          ident "new"
        )
      )
  # generate identdefs for formalparams and local field inits
  var initParams = nnkFormalParams.newTree(
    newEmptyNode(),
    nnkIdentDefs.newTree(
      ident "self",
      ident packetname,
      newEmptyNode()
    )
  )
  var newParams = nnkFormalParams.newTree(
    ident packetname,
    nnkIdentDefs.newTree(
      ident "_",
      nnkBracketExpr.newTree(
        ident "typedesc",
        ident packetname
      ),
      newEmptyNode()
    )
  )
  var newInitCall = nnkCall.newTree(
    nnkDotExpr.newTree(
      ident "result",
      ident "init"
    )
  )
  for paramname, paramdata in cacheData.allFields.pairs:
    initParams.add(
      nnkIdentDefs.newTree(
        ident paramname,
        paramdata.fType.copy,
        paramdata.defaultValue.copy
      )
    )
    newParams.add(
      nnkIdentDefs.newTree(
        ident paramname,
        paramdata.fType.copy,
        paramdata.defaultValue.copy
      )
    )
    newInitCall.add(ident paramname)
    if paramname notin usedParams:
      allInits.add(
        nnkAsgn.newTree(
          nnkDotExpr.newTree(
            ident "self",
            ident paramname
          ),
          ident paramname
        )
      )
  result.add(
    nnkProcDef.newTree(
      nnkPostfix.newTree(
        ident "*",
        ident "init"
      ),
      newEmptyNode(),
      newEmptyNode(),
      initParams,
      newEmptyNode(),
      newEmptyNode(),
      allInits
    )
  )
  result.add(
    nnkProcDef.newTree(
      nnkPostfix.newTree(
        ident "*",
        ident "new"
      ),
      newEmptyNode(),
      newEmptyNode(),
      newParams,
      newEmptyNode(),
      newEmptyNode(),
      nnkStmtList.newTree(
        nnkDotExpr.newTree(
          ident "result",
          ident "new"
        ),
        newInitCall
      )
    )
  )
  result.add(
    nnkProcDef.newTree(
      nnkPostfix.newTree(
        ident "*",
        ident "new"
      ),
      newEmptyNode(),
      newEmptyNode(),
      nnkFormalParams.newTree(
        newEmptyNode(),
        nnkIdentDefs.newTree(
          ident "self",
          nnkVarTy.newTree(
            ident packetname
          ),
          newEmptyNode()
        )
      ),
      newEmptyNode(),
      newEmptyNode(),
      dumbNewInits
    )
  )
