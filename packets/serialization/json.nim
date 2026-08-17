import std/[tables, streams, macros]
import json/context
import json/processors/[booleans, numerics, strs, datetimes, enums, optionals, seqs, sets, subpackets, tables]


export booleans, numerics, strs, datetimes, enums, optionals, seqs, sets, subpackets, tables


# ------------------- Load

proc loads*[T: TPacket | TArrayPacket](p: type[T], jsStream: Stream): T =
  var ctx = newDataSourceJson()
  ctx.parser.open(jsStream)
  try:
    ctx.parser.getTok()
    result = T.load(ctx)
  finally:
    ctx.parser.close()


proc loads*[T: TPacket | TArrayPacket](p: type[T], js: sink string): T =
  let jsStream = newStringStream(js)
  try:
    result = p.loads(jsStream)
  finally:
    jsStream.close()


proc loads*[T: TPacket | TArrayPacket](p: type[seq[T]], jsStream: Stream): seq[T] =
  var ctx = newDataSourceJson()
  ctx.parser.open(jsStream)
  try:
    ctx.parser.getTok()
    result = seq[T].load(ctx)
  finally:
    ctx.parser.close()


proc loads*[T: TPacket | TArrayPacket](p: type[seq[T]], js: sink string): seq[T] =
  let jsStream = newStringStream(js)
  try:
    result = p.loads(jsStream)
  finally:
    jsStream.close()


iterator items*[T](p: type[seq[T]], jsStream: Stream): T =
  var ctx = newDataSourceJson()
  ctx.parser.open(jsStream)
  try:
    ctx.parser.getTok()
    for i in seq[T].items(ctx):
      yield i
  finally:
    ctx.parser.close()

# ------------------- Dump

proc dumps*[T: TPacket | TArrayPacket](p: T): string =
  mixin dump
  p.dump(result)


proc dumps*[T: TPacket | TArrayPacket](p: seq[T]): string =
  mixin dump
  p.dump(result)


type
  JsonType* = enum
    JT_NULL,
    JT_BOOL,
    JT_INT,
    JT_FLOAT,
    JT_STRING,
    JT_ARRAY,
    JT_OBJ
  
  Json* = ref JsonObj
  JsonObj* {.acyclic.} = object
    case jt: JsonType
    of JT_NULL:
      nil
    of JT_BOOL:
      b: bool
    of JT_INT:
      i: int
    of JT_FLOAT:
      f: float
    of JT_STRING:
      s: string
    of JT_ARRAY:
      a: seq[Json]
    of JT_OBJ:
      o: OrderedTable[string, Json]

  JsonError* = object of CatchableError
  JsonParseError* = object of JsonError
  JsonValueError* = object of JsonError


func newJObject*(): Json {.inline.} = Json(jt: JT_OBJ, o: initOrderedTable[string, Json](2))
func newJArray*(): Json {.inline.} = Json(jt: JT_ARRAY, a: @[])
func newJNull*(): Json {.inline.} = Json(jt: JT_NULL)
func newJBool*(b: bool): Json {.inline.} = Json(jt: JT_BOOL, b: b)
func newJFloat*(f: float): Json {.inline.} = Json(jt: JT_FLOAT, f: f)
func newJInt*(i: int): Json {.inline.} = Json(jt: JT_INT, i: i)
func newJString*(s: sink string): Json {.inline.} = Json(jt: JT_STRING, s: s)


proc parse(parser: JsonParser, firstRun: bool = false): Json =
  var val: Json
  if firstRun:
    parser.getTok()
    if parser.tok != tkCurlyLe and parser.tok != tkBracketLe:
      raise newException(JsonParseError, "Wrong start token " & $parser.tok)
  case parser.tok
  of tkError:
    raise newException(JsonParseError, "Wrong token " & $parser.tok)
  of tkCurlyLe:
    result = newJObject()
    parser.eat(tkCurlyLe)
    var currKey: string
    while parser.tok != tkCurlyRi:
      currKey = parser.getString()
      parser.getTok()
      parser.eat(tkColon)
      val = parser.parse()
      result.o[currKey] = val
      if parser.tok != tkComma:
        break
      parser.getTok() #skipping "," token
    parser.eat(tkCurlyRi)
  of tkBracketLe:
    result = newJArray()
    parser.eat(tkBracketLe)
    while parser.tok != tkBracketRi:
      val = parser.parse()
      result.a.add(val)
      if parser.tok == tkComma:
        parser.getTok() #skipping "," token
    parser.eat(tkBracketRi)
  of tkNull:
    result = newJNull()
    parser.getTok()
  of tkInt:
    if parser.isFloat():
      result = Json(jt: JT_FLOAT)
      result.f = getFloat[float](parser)
    else:
      result = Json(jt: JT_INT)
      result.i = getInt[int](parser)
    parser.getTok()
  of tkFalse, tkTrue:
    result = newJBool(parser.tok == tkTrue)
    parser.getTok()
  of tkString:
    result = Json(jt: JT_STRING)
    result.s = parser.getString()
    parser.getTok()
  else:
    parser.getTok()


proc load*(js: Stream): Json =
  let parser = new JsonParser
  try:
    parser.open(js)
    result = parser.parse(true)
  finally:
    parser.close()


proc loads*(js: sink string): Json =
  let strm = newStringStream(js)
  try:
    result = strm.load()
  finally:
    strm.close()


proc dump(json: Json, to: Stream, currIdent: var int, identStep: int) =
  #let yesCR = identStep > 0
  var first: bool
  case json.jt
  of JT_OBJ:
    to.write(strLCurly)
    currIdent.inc(identStep)
    first = true
    for k, v in json.o.pairs:
      if not first:
        to.write(strComma)
      first = false
      to.write(strQuote)
      to.write(k)
      to.write(strQuoteColon)
      v.dump(to, currIdent, identStep)
    currIdent.dec(identStep)
    to.write(strRCurly)
  of JT_ARRAY:
    to.write(strLBracket)
    currIdent.inc(identStep)
    first = true
    for v in json.a.items:
      if not first:
        to.write(strComma)
      first = false
      v.dump(to, currIdent, identStep)
    currIdent.dec(identStep)
    to.write(strRBracket)
  of JT_NULL:
    to.write("null")
  of JT_BOOL:
    to.write(if json.b: "true" else: "false")
  of JT_FLOAT:
    to.write($json.f)
  of JT_INT:
    to.write($json.i)
  of JT_STRING:
    to.write(strQuote)
    to.write(json.s)
    to.write(strQuote)


proc dump*(json: Json, to: Stream, ident: int = 0) =
  var indent = 0
  json.dump(to, indent, ident)


proc dumps*(json: Json, ident: int = 0): string =
  var to = newStringStream()
  json.dump(to, ident)
  to.setPosition(0)
  result = to.data
  to.close()


func isNil*(json: Json): bool {.inline.} = json.jt == JT_NULL


func asBool*(json: Json): bool {.inline.} =
  if json.jt == JT_BOOL:
    result = json.b
  else:
    raise newException(JsonValueError, "json must be bool")


func asInt*(json: Json): int {.inline.} =
  if json.jt == JT_INT:
    result = json.i
  else:
    raise newException(JsonValueError, "json must be a string")


func asFloat*(json: Json): float {.inline.} =
  if json.jt == JT_INT:
    result = json.i.float
  elif json.jt == JT_FLOAT:
    result = json.f
  else:
    raise newException(JsonValueError, "json must be a string")


func asString*(json: Json): string {.inline.} =
  if json.jt == JT_STRING:
    result = json.s
  else:
    raise newException(JsonValueError, "json must be a string")


proc `[]`*(json: Json, k: string): Json =
  if json.jt == JT_OBJ:
    result = json.o.getOrDefault(k, newJNull())
  else:
    raise newException(JsonValueError, "json must be an object")


proc `[]`*(json: Json, i: int): Json =
  if json.jt == JT_ARRAY:
    result = json.a[i]
  else:
    raise newException(JsonValueError, "json must be an array")


iterator items*(json: Json): Json =
  if json.jt == JT_ARRAY:
    for v in json.a.items:
      yield v
  else:
    raise newException(JsonValueError, "json must be an array")


iterator pairs*(json: Json): (string, Json) =
  if json.jt == JT_OBJ:
    for k,v in json.o.pairs:
      yield (k, v)
  else:
    raise newException(JsonValueError, "json must be an object")


proc len*(json: Json): int =
  if json.jt == JT_ARRAY:
    result = json.a.len
  else:
    raise newException(JsonValueError, "json must be an array")
  

template js*(v: Json): Json = v
func js*(v: type(nil)): Json {.inline.} = newJNull()
func js*(v: bool): Json {.inline.} = newJBool(v)
func js*(v: int): Json {.inline.} = newJInt(v)
func js*(v: float): Json {.inline.} = newJFloat(v)
func js*(v: sink string): Json {.inline.} = newJString(v)
func js*[T](v: openArray[T]): Json {.inline.}
func js*[T](v: sink Table[string, T] | sink OrderedTable[string, T]): Json {.inline.}
func js*(v: openArray[tuple[k: string, i: Json]]): Json {.inline.}
func js*[T: object](v: T): Json {.inline.}
func js*(v: ref object): Json {.inline.}


proc `[]=`*(json: Json, k: string, v: type(nil)) =
  if json.jt == JT_OBJ:
    json.o[k] = newJNull()
  else:
    raise newException(JsonValueError, "json must be an object")


proc `[]=`*[T: bool | int | float](json: Json, k: string, v: T) =
  if json.jt == JT_OBJ:
    json.o[k] = v.js
  else:
    raise newException(JsonValueError, "json must be an object")


proc `[]=`*(json: Json, k: string, v: sink string) =
  if json.jt == JT_OBJ:
    json.o[k] = newJString(v)
  else:
    raise newException(JsonValueError, "json must be an object")


proc `[]=`*(json: Json, k: string, v: enum) =
  if json.jt == JT_OBJ:
    json.o[k] = newJString($v)
  else:
    raise newException(JsonValueError, "json must be an object")


proc `[]=`*[T](json: Json, k: string, v: openArray[T]) =
  if json.jt == JT_OBJ:
    json.o[k] = v.js
  else:
    raise newException(JsonValueError, "json must be an object")


proc `[]=`*(json: Json, k: string, v: Json) =
  if json.jt == JT_OBJ:
    json.o[k] = v
  else:
    raise newException(JsonValueError, "json must be an object")


proc `[]=`*(json: Json, k: int, v: Json) =
  if json.jt == JT_ARRAY:
    json.a[k] = v
  else:
    raise newException(JsonValueError, "json must be an array")


proc add*[T: bool | int | float](json: Json, v: T) =
  if json.jt == JT_ARRAY:
    json.a.add(v.js)
  else:
    raise newException(JsonValueError, "json must be an array")


proc add*(json: Json, v: sink string) =
  if json.jt == JT_ARRAY:
    json.a.add(v.js)
  else:
    raise newException(JsonValueError, "json must be an array")


proc add*(json: Json, v: Json) =
  if json.jt == JT_ARRAY:
    json.a.add(v)
  else:
    raise newException(JsonValueError, "json must be an array")


func js*[T](v: openArray[T]): Json {.inline.} =
  result = newJArray()
  for i in v:
    result.add(i)


func js*[T](v: sink Table[string, T] | sink OrderedTable[string, T]): Json {.inline.} =
  result = newJObject()
  for k,i in v.pairs:
    result[k] = i


func js*(v: openArray[tuple[k: string, i: Json]]): Json {.inline.} =
  result = newJObject()
  for k, i in v.items: 
    result.o[k] = i


func js*[T: object](v: T): Json {.inline.} =
  result = newJObject()
  for k, i in v.fieldPairs: 
    result[k] = i


func js*(v: ref object): Json {.inline.} =
  if v.isNil:
    result = newJNull()
  else:
    result = v[].js


proc toJsonInternal(x: NimNode): NimNode =
  case x.kind
  of nnkBracket: # array
    if x.len == 0: return newCall(bindSym"newJArray")
    result = newNimNode(nnkBracket)
    for i in 0 ..< x.len:
      result.add(toJsonInternal(x[i]))
    result = newCall(bindSym("js", brOpen), result)
  of nnkTableConstr: # object
    if x.len == 0: return newCall(bindSym"newJObject")
    result = newNimNode(nnkTableConstr)
    for i in 0 ..< x.len:
      x[i].expectKind nnkExprColonExpr
      result.add newTree(nnkExprColonExpr, x[i][0], toJsonInternal(x[i][1]))
    result = newCall(bindSym("js", brOpen), result)
  of nnkCurly: # empty object
    x.expectLen(0)
    result = newCall(bindSym"newJObject")
  of nnkNilLit:
    result = newCall(bindSym"newJNull")
  of nnkPar:
    if x.len == 1: result = toJsonInternal(x[0])
    else: result = newCall(bindSym("js", brOpen), x)
  else:
    result = newCall(bindSym("js", brOpen), x)


macro `%*`*(x: untyped): untyped =
  ## Convert an expression to a Json directly, without having to specify
  ## `%` for every element.
  result = toJsonInternal(x)
