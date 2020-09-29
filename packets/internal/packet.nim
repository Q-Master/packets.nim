import macros
import tables
import crc32
import sequtils
import strutils

type
    TCacheItem = object
        base: string
        params: seq[NimNode]
    TVarData = ref object
        fieldName*: NimNode
        fieldParam*: NimNode
        fieldParam2*: NimNode
        fieldExported*: bool
        fieldRequired*: bool
        fieldAsName*: string

proc concatParams(base: string): seq[NimNode] {.compiletime.}
proc concatBases(base: string): seq[string] {.compiletime.}
proc generateId(name, base: string): int32 {.compiletime.}
proc extractFromVar(n: NimNode): TVarData {.compiletime.}
proc generateRefFunct(tName, retType: NimNode, ending, fun: static string): NimNode {.compiletime.}
var packet_cache {.compiletime, global.}: Table[string, TCacheItem]

macro packet*(head, body: untyped): untyped =
    var typeName, baseName: NimNode
    var isExported: bool = true
    var bnIdx: int
    #echo head.treeRepr
    if head.kind == nnkIdent:
        typeName = head
    elif head.kind == nnkInfix:
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
    let initIdent = nnkPostfix.newTree(ident("*"), ident("init"))
    var fieldList = nnkBracket.newTree()
    var requiredList = nnkBracket.newTree()
    var mappedList = nnkTableConstr.newTree()
    var initProcRes = nnkObjConstr.newTree(typeName)
    var initProc = newProc(
        name = initIdent,
        params = @[
            typeName, # the return type comes first
            newIdentDefs(ident"_", newTree(nnkBracketExpr, ident"type", typeName))
        ],
        body = nnkStmtList.newTree(
            nnkAsgn.newTree(ident"result", initProcRes),
            nnkAsgn.newTree(nnkDotExpr.newTree(ident"result", ident"id"), newIntLitNode(generateId($typeName, (if not baseName.isNil: $baseName else: "")))),
        )
    )

    var recList = newNimNode(nnkRecList)
    var item = TCacheItem()
    var baseParams: seq[NimNode] = @[]
    if baseName.isNil:
        baseName = newIdentNode("TPacket")
    else:
        baseParams = concatParams($baseName)
        for param in baseParams:
            var varData: auto = extractFromVar(param)
            initProc.params.add(varData.fieldParam)
            initProcRes.add(nnkExprColonExpr.newTree(varData.fieldName, varData.fieldName))
            if varData.fieldExported:
                fieldList.add(newStrLitNode($varData.fieldName))
            if varData.fieldRequired:
                requiredList.add(newStrLitNode($varData.fieldName))
            if not (varData.fieldAsName == ""):
                mappedList.add(nnkExprColonExpr.newTree(newStrLitNode($varData.fieldName), newStrLitNode(varData.fieldAsName)))
        if packet_cache.hasKey($baseName):
            item.base = $baseName

    for child in body.children:
        case child.kind:
            of nnkVarSection:
                for n in child.children:
                    var varData: auto = extractFromVar(n)
                    initProc.params.add(varData.fieldParam)
                    initProcRes.add(nnkExprColonExpr.newTree(varData.fieldName, varData.fieldName))
                    recList.add(varData.fieldParam2)
                    item.params.add(n)
                    if varData.fieldExported:
                        fieldList.add(newStrLitNode($varData.fieldName))
                    if varData.fieldRequired and varData.fieldExported:
                        requiredList.add(newStrLitNode($varData.fieldName))
                    if not (varData.fieldAsName == ""):
                        mappedList.add(nnkExprColonExpr.newTree(newStrLitNode($varData.fieldName), newStrLitNode(varData.fieldAsName)))
            else:
                error("Not supported")
    
    packet_cache[$typeName] = item
    #if isExported:
    #    typeName = nnkPostfix.newTree(newIdentNode("*"), typeName)
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

    let required = nnkLetSection.newTree(
        nnkIdentDefs.newTree(
            newIdentNode($typeName&"required"),
            nnkBracketExpr.newTree(
                ident"seq",
                ident"string"
            ),
            nnkPrefix.newTree(
                ident"@",
                requiredList
            )
        )
    )
    result.add(required)
    result.add(generateRefFunct(typeName, nnkBracketExpr.newTree(newIdentNode("seq"), newIdentNode("string")), "required", "required_fields"))

    let fields = nnkLetSection.newTree(
        nnkIdentDefs.newTree(
            newIdentNode($typeName&"fields"),
            nnkBracketExpr.newTree(
                ident"seq",
                ident"string"
            ),
            nnkPrefix.newTree(
                ident"@",
                fieldList
            )
        )
    )
    result.add(fields)
    result.add(generateRefFunct(typeName, nnkBracketExpr.newTree(newIdentNode("seq"), newIdentNode("string")), "fields", "packet_fields"))

    let mapped = (if mappedList.len() > 0: nnkDotExpr.newTree(
        mappedList,
        newIdentNode("newTable")
    ) else:
        nnkCall.newTree(
            nnkBracketExpr.newTree(
                newIdentNode("TableRef"),
                newIdentNode("string"),
                newIdentNode("string")
            )
        )
    )
    let mapping = nnkLetSection.newTree(
        nnkIdentDefs.newTree(
            newIdentNode($typeName&"mapping"),
            nnkBracketExpr.newTree(
                newIdentNode("TableRef"),
                newIdentNode("string"),
                newIdentNode("string")
            ),
            mapped
        ),
    )
    result.add(mapping)
    result.add(generateRefFunct(typeName, nnkBracketExpr.newTree(newIdentNode("TableRef"), newIdentNode("string"), newIdentNode("string")), "mapping", "mapping"))

    result.add(initProc)
    result = result.copy
    #echo result.treerepr
    when defined(packetDumpTree):
        echo result.repr

#--------------------------------------------------------------------------#

proc concatParams(base: string): seq[NimNode] {.compiletime.} =
    var x: seq[NimNode] = @[]
    if packet_cache.hasKey(base):
        var baseItem: TCacheItem = packet_cache[base]
        x = x & concatParams(baseItem.base)
        x = x & baseItem.params
    result = deduplicate(x)

proc concatBases(base: string): seq[string] {.compiletime.} =
    var x: seq[string] = @[]
    if packet_cache.hasKey(base):
        var baseItem: TCacheItem = packet_cache[base]
        x = x & concatBases(baseItem.base)
    if base.len() > 0:
        x = x & base
    result = x

proc generateId(name, base: string): int32 {.compiletime.} =
    var hash:string = join(concatBases(base) & name, "__")
    let packet_id: BiggestInt = BiggestInt(crc32(hash))
    var id: int32
    if packet_id >= int32.high:
        id = int32(packet_id - 1.shl(32))
    else:
        id = int32(packet_id)
    result = id

proc extractFromVar(n: NimNode): TVarData {.compiletime.}=
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
    #echo "FIELD: " & $fieldName & ", " & fieldType.repr & ", " & fieldDefault.repr
    result = TVarData(
        fieldName: fieldName, 
        fieldParam: newIdentDefs(fieldName, fieldType, fieldDefault), 
        fieldParam2: newIdentDefs(n[0], fieldType, newEmptyNode()), 
        fieldExported: fieldExported, 
        fieldRequired: fieldRequired,
        fieldAsName: fieldAsName
    )

proc generateRefFunct(tName, retType: NimNode, ending, fun: static string): NimNode {.compiletime.} =
    let fName = newIdentNode($tName & ending)
    result = newStmtList()
    result.add(
        nnkProcDef.newTree(
            nnkPostfix.newTree(
                newIdentNode("*"),
                newIdentNode(fun),
            ),
            newEmptyNode(),
            newEmptyNode(),
            nnkFormalParams.newTree(
                retType,
                nnkIdentDefs.newTree(
                    newIdentNode("t"),
                    tName,
                    newEmptyNode()
                ),
            ),
            newEmptyNode(),
            newEmptyNode(),
            nnkStmtList.newTree(fName)
        )
    )
    result.add(
        nnkProcDef.newTree(
            nnkPostfix.newTree(
                newIdentNode("*"),
                newIdentNode(fun),
            ),
            newEmptyNode(),
            newEmptyNode(),
            nnkFormalParams.newTree(
                retType,
                nnkIdentDefs.newTree(
                    newIdentNode("t"),
                    nnkBracketExpr.newTree(
                        newIdentNode("type"),
                        tName,
                    ),
                    newEmptyNode()
                ),
            ),
            newEmptyNode(),
            newEmptyNode(),
            nnkStmtList.newTree(fName)
        )
    )

#[
template init*[T: TPacket](val: var T, args: varargs[typed]) =
    mixin defaults
    val = init(T, args)
]#