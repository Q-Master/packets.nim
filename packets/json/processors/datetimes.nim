import std/[times, strutils]
import ../context

type
  TStrTime* = distinct Time
  TStrDateTime* = distinct DateTime

# ------------------- Load

proc load*(ctx: var TPacketDataSource, t: typedesc[Time]): Time =
  if ctx.toCtx.parser.tok == tkInt:
    result = fromUnix(parseBiggestInt(ctx.toCtx.parser.a))
  elif ctx.toCtx.parser.tok == tkFloat:
    result = fromUnixFloat(parseFloat(ctx.toCtx.parser.a))
  else:
    raise newException(ValueError, "Wrong field type: " & $ctx.toCtx.parser.tok)
  discard ctx.toCtx.parser.getTok()

proc load*(ctx: var TPacketDataSource, t: typedesc[DateTime]): DateTime =
  if ctx.toCtx.parser.tok == tkInt:
    result = fromUnix(parseBiggestInt(ctx.toCtx.parser.a)).local()
  elif ctx.toCtx.parser.tok == tkFloat:
    result = fromUnixFloat(parseFloat(ctx.toCtx.parser.a)).local()
  else:
    raise newException(ValueError, "Wrong field type: " & $ctx.toCtx.parser.tok)
  discard ctx.toCtx.parser.getTok()

# ------------------- Dump

proc dump*(t: Time): string =
  result = $(t.toUnix)

proc dump*(t: DateTime): string =
  result = $(t.toTime.toUnix)
