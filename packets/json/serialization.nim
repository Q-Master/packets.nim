import std/[streams]
import ./processors/[booleans, numerics, strs, datetimes, enums, optionals, seqs, subpackets]
import ./context
import ../internal/types

export parsejson, booleans, numerics, strs, datetimes, enums, optionals, seqs, subpackets

# ------------------- Load

proc loads*[T: TPacket | TArrayPacket](p: type[T], buffer: string): T =
  mixin load
  let bufferStream = newStringStream(buffer)
  var ctx = TPacketDataSourceJson()
  ctx.parser.open(bufferStream, "")
  try:
    discard ctx.parser.getTok()
    result = ctx.load(p)
    eat(ctx.parser, tkEof) # check if there is no extra data
  finally:
    ctx.parser.close()

# ------------------- Dump

proc dumps*[T: TPacket | TArrayPacket](p: T): string =
  mixin dump
  result.add(p.dump())
