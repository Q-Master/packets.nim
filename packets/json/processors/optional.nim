import options
import ../json
import ../../internal/types

proc load*[T](to: var Option[T], json: JsonNode) {.raises:[ValueError].} =
  mixin load
  if json.isNil() or json.kind == JNull:
    to = none(T)
  else:
    var rTo: T
    rTo.load(json)
    to = rTo.option

proc dump*[T: seq | TPacket](t: Option[T]): JsonTree = 
  mixin dump
  if t.isSome():
    result = t.get().dump()
  else:
    result = newJNull()

proc dump*[T](t: Option[T]): JsonNode =
  mixin dump
  if t.isSome():
    result = t.get().dump()
  else:
    result = newJNull()
