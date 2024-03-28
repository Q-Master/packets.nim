import std/[streams]
import ./processors/[booleans, numerics, strs, datetimes, enums, optionals, seqs, subpackets, tables]
import ./context
import ../internal/types

export booleans, numerics, strs, datetimes, enums, optionals, seqs, subpackets, tables

# ------------------- Load

proc loads*[T: TPacket | TArrayPacket](p: type[T], bufferStream: Stream): T =
  mixin load
  var ctx = TPacketDataSourceJson()
  ctx.parser.open(bufferStream)
  discard ctx.parser.getTok()
  ctx.load(result)

proc loads*[T: TPacket | TArrayPacket](p: type[T], buffer: string): T =
  let bufferStream = newStringStream(buffer)
  result = p.loads(bufferStream)
  defer:
    bufferStream.close()


proc loads*[T: TPacket | TArrayPacket](p: type[seq[T]], bufferStream: Stream): seq[T] =
  mixin load
  var ctx = TPacketDataSourceJson()
  ctx.parser.open(bufferStream)
  discard ctx.parser.getTok()
  ctx.load(result)

proc loads*[T: TPacket | TArrayPacket](p: type[seq[T]], buffer: string): seq[T] =
  let bufferStream = newStringStream(buffer)
  result = p.loads(bufferStream)
  defer:
    bufferStream.close()


# ------------------- Dump

proc dumps*[T: TPacket | TArrayPacket](p: T): string =
  mixin dump
  p.dump(result)

proc dumps*[T: TPacket | TArrayPacket](p: seq[T]): string =
  mixin dump
  p.dump(result)
