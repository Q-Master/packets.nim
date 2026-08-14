import std/[sets]
import ../context

# ------------------- Load

iterator items*[T](_: typedesc[SomeSet[T]], ctx: TPacketDataSource): T =
  mixin load
  if ctx.toCtx.parser.tok == tkBracketLe:
    ctx.toCtx.parser.getTok()
  else:
    raise newException(ValueError, "Not an array")
  while true:
    if ctx.toCtx.parser.tok != tkBracketRi:
      yield T.load(ctx)
      if ctx.toCtx.parser.tok == tkComma:
        ctx.toCtx.parser.getTok() #skipping "," token
    else:
      ctx.toCtx.parser.eat(tkBracketRi)
      break


proc load*[T](_: typedesc[HashSet[T]], ctx: TPacketDataSource): HashSet[T] =
  for i in seq[T].items(ctx):
    result.add(i)


proc load*[T](_: typedesc[OrderedSet[T]], ctx: TPacketDataSource): OrderedSet[T] =
  for i in seq[T].items(ctx):
    result.add(i)


# ------------------- Dump

proc dump*[T](t: SomeSet[T], dest: var string) =
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
