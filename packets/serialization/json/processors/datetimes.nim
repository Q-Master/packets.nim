import std/times
import ../context

type
  TStrTime* = distinct Time
  TStrDateTime* = distinct DateTime

# ------------------- Load

proc load*(_: typedesc[Time], ctx: TPacketDataSource): Time =
  result = getFloat[float](ctx.toCtx.parser).fromUnixFloat()
  ctx.toCtx.parser.getTok()


proc load*(_: typedesc[DateTime], ctx: TPacketDataSource): DateTime =
  result = getFloat[float](ctx.toCtx.parser).fromUnixFloat().local()
  ctx.toCtx.parser.getTok()

# ------------------- Dump

proc dump*(t: Time, dest: var string) =
  dest.add($(t.toUnix))


proc dump*(t: DateTime, dest: var string) =
  dest.add($(t.toTime.toUnix))
