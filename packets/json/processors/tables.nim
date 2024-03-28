import std/[tables, strutils]
import ../context

# ------------------- Load

proc load*[U: string|SomeInteger|SomeFloat, T](ctx: var TPacketDataSource, dest: var Table[U, T]) =
  mixin load
  var d: T
  if ctx.toCtx.parser.tok == tkCurlyLe:
    discard ctx.toCtx.parser.getTok()
    while ctx.toCtx.parser.tok != tkCurlyRi:
      let currKey =
        when U is string:
          ctx.toCtx.parser.a
        else:
          when U is SomeInteger:
            when U is SomeUnsignedInt:
              U(parseBiggestUInt(ctx.toCtx.parser.a))
            else:
              U(parseBiggestInt(ctx.toCtx.parser.a))
          else:
            when U is SomeFloat:
              U(parseFloat(ctx.toCtx.parser.a))
            else:
              error "Unsupported key type"
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
