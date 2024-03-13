import std/[streams]
import ./processors/[booleans, numerics, strs, datetimes, enums, optionals, seqs, subpackets, tables]
import ./context
import ../internal/types

export parsejson, booleans, numerics, strs, datetimes, enums, optionals, seqs, subpackets, tables

# ------------------- Load

proc loads*[T: TPacket | TArrayPacket](p: type[T], buffer: string): T =
  mixin load
  let bufferStream = newStringStream(buffer)
  var ctx = TPacketDataSourceJson()
  ctx.parser.open(bufferStream, "")
  try:
    discard ctx.parser.getTok()
    echo "!!!! ", ctx.parser.tok
    result = ctx.load(p)
    eat(ctx.parser, tkEof) # check if there is no extra data
  finally:
    ctx.parser.close()


proc loads*[T: TPacket | TArrayPacket](p: type[seq[T]], buffer: string): seq[T] =
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

proc dumps*[T: TPacket | TArrayPacket](p: seq[T]): string =
  mixin dump
  result.add(p.dump())
