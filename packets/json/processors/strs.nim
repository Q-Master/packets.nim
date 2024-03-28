import std/[strutils]
import ../context

# ------------------- Load

proc load*(ctx: var TPacketDataSource, dest: var string) =
  if ctx.toCtx.parser.tok != tkString:
    raise newException(ValueError, "Wrong field type: " & $ctx.toCtx.parser.tok)
  dest = ctx.toCtx.parser.a.unescape(prefix="", suffix="")
  discard ctx.toCtx.parser.getTok()

# ------------------- Dump

proc dump*(t: string, dest: var string) =
  dest.add(t.escape())
