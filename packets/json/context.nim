import std/parsejson
import ../internal/types

export parsejson, types

type
  TPacketDataSourceJson* = ref object of TPacketDataSource
    parser*: JsonParser

template toCtx*(s: TPacketDataSource): TPacketDataSourceJson = cast[TPacketDataSourceJson](s)

proc skip*(s: TPacketDataSource) =
  let ctx = s.toCtx
  case ctx.parser.tok
  of tkCurlyLe:
    discard ctx.parser.getTok()
    while ctx.parser.tok != tkCurlyRi:
      discard ctx.parser.getTok()
      ctx.parser.eat(tkColon)
      s.skip()
      if ctx.parser.tok != tkComma:
        break
      discard ctx.parser.getTok() #skipping "," token
    eat(ctx.parser, tkCurlyRi)
  of tkBracketLe:
    discard ctx.parser.getTok()
    while ctx.parser.tok != tkBracketRi:
      ctx.skip()
      if ctx.parser.tok != tkComma:
        break
      discard ctx.parser.getTok() #skipping "," token
    eat(ctx.parser, tkBracketRi)
  else:
    discard ctx.parser.getTok()
