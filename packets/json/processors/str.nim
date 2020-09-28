import json
import options

proc load*(to: var string, json: JsonNode) {.raises:[ValueError].} =
    if json.kind != JString:
        raise newException(ValueError, "Wrong field type: " & $json.kind)
    to = json.str

proc load*(to: var Option[string], json: JsonNode) {.raises:[ValueError].} =
    if json.isNil() or json.kind == JNull:
        to = none(string)
    else:
        if json.kind != JString:
            raise newException(ValueError, "Wrong field type: " & $json.kind)
        to = json.str.option

proc dump*(t: string): JsonNode =
    result = %t

proc dump*(t: Option[string]): JsonNode =
    if t.isSome():
        result = t.get.dump()
    else:
        result = newJNull()
