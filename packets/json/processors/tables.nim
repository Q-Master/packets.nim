import std/[tables]
import ../context

# ------------------- Load

template getKey[T: string](ctx: TPacketDataSource, k: var T) = ctx.toCtx.parser.getString(k)
template getKey[T: SomeInteger](ctx: TPacketDataSource, k: var T) = ctx.toCtx.parser.getInt[T](k)
template getKey[T: SomeFloat](ctx: TPacketDataSource, k: var T) = ctx.toCtx.parser.getFloat[T](k)


proc load*[U: string|SomeInteger|SomeFloat, T](ctx: TPacketDataSource, dest: var Table[U, T]) =
  mixin load
  var d: T
  if ctx.toCtx.parser.tok == tkCurlyLe:
    ctx.toCtx.parser.getTok()
    var currKey: U
    while ctx.toCtx.parser.tok != tkCurlyRi:
      ctx.getKey(currKey)
      ctx.toCtx.parser.getTok()
      ctx.toCtx.parser.eat(tkColon)
      ctx.load(d)
      dest[currKey] = d 
      if ctx.toCtx.parser.tok != tkComma:
        break
      ctx.toCtx.parser.getTok() #skipping "," token
    ctx.toCtx.parser.eat(tkCurlyRi)
  else:
    raise newException(ValueError, "Not a table")

# ------------------- Dump

proc dump*[U, T](t: Table[U, T], dest: var string) =
  mixin dump
  dest.add(strLCurly)
  var first: bool = true
  for k,v in t.pairs:
    if first:
      first = false
    else:
      dest.add(strComma) 
    dest.add(strQuote)
    k.dump(dest)
    dest.add(strQuoteColon)
    v.dump(dest)
  dest.add(strRCurly)
