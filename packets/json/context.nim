import std/[streams, unicode, strutils]
import ../internal/types

export types

type
  TokKind* = enum # must be synchronized with TJsonEventKind!
    tkError,
    tkEof,
    tkString,
    tkInt,
    tkFloat,
    tkTrue,
    tkFalse,
    tkNull,
    tkCurlyLe,
    tkCurlyRi,
    tkBracketLe,
    tkBracketRi,
    tkColon,
    tkComma

  JsonParser* = object
    source: Stream
    tok*: TokKind
    a*: string

  TPacketDataSourceJson* = object of TPacketDataSource
    parser*: JsonParser


const strLCurly* = "{"
const strRCurly* = "}"
const strLBracket* = "["
const strRBracket* = "]"
const strComma* = ","
const strQuote* = "\""
const strQuoteColon* = "\":"
const strTrue* = "true"
const strFalse* = "false"
const strNull* = "null"


template toCtx*(s: var TPacketDataSource): var TPacketDataSourceJson = TPacketDataSourceJson(s)


proc skip(source: var Stream, amount: Natural) =
  var pos = source.getPosition()
  pos += amount
  source.setPosition(pos)


proc skipCR(self: var Stream) =
  let c = self.peekChar()
  if c == '\L':
    self.skip(1)


proc skip(self: var JsonParser) =
  var buf: string = newString(2)
  while true:
    discard self.source.peekData(buf[0].addr, 2)
    case buf[0]
    of '/':
      if buf[1] == '/':
        # skip line comment:
        self.source.skip(2)
        while true:
          let c = self.source.readChar()
          case c
          of '\0':
            break
          of '\c':
            self.source.skipCR()
            break
          of '\L':
            break
          else:
            discard
      elif buf[1] == '*':
        # skip long comment:
        self.source.skip(2)
        var star = false
        while true:
          let c = self.source.readChar()
          case c
          of '\0':
            raise newException(IOError, "Unexpected EOF")
          of '\c':
            self.source.skipCR()
            star = false
          of '\L':
            star = false
          of '*':
            star = true
          of '/':
            if star:
              break
          else:
            star = false
      else:
        break
    of ' ', '\t':
      self.source.skip(1)
    of '\c':
      self.source.skipCR()
    of '\L':
      self.source.skip(1)
    else:
      break

proc parseHex4(source: var Stream): uint32 =
  for i in 0..3:
    var ch = source.readChar()
    if ch >= '0' and ch <= '9':
      result += ch.uint32 - '0'.uint32
    elif ch >= 'A' and ch <= 'F':
      result += 10.uint32 + ch.uint32 - 'A'.uint32
    elif ch >= 'a' and ch <= 'f':
      result += 10.uint32 + ch.uint32 - 'a'.uint32
    else:
      raise newException(ValueError, "Unexpected hex code")
    if i < 3:
      result = result.shl(4)


proc parseUTF16(source: var Stream): string =
  var codepoint: uint32
  var firstCode = source.parseHex4()
  if firstCode >= 0xDC00 and firstCode <= 0xDFFF:
    raise newException(ValueError, "Mailformed UTF16")
  if firstCode >= 0xD800 and firstCode <= 0xDBFF:
    var twoBytes = source.readStr(2)
    if twoBytes != "\\u":
      raise newException(ValueError, "Mailformed UTF16")
    var secondCode = source.parseHex4()
    if secondCode < 0xDC00 or secondCode > 0xDFFF:
      raise newException(ValueError, "Mailformed UTF16")
    codepoint = 0x10000.uint32 + ((firstCode and 0x3FF).shl(10) or (secondCode and 0x3FF))
  else:
    codepoint = firstCode
  result = toUTF8(Rune(codepoint))


proc parseString(source: var Stream, dest: var string) =
  while true:
    var ch = source.readChar()
    if ch == '\"':
      break
    if ch != '\\':
      dest.add(ch)
    else:
      ch = source.readChar()
      case ch
      of 'b':
        dest.add('\b')
      of 'f':
        dest.add('\f')
      of 'n':
        dest.add('\n')
      of 'r':
        dest.add('\r')
      of 't':
        dest.add('\t')
      of '\"', '\\', '/':
        dest.add(ch)
      of 'u':
        dest.add(source.parseUTF16())
      else:
        raise newException(ValueError, "Unexpected escape sequence")


proc parseNumber(source: var Stream, dest: var string): bool =
  result = false
  while true:
    let pos = source.getPosition()
    let ch = source.readChar()
    case ch
    of '0'..'9', '-':
      dest.add(ch)
    of '.', 'E', 'e':
      dest.add(ch)
      result = true
    else:
      source.setPosition(pos)
      break
  

proc parseBoolNull(source: var Stream, dest: var string) =
  var ch = source.peekChar()
  if ch in {'T', 't', 'F', 'f', 'N', 'n'}:
    while true:
      let pos = source.getPosition()
      let ch = source.readChar()
      if ch in IdentChars:
        dest.add(ch)
      else:
        source.setPosition(pos)
        break


proc getTok*(self: var JsonParser): TokKind =
  self.a.setLen(0)
  self.skip() # skip whitespace, comments
  let ch = self.source.peekChar
  case ch
  of '-', '.', '0'..'9':
    let isFloat = self.source.parseNumber(self.a)
    if isFloat:
      result = tkFloat
    else:
      result = tkInt
  of '"':
    self.source.skip(1)
    self.source.parseString(self.a)
    result = tkString
  of '[':
    self.source.skip(1)
    result = tkBracketLe
  of '{':
    self.source.skip(1)
    result = tkCurlyLe
  of ']':
    self.source.skip(1)
    result = tkBracketRi
  of '}':
    self.source.skip(1)
    result = tkCurlyRi
  of ',':
    self.source.skip(1)
    result = tkComma
  of ':':
    self.source.skip(1)
    result = tkColon
  of '\0':
    result = tkEof
  of 'a'..'z', 'A'..'Z', '_':
    self.source.parseBoolNull(self.a)
    case self.a.toLower()
    of "null": result = tkNull
    of "true": result = tkTrue
    of "false": result = tkFalse
    else: result = tkError
  else:
    self.source.skip(1)
    result = tkError
  self.tok = result


proc eat*(p: var JsonParser, tok: TokKind) =
  if p.tok == tok: discard getTok(p)
  else: raise newException(ValueError, "Unexpected token " & $tok)


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


proc open*(self: var JsonParser, strm: Stream) =
  self.source = strm
  self.a = ""
  self.tok = tkError
