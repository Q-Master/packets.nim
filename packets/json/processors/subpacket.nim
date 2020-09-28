import json
import ../types


proc load*[T: TPacket](to: T, json: JsonNode) {.raises:[ValueError].} =
    if json.kind != JObject:
        raise newException(ValueError, "Wrong field type: " & $json.kind)
    to = T.load(json)
