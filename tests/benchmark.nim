import options
import tables
import times
import strutils
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

proc spacket() =
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
  var js: JsonTree = pkt.dump()
  #echo "Resulted JSON: ", $js
  js["field4"] = %false
  let pktLoaded = SimplePacket.load(js)
  discard pktLoaded.field1 == 10
  
proc spacketwdefault() =
  var pkt = SimplePacketWithDefault.init(field2="x")
  var pkt2 = SimplePacketWithDefault.init(field1=100, field2="y")
  var js: JsonTree = pkt.dump()
  var js2: JsonTree = pkt2.dump()
  js["field2"] = %"y"
  js2["field2"] = %"x"
  let pktLoaded = SimplePacketWithDefault.load(js)
  let pktLoaded2 = SimplePacketWithDefault.load(js2)
  discard pktLoaded.field1 == 10
  discard pktLoaded2.field1 == 100

proc spacketwrenamed() =
  var pkt = PacketWithRename.init(field1 = 7.0, field2 = false)
  var js: JsonTree = pkt.dump()
  js["field3"] = %true
  let pktLoaded = PacketWithRename.load(js)
  discard pktLoaded.field1 == 7.0

proc inheritance() =
  let nowTime = getTime()
  let pkt = InheritedPacket.init(field2=nowTime)
  let js: JsonTree = pkt.dump()
  let pktLoaded = InheritedPacket.load(js)
  discard pktLoaded.field1 == 3.0
  
proc optfield() =
  let pkt = PacketWithOptionalFields.init(field1 = 10)
  let pkt2 = PacketWithOptionalFields.init(field1 = 1000, field2 = true.option)
  let js: JsonTree = pkt.dump()
  let js2: JsonTree = pkt2.dump()
  let pktLoaded = PacketWithOptionalFields.load(js)
  let pktLoaded2 = PacketWithOptionalFields.load(js2)
  discard pktLoaded.field1 == 10
  discard pktLoaded2.field1 == 1000

proc optfielddefault() =
  let pkt = PacketWithOptionalFieldsAndDefault.init()
  let pkt2 = PacketWithOptionalFieldsAndDefault.init(field1 = 1000.option)
  let pkt3 = PacketWithOptionalFieldsAndDefault.init(field1 = 7.option, field2 = 4.0.option)
  let js: JsonTree = pkt.dump()
  let js2: JsonTree = pkt2.dump()
  let js3: JsonTree = pkt3.dump()
  let pktLoaded = PacketWithOptionalFieldsAndDefault.load(js)
  let pktLoaded2 = PacketWithOptionalFieldsAndDefault.load(js2)
  let pktLoaded3 = PacketWithOptionalFieldsAndDefault.load(js3)
  discard pktLoaded.field1 == none(int)
  discard pktLoaded2.field1 == 1000.option
  discard pktLoaded3.field1 == 7.option

proc notexported() =
  let pkt = PacketWithNotExportedFields.init(field1 = 5, field2 = false)
  let js = pkt.dump()
  let pktLoaded = PacketWithNotExportedFields.load(js)
  discard pktLoaded.field1 == 5

proc subpacket() =
  let pkt = PacketWithSubpacket.init(field1 = 50, field2 = SimplePacketWithDefault.init(field2 = "subpacket"))
  let js = pkt.dump()
  #echo "Resulted JSON: ", $js
  let pktLoaded = PacketWithSubpacket.load(js)
  discard pktLoaded.field1 == 50

proc main() =
  spacket()
  spacketwdefault()
  spacketwrenamed()
  inheritance()
  optfield()
  optfielddefault()
  notexported()
  subpacket()

let start = cpuTime()
for x in 0..100000:
  main()
echo "used Mem: ", formatSize getOccupiedMem(), " time: ", cpuTime() - start, "s"
