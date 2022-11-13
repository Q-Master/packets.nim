import std/[unittest, options, tables, times, macros]
import packets/packets
import packets/json/serialization

type EnumCheck = enum
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
  var field2*: Option[float] = 3.0

packet PacketWithNotExportedFields:
  var field1: int #When loaded the contents of the field are undefined
  var field2*: bool

packet PacketWithSubpacket:
  var field1*: int
  var field2*: SimplePacketWithDefault

packet PacketWithOptionalSubpacket:
  var field1*: Option[SimplePacketWithDefault]

arrayPacket SimpleArrayPacket:
  var field1*: int
  var field2*: float

packet PacketCyclic:
  var field1*: Option[PacketCyclic]
  var field2*: int

suite "Packets":
  setup:
    discard

  test "Simple packet":
    let nowTime = initTime(getTime().toUnix, 0)
    var nowDate = now()
    nowDate = nowDate - initDuration(nanoseconds=nowDate.nanosecond)
    #echo nowDate.nanosecond
    var pkt = SimplePacket.new(
      field1 = 10,
      field2 = 862.0,
      field3 = first,
      field4 = true,
      field5 = "test string",
      field6 = nowTime,
      field7 = nowDate)
    check(pkt.field1 == 10)
    check(pkt.field2 == 862.0)
    check(pkt.field3 == first)
    check(pkt.field4 == true)
    check(pkt.field5 == "test string")
    check(pkt.field6 == nowTime)
    check(pkt.field7 == nowDate)
    let js = pkt.dumps()
    #echo "Resulted JSON: ", js
    let pktLoaded = SimplePacket.loads(js)
    check(pktLoaded.field1 == 10)
    check(pktLoaded.field2 == 862.0)
    check(pktLoaded.field3 == first)
    check(pktLoaded.field4 == true)
    check(pktLoaded.field5 == "test string")
    check(pktLoaded.field6 == nowTime)
    check(pktLoaded.field7 == nowDate)
  
  test "Simple packet with default value":
    var pkt = SimplePacketWithDefault.new(field2="x")
    var pkt2 = SimplePacketWithDefault.new(field1=100, field2="y")
    check(pkt.field1 == 10)
    check(pkt.field2 == "x")
    check(pkt2.field1 == 100)
    check(pkt2.field2 == "y")
    let js = pkt.dumps()
    let js2 = pkt2.dumps()
    let pktLoaded = SimplePacketWithDefault.loads(js)
    let pktLoaded2 = SimplePacketWithDefault.loads(js2)
    check(pktLoaded.field1 == 10)
    check(pktLoaded.field2 == "x")
    check(pktLoaded2.field1 == 100)
    check(pktLoaded2.field2 == "y")

  test "Packet with renamed field":
    var pkt = PacketWithRename.new(field1 = 7.0, field2 = false)
    check(pkt.field1 == 7.0)
    check(pkt.field2 == false)
    var js: string = pkt.dumps()
    let pktLoaded = PacketWithRename.loads(js)
    check(pktLoaded.field1 == 7.0)
    check(pktLoaded.field2 == false)
  
  test "Packet inheritance":
    var nowTime = getTime()
    nowTime = nowTime - initDuration(nanoseconds=nowTime.nanosecond)
    var pkt = InheritedPacket.new(field2=nowTime)
    check(pkt.field1 == 3.0)
    check(pkt.field2 == nowTime)
    let js: string = pkt.dumps()
    let pktLoaded = InheritedPacket.loads(js)
    check(pktLoaded.field1 == 3.0)
    check(pktLoaded.field2 == nowTime)
  
  test "Packet with optional field":
    let pkt = PacketWithOptionalFields.new(field1 = 10)
    let pkt2 = PacketWithOptionalFields.new(field1 = 1000, field2 = true.option)
    check(pkt.field1 == 10)
    check(pkt.field2 == none(bool))
    check(pkt2.field1 == 1000)
    check(pkt2.field2 == true.option)
    let js: string = pkt.dumps()
    let js2: string = pkt2.dumps()
    let pktLoaded = PacketWithOptionalFields.loads(js)
    let pktLoaded2 = PacketWithOptionalFields.loads(js2)
    check(pktLoaded.field1 == 10)
    check(pktLoaded.field2 == none(bool))
    check(pktLoaded2.field1 == 1000)
    check(pktLoaded2.field2 == true.option)

  test "Packet with optional field and default value":
    let pkt = PacketWithOptionalFieldsAndDefault.new()
    let pkt2 = PacketWithOptionalFieldsAndDefault.new(field1 = 1000.option)
    let pkt3 = PacketWithOptionalFieldsAndDefault.new(field1 = 7.option, field2 = 4.0.option)
    check(pkt.field1 == none(int))
    check(pkt.field2 == 3.0.option)
    check(pkt2.field1 == 1000.option)
    check(pkt2.field2 == 3.0.option)
    check(pkt3.field1 == 7.option)
    check(pkt3.field2 == 4.0.option)
    let js: string = pkt.dumps()
    let js2: string = pkt2.dumps()
    let js3: string = pkt3.dumps()
    let pktLoaded = PacketWithOptionalFieldsAndDefault.loads(js)
    let pktLoaded2 = PacketWithOptionalFieldsAndDefault.loads(js2)
    let pktLoaded3 = PacketWithOptionalFieldsAndDefault.loads(js3)
    check(pktLoaded.field1 == none(int))
    check(pktLoaded.field2 == 3.0.option)
    check(pktLoaded2.field1 == 1000.option)
    check(pktLoaded2.field2 == 3.0.option)
    check(pktLoaded3.field1 == 7.option)
    check(pktLoaded3.field2 == 4.0.option)

  test "Packet with not exported fields":
    let pkt = PacketWithNotExportedFields.new(field1 = 5, field2 = false)
    check(pkt.field1 == 5)
    check(pkt.field2 == false)
    let js = pkt.dumps()
    let pktLoaded = PacketWithNotExportedFields.loads(js)
    check(pktLoaded.field1 == 0)
    check(pktLoaded.field2 == false)

  test "Packet with subpacket":
    let pkt = PacketWithSubpacket.new(field1 = 50, field2 = SimplePacketWithDefault.new(field2 = "subpacket"))
    check(pkt.field1 == 50)
    check(pkt.field2 is SimplePacketWithDefault)
    check(pkt.field2.field1 == 10)
    check(pkt.field2.field2 == "subpacket")
    let js = pkt.dumps()
    let pktLoaded = PacketWithSubpacket.loads(js)
    check(pktLoaded.field1 == 50)
    check(pktLoaded.field2 is SimplePacketWithDefault)
    check(pktLoaded.field2.field1 == 10)
    check(pktLoaded.field2.field2 == "subpacket")

  test "Packet with optional subpacket":
    let pkt = PacketWithOptionalSubpacket.new(field1 = SimplePacketWithDefault.new(field2 = "subpacket").option)
    check(pkt.field1.get() is SimplePacketWithDefault)
    check(pkt.field1.get().field1 == 10)
    check(pkt.field1.get().field2 == "subpacket")
    let js = pkt.dumps()
    let pktLoaded = PacketWithOptionalSubpacket.loads(js)
    check(pktLoaded.field1.get() is SimplePacketWithDefault)
    check(pktLoaded.field1.get().field1 == 10)
    check(pktLoaded.field1.get().field2 == "subpacket")

suite "Array Packets":
  setup:
    discard

  test "Simple ArrayPacket":
    let pkt = SimpleArrayPacket.new(field1 = 1, field2 = 2.0)
    check(pkt.field1 == 1)
    check(pkt.field2 == 2.0)
    let js = pkt.dumps()
    #echo "Resulted JSON: ", js
    when not defined(disablePacketIDs):
      check(js.len == 19)
    else:
      check js == "[1,2.0]"
      check(js.len == 7)
    let pktLoaded = SimpleArrayPacket.loads(js)
    check(pktLoaded.field1 == 1)
    check(pktLoaded.field2 == 2.0)

#[
# Produces some unknown error, so disabled right now
suite "Cyclic packets":
  setup:
    discard

  test "Cyclic packet":
    let pkt = PacketCyclic.new(field1 = PacketCyclic.none, field2 = 2)
    let pkt2 = PacketCyclic.new(field1 = pkt.option, field2 = 1)
    let js = pkt2.dumps()
    #echo "Resulted JSON: ", $js
    let pktLoaded = PacketCyclic.loads(js)
    check(pktLoaded.field1.get() is PacketCyclic)
    check(pktLoaded.field2 == 1)
    check(pktLoaded.field1.get().field1.isNone())
    check(pktLoaded.field1.get().field2 == 2)
]#