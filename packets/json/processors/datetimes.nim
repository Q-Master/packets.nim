import std/[times, strutils]
import ../context

type
  TStrTime* = distinct Time
  TStrDateTime* = distinct DateTime

# ------------------- Load

proc load*(ctx: var TPacketDataSource, dest: var Time) =
  if ctx.toCtx.parser.tok == tkInt:
    dest = fromUnix(parseBiggestInt(ctx.toCtx.parser.a))
  elif ctx.toCtx.parser.tok == tkFloat:
    dest = fromUnixFloat(parseFloat(ctx.toCtx.parser.a))
  else:
    raise newException(ValueError, "Wrong field type: " & $ctx.toCtx.parser.tok)
  discard ctx.toCtx.parser.getTok()

proc load*(ctx: var TPacketDataSource, dest: var DateTime) =
  if ctx.toCtx.parser.tok == tkInt:
    dest = fromUnix(parseBiggestInt(ctx.toCtx.parser.a)).local()
  elif ctx.toCtx.parser.tok == tkFloat:
    dest = fromUnixFloat(parseFloat(ctx.toCtx.parser.a)).local()
  else:
    raise newException(ValueError, "Wrong field type: " & $ctx.toCtx.parser.tok)
  discard ctx.toCtx.parser.getTok()

# ------------------- Dump

proc dump*(t: Time, dest: var string) =
  dest.add($(t.toUnix))

proc dump*(t: DateTime, dest: var string) =
  dest.add($(t.toTime.toUnix))
