import ../json

proc load*[T: enum](to: var T, json: JsonNode) {.raises:[ValueError].} =
    if json.kind != JInt:
        raise newException(ValueError, "Wrong field type: " & $json.kind)
    to = T(json.getBiggestInt())

proc dump*[T: enum](en: T): JsonNode =
    result = newJInt(ord(en))
