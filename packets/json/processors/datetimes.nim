import std/times
import ../context

type
  TStrTime* = distinct Time
  TStrDateTime* = distinct DateTime

# ------------------- Load

proc load*(ctx: TPacketDataSource, dest: var Time) =
  var f: float
  ctx.toCtx.parser.getFloat(f)
  dest = fromUnixFloat(f)
  ctx.toCtx.parser.getTok()

proc load*(ctx: TPacketDataSource, dest: var DateTime) =
  var f: float
  ctx.toCtx.parser.getFloat(f)
  dest = fromUnixFloat(f).local()
  ctx.toCtx.parser.getTok()

# ------------------- Dump

proc dump*(t: Time, dest: var string) =
  dest.add($(t.toUnix))

proc dump*(t: DateTime, dest: var string) =
  dest.add($(t.toTime.toUnix))
