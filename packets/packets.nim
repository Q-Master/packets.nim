import std/[options, strutils, tables, sets, macros]
import ./internal/types
import ./internal/packet
export TPacket, TArrayPacket, TPacketDataSource, TPacketFieldSetFunc, as_name, packet, arrayPacket, tables, sets, macros

proc indent(s: var string, i: int)
proc pretty*[T: TPacket | TArrayPacket](p: T, ci=1): string =
    var str = "packet " & $type(T)
    let req: HashSet[string] = p.requiredFields()
    let fields: seq[string] = p.packetFields()
    str.add("\n")
    indent(str, ci)
    str.add("ID " & $p.id)
    for k, v in p[].fieldPairs:
        if k in fields:
            str.add("\n")
            indent(str, ci)
            when v is TPacket:
                str.add("field " & k & " = " & v.pretty(ci=ci+1) & (if k in req: " required" else: ""))
            else:
                str.add("field " & k & " = " & $v & (if k in req: " required" else: ""))
    result=str

proc `$`*[T: TPacket | TArrayPacket](p: T): string =
    result = p.pretty()

#--------------------------------------------------------------------------#
proc indent(s: var string, i: int) =
  s.add(spaces(i*4))

