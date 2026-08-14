import std/[tables]
import ../context

# ------------------- Load

template getKey[T: string](ctx: TPacketDataSource, _: typedesc[T]) = ctx.toCtx.parser.getString()
template getKey[T: SomeInteger](ctx: TPacketDataSource, _: typedesc[T]) = ctx.toCtx.parser.getInt[T]()
template getKey[T: SomeFloat](ctx: TPacketDataSource, _: typedesc[T]) = ctx.toCtx.parser.getFloat[T]()


proc load*[U: string|SomeInteger|SomeFloat, T](_: typedesc[Table[U, T]], ctx: TPacketDataSource): Table[U, T] =
  mixin load
  var d: T
  if ctx.toCtx.parser.tok == tkCurlyLe:
    ctx.toCtx.parser.getTok()
    var currKey: U
    while ctx.toCtx.parser.tok != tkCurlyRi:
      currKey = ctx.getKey(U)
      ctx.toCtx.parser.getTok()
      ctx.toCtx.parser.eat(tkColon)
      ctx.load(d)
      result[currKey] = d
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
