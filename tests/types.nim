import std/[options, tables, times]
import ../packets


type EnumCheck* = enum
  first = 1
  second = 2

packet SimplePacket:
  var field1*: int
  var field2*: float
  var field3*: EnumCheck
  var field4*: bool
  var field5*: string
  var field6*: Time
  var field7*: DateTime

packet SimplePacketWithDefault:
  var field1*: int = 10
  var field2*: string

packet PacketWithRename:
  var field1*: float
  var field2* {.as_name: "field3".}: bool

packet BasePacket:
  var field1*: float = 3.0

packet InheritedPacket of BasePacket:
  var field2*: Time

packet PacketWithOptionalFields:
  var field1*: int
  var field2*: Option[bool]

packet PacketWithOptionalFieldsAndDefault:
  var field1*: Option[int]
  var field2*: Option[float] = 3.0.option

packet PacketWithSubpacket:
  var field1*: int
  var field2*: SimplePacketWithDefault

packet PacketWithOptionalSubpacket:
  var field1*: Option[SimplePacketWithDefault]

packet PacketWithTable:
  var field1*: int
  var field2*: Table[string, int]


arrayPacket SimpleArrayPacket:
  var field1*: int
  var field2*: float


packet SimplePacketWithId {.packetId.}:
  var field1*: int
  var field2*: float

arrayPacket SimpleArrayPacketWithId {.packetId.}:
  var field1*: int
  var field2*: float
