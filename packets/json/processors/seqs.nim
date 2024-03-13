import ../context

# ------------------- Load

proc load*[T](ctx: var TPacketDataSource, t: typedesc[seq[T]]): seq[T] =
  mixin load
  if ctx.toCtx.parser.tok == tkBracketLe:
    discard ctx.toCtx.parser.getTok()
    while ctx.toCtx.parser.tok != tkBracketRi:
      result.add(ctx.load(T))
      if ctx.toCtx.parser.tok != tkComma:
        break
      discard ctx.toCtx.parser.getTok() #skipping "," token
    eat(ctx.toCtx.parser, tkBracketRi)
  else:
    raise newException(ValueError, "Not an array")

# ------------------- Dump

proc dump*[T](t: seq[T]): string =
  mixin dump
  result = "["
  var first: bool = true
  for v in t:
    if first:
      first = false
    else:
      result.add(",") 
    result.add(v.dump())
  result.add("]")
