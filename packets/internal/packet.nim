import std/[macros, tables, strutils, sets]
import ./util/crc32
import ./types


type
  TCacheItem = object
    basenames: seq[string]
    allFields: seq[(NimNode, NimNode, string)]


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


proc createType(
  packetIdent: NimNode, basenames: seq[string], 
  body: NimNode,
  isArray = false
): (NimNode, seq[string], seq[(NimNode, NimNode, string)], NimNode) {.compiletime.} =
  let packetname = $packetIdent
  if packetCache.hasKey(packetname):
    error("Redefining the " & packetname, body)
  var reclist = newNimNode(nnkRecList)
  var requiredFields: seq[string]
  var allFields: seq[(NimNode, NimNode, string)]
  var baseFunctions = newStmtList()
  var allFieldsHash: HashSet[string]
  for basename in basenames:
    let t = packetCache[basename]
    let basenameident = ident(basename.normalize())
    for field in t.allFields:
      let fname = field[0]
      let fnameeq = ident($fname & "=")
      let ftype = field[1]
      if $fname in allFieldsHash or field[2] in allFieldsHash:
        error("Duplicate field " & $fname, field[0])
      allFields.add(field)
      allFieldsHash.incl($fname)
      allFieldsHash.incl(field[2])
      baseFunctions.add(
        quote do:
          proc `fname`*(t: `packetIdent`): `ftype` = t.`basenameident`.`fname`
      )
      baseFunctions.add(
        quote do:
          proc `fnameeq`*(t: var `packetIdent`, x: `ftype`) = t.`basenameident`.`fname` = x
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
            if not isArray:
              requiredFields.add($fieldNode[1])
          elif isArray:
            error("Array packets can't contain optional fields", trueElem)
          allFields.add((fieldNode[1], trueElem[1], $fieldNode[1]))
          allFieldsHash.incl($fieldNode[1])
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
            if not isArray:
              requiredFields.add(asName)
          elif isArray:
            error("Array packets can't contain optional fields", trueElem)
        allFields.add((fieldNode[1], trueElem[1], asName))
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
  result = (theType, requiredFields, allFields, baseFunctions)
  packetCache[packetname] = TCacheItem(
    basenames: basenames,
    allFields: allFields
  )


proc createLoaderForField(name: string, field, fieldType: NimNode, isArray: bool = false): (NimNode, NimNode) {.compiletime.} =
  let fieldLoaderIdent = ident(name.normalize() & $field & "Loader")
  let nameIdent = ident(name)
  let sIdent = ident "s"
  let pIdent = ident "p"
  let loader = 
    if isArray:
      quote do:
        proc `fieldLoaderIdent`(`pIdent`: var TArrayPacket, `sIdent`: var TPacketDataSource)=
          #mixin load
          `nameIdent`(`pIdent`).`field` = s.load(`fieldType`)
    else:
      quote do:
        proc `fieldLoaderIdent`(`pIdent`: var TPacket, `sIdent`: var TPacketDataSource)=
          #mixin load
          `nameIdent`(`pIdent`).`field` = s.load(`fieldType`)
  result = (fieldLoaderIdent, loader)


proc addPacketFields(nameIdent: NimNode, normalName: string, fields: openArray[(NimNode, NimNode, string)]): NimNode {.compiletime.}=
  result = nnkStmtList.newTree()
  let fieldsName = ident(normalName & "Fields")
  if fields.len == 0:
    result.add(
      quote do:
        const `fieldsName` = []
    )
  else:
    var allfieldnames: seq[NimNode]
    for (field, _, _) in fields:
      allfieldnames.add(newStrLitNode($field))
    result.add(
      quote do:
        const `fieldsName` = `allfieldnames`
    )
  result.add(
    quote do:
      proc packetFields*(_: `nameIdent`): auto = `fieldsName`
  )


proc createDeserData(name: string, fields: openArray[(NimNode, NimNode, string)], requiredFields: openArray[string]): NimNode {.compiletime.} =
  let normalName = name.normalize()
  result = newStmtList()
  let nameIdent = ident(name)
  let deserName = ident(normalName & "Deser")
  result.add(
    quote do:
      var `deserName`: Table[string, TPacketFieldSetFunc]
  )

  for (fieldIdent, fieldType, fieldName) in fields:
    let (loaderIdent, loader) = createLoaderForField(name, fieldIdent, fieldType)
    result.add(loader)
    let fieldNameStrLit = newStrLitNode(fieldName)
    result.add(
      quote do:
        `deserName`[`fieldNameStrLit`] = `loaderIdent`
    )
  result.add(
    quote do:
      proc deserMapping*(_: typedesc[`nameIdent`]): auto = `deserName`
  )
  result.add(addPacketFields(nameIdent, normalName, fields))

  let requiredName = ident(normalName & "Required")
  if requiredFields.len == 0:
    result.add(
      quote do:
        const `requiredName`: HashSet[string] = initHashSet[string]()
    )
  else:
    var requiredList: seq[NimNode]
    for field in requiredFields:
      requiredList.add(newStrLitNode(field))
    result.add(
      quote do:
        const `requiredName`: HashSet[string] = `requiredList`.toHashSet()
    )
  result.add(
    quote do:
      proc requiredFields*(_: typedesc[`nameIdent`]): auto = `requiredName`
      proc requiredFields*(_: `nameIdent`): auto = `requiredName`
  )
  let mappingName = ident(normalName & "Mapping")
  var mappingList: NimNode = nnkTableConstr.newTree()
  for (fident, _, fname) in fields:
    if $fident != fname:
      mappingList.add(
        nnkExprColonExpr.newTree(
          newStrLitNode($fident),
          newStrLitNode(fname)
        )
      )
  if mappingList.len > 0:
    result.add(
      nnkConstSection.newTree(
        nnkConstDef.newTree(
          mappingName,
          nnkBracketExpr.newTree(
            ident "Table",
            ident "string",
            ident "string"
          ),
          nnkCall.newTree(
            nnkDotExpr.newTree(
              mappingList,
              ident "toTable"
            )
          )
        )
      )
    )
  else:
    result.add(
      quote do:
        const `mappingName`: Table[string, string] = initTable[string, string]()
    )
  result.add(
    quote do:
      proc mapping*(_: typedesc[`nameIdent`]): auto = `mappingName`
      proc mapping*(_: `nameIdent`): auto = `mappingName`
  )


proc createArrayDeserData(name: string, fields: openArray[(NimNode, NimNode, string)]): NimNode {.compiletime.} =
  let normalName = name.normalize()
  result = newStmtList()
  let nameIdent = ident(name)
  let deserName = ident(normalName & "Deser")
  var deserFuncs = nnkBracket.newTree()
  for (fieldIdent, fieldType, fieldName) in fields:
    let (loaderIdent, loader) = createLoaderForField(name, fieldIdent, fieldType, true)
    result.add(loader)
    deserFuncs.add(loaderIdent)
  result.add(
    quote do:
      const `deserName` = `deserFuncs`
      proc deserMapping*(_: typedesc[`nameIdent`]): auto = `deserName`
  )
  result.add(addPacketFields(nameIdent, normalName, fields))


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
  let (typeNode, requiredFields, allFields, baseFunctions) = createType(packetname, basenames, body)
  typeNode.setLineInfo(head.lineInfoObj)
  result.add(typeNode)
  result.add(baseFunctions)
  let deserData = createDeserData($packetname, allFields, requiredFields)
  result.add(deserData)


macro arrayPacket*(head, body: untyped): untyped =
  let (packetname, basenames) = getNameAndBases(head)
  result = newStmtList()
  let (typeNode, _, allFields, baseFunctions) = createType(packetname, basenames, body, true)
  typeNode.setLineInfo(head.lineInfoObj)
  result.add(typeNode)
  result.add(baseFunctions)
  let deserData = createArrayDeserData($packetname, allFields)
  result.add(deserData)
