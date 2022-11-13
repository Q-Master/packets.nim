import std/[macros, tables, sequtils, strutils, sets]
import ./util/crc32
import ./types

type
  TCacheItem = object
    base: string
    params: seq[NimNode]
  TVarData = ref object
    fieldName: NimNode
    fieldType: NimNode
    fieldDefault: NimNode
    fieldForType: NimNode
    fieldExported: bool
    fieldRequired: bool
    fieldAsName: string

proc concatParams(base: string): seq[NimNode] {.compiletime.}
proc concatBases(base: string): seq[string] {.compiletime.}
proc generateId(name, base: string): int32 {.compiletime.}
proc extractFromVar(n: NimNode, asArray: bool = false): TVarData {.compiletime.}
proc generateRefFunct(tName, retType: NimNode, ending, fun: static string): (NimNode, NimNode) {.compiletime.}
proc addRequired(to, refs: var NimNode, requiredList, typeName: NimNode) {.compiletime.}
proc addFields(to, refs: var NimNode, fieldList, typeName: NimNode) {.compiletime.}
proc addMapping(to, refs: var NimNode, mappedList, typeName: NimNode) {.compiletime.}
proc addDeserMapping(to, refs: var NimNode, mappedList, typeName: NimNode) {.compiletime.}
proc addArrayDeserMapping(to, refs: var NimNode, mappedList, typeName: NimNode) {.compiletime.}
proc generatePacketDeserFunc(variable: TVarData, typeName: NimNode, setupMap: NimNode): NimNode {.compiletime.}
proc generateArrayPacketDeserFunc(variable: TVarData, typeName: NimNode, setupSeq: NimNode): NimNode {.compiletime.}
proc generateIDPacketDeserFunc(typeName: NimNode, setupMap: NimNode): NimNode {.compiletime.}
proc generateIDArrayPacketDeserFunc(typeName: NimNode, setupSeq: NimNode): NimNode {.compiletime.}
proc generateForMacroHeader(typeName, internalStmts: NimNode): NimNode {.compiletime.}
proc generateForMacroArrayVarBlock(stmts: var NimNode, variable: NimNode) {.compiletime.}
proc generateForMacroVarBlock(stmts: var NimNode, variable: NimNode, asName: string) {.compiletime.}
proc generateForMacroFooter(stmts: var NimNode) {.compiletime.}
var packetCache {.compiletime, global.}: Table[string, TCacheItem]

let initIdent {.compiletime.} = nnkPostfix.newTree(ident("*"), ident("new"))
let packetIdent {.compiletime.} = ident "packet" 
let dataIdent {.compiletime.} = ident "data"
let idIdent {.compiletime.} = ident "id"

macro arrayPacket*(head, body: untyped): untyped =
  var typeName, baseName: NimNode
  var isExported: bool = true
  var bnIdx: int
  
  case head.kind
  of nnkIdent:
    typeName = head
  of nnkInfix:
    if eqIdent(head[0], "*"):
      typeName = head[1]
      bnIdx = 2
      isExported = true
      baseName = head[2][1]
    else:
      typeName = head[1]
      baseName = head[2]
      isExported = false
  else:
    error "Invalid node: " & head.lispRepr

  result = newStmtList()
  var setupFuncs = newStmtList()
  var setupMap = newStmtList()
  var fieldList = nnkBracket.newTree()
  var requiredList = nnkBracket.newTree()
  var mappedList = nnkTableConstr.newTree()
  var initProcRes = nnkObjConstr.newTree(typeName)
  var initBody = nnkStmtList.newTree(nnkAsgn.newTree(ident"result", initProcRes))
  var initProcResWithoutParamsWithDefaults = nnkObjConstr.newTree(typeName)
  var initBodyWithoutParamsWithDefaults = nnkStmtList.newTree(nnkAsgn.newTree(ident"result", initProcResWithoutParamsWithDefaults))
  var internalStmts = newStmtList()
  var forMacro = generateForMacroHeader(typeName, internalStmts)

  when not defined(disablePacketIDs):
    initProcRes.add(
      nnkExprColonExpr.newTree(idIdent, newIntLitNode(generateId($typeName, (if not baseName.isNil: $baseName else: ""))))
    )
    initProcResWithoutParamsWithDefaults.add(
      nnkExprColonExpr.newTree(idIdent, newIntLitNode(generateId($typeName, (if not baseName.isNil: $baseName else: ""))))
    )
    fieldList.add(newStrLitNode("id"))
    requiredList.add(newStrLitNode("id"))
    setupFuncs.add(generateIDArrayPacketDeserFunc(typename, setupMap))
    generateForMacroArrayVarBlock(internalStmts, ident "id")
    
  var initProc = newProc(
    name = initIdent,
    params = @[
      typeName, # the return type comes first
      newIdentDefs(ident"_", newTree(nnkBracketExpr, ident"type", typeName))
    ],
    body = initBody,
    pragmas = nnkPragma.newTree(ident "noinit")
  )
  var initProcWithoutParams = newProc(
    name = initIdent,
    params = @[
      typeName, # the return type comes first
      newIdentDefs(ident"_", newTree(nnkBracketExpr, ident"type", typeName))
    ],
    body = initBodyWithoutParamsWithDefaults,
    pragmas = nnkPragma.newTree(ident "noinit")
  )

  var recList = newNimNode(nnkRecList)
  var item = TCacheItem()
  if baseName.isNil:
    baseName = newIdentNode("TArrayPacket")
  else:
    var baseParams: seq[NimNode] = concatParams($baseName)
    for param in baseParams:
      var varData: auto = param.extractFromVar(true)
      initProc.params.add(newIdentDefs(varData.fieldName, varData.fieldType, varData.fieldDefault))
      initProcRes.add(nnkExprColonExpr.newTree(varData.fieldName, varData.fieldName))
      if varData.fieldExported:
        fieldList.add(newStrLitNode($varData.fieldName))
        requiredList.add(newStrLitNode(if vardata.fieldAsName == "": $varData.fieldName else: vardata.fieldAsName))
        let f = generateArrayPacketDeserFunc(varData, typeName, setupMap)
        setupFuncs.add(f)
        if not (varData.fieldAsName == ""):
          mappedList.add(nnkExprColonExpr.newTree(newStrLitNode($varData.fieldName), newStrLitNode(varData.fieldAsName)))
        generateForMacroArrayVarBlock(internalStmts, varData.fieldName)
      if varData.fieldDefault.kind != nnkEmpty:
        initProcResWithoutParamsWithDefaults.add(nnkExprColonExpr.newTree(varData.fieldName, varData.fieldDefault))
    if packetCache.hasKey($baseName):
      item.base = $baseName

  for child in body.children:
    case child.kind:
      of nnkVarSection:
        for n in child.children:
          var varData: auto = n.extractFromVar(true)
          initProc.params.add(newIdentDefs(varData.fieldName, varData.fieldType, varData.fieldDefault))
          initProcRes.add(nnkExprColonExpr.newTree(varData.fieldName, varData.fieldName))
          recList.add(varData.fieldForType)
          item.params.add(n)
          if varData.fieldExported:
            fieldList.add(newStrLitNode($varData.fieldName))
            requiredList.add(newStrLitNode(if vardata.fieldAsName == "": $varData.fieldName else: vardata.fieldAsName))
            let f = generateArrayPacketDeserFunc(varData, typeName, setupMap)
            setupFuncs.add(f)
            if not (varData.fieldAsName == ""):
              mappedList.add(nnkExprColonExpr.newTree(newStrLitNode($varData.fieldName), newStrLitNode(varData.fieldAsName)))
            generateForMacroArrayVarBlock(internalStmts, varData.fieldName)
          if varData.fieldDefault.kind != nnkEmpty:
            initProcResWithoutParamsWithDefaults.add(nnkExprColonExpr.newTree(varData.fieldName, varData.fieldDefault))
      else:
        error("Not supported")
  if internalStmts.len == 0:
    generateForMacroFooter(internalStmts)
  packetCache[$typeName] = item
  result.add( 
    nnkTypeSection.newTree(
      nnkTypeDef.newTree(
        nnkPostfix.newTree(ident("*"), typeName),
        newEmptyNode(),
        nnkRefTy.newTree(
          nnkObjectTy.newTree(
            newEmptyNode(),
            nnkOfInherit.newTree(
              baseName
            ),
            recList
          )
        )
      )
    )
  )
  var references = newStmtList()
  var functions = newStmtList()
  functions.addRequired(references, requiredList, typeName)
  functions.addFields(references, fieldList, typeName)
  functions.addMapping(references, mappedList, typeName)
  functions.addArrayDeserMapping(references, setupMap, typeName)

  result.add(references)
  result.add(setupFuncs)
  result.add(functions)
  result.add(forMacro)

  if initProcRes.len != initProcResWithoutParamsWithDefaults.len:
    result.add(initProcWithoutParams)
  result.add(initProc)
  result = result.copy
  #echo result.treerepr
  when defined(packetDumpTree):
    echo result.repr

macro packet*(head, body: untyped): untyped =
  var typeName, baseName: NimNode
  var isExported: bool = true
  var bnIdx: int
  
  case head.kind
  of nnkIdent:
    typeName = head
  of nnkInfix:
    if eqIdent(head[0], "*"):
      typeName = head[1]
      bnIdx = 2
      isExported = true
      baseName = head[2][1]
    else:
      typeName = head[1]
      baseName = head[2]
  else:
    error "Invalid node: " & head.lispRepr

  result = newStmtList()
  var setupFuncs = newStmtList()
  var setupMap = newStmtList()
  var fieldList = nnkBracket.newTree()
  var requiredList = nnkBracket.newTree()
  var mappedList = nnkTableConstr.newTree()
  var initProcRes = nnkObjConstr.newTree(typeName)
  var initBody = nnkStmtList.newTree(nnkAsgn.newTree(ident"result", initProcRes))
  var initProcResWithoutParamsWithDefaults = nnkObjConstr.newTree(typeName)
  var initBodyWithoutParamsWithDefaults = nnkStmtList.newTree(nnkAsgn.newTree(ident"result", initProcResWithoutParamsWithDefaults))
  var internalStmts = newStmtList()
  var forMacro = generateForMacroHeader(typeName, internalStmts)

  when not defined(disablePacketIDs):
    initProcRes.add(
      nnkExprColonExpr.newTree(idIdent, newIntLitNode(generateId($typeName, (if not baseName.isNil: $baseName else: ""))))
    )
    initProcResWithoutParamsWithDefaults.add(
      nnkExprColonExpr.newTree(idIdent, newIntLitNode(generateId($typeName, (if not baseName.isNil: $baseName else: ""))))
    )
    fieldList.add(newStrLitNode("id"))
    requiredList.add(newStrLitNode("id"))
    setupFuncs.add(generateIDPacketDeserFunc(typename, setupMap))
    generateForMacroVarBlock(internalStmts, ident "id", "id")

  var initProc = newProc(
    name = initIdent,
    params = @[
      typeName, # the return type comes first
      newIdentDefs(ident"_", newTree(nnkBracketExpr, ident"type", typeName))
    ],
    body = initBody,
    pragmas = nnkPragma.newTree(ident "noinit")
  )
  var initProcWithoutParams = newProc(
    name = initIdent,
    params = @[
      typeName, # the return type comes first
      newIdentDefs(ident"_", newTree(nnkBracketExpr, ident"type", typeName))
    ],
    body = initBodyWithoutParamsWithDefaults,
    pragmas = nnkPragma.newTree(ident "noinit")
  )
  var recList = newNimNode(nnkRecList)
  var item = TCacheItem()
  var baseParams: seq[NimNode] = @[]
  if baseName.isNil:
    baseName = newIdentNode("TPacket")
  else:
    baseParams = concatParams($baseName)
    for param in baseParams:
      var varData: auto = param.extractFromVar()
      initProc.params.add(newIdentDefs(varData.fieldName, varData.fieldType, varData.fieldDefault))
      initProcRes.add(nnkExprColonExpr.newTree(varData.fieldName, varData.fieldName))
      if varData.fieldExported:
        fieldList.add(newStrLitNode($varData.fieldName))
        let fieldName = (if vardata.fieldAsName == "": $varData.fieldName else: vardata.fieldAsName)
        if varData.fieldRequired:
          requiredList.add(newStrLitNode(fieldName))
        if not (varData.fieldAsName == ""):
          mappedList.add(nnkExprColonExpr.newTree(newStrLitNode($varData.fieldName), newStrLitNode(varData.fieldAsName)))
        let f = generatePacketDeserFunc(varData, typeName, setupMap)
        setupFuncs.add(f)
        generateForMacroVarBlock(internalStmts, varData.fieldName, fieldName)
      if varData.fieldDefault.kind != nnkEmpty:
        initProcResWithoutParamsWithDefaults.add(nnkExprColonExpr.newTree(varData.fieldName, varData.fieldDefault))
    if packetCache.hasKey($baseName):
      item.base = $baseName

  for child in body.children:
    case child.kind:
      of nnkVarSection:
        for n in child.children:
          var varData: auto = n.extractFromVar()
          initProc.params.add(newIdentDefs(varData.fieldName, varData.fieldType, varData.fieldDefault))
          initProcRes.add(nnkExprColonExpr.newTree(varData.fieldName, varData.fieldName))
          recList.add(varData.fieldForType)
          item.params.add(n)
          if varData.fieldExported:
            let fieldName = (if vardata.fieldAsName == "": $varData.fieldName else: vardata.fieldAsName)
            fieldList.add(newStrLitNode($varData.fieldName))
            if varData.fieldRequired:
              requiredList.add(newStrLitNode(fieldName))
            if not (varData.fieldAsName == ""):
              mappedList.add(nnkExprColonExpr.newTree(newStrLitNode($varData.fieldName), newStrLitNode(varData.fieldAsName)))
            let f = generatePacketDeserFunc(varData, typeName, setupMap)
            setupFuncs.add(f)
            generateForMacroVarBlock(internalStmts, varData.fieldName, fieldName)
          if varData.fieldDefault.kind != nnkEmpty:
            initProcResWithoutParamsWithDefaults.add(nnkExprColonExpr.newTree(varData.fieldName, varData.fieldDefault))
      else:
        error("Not supported")
  
  if internalStmts.len == 0:
    generateForMacroFooter(internalStmts)

  packetCache[$typeName] = item
  result.add( 
    nnkTypeSection.newTree(
      nnkTypeDef.newTree(
        nnkPragmaExpr.newTree(
          nnkPostfix.newTree(ident("*"), typeName),
          nnkPragma.newTree(ident "acyclic")
        ),
        newEmptyNode(),
        nnkRefTy.newTree(
          nnkObjectTy.newTree(
            newEmptyNode(),
            nnkOfInherit.newTree(
              baseName
            ),
            recList
          )
        )
      )
    )
  )

  var references = newStmtList()
  var functions = newStmtList()
  functions.addRequired(references, requiredList, typeName)
  functions.addFields(references, fieldList, typeName)
  functions.addMapping(references, mappedList, typeName)
  functions.addDeserMapping(references, setupMap, typeName)

  result.add(references)
  result.add(setupFuncs)
  result.add(functions)
  result.add(forMacro)

  if initProcRes.len != initProcResWithoutParamsWithDefaults.len:
    result.add(initProcWithoutParams)
  result.add(initProc)
  result = result.copy
  when defined(packetDumpTree):
    echo result.repr

#--------------------------------------------------------------------------#

proc concatParams(base: string): seq[NimNode] {.compiletime.} =
  var x: seq[NimNode] = @[]
  if packetCache.hasKey(base):
    var baseItem: TCacheItem = packetCache[base]
    x = x & concatParams(baseItem.base)
    x = x & baseItem.params
  result = deduplicate(x)

proc concatBases(base: string): seq[string] {.compiletime.} =
  var x: seq[string] = @[]
  if packetCache.hasKey(base):
    var baseItem: TCacheItem = packetCache[base]
    x = x & concatBases(baseItem.base)
  if base.len() > 0:
    x = x & base
  result = x

proc generateId(name, base: string): int32 {.compiletime.} =
  var hash:string = join(concatBases(base) & name, "__")
  let packetId: BiggestInt = BiggestInt(crc32(hash))
  var id: int32
  if packetId >= int32.high:
    id = int32(packetId - 1.shl(32))
  else:
    id = int32(packetId)
  result = id

proc extractFromVar(n: NimNode, asArray: bool = false): TVarData {.compiletime.}=
  var fieldName, fieldType, fieldDefault: NimNode
  var fieldExported: bool = false
  var fieldRequired: bool = true
  var fieldAsName: string = ""
  #echo "VarSection " & n.treeRepr
  case n[0].kind:
  of nnkPragmaExpr:
    if n[0][0].kind == nnkPostfix:
      fieldExported = true
      fieldName = n[0][0][1]
    else:
      fieldName = n[0][0]
    for p in n[0][1].children:
      if p.kind == nnkExprColonExpr and eqIdent(p[0], "as_name"):
        fieldAsName = $p[1]
  of nnkIdent:
    fieldName = n[0]
  of nnkPostfix:
    fieldExported = true
    fieldName = n[0][1]
  else:
    error "Node kind not supported: " & n.treeRepr
  fieldType = n[1]
  if fieldType.kind == nnkBracketExpr and eqIdent(fieldType[0], "Option"):
    if asArray:
      error "Optional fields not possible in array packets"
    else:
      fieldRequired = false
  if fieldRequired:
    fieldDefault = (if n[2].kind == nnkNilLit: newEmptyNode() else: n[2])
  else:
    case n[2].kind:
    of nnkEmpty:
      fieldDefault = nnkCall.newTree(ident("none"), fieldType[1])
    of nnkCall:
      if eqIdent(n[2][0], "option"):
        fieldDefault = n[2]
      else:
        fieldDefault = nnkCall.newTree(
          newIdentNode("option"),
          n[2]
        )
    else:
      fieldDefault = nnkCall.newTree(
        newIdentNode("option"),
        n[2]
      )
  #echo "FIELD: " & $fieldName & ", " & fieldType.repr & ", " & fieldDefault.treeRepr
  result = TVarData(
    fieldName: fieldName, 
    fieldType: fieldType,
    fieldDefault: fieldDefault,
    fieldForType: newIdentDefs(n[0], fieldType, newEmptyNode()), 
    fieldExported: fieldExported, 
    fieldRequired: fieldRequired,
    fieldAsName: fieldAsName
  )

proc generateRefFunct(tName, retType: NimNode, ending, fun: static string): (NimNode, NimNode) {.compiletime.} =
  let fName = ident (($tName).normalize() & ending.nimIdentNormalize())
  let fun = newIdentNode(fun)
  #echo "generateRefFunct: ", $fun, " : ", $fName, ", ", $tName
  let reference = quote do:
    proc `fun`*(`packetIdent`: `tName`): lent `retType`
    proc `fun`*(`packetIdent`: type[`tName`]): lent `retType`

  let funcs = quote do:
    proc `fun`*(`packetIdent`: `tName`): lent `retType` =
      `fName`
    proc `fun`*(`packetIdent`: type[`tName`]): lent `retType` =
      `fName`
  result = (reference, funcs)

proc addRequired(to, refs: var NimNode, requiredList, typeName: NimNode) {.compiletime.} =
  let name = ident ($typeName).normalize() & "Required"
  if requiredList.len == 0:
    to.add(
      quote do:
        const `name`: HashSet[string] = initHashSet[string]()
    )
  else:
    to.add(
      quote do:
        const `name`: HashSet[string] = `requiredList`.toHashSet()
    )
  let (references, funcs) = generateRefFunct(typeName, nnkBracketExpr.newTree(newIdentNode("HashSet"), newIdentNode("string")), "Required", "requiredFields")
  to.add(funcs)
  refs.add(references)

proc addFields(to, refs: var NimNode, fieldList, typeName: NimNode) {.compiletime.} =
  let name = ident ($typeName).normalize() & "Fields"
  to.add(
    quote do:
      let `name`: seq[string] = @`fieldList`
  )
  let (references, funcs) = generateRefFunct(typeName, nnkBracketExpr.newTree(newIdentNode("seq"), newIdentNode("string")), "Fields", "packetFields")
  to.add(funcs)
  refs.add(references)

proc addMapping(to, refs: var NimNode, mappedList, typeName: NimNode) {.compiletime.} =
  let name = ident ($typeName).normalize() & "Mapping"
  to.add(
    if mappedList.len > 0: 
      quote do:
        let `name`: TableRef[string, string] = `mappedList`.newTable
    else:
      quote do:
        let `name`: TableRef[string, string] = TableRef[string, string]()
  )
  let (references, funcs) = generateRefFunct(typeName, nnkBracketExpr.newTree(newIdentNode("TableRef"), newIdentNode("string"), newIdentNode("string")), "Mapping", "mapping")
  to.add(funcs)
  refs.add(references)

proc addDeserMapping(to, refs: var NimNode, mappedList, typeName: NimNode) {.compiletime.} =
  let name = ident ($typeName).normalize() & "DeserMapping"
  to.add(
    quote do:
      var `name`: OrderedTableRef[string, TPacketFieldSetFunc] = newOrderedTable[string, TPacketFieldSetFunc]()
  )
  to.add(mappedList)
  let (references, funcs) = generateRefFunct(typeName, nnkBracketExpr.newTree(newIdentNode("OrderedTableRef"), newIdentNode("string"), newIdentNode("TPacketFieldSetFunc")), "DeserMapping", "deserMapping")
  to.add(funcs)
  refs.add(references)

proc addArrayDeserMapping(to, refs: var NimNode, mappedList, typeName: NimNode) {.compiletime.} =
  let name = ident ($typeName).normalize() & "DeserMapping"
  to.add(
    quote do:
      var `name`: seq[TPacketFieldSetFunc] = @[]
  )
  to.add(mappedList)
  let (references, funcs) = generateRefFunct(typeName, nnkBracketExpr.newTree(newIdentNode("seq"), newIdentNode("TPacketFieldSetFunc")), "DeserMapping", "deserMapping")
  to.add(funcs)
  refs.add(references)

proc generatePacketSetupFunc(variable: TVarData, typeName: NimNode): (NimNode, NimNode) {.compiletime.} =
  let procName = ident "`" & ($typeName).normalize() & ($variable.fieldName).capitalizeAscii() & "=`"
  let typeName = ident $typeName
  let fieldName = variable.fieldName
  let fieldType = variable.fieldType
  let res = quote do:
    proc `procName`*(`packetIdent`: TPacket, `dataIdent`: TPacketDataSource) = 
      let packet = cast[`typeName`](`packetIdent`)
      packet.`fieldName` = `dataIdent`.load(`fieldType`)
  result = (procName, res)

proc generatePacketDeserFunc(variable: TVarData, typeName: NimNode, setupMap: NimNode): NimNode {.compiletime.} =
  let name = ident ($typeName).normalize() & "DeserMapping"
  let strFieldName = (if variable.fieldAsName == "": newStrLitNode($(variable.fieldName)) else: newStrLitNode($(variable.fieldAsName)))
  let (procName, res) = generatePacketSetupFunc(variable, typeName)
  setupMap.add(
    quote do:
      `name`[`strFieldName`] = `procName`
  )
  result = res

proc generateArrayPacketDeserFunc(variable: TVarData, typeName: NimNode, setupSeq: NimNode): NimNode {.compiletime.} =
  let name = ident ($typeName).normalize() & "DeserMapping"
  let (procName, res) = generatePacketSetupFunc(variable, typeName) 
  setupSeq.add(
    quote do:
      `name`.add(`procName`)
  )
  result = res

proc generateIDPacketCheckFunc(typeName: NimNode): (NimNode, NimNode) {.compiletime.} =
  let procName = ident "`" & ($typeName).normalize() & ("id").capitalizeAscii() & "=`"
  let typeName = ident $typeName
  let res = quote do:
    proc `procName`*(`packetIdent`: TPacket, `dataIdent`: TPacketDataSource) = 
      let packet = cast[`typeName`](`packetIdent`)
      let id = `dataIdent`.load(int32)
      if packet.`idIdent` != id:
        raise newException(ValueError, "ID's not same: " & $(packet.`idIdent`) & " != " & $id) 
  result = (procName, res)

proc generateIDPacketDeserFunc(typeName: NimNode, setupMap: NimNode): NimNode {.compiletime.} =
  let name = ident ($typeName).normalize() & "DeserMapping"
  let (procName, res) = generateIDPacketCheckFunc(typeName)
  setupMap.add(
    quote do:
      `name`["id"] = `procName`
  )
  result = res

proc generateIDArrayPacketDeserFunc(typeName: NimNode, setupSeq: NimNode): NimNode {.compiletime.} =
  let name = ident ($typeName).normalize() & "DeserMapping"
  let (procName, res) = generateIDPacketCheckFunc(typeName) 
  setupSeq.add(
    quote do:
      `name`.add(`procName`)
  )
  result = res

proc generateForMacroHeader(typeName, internalStmts: NimNode): NimNode {.compiletime.} =
  let name = ident $typeName
  result = newStmtList(
    nnkMacroDef.newTree(
      nnkPostfix.newTree(
        ident "*",
        ident "forFields"
      ),
      newEmptyNode(),
      newEmptyNode(),
      nnkFormalParams.newTree(
        ident "untyped",
        newIdentDefs(ident "pkt", name, newEmptyNode()),
        newIdentDefs(ident "body", ident "untyped", newEmptyNode()),
      ),
      newEmptyNode(),
      newEmptyNode(),
      newStmtList(
        newLetStmt(
          nnkAccQuoted.newTree(ident "fieldIdent"), 
          nnkCommand.newTree(ident "ident", newStrLitNode("fieldValue"))
        ),
        newLetStmt(
          nnkAccQuoted.newTree(ident "nameIdent"), 
          nnkCommand.newTree(ident "ident", newStrLitNode("fieldName"))
        ),
        newAssignment(ident "result", newCall(ident "newStmtList")),
        newCall(
          newDotExpr(ident "result", ident "add"),
          newCall(ident "quote", internalStmts)
        )
      )
    )
  )

proc generateForMacroArrayVarBlock(stmts: var NimNode, variable: NimNode) {.compiletime.} =
  stmts.add(
    newBlockStmt(
      newStmtList(
        newLetStmt(
          nnkAccQuoted.newTree(ident "fieldIdent"),
          newDotExpr(
            nnkAccQuoted.newTree(ident "pkt"),
            variable
          )
        ),
        nnkAccQuoted.newTree(ident "body")
      )
    )
  )
  #echo stmts.repr()

proc generateForMacroVarBlock(stmts: var NimNode, variable: NimNode, asName: string) {.compiletime.} =
  stmts.add(
    newBlockStmt(
      newStmtList(
        newLetStmt(
          nnkAccQuoted.newTree(ident "fieldIdent"),
          newDotExpr(
            nnkAccQuoted.newTree(ident "pkt"),
            variable
          )
        ),
        newLetStmt(
          nnkAccQuoted.newTree(ident "nameIdent"),
          newStrLitNode(asName)
        ),
        nnkAccQuoted.newTree(ident "body")
      )
    )
  )

proc generateForMacroFooter(stmts: var NimNode) {.compiletime.} =
  stmts.add(
    quote do:
      discard
  )