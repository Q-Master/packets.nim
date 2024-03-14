import std/[options, strutils, tables, sets, macros]
import ./internal/types
import ./internal/packet
export TPacket, TPacketDataSource, TPacketFieldSetFunc, asName, packet, tables, sets, macros
export TArrayPacket, arrayPacket

proc indent(s: var string, i: int)
proc pretty*[T: TPacket | TArrayPacket](p: T, ci=1): string =
  var str = "packet " & $type(T)
  var req = p.requiredFields()
  let fields = p.packetFields()
  str.add("\n")
  indent(str, ci)
  when defined(enablePacketIDs):
    str.add("ID " & $p.id)
  for k, v in p.fieldPairs:
    if k in fields:
      str.add("\n")
      indent(str, ci)
      when v is TPacket:
        str.add(k & " = " & v.pretty(ci=ci+1))
      else:
        str.add(k & " = " & $v)
  result=str

#proc `$`*[T: TPacket | TArrayPacket](p: T): string =
#  result = p.pretty()

#--------------------------------------------------------------------------#
proc indent(s: var string, i: int) =
  s.add(spaces(i*4))

