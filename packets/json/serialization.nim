import std/[streams]
import ./processors/[booleans, numerics, strs, datetimes, enums, optionals, seqs, subpackets, tables]
import ./context
import ../internal/types

export booleans, numerics, strs, datetimes, enums, optionals, seqs, subpackets, tables

# ------------------- Load

proc loads*[T: TPacket | TArrayPacket](p: type[T], jsStream: Stream): T =
  var ctx = TPacketDataSourceJson()
  ctx.parser.open(jsStream)
  try:
    discard ctx.parser.getTok()
    ctx.load(result)
  finally:
    ctx.parser.close(jsStream)

proc loads*[T: TPacket | TArrayPacket](p: type[T], js: string): T =
  let jsStream = newStringStream(js)
  try:
    result = p.loads(jsStream)
  finally:
    jsStream.close()


proc loads*[T: TPacket | TArrayPacket](p: type[seq[T]], jsStream: Stream): seq[T] =
  var ctx = TPacketDataSourceJson()
  ctx.parser.open(jsStream)
  try:
    discard ctx.parser.getTok()
    ctx.load(result)
  finally:
    ctx.parser.close(jsStream)

proc loads*[T: TPacket | TArrayPacket](p: type[seq[T]], js: string): seq[T] =
  let jsStream = newStringStream(js)
  try:
    result = p.loads(jsStream)
  finally:
    jsStream.close()


iterator items*[T](p: type[seq[T]], jsStream: Stream): T =
  var ctx = TPacketDataSourceJson()
  var d: T
  ctx.parser.open(jsStream)
  try:
    discard ctx.parser.getTok()
    p.begin(ctx)
    while ctx.next(d):
      yield d
  finally:
    ctx.parser.close(jsStream)

# ------------------- Dump

proc dumps*[T: TPacket | TArrayPacket](p: T): string =
  mixin dump
  p.dump(result)

proc dumps*[T: TPacket | TArrayPacket](p: seq[T]): string =
  mixin dump
  p.dump(result)
