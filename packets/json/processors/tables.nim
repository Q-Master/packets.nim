import std/[tables]
import ../context

# ------------------- Load

template getKey[T: string](ctx: var TPacketDataSource, k: var T) = ctx.toCtx.parser.getString(k)
template getKey[T: SomeInteger](ctx: var TPacketDataSource, k: var T) = ctx.toCtx.parser.getInt[T](k)
template getKey[T: SomeFloat](ctx: var TPacketDataSource, k: var T) = ctx.toCtx.parser.getFloat[T](k)


proc load*[U: string|SomeInteger|SomeFloat, T](ctx: var TPacketDataSource, dest: var Table[U, T]) =
  mixin load
  var d: T
  if ctx.toCtx.parser.tok == tkCurlyLe:
    discard ctx.toCtx.parser.getTok()
    var currKey: U
    while ctx.toCtx.parser.tok != tkCurlyRi:
      ctx.getKey(currKey)
      discard ctx.toCtx.parser.getTok()
      ctx.toCtx.parser.eat(tkColon)
      ctx.load(d)
      dest[currKey] = d 
      if ctx.toCtx.parser.tok != tkComma:
        break
      discard ctx.toCtx.parser.getTok() #skipping "," token
    eat(ctx.toCtx.parser, tkCurlyRi)
  else:
    raise newException(ValueError, "Not a table")

# ------------------- Dump

const strLBracket = "{"
const strRBracket = "}"
const strComma = ","
const strQuote = "\""
const strQuoteColon = "\":"

proc dump*[U, T](t: Table[U, T], dest: var string) =
  mixin dump
  dest.add(strLBracket)
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
  dest.add(strRBracket)
