import std/[strutils]
import ../context

# ------------------- Load

proc load*(ctx: var TPacketDataSource, dest: var string) =
  ctx.toCtx.parser.getString(dest)
  discard ctx.toCtx.parser.getTok()

# ------------------- Dump

proc dump*(t: string, dest: var string) =
  dest.add(t.escape())
