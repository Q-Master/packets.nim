import unittest
import options
import tables
import times
import packets/json/json
import packets/packets
import packets/json/serialization
import packets/json/processors/[boolean, numeric, str, datetime, enums, optional]

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

suite "Packets":
  setup:
    discard

  test "Simple packet":
    let nowTime = initTime(getTime().toUnix, 0)
    var nowDate = now()
    nowDate.nanosecond = 0
    var pkt = SimplePacket.init(
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
    var js: JsonTree = pkt.dump()
    #echo "Resulted JSON: ", $js
    check(js["field1"] == %10)
    check(js["field2"] == %862.0)
    check(js["field3"] == %first.ord)
    check(js["field4"] == %true)
    check(js["field5"] == %"test string")
    check(js["field6"] == %(nowTime.toUnix))
    check(js["field7"] == %(nowDate.toTime.toUnix))
    js["field4"] = %false
    let pktLoaded = SimplePacket.load(js)
    check(pktLoaded.field1 == 10)
    check(pktLoaded.field2 == 862.0)
    check(pktLoaded.field3 == first)
    check(pktLoaded.field4 == false)
    check(pktLoaded.field5 == "test string")
    check(pktLoaded.field6 == nowTime)
    check(pktLoaded.field7 == nowDate)
  
  test "Simple packet with default value":
    var pkt = SimplePacketWithDefault.init(field2="x")
    var pkt2 = SimplePacketWithDefault.init(field1=100, field2="y")
    check(pkt.field1 == 10)
    check(pkt2.field1 == 100)
    check(pkt.field2 == "x")
    check(pkt2.field2 == "y")
    var js: JsonTree = pkt.dump()
    var js2: JsonTree = pkt2.dump()
    check(js["field1"] == %10)
    check(js["field2"] == %"x")
    check(js2["field1"] == %100)
    check(js2["field2"] == %"y")
    js["field2"] = %"y"
    js2["field2"] = %"x"
    let pktLoaded = SimplePacketWithDefault.load(js)
    let pktLoaded2 = SimplePacketWithDefault.load(js2)
    check(pktLoaded.field1 == 10)
    check(pktLoaded.field2 == "y")
    check(pktLoaded2.field1 == 100)
    check(pktLoaded2.field2 == "x")

  test "Packet with renamed field":
    var pkt = PacketWithRename.init(field1 = 7.0, field2 = false)
    check(pkt.field1 == 7.0)
    check(pkt.field2 == false)
    var js: JsonTree = pkt.dump()
    check(js["field1"] == %7.0)
    check(js.hasKey("field2") == false)
    check(js["field3"] == %false)
    js["field3"] = %true
    let pktLoaded = PacketWithRename.load(js)
    check(pktLoaded.field2 == true)
  
  test "Packet inheritance":
    let nowTime = getTime()
    var pkt = InheritedPacket.init(field2=nowTime)
    check(pkt.field1 == 3.0)
    check(pkt.field2 == nowTime)
    let js: JsonTree = pkt.dump()
    check(js["field1"] == %3.0)
    check(js["field2"] == %(nowTime.toUnix))
  
  test "Packet with optional field":
    let pkt = PacketWithOptionalFields.init(field1 = 10)
    let pkt2 = PacketWithOptionalFields.init(field1 = 1000, field2 = true.option)
    check(pkt.field1 == 10)
    check(pkt.field2 == none(bool))
    check(pkt2.field1 == 1000)
    check(pkt2.field2 == true.option)
    let js: JsonTree = pkt.dump()
    let js2: JsonTree = pkt2.dump()
    check(js["field1"] == %10)
    check(js.hasKey("field2") == false)
    check(js2["field1"] == %1000)
    check(js2["field2"] == %true)
    let pktLoaded = PacketWithOptionalFields.load(js)
    let pktLoaded2 = PacketWithOptionalFields.load(js2)
    check(pktLoaded.field1 == 10)
    check(pktLoaded.field2 == none(bool))
    check(pktLoaded2.field1 == 1000)
    check(pktLoaded2.field2 == true.option)

  test "Packet with optional field and default value":
    let pkt = PacketWithOptionalFieldsAndDefault.init()
    let pkt2 = PacketWithOptionalFieldsAndDefault.init(field1 = 1000.option)
    let pkt3 = PacketWithOptionalFieldsAndDefault.init(field1 = 7.option, field2 = 4.0.option)
    check(pkt.field1 == none(int))
    check(pkt.field2 == 3.0.option)
    check(pkt2.field1 == 1000.option)
    check(pkt2.field2 == 3.0.option)
    check(pkt3.field1 == 7.option)
    check(pkt3.field2 == 4.0.option)
    let js: JsonTree = pkt.dump()
    let js2: JsonTree = pkt2.dump()
    let js3: JsonTree = pkt3.dump()
    check(js.hasKey("field1") == false)
    check(js["field2"] == %3.0)
    check(js2["field1"] == %1000)
    check(js2["field2"] == %3.0)
    check(js3["field1"] == %7)
    check(js3["field2"] == %4.0)

  test "Packet with not exported fields":
    let pkt = PacketWithNotExportedFields.init(field1 = 5, field2 = false)
    check(pkt.field1 == 5)
    check(pkt.field2 == false)
    let js = pkt.dump()
    check(js.hasKey("field1") == false)
    check(js["field2"] == %false)
    let pktLoaded = PacketWithNotExportedFields.load(js)
    check(pktLoaded.field2 == false)

  test "Packet with subpacket":
    let pkt = PacketWithSubpacket.init(field1 = 50, field2 = SimplePacketWithDefault.init(field2 = "subpacket"))
    check(pkt.field1 == 50)
    check(pkt.field2 is SimplePacketWithDefault)
    check(pkt.field2.field1 == 10)
    check(pkt.field2.field2 == "subpacket")
    let js = pkt.dump()
    #echo "Resulted JSON: ", $js
    check(js["field1"] == %50)
    check(js["field2"]["field2"] == %"subpacket")
    let pktLoaded = PacketWithSubpacket.load(js)
    check(pktLoaded.field1 == 50)
    check(pktLoaded.field2 is SimplePacketWithDefault)
    check(pktLoaded.field2.field1 == 10)
    check(pktLoaded.field2.field2 == "subpacket")
