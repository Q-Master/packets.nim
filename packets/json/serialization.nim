import std/[streams]
import ./processors/[booleans, numerics, strs, datetimes, enums, optionals, seqs, sets, subpackets, tables]
import ./context
import ../internal/types

export booleans, numerics, strs, datetimes, enums, optionals, seqs, sets, subpackets, tables

# ------------------- Load

proc loads*[T: TPacket | TArrayPacket](p: type[T], jsStream: Stream): T =
  var ctx = newDataSourceJson()
  ctx.parser.open(jsStream)
  try:
    ctx.parser.getTok()
    result = T.load(ctx)
  finally:
    ctx.parser.close()

proc loads*[T: TPacket | TArrayPacket](p: type[T], js: sink string): T =
  let jsStream = newStringStream(js)
  try:
    result = p.loads(jsStream)
  finally:
    jsStream.close()


proc loads*[T: TPacket | TArrayPacket](p: type[seq[T]], jsStream: Stream): seq[T] =
  var ctx = newDataSourceJson()
  ctx.parser.open(jsStream)
  try:
    ctx.parser.getTok()
    result = seq[T].load(ctx)
  finally:
    ctx.parser.close()

proc loads*[T: TPacket | TArrayPacket](p: type[seq[T]], js: sink string): seq[T] =
  let jsStream = newStringStream(js)
  try:
    result = p.loads(jsStream)
  finally:
    jsStream.close()


iterator items*[T](p: type[seq[T]], jsStream: Stream): T =
  var ctx = newDataSourceJson()
  ctx.parser.open(jsStream)
  try:
    ctx.parser.getTok()
    for i in seq[T].items(ctx):
      yield i
  finally:
    ctx.parser.close()

# ------------------- Dump

proc dumps*[T: TPacket | TArrayPacket](p: T): string =
  mixin dump
  p.dump(result)

proc dumps*[T: TPacket | TArrayPacket](p: seq[T]): string =
  mixin dump
  p.dump(result)
