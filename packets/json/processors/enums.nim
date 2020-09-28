import json
import options

proc load*[T: enum](to: var T, json: JsonNode) {.raises:[ValueError].} =
    if json.kind != JInt:
        raise newException(ValueError, "Wrong field type: " & $json.kind)
    to = T(json.num)

proc load*[T: enum](to: var Option[T], json: JsonNode) {.raises:[ValueError].} =
    if json.isNil() or json.kind == JNull:
        to = none(T)
    elif json.kind == JInt:
        to = T(json.num)
    else:
        raise newException(ValueError, "Wrong field type: " & $json.kind)

proc dump*[T: enum](en: T): JsonNode =
    result = newJInt(ord(en))

proc dump*[T: enum](en: Option[T]): JsonNode =
    if en.isSome():
        result = en.get.dump()
    else:
        result = newJNull()
