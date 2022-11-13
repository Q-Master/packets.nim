import std/[tables, times]
import packets/packets
import packets/json/serialization

packet Test:
  var userName* {.as_name: "user_name".}: string

packet Test1:
  var userName* {.as_name: "user_name".}: string
  var login*: string
  var password*: string
  var friends*: seq[Test]

let tJson = """{"user_name":"Васисуалий","login":"vasasuali","password":"password","friends":[{"user_name":"Вас"},{"user_name":"Вас1"},{"user_name":"Вас2"}]}"""

var t = now()
for _ in 0..1_000_000:
  var f {.used.} = Test1.loads(tJson)
echo "Nim packets " &  $(now()-t)
