import times
import ../json

#[
    Time, DateTime
    toUnix, fromUnix, toUnixFloat, fromUnixFloat
]#

type
    TStrTime* = distinct Time
    TStrDateTime* = distinct DateTime

proc load*(to: var Time, json: JsonNode) {.raises:[ValueError].} =
    if json.kind == JInt:
        to = fromUnix(json.getBiggestInt())
    elif json.kind == JFloat:
        to = fromUnixFloat(json.getFloat())
    else:
        raise newException(ValueError, "Wrong field type: " & $json.kind)

proc load*(to: var DateTime, json: JsonNode) {.raises:[ValueError].} =
    if json.kind == JInt:
        to = local(fromUnix(json.getBiggestInt()))
    elif json.kind == JFloat:
        to = local(fromUnixFloat(json.getFloat()))
    else:
        raise newException(ValueError, "Wrong field type: " & $json.kind)

proc dump*(t: Time): JsonNode =
    result = newJInt(t.toUnix)

proc dump*(t: DateTime): JsonNode =
    result = newJInt(t.toTime.toUnix)
