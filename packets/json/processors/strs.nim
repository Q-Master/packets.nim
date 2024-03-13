import std/[strutils]
import ../context

# ------------------- Load

proc load*(ctx: var TPacketDataSource, t: typedesc[string]): string =
  if ctx.toCtx.parser.tok != tkString:
    raise newException(ValueError, "Wrong field type: " & $ctx.toCtx.parser.tok)
  result = ctx.toCtx.parser.a.unescape(prefix="", suffix="")
  discard ctx.toCtx.parser.getTok()

# ------------------- Dump

proc dump*(t: string): string =
  result = t.escape()
