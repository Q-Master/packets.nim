import ../context

# ------------------- Load

proc begin*[T](_: type[seq[T]], ctx: var TPacketDataSource) = 
  if ctx.toCtx.parser.tok == tkBracketLe:
    discard ctx.toCtx.parser.getTok()
  else:
    raise newException(ValueError, "Not an array")

proc next*[T](ctx: var TPacketDataSource, dest: var T): bool =
  mixin load
  if ctx.toCtx.parser.tok != tkBracketRi:
    load(ctx, dest)
    if ctx.toCtx.parser.tok == tkComma:
      discard ctx.toCtx.parser.getTok() #skipping "," token
    result = true
  else:
    eat(ctx.toCtx.parser, tkBracketRi)
    result = false

proc load*[T](ctx: var TPacketDataSource, dest: var seq[T]) =
  var d: T
  seq[T].begin(ctx)
  while true:
    if ctx.next(d):
      dest.add(d)
    else:
      break

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
