import std/[tables]
import ../context

# ------------------- Load

proc load*[U: string|SomeInteger|SomeFloat, T](_: typedesc[Table[U, T]], ctx: TPacketDataSource): Table[U, T] =
  mixin load
  if ctx.toCtx.parser.tok == tkCurlyLe:
    ctx.toCtx.parser.getTok()
    var currKey: U
    while ctx.toCtx.parser.tok != tkCurlyRi:
      when U is string:
        currKey = ctx.toCtx.parser.getString()
      elif U is SomeInteger:
        currKey = getInt[U](ctx.toCtx.parser)
      elif U is SomeFloat:
        currKey = getFloat[U](ctx.toCtx.parser)
      else:
        error "Unknown key type"
      ctx.toCtx.parser.getTok()
      ctx.toCtx.parser.eat(tkColon)
      result[currKey] = T.load(ctx)
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
