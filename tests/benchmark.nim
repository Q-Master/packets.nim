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

const tJson = """{"user_name":"Васисуалий","login":"vasasuali","password":"password","friends":[{"user_name":"Вас"},{"user_name":"Вас1"},{"user_name":"Вас2"}]}"""

proc tproc(p: Test1) =
  var fl {.used.} = p.login

var t = now()
var f: Test1
for _ in 0..100:
  f = Test1.loads(tJson)
  f.tproc()

echo "Nim packets " &  $(now()-t)
