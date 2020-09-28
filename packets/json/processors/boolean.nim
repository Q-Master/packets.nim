import json
import options

proc load*(to: var bool, json: JsonNode) {.raises:[ValueError].}=
    if json.kind != JBool:
        raise newException(ValueError, "Wrong field type: " & $json.kind)
    to = json.bval

proc load*(to: var Option[system.bool], json: JsonNode) {.raises:[ValueError].}=
    if json.isNil() or json.kind == JNull:
        to = none(system.bool)
    else:
        if json.kind != JBool:
            raise newException(ValueError, "Wrong field type: " & $json.kind)
        to = json.bval.option

proc dump*(t: bool): JsonNode =
    result = %t

proc dump*(t: Option[bool]): JsonNode =
    if t.isSome():
        result = %(t.get())
    else:
        result = newJNull()
