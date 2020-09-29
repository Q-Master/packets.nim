import ../json

proc load*(to: var string, json: JsonNode) {.raises:[ValueError].} =
    if json.kind != JString:
        raise newException(ValueError, "Wrong field type: " & $json.kind)
    to = json.getStr()

proc dump*(t: string): JsonNode =
    result = %t
