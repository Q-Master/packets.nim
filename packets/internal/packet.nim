import std/[macros, tables, strutils, sets, options]
import ./util/crc32
import ./types


type
  TCacheItem = object
    basenames: seq[string]
    allFields: seq[(NimNode, NimNode, string)]


var packetCache {.compiletime, global.}: Table[string, TCacheItem]


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
          proc `fname`(t: `packetIdent`): `ftype` = t.`basenameident`.`fname`
      )
      baseFunctions.add(
        quote do:
          proc `fnameeq`(t: var `packetIdent`, x: `ftype`) = t.`basenameident`.`fname` = x
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
          allFields.add((fieldNode[1], trueElem[1], $fieldNode[1]))
          allFieldsHash.incl($fieldNode[1])
        else:
          # adding only to all fields
          if $fieldNode in allFieldsHash:
            error("Redefinition of field " & $fieldNode, trueElem)
          allFields.add((fieldNode, trueElem[1], $fieldNode))
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
        allFields.add((fieldNode[1], trueElem[1], asName))
        allFieldsHash.incl($fieldNode[1])
        allFieldsHash.incl(asName)
      else:
        error("Unknown var section", elem)
      typeNode.setLineInfo(elem.lineInfoObj)
      reclist.add(typeNode)
  let theType = nnkTypeSection.newTree(
    nnkTypeDef.newTree(
      ident packetname,
      newEmptyNode(),
      nnkObjectTy.newTree(
        newEmptyNode(),
        nnkOfInherit.newTree(
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


proc createLoaderForField(name: string, field, fieldType: NimNode): (NimNode, NimNode) {.compiletime.} =
  let fieldLoaderIdent = ident(name.normalize() & $field & "Loader")
  let nameIdent = ident(name)
  let sIdent = ident "s"
  let pIdent = ident "p"
  let destIdent = ident "dest"
  let loader = quote do:
    proc `fieldLoaderIdent`(`pIdent`: var TPacket, `sIdent`: var TPacketDataSource)=
      mixin load
      var `destIdent` = `nameIdent`(`pIdent`)
      `destIdent`.`field` = s.load(`fieldType`)
  result = (fieldLoaderIdent, loader)


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
      proc deserMapping(_: typedesc[`nameIdent`]): auto = `deserName`
  )

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
      proc packetFields(_: `nameIdent`): auto = `fieldsName`
  )

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
      proc requiredFields(_: typedesc[`nameIdent`]): auto = `requiredName`
  )



macro packet*(head, body: untyped): untyped =
  var packetname: NimNode
  var normalPacketName: string
  var packetnameIdent: NimNode
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
  normalPacketName = ($packetname).normalize()
  packetnameIdent = ident($packetname)

  for basename in basenames:
    if not packetCache.hasKey(basename):
      error("No such base type " & basename, head)

  result = newStmtList()
  let (typeNode, requiredFields, allFields, baseFunctions) = createType(packetname, basenames, body)
  typeNode.setLineInfo(head.lineInfoObj)
  result.add(typeNode)
  result.add(baseFunctions)
  let deserData = createDeserData($packetname, allFields, requiredFields)
  result.add(deserData)

  echo result.repr
