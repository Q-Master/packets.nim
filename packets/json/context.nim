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


template skip(source: var Stream, amount: Natural) =
  var pos = source.getPosition()
  pos += amount
  source.setPosition(pos)


template skipCR(self: var Stream) =
  let c = self.peekChar()
  if c == '\L':
    self.skip(1)


template skipIdents(source: var Stream) =
  var pos = 0
  var ch: char
  while true:
    pos = source.getPosition()
    ch = source.readChar()
    if ch in IdentChars:
      discard
    else:
      source.setPosition(pos)
      break


proc skip(self: var JsonParser) =
  var buf: array[2, char]
  var len: int
  var c: char
  var star = false
  while true:
    len = self.source.peekData(buf[0].addr, 2)
    if len == 0:
      break
    case buf[0]
    of '/':
      if buf[1] == '/':
        # skip line comment:
        self.source.skip(2)
        while true:
          c = self.source.readChar()
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
        while true:
          c = self.source.readChar()
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
  var ch: char
  for i in 0..3:
    ch = source.readChar()
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
  let firstCode = source.parseHex4()
  if firstCode >= 0xDC00 and firstCode <= 0xDFFF:
    raise newException(ValueError, "Mailformed UTF16")
  if firstCode >= 0xD800 and firstCode <= 0xDBFF:
    source.skip(2)
    let secondCode = source.parseHex4()
    if secondCode < 0xDC00 or secondCode > 0xDFFF:
      raise newException(ValueError, "Mailformed UTF16")
    codepoint = 0x10000.uint32 + ((firstCode and 0x3FF).shl(10) or (secondCode and 0x3FF))
  else:
    codepoint = firstCode
  result = toUTF8(Rune(codepoint))


proc skipString(source: var Stream): int =
  var ch : char
  result = 0
  while true:
    ch = source.readChar()
    if ch == '\"':
      break
    if ch != '\\':
      result.inc
    else:
      ch = source.readChar()
      case ch
      of 'b':
        result.inc
      of 'f':
        result.inc
      of 'n':
        result.inc
      of 'r':
        result.inc
      of 't':
        result.inc
      of '\"', '\\', '/':
        result.inc
      of 'u':
        result.inc(source.parseUTF16().len)
      else:
        raise newException(ValueError, "Unexpected escape sequence")


proc parseString(source: var Stream, dest: var string) =
  var ch : char
  var pos = source.getPosition()
  let strlen = source.skipString()
  source.setPosition(pos)
  dest.setLen(strlen)
  var destUnchecked = cast[ptr UncheckedArray[char]](dest[0].addr)
  var at = 0
  template add(ds: ptr UncheckedArray[char], c: char) =
    ds[at] = c
    at.inc
  while true:
    ch = source.readChar()
    if ch == '\"':
      break
    if ch != '\\':
      destUnchecked.add(ch)
    else:
      ch = source.readChar()
      case ch
      of 'b':
        destUnchecked.add('\b')
      of 'f':
        destUnchecked.add('\f')
      of 'n':
        destUnchecked.add('\n')
      of 'r':
        destUnchecked.add('\r')
      of 't':
        destUnchecked.add('\t')
      of '\"', '\\', '/':
        destUnchecked.add(ch)
      of 'u':
        for c in source.parseUTF16():
          destUnchecked.add(c)
      else:
        raise newException(ValueError, "Unexpected escape sequence")


proc parseInt(source: var Stream, dest: var int): int =
  result = 0
  var pos: int
  var ch: char
  var sign = 1
  while true:
    pos = source.getPosition()
    ch = source.readChar()
    case ch
    of '-':
      sign = -1
    of '0' .. '9':
      dest *= 10
      dest += (ord(ch) - ord('0'))
      if result == 0:
        result = 1
      else:
        result *= 10
    else:
      source.setPosition(pos)
      break    


proc getString*(self: var JsonParser, dest: var string) =
  if self.tok == tkString:
    self.source.parseString(dest)
    self.tok = tkError
  else:
    raise newException(ValueError, "Current token is not string: " & $self.tok)


proc getInt*[T:SomeInteger](self: var JsonParser, dest: var T) =
  if self.tok == tkInt:
    var i = 0
    discard self.source.parseInt(i)
    let ch = self.source.peekChar()
    if ch in {'.', 'E', 'e'}:
      raise newException(ValueError, "Floating point number found")
    dest = T(i)
    self.tok = tkError
  else:
    raise newException(ValueError, "Current token is not integer: " & $self.tok)


proc getFloat*[T: SomeFloat](self: var JsonParser, dest: var T) =
  var pos: int
  var f = 0.0
  var mantissa = 0
  var exponent = 0
  var multiplier = 0
  if self.tok == tkFloat or self.tok == tkInt:
    discard self.source.parseInt(mantissa)
    f = mantissa.float
    pos = self.source.getPosition()
    let ch = self.source.readChar()
    case ch
    of '.':
      multiplier = self.source.parseInt(exponent)
      f += exponent.float / multiplier.float
    of 'E', 'e':
      multiplier = 0
      discard self.source.parseInt(multiplier)
      if multiplier > 0:
        f *= multiplier.float
      elif multiplier < 0:
        f /= multiplier.float
    else:
      self.source.setPosition(pos)
    dest = T(f)
    self.tok = tkError
  else:
    raise newException(ValueError, "Current token is not float: " & $self.tok)


proc getBool*(self: var JsonParser, dest: var bool) =
  if self.tok == tkTrue:
    dest = true
  elif self.tok == tkFalse:
    dest = false
  else:
    raise newException(ValueError, "Current token is not bool: " & $self.tok)
  self.source.skipIdents()
  self.tok = tkError


proc getNull*(self: var JsonParser) =
  if self.tok != tkNull:
    raise newException(ValueError, "Current token is not bool: " & $self.tok)
  self.source.skipIdents()
  self.tok = tkError


proc getTok*(self: var JsonParser): TokKind =
  self.skip() # skip whitespace, comments
  let ch = self.source.peekChar
  case ch
  of '-', '.', '0'..'9':
    result = tkInt
  of '"':
    self.source.skip(1)
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
  of 'n', 'N':
    result = tkNull
  of 't', 'T':
    result = tkTrue
  of 'f', 'F':
    result = tkFalse
  else:
    self.source.skip(1)
    result = tkError
  self.tok = result


proc eat*(p: var JsonParser, tok: TokKind) =
  if p.tok == tok: discard getTok(p)
  else: raise newException(ValueError, "Unexpected token " & $p.tok & ", waiting " & $tok)


template skipCurlies(self: var JsonParser) =
  var curlies = 1
  var ch: char = ' '
  var skip: bool = false
  while true:
    ch = self.source.readChar()
    if not skip:
      case ch
      of '{':
        curlies.inc()
      of '}':
        curlies.dec()
        if curlies == 0:
          break
      else:
        discard
    if ch == '\\':
      skip = true
    else:
      skip = false


template skipBrackets(self: var JsonParser) =
  var brackets = 1
  var ch: char = ' '
  var skip: bool = false
  while true:
    ch = self.source.readChar()
    if not skip:
      case ch
      of '[':
        brackets.inc()
      of ']':
        brackets.dec()
        if brackets == 0:
          break
      else:
        discard
    if ch == '\\':
      skip = true
    else:
      skip = false


proc skip*(s: var TPacketDataSource) =
  case s.toCtx.parser.tok
  of tkCurlyLe:
    s.toCtx.parser.skipCurlies()
    s.toCtx.parser.tok = tkError
  of tkBracketLe:
    s.toCtx.parser.skipBrackets()
    s.toCtx.parser.tok = tkError
  else:
    case s.toCtx.parser.tok
    of tkString:
      discard s.toCtx.parser.source.skipString()
    of tkTrue, tkFalse, tkNull:
      s.toCtx.parser.source.skipIdents()
    of tkInt, tkFloat:
      var f: float
      s.toCtx.parser.getFloat(f)
    else:
      discard
  discard s.toCtx.parser.getTok()


proc open*(self: var JsonParser, strm: Stream) =
  self.source = strm
  self.tok = tkError
