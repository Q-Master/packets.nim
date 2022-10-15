import std/strutils
import ../context

# ------------------- Load

proc load*[T: enum](ctx: TPacketDataSource, t: typedesc[T]): T =
  if ctx.toCtx.parser.tok != tkInt:
    raise newException(ValueError, "Wrong field type: " & $ctx.toCtx.parser.tok)
  result = T(parseBiggestInt(ctx.toCtx.parser.a))
  discard ctx.toCtx.parser.getTok()

# ------------------- Dump

proc dump*[T: enum](en: T): string =
  result = $(ord(en).int)
