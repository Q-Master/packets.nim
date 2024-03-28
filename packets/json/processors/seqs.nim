import ../context

# ------------------- Load

proc load*[T](ctx: var TPacketDataSource, dest: var seq[T]) =
  mixin load
  if ctx.toCtx.parser.tok == tkBracketLe:
    discard ctx.toCtx.parser.getTok()
    while ctx.toCtx.parser.tok != tkBracketRi:
      var d: T
      load(ctx, d)
      dest.add(d)
      if ctx.toCtx.parser.tok != tkComma:
        break
      discard ctx.toCtx.parser.getTok() #skipping "," token
    eat(ctx.toCtx.parser, tkBracketRi)
  else:
    raise newException(ValueError, "Not an array")

# ------------------- Dump

const strLBracket = "["
const strRBracket = "]"
const strComma = ","

proc dump*[T](t: seq[T], dest: var string) =
  mixin dump
  dest.add(strLBracket)
  var first: bool = true
  for v in t:
    if first:
      first = false
    else:
      dest.add(strComma)
    v.dump(dest)
  dest.add(strRBracket)
