import std/[strutils]
import ../context

# ------------------- Load

proc load*(_: typedesc[string], ctx: TPacketDataSource): string =
  result = ctx.toCtx.parser.getString()
  ctx.toCtx.parser.getTok()

# ------------------- Dump

proc dump*(t: string, dest: var string) =
  dest.add(t.escape())
