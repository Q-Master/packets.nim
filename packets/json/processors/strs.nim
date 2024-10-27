import std/[strutils]
import ../context

# ------------------- Load

proc load*(ctx: TPacketDataSource, dest: var string) =
  ctx.toCtx.parser.getString(dest)
  ctx.toCtx.parser.getTok()

# ------------------- Dump

proc dump*(t: string, dest: var string) =
  dest.add(t.escape())
