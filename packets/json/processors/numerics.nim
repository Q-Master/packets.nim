import std/strutils
import ../context

# ------------------- Load

proc load*[T: SomeSignedInt](ctx: var TPacketDataSource, t: typedesc[T]): T =
  if ctx.toCtx.parser.tok != tkInt:
    raise newException(ValueError, "Wrong field type: " & $ctx.toCtx.parser.tok)
  let decoded = parseBiggestInt(ctx.toCtx.parser.a)
  if decoded > high(T) or decoded < low(T):
    raise newException(ValueError, "Value too high or too low for type" & $type(T) & ": " & $decoded & ", h: " & $high(T) & ", l: " & $low(T))
  result = T(decoded)
  discard ctx.toCtx.parser.getTok()

proc load*[T: SomeUnsignedInt](ctx: var TPacketDataSource, t: typedesc[T]): T =
  if ctx.toCtx.parser.tok != tkInt:
    raise newException(ValueError, "Wrong field type: " & $ctx.toCtx.parser.tok)
  let decoded = parseBiggestInt(ctx.toCtx.parser.a)
  if decoded > high(T):
    raise newException(ValueError, "Value too high for type " & $type(T) & ": " & $decoded & ", h: " & $high(T))
  result = T(decoded)
  discard ctx.toCtx.parser.getTok()

proc load*[T: SomeFloat](ctx: var TPacketDataSource, t: typedesc[T]): T =
  if ctx.toCtx.parser.tok != tkFloat and ctx.toCtx.parser.tok != tkInt:
    raise newException(ValueError, "Wrong field type: " & $ctx.toCtx.parser.tok)
  let decoded = parseFloat(ctx.toCtx.parser.a)
  if decoded > high(T) or decoded < low(T):
    raise newException(ValueError, "Value too high or too low for type" & $type(T) & ": " & $decoded & ", h: " & $high(T) & ", l: " & $low(T))
  result = T(decoded)
  discard ctx.toCtx.parser.getTok()

# ------------------- Dump

proc dump*[T: SomeSignedInt | SomeUnsignedInt | float | float32 | float64](t: T): string =
  result = $t
