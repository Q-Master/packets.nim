import std/parsejson
import ../internal/types

export parsejson, types

type
  TPacketDataSourceJson* = object of TPacketDataSource
    parser*: JsonParser

template toCtx*(s: var TPacketDataSource): var TPacketDataSourceJson = TPacketDataSourceJson(s)

proc skip*(s: var TPacketDataSource) =
  case s.toCtx.parser.tok
  of tkCurlyLe:
    discard s.toCtx.parser.getTok()
    while s.toCtx.parser.tok != tkCurlyRi:
      discard s.toCtx.parser.getTok()
      s.toCtx.parser.eat(tkColon)
      s.skip()
      if s.toCtx.parser.tok != tkComma:
        break
      discard s.toCtx.parser.getTok() #skipping "," token
    eat(s.toCtx.parser, tkCurlyRi)
  of tkBracketLe:
    discard s.toCtx.parser.getTok()
    while s.toCtx.parser.tok != tkBracketRi:
      s.toCtx.skip()
      if s.toCtx.parser.tok != tkComma:
        break
      discard s.toCtx.parser.getTok() #skipping "," token
    eat(s.toCtx.parser, tkBracketRi)
  else:
    discard s.toCtx.parser.getTok()
