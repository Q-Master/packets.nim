import options
import strutils
import tables
import ./json
import ../internal/types
import ./processors/[boolean, numeric, str, datetime, enums, optional]
export json, boolean, numeric, str, datetime, enums, optional

proc load*[T: TPacket](p: type[T], json: JsonNode): T {.raises:[ValueError].} =
    mixin load
    if json.kind != JObject:
        raise newException(ValueError, "Wrong field type: " & $json.kind)
    let req: seq[string] = p.required_fields()
    let fields: seq[string] = p.packet_fields()
    let mapping: TableRef[string, string] = p.mapping()
    let res = p()
    load(res.id, json["id"])
    for k, t in res[].fieldPairs:
        if k in fields:
            let key = mapping.getOrDefault(k, k)
            let target: JsonNode = json.getOrDefault(key)
            if (target.isNil() or target.kind == JNull) and k in req:
                raise newException(ValueError, "Required field " & k & " missing")
            when t is TPacket:
                t = type(t).load(target)
            else:
                load(t, target)
    result=res

proc load*[T: TPacket](p: type[Option[T]], json: JsonNode): Option[T] {.raises:[ValueError].} =
    mixin load
    if json.isNil() or json.kind == JNull:
        result = none(T)
    else:
        result = T.load(json).option

proc load*[T](to: var seq[T], json: JsonNode) {.raises:[ValueError].} =
    mixin load
    if json.kind != JArray:
        raise newException(ValueError, "Wrong field type: " & $json.kind)
    for item in json.elems:
        var t: T
        t.load(item)
        to.add(t)

proc load*[T](to: var Option[seq[T]], json: JsonNode) {.raises:[ValueError].} =
    mixin load
    if json.isNil() or json.kind == JNull:
        to = none(seq[T])
    else:
        var t: seq[T]
        t.load(json)
        to = t.option

proc loads*[T: TPacket](p: type[T], buffer: string): T =
    mixin load
    let js = parseJson(string)
    return load(p, js)

proc dump*[T: TPacket](p: T): JsonTree =
    mixin dump
    result = newJObject()
    result["id"]= %p.id
    let fields: seq[string] = p.packet_fields()
    let mapping: TableRef[string, string] = p.mapping()
    for k, v in p[].fieldPairs:
        if k in fields:
            let key = mapping.getOrDefault(k, k)
            when v is Option:
                if v.isSome:
                    try:
                        result[key] = v.dump()
                    except UnpackError:
                        discard
            else:
                result[key] = v.dump()

proc dump*[T: TPacket](p: Option[T]): JsonTree =
    mixin dump
    if p.isSome():
        return p.get().dump()
    else:
        return newJNull()

proc dump*[T](t: seq[T]): JsonTree =
    mixin dump
    var o: JsonTree = newJArray()
    for item in t:
        o.add(item.dump())
    result = o

proc dump*[T](t: Option[seq[T]]): JsonTree =
    mixin dump
    if t.isSome():
        result = t.get().dump()
    else:
        result = newJNull()

proc dumps*[T: TPacket](p: T): string =
    mixin dump
    result = $p.dump()
