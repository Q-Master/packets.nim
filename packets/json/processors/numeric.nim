import json
import options


proc decodeSigned[T: SomeSignedInt](_: type[T], json: JsonNode): T {.raises:[ValueError].} =
    if json.kind != JInt and json.kind != JFloat:
        raise newException(ValueError, "Wrong field type: " & $json.kind)
    let decoded: BiggestInt = (if json.kind == JInt: json.num else: BiggestInt(json.fnum))
    if decoded > high(T) or decoded < low(T):
        raise newException(ValueError, "Value too high or too low for type" & $type(T) & ": " & $decoded & ", h: " & $high(T) & ", l: " & $low(T))
    result = T(decoded)

proc decodeUnsigned[T: SomeUnsignedInt](_: type[T], json: JsonNode): T {.raises:[ValueError].} =
    if json.kind != JInt and json.kind != JFloat:
        raise newException(ValueError, "Wrong field type: " & $json.kind)
    let decoded: BiggestInt = (if json.kind == JInt: json.num else: BiggestInt(json.fnum))
    if decoded > BiggestInt(T.high):
        raise newException(ValueError, "Value too high for type " & $type(T) & ": " & $decoded & ", h: " & $high(T))
    result = T(decoded)

proc decodeFloat[T: float | float32 | float64](_: type(T), json: JsonNode): T =
    if json.kind != JInt and json.kind != JFloat:
        raise newException(ValueError, "Wrong field type: " & $json.kind)
    let decoded: float = (if json.kind == JInt: float(json.num) else: json.fnum)
    if decoded > high(T) or decoded < low(T):
        raise newException(ValueError, "Value too high or too low: " & $decoded & ", h: " & $high(T) & ", l: " & $low(T))
    result = T(decoded)

proc load*[T: SomeSignedInt](to: var T, json: JsonNode) {.raises:[ValueError].} =
    to = T.decodeSigned(json)

proc load*[T: SomeUnsignedInt](to: var T, json: JsonNode) {.raises:[ValueError].} =
    to = T.decodeUnsigned(json)

proc load*[T: float | float32 | float64](to: var T, json: JsonNode) {.raises:[ValueError].} =
    to = T.decodeFloat(json)

proc load*[T: SomeSignedInt](to: var Option[T], json: JsonNode) {.raises:[ValueError].} =
    if json.isNil() or json.kind == JNull:
        to = none(T)
    else:
        to = (T.decodeSigned(json)).option

proc load*[T: SomeUnsignedInt](to: var Option[T], json: JsonNode) {.raises:[ValueError].} =
    if json.isNil() or json.kind == JNull:
        to = none(T)
    else:
        to = (T.decodeUnsigned(json)).option

proc load*[T: float | float32 | float64](to: var Option[T], json: JsonNode) {.raises:[ValueError].} =
    if json.isNil() or json.kind == JNull:
        to = none(T)
    else:
        to = (T.decodeFloat(json)).option

proc dump*[T: SomeSignedInt | SomeUnsignedInt | float | float32 | float64](t: T): JsonNode =
    result = %t

proc dump*[T: SomeSignedInt | SomeUnsignedInt | float | float32 | float64](t: Option[T]): JsonNode =
    if t.isSome():
        result = t.get().dump()
    else:
        result = newJNull()
