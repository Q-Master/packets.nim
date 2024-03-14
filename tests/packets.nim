import std/[unittest, options, tables, times]
import packets/packets
import packets/json/serialization
import types


packet PacketWithNotExportedFields:
  var field1: int #When loaded the contents of the field are undefined
  var field2*: bool


suite "Packets":
  setup:
    discard

  test "Simple packet":
    let nowTime = initTime(getTime().toUnix, 0)
    var nowDate = now()
    nowDate = nowDate - initDuration(nanoseconds=nowDate.nanosecond)
    #echo nowDate.nanosecond
    var pkt = SimplePacket(
      field1: 10,
      field2: 862.0,
      field3: first,
      field4: true,
      field5: "test string",
      field6: nowTime,
      field7: nowDate)
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
    var pkt = SimplePacketWithDefault(field2:"x")
    var pkt2 = SimplePacketWithDefault(field1:100, field2:"y")
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
    var pkt = PacketWithRename(field1: 7.0, field2: false)
    check(pkt.field1 == 7.0)
    check(pkt.field2 == false)
    var js: string = pkt.dumps()
    let pktLoaded = PacketWithRename.loads(js)
    check(pktLoaded.field1 == 7.0)
    check(pktLoaded.field2 == false)
  
  test "Packet inheritance":
    var nowTime = getTime()
    nowTime = nowTime - initDuration(nanoseconds=nowTime.nanosecond)
    var pkt = InheritedPacket(field2: nowTime)
    check(pkt.field1 == 3.0)
    check(pkt.field2 == nowTime)
    let js: string = pkt.dumps()
    let pktLoaded = InheritedPacket.loads(js)
    check(pktLoaded.field1 == 3.0)
    check(pktLoaded.field2 == nowTime)
  
  test "Packet with optional field":
    let pkt = PacketWithOptionalFields(field1: 10)
    let pkt2 = PacketWithOptionalFields(field1: 1000, field2: true.option)
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
    let pkt = PacketWithOptionalFieldsAndDefault()
    let pkt2 = PacketWithOptionalFieldsAndDefault(field1: 1000.option)
    let pkt3 = PacketWithOptionalFieldsAndDefault(field1: 7.option, field2: 4.0.option)
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
    let pkt = PacketWithNotExportedFields(field1: 5, field2: false)
    check(pkt.field1 == 5)
    check(pkt.field2 == false)
    let js = pkt.dumps()
    let pktLoaded = PacketWithNotExportedFields.loads(js)
    check(pktLoaded.field1 == 0)
    check(pktLoaded.field2 == false)

  test "Packet with subpacket":
    let pkt = PacketWithSubpacket(field1: 50, field2: SimplePacketWithDefault(field2: "subpacket"))
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
    let pkt = PacketWithOptionalSubpacket(field1: SimplePacketWithDefault(field2: "subpacket").option)
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
    let pkt = SimpleArrayPacket(field1: 1, field2: 2.0)
    check(pkt.field1 == 1)
    check(pkt.field2 == 2.0)
    let js = pkt.dumps()
    #echo "Resulted JSON: ", js
    when defined(enablePacketIDs):
      check(js.len == 19)
    else:
      check js == "[1,2.0]"
      check(js.len == 7)
    let pktLoaded = SimpleArrayPacket.loads(js)
    check(pktLoaded.field1 == 1)
    check(pktLoaded.field2 == 2.0)

#[
suite "Seq of packets":
  setup:
    discard

  test "Seq of packets":
    var js: string
    when defined(enablePacketIDs):
      js = "[{\"id\": -135810012, \"field1\": 1, \"field2\": \"a\"}, {\"id\": -135810012, \"field1\": 2, \"field2\": \"b\"}]"
    else:
      js = "[{\"field1\": 1, \"field2\": \"a\"}, {\"field1\": 2, \"field2\": \"b\"}]"
    let pkt = seq[SimplePacketWithDefault].loads(js)
    check(pkt.len == 2)
    check(pkt[0].field1 == 1)
    check(pkt[1].field1 == 2)
    let pktd {.used.}= pkt.dumps()


suite "Packet with table":
  setup:
    discard

  test "Packet with table":
    var js: string
    when defined(enablePacketIDs):
      js = "{\"id\": -2135839261, \"field1\": 1, \"field2\": {\"a\": 1}}"
    else:
      js = "{\"field1\": 1, \"field2\": {\"a\": 1}}"
    let pkt = PacketWithTable.loads(js)
    check(pkt.field2["a"] == 1)
]#

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