import std/[sets]
import ../context

# ------------------- Load

proc load*[T: TPacket](ctx: var TPacketDataSource, p: typedesc[T]): T =
  mixin load
  if ctx.toCtx.parser.tok == tkCurlyLe:
    var req = p.requiredFields()
    let deserMapping = p.deserMapping()
    var decodedPacket = p()
    discard ctx.toCtx.parser.getTok()
    while ctx.toCtx.parser.tok != tkCurlyRi:
      if ctx.toCtx.parser.tok != tkString:
        raise newException(ValueError, "Key must be string")
      let currKey = ctx.toCtx.parser.a
      req.excl(currKey) # mapped by default by a generator
      echo "!! ", currKey
      let loader = deserMapping.getOrDefault(currKey, nil)
      discard ctx.toCtx.parser.getTok()
      ctx.toCtx.parser.eat(tkColon)
      if loader.isNil:
        ctx.skip()
      else:
        loader(decodedPacket, ctx)
      if ctx.toCtx.parser.tok != tkComma:
        break
      discard ctx.toCtx.parser.getTok() #skipping "," token
    if req.len > 0:
      raise newException(ValueError, "Required field(s) " & $req & " missing (" & $p & ")")
    eat(ctx.toCtx.parser, tkCurlyRi)
    result = decodedPacket
  else:
    raise newException(ValueError, "Not an object")

proc load*[T: TArrayPacket](ctx: var TPacketDataSource, p: typedesc[T]): T =
  mixin load
  if ctx.toCtx.parser.tok == tkBracketLe:
    let deserMapping = p.deserMapping()
    var idx = 0
    result = p.new()
    discard ctx.toCtx.parser.getTok()
    while ctx.toCtx.parser.tok != tkBracketRi:
      #ArrayPacket's fields are all required fields
      if idx < deserMapping.len:
        let loader = deserMapping[idx]
        loader(TPacket(result), TPacketDataSource(ctx))
      else:
        discard ctx.toCtx.parser.getTok() #skipping extra data
      if ctx.toCtx.parser.tok != tkComma:
        break
      idx.inc()
      discard ctx.toCtx.parser.getTok() #skipping "," token
    eat(ctx.toCtx.parser, tkBracketRi)
    if idx < deserMapping.len-1:
      raise newException(ValueError, $(deserMapping.len - idx) & " required field(s) missing")
  else:
    raise newException(ValueError, "Not an object")

# ------------------- Dump

proc dump*[T: TPacket](p: T): string =
  mixin dump
  result = "{"
  let fields = p.packetFields()
  let m = p.mapping()
  var first: bool = true
  for k,v in p.fieldPairs:
    if k in fields:
      if first:
        first = false
      else:
        result.add(",") 
      result.add("\"" & m.getOrDefault(k, k) & "\":" & v.dump())
  result.add("}")

proc dump*[T: TArrayPacket](p: T): string =
  mixin dump
  result = "["
  let fields = p.packetFields()
  var first: bool = true
  when defined(enablePacketIDs):
    first = false
    result.add(p.id.dump())
  for k,v in p.fieldPairs:
    if k != "id" and k in fields:
      if first:
        first = false
      else:
        result.add(",") 
      result.add(v.dump())
  result.add("]")