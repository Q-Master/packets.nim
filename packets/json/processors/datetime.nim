import json
import options
import times

#[
    Time, DateTime
    toUnix, fromUnix, toUnixFloat, fromUnixFloat
]#

type
    TStrTime* = distinct Time
    TStrDateTime* = distinct DateTime

proc load*(to: var Time, json: JsonNode) {.raises:[ValueError].} =
    if json.kind == JInt:
        to = fromUnix(json.num)
    elif json.kind == JFloat:
        to = fromUnixFloat(json.fnum)
    else:
        raise newException(ValueError, "Wrong field type: " & $json.kind)

proc load*(to: var Option[Time], json: JsonNode) {.raises:[ValueError].} =
    if json.isNil() or json.kind == JNull:
        to = none(Time)
    elif json.kind == JInt:
        to = fromUnix(json.num).option
    elif json.kind == JFloat:
        to = fromUnixFloat(json.fnum).option
    else:
        raise newException(ValueError, "Wrong field type: " & $json.kind)

proc load*(to: var DateTime, json: JsonNode) {.raises:[ValueError].} =
    if json.kind == JInt:
        to = local(fromUnix(json.num))
    elif json.kind == JFloat:
        to = local(fromUnixFloat(json.fnum))
    else:
        raise newException(ValueError, "Wrong field type: " & $json.kind)

proc load*(to: var Option[DateTime], json: JsonNode) {.raises:[ValueError].} =
    if json.isNil() or json.kind == JNull:
        to = none(DateTime)
    elif json.kind == JInt:
        to = local(fromUnix(json.num)).option
    elif json.kind == JFloat:
        to = local(fromUnixFloat(json.fnum)).option
    else:
        raise newException(ValueError, "Wrong field type: " & $json.kind)

proc dump*(t: Time): JsonNode =
    result = newJInt(int32(t.toUnix))

proc dump*(t: DateTime): JsonNode =
    result = newJInt(int32(t.toTime.toUnix))

proc dump*(t: Option[Time]): JsonNode =
    if t.isSome():
        result = t.get().dump()
    else:
        result = newJNull()

proc dump*(t: Option[DateTime]): JsonNode =
    if t.isSome():
        result = t.get().dump()
    else:
        result = newJNull()
