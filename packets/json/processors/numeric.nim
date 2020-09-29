import ../json

proc load*[T: SomeSignedInt](to: var T, json: JsonNode) {.raises:[ValueError].} =
    if json.kind != JInt and json.kind != JFloat:
        raise newException(ValueError, "Wrong field type: " & $json.kind)
    let decoded: BiggestInt = (if json.kind == JInt: json.getBiggestInt() else: BiggestInt(json.getFloat()))
    if decoded > high(T) or decoded < low(T):
        raise newException(ValueError, "Value too high or too low for type" & $type(T) & ": " & $decoded & ", h: " & $high(T) & ", l: " & $low(T))
    to = T(decoded)

proc load*[T: SomeUnsignedInt](to: var T, json: JsonNode) {.raises:[ValueError].} =
    if json.kind != JInt and json.kind != JFloat:
        raise newException(ValueError, "Wrong field type: " & $json.kind)
    let decoded: BiggestInt = (if json.kind == JInt: json.getBiggestInt() else: BiggestInt(json.getFloat()))
    if decoded > BiggestInt(T.high):
        raise newException(ValueError, "Value too high for type " & $type(T) & ": " & $decoded & ", h: " & $high(T))
    to = T(decoded)

proc load*[T: float | float32 | float64](to: var T, json: JsonNode) {.raises:[ValueError].} =
    if json.kind != JInt and json.kind != JFloat:
        raise newException(ValueError, "Wrong field type: " & $json.kind)
    let decoded: float = (if json.kind == JInt: float(json.getBiggestInt()) else: json.getFloat())
    if decoded > high(T) or decoded < low(T):
        raise newException(ValueError, "Value too high or too low: " & $decoded & ", h: " & $high(T) & ", l: " & $low(T))
    to = T(decoded)

proc dump*[T: SomeSignedInt | SomeUnsignedInt | float | float32 | float64](t: T): JsonNode =
    result = %t
