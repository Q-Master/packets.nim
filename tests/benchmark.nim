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

proc tproc(p: Test1) =
  var fl {.used.} = p.login

var t = now()
for _ in 0..1000000:
  var f = Test1.loads(tJson)
  tproc(f)
  #echo f.pretty

echo "Nim packets " &  $(now()-t)
