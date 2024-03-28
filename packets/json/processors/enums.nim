import std/strutils
import ../context

# ------------------- Load

proc load*[T: enum](ctx: var TPacketDataSource, dest: var T) =
  if ctx.toCtx.parser.tok != tkInt:
    raise newException(ValueError, "Wrong field type: " & $ctx.toCtx.parser.tok)
  dest = T(parseBiggestInt(ctx.toCtx.parser.a))
  discard ctx.toCtx.parser.getTok()

# ------------------- Dump

proc dump*[T: enum](en: T, dest: var string) =
  dest.add($(ord(en).int))
