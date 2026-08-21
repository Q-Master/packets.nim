import std/[unittest]
import ../packets/serialization/json

const tJson = """{"user_name":"Васисуалий","login":"vasasuali","password":"password","friends":[{"user_name":"Вас"},{"user_name":"Вас1"},{"user_name":"Вас2"}]}"""
const tJson1 = """{"field1":1,"field2":2,"field3":[1,2,3,4]}"""
const tJson2 = """{"field1":1e3,"field2":1.1e-3}"""


suite "JSON":
  setup:
    discard

  test "JSON loads":
    let js {.used.} = tJson.loads() 
    let res = js.dumps()
    check(res == tJson)
    check(js["user_name"].asString=="Васисуалий")

  test "Macro JSON generate":
    let macrotest = %*{
      "user_name":"Васисуалий",
      "login":"vasasuali",
      "password":"password",
      "friends":[
        {"user_name":"Вас"},
        {"user_name":"Вас1"},
        {"user_name":"Вас2"}
      ]
    }
    check(macrotest.dumps()==tJson)

  test "Manual object creation":
    var js = newJObject()
    js["field1"] = 1
    js["field2"] = 2
    js["field3"] = @[1,2,3]
    js["field3"].add(4)
    check(js.dumps() == tJson1)

  test "Check fp parsing":
    let js = tJson2.loads()
    check js["field1"].asFloat == 1000.0
    check js["field2"].asFloat == 0.0011
