import std/[streams]
import ./processors/[booleans, numerics, strs, datetimes, enums, optionals, seqs, subpackets, tables]
import ./context
import ../internal/types

export booleans, numerics, strs, datetimes, enums, optionals, seqs, subpackets, tables

# ------------------- Load

proc loads*[T: TPacket | TArrayPacket](p: type[T], jsStream: Stream): T =
  var ctx = TPacketDataSourceJson()
  ctx.parser.open(jsStream)
  discard ctx.parser.getTok()
  ctx.load(result)

proc loads*[T: TPacket | TArrayPacket](p: type[T], js: string): T =
  let jsStream = newStringStream(js)
  defer:
    jsStream.close()
  result = p.loads(jsStream)


proc loads*[T: TPacket | TArrayPacket](p: type[seq[T]], jsStream: Stream): seq[T] =
  var ctx = TPacketDataSourceJson()
  ctx.parser.open(jsStream)
  discard ctx.parser.getTok()
  ctx.load(result)

proc loads*[T: TPacket | TArrayPacket](p: type[seq[T]], js: string): seq[T] =
  let jsStream = newStringStream(js)
  defer:
    jsStream.close()
  result = p.loads(jsStream)


iterator items*[T](p: type[seq[T]], jsStream: Stream): T =
  var ctx = TPacketDataSourceJson()
  ctx.parser.open(jsStream)
  discard ctx.parser.getTok()
  p.begin(ctx)
  var d: T
  while ctx.next(d):
    yield d

# ------------------- Dump

proc dumps*[T: TPacket | TArrayPacket](p: T): string =
  mixin dump
  p.dump(result)

proc dumps*[T: TPacket | TArrayPacket](p: seq[T]): string =
  mixin dump
  p.dump(result)
