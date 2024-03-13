import std/[tables, strutils]
import ../context

# ------------------- Load

proc load*[U: string|SomeInteger|SomeFloat, T](ctx: var TPacketDataSource, t: typedesc[Table[U, T]]): Table[U, T] =
  mixin load
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
      result[currKey] = ctx.load(T)
      if ctx.toCtx.parser.tok != tkComma:
        break
      discard ctx.toCtx.parser.getTok() #skipping "," token
    eat(ctx.toCtx.parser, tkCurlyRi)
  else:
    raise newException(ValueError, "Not a table")

# ------------------- Dump

proc dump*[U, T](t: Table[U, T]): string =
  mixin dump
  result = "{"
  var first: bool = true
  for k,v in t.pairs:
    if first:
      first = false
    else:
      result.add(",") 
    result.add("\"" & k.dump() & "\": " & v.dump())
  result.add("}")
