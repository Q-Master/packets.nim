import unittest
import options
import tables
import packets/packets
import packets/json/serialization
import packets/json/processors/[boolean, numeric, str, datetime, enums]

packet SimplePacket:
  var field1*: int
  var field2*: bool

packet SimplePacketWithDefault:
  var field1*: int = 10
  var field2*: string

suite "Simple packets":
  setup:
    discard

  test "Simple Packet":
    var pkt = SimplePacket.init(field1=10, field2=true)
    check(pkt.field1 == 10)
    check(pkt.field2 == true)

  test "Simple Packet with Default":
    var pkt = SimplePacketWithDefault.init(field2="x")
    var pkt2 = SimplePacketWithDefault.init(field1=100, field2="y")
    check(pkt.field1 == 10)
    check(pkt2.field1 == 100)
    check(pkt.field2 == "x")
    check(pkt2.field2 == "y")

