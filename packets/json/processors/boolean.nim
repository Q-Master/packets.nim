import ../json

proc load*(to: var bool, json: JsonNode) {.raises:[ValueError].}=
    if json.kind != JBool:
        raise newException(ValueError, "Wrong field type: " & $json.kind)
    to = json.getBool()

proc dump*(t: bool): JsonNode =
    result = newJBool(t)
