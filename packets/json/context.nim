import std/[streams, unicode, strutils]
import ../internal/types

export types

type
  TokKind* = enum # must be synchronized with TJsonEventKind!
    tkNone,
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

  JsonParser* = ref JsonParserObj
  JsonParserObj* = object
    source: Stream
    tok*: TokKind

  TPacketDataSourceJson* = ref object of TPacketDataSource
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


proc newDataSourceJson*(): TPacketDataSourceJson =
  result.new
  result.parser.new


template toCtx*(s: TPacketDataSource): TPacketDataSourceJson = TPacketDataSourceJson(s)


template skip(self: JsonParser, amount: Natural) =
  self.source.setPosition(self.source.getPosition()+amount)


template skipCR(self: JsonParser) =
  let c = self.source.peekChar()
  if c == '\L':
    self.skip(1)


template skipIdents(self: JsonParser) =
  var pos = 0
  var ch: char
  while true:
    pos = self.source.getPosition()
    ch = self.source.readChar()
    if ch in IdentChars:
      discard
    else:
      self.source.setPosition(pos)
      break


proc skip(self: JsonParser) =
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
        self.skip(2)
        while true:
          c = self.source.readChar()
          case c
          of '\0', '\L':
            break
          of '\c':
            self.skipCR()
            break
          else:
            discard
      elif buf[1] == '*':
        # skip long comment:
        self.skip(2)
        while true:
          c = self.source.readChar()
          case c
          of '\0':
            raise newException(IOError, "Unexpected EOF")
          of '\c':
            self.skipCR()
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
    of ' ', '\t', '\L':
      self.skip(1)
    of '\c':
      self.skipCR()
    else:
      break


proc parseHex4(self: JsonParser): uint32 =
  var ch: char
  for i in 0..3:
    ch = self.source.readChar()
    case ch
    of '0' .. '9':
      result += ch.uint32 - '0'.uint32
    of 'A' .. 'F':
      result += 10.uint32 + ch.uint32 - 'A'.uint32
    of 'a' .. 'f':
      result += 10.uint32 + ch.uint32 - 'a'.uint32
    else:
      raise newException(ValueError, "Unexpected hex code")
    if i < 3:
      result = result.shl(4)


proc parseUTF16(self: JsonParser): string =
  var codepoint: uint32
  let firstCode = self.parseHex4()
  if firstCode >= 0xDC00 and firstCode <= 0xDFFF:
    raise newException(ValueError, "Mailformed UTF16")
  if firstCode >= 0xD800 and firstCode <= 0xDBFF:
    self.skip(2)
    let secondCode = self.parseHex4()
    if secondCode < 0xDC00 or secondCode > 0xDFFF:
      raise newException(ValueError, "Mailformed UTF16")
    codepoint = 0x10000.uint32 + ((firstCode and 0x3FF).shl(10) or (secondCode and 0x3FF))
  else:
    codepoint = firstCode
  result = toUTF8(Rune(codepoint))


proc strLen(self: JsonParser): int =
  var ch : char
  result = 0
  while true:
    ch = self.source.readChar()
    if ch == '\"':
      break
    if ch != '\\':
      result.inc
    else:
      ch = self.source.readChar()
      case ch
      of 'b', 'f', 'n', 'r', 't', '\"', '\\', '/':
        result.inc
      of 'u':
        result.inc(self.parseUTF16().len)
      else:
        raise newException(ValueError, "Unexpected escape sequence")


proc parseString(self: JsonParser, dest: var string) =
  var ch : char
  var pos = self.source.getPosition()
  let strlen = self.strLen()
  self.source.setPosition(pos)
  dest.setLen(strlen)
  if strlen == 0:
    ch = self.source.readChar() # skipping '\"'
  else:
    var destUnchecked = cast[ptr UncheckedArray[char]](dest[0].addr)
    var at = 0
    template add(ds: ptr UncheckedArray[char], c: char) =
      ds[at] = c
      at.inc
    while true:
      ch = self.source.readChar()
      if ch == '\"':
        break
      if ch != '\\':
        destUnchecked.add(ch)
      else:
        ch = self.source.readChar()
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
          for c in self.parseUTF16():
            destUnchecked.add(c)
        else:
          raise newException(ValueError, "Unexpected escape sequence")


proc parseInt(self: JsonParser): (int, int) =
  var res: int = 0
  var multiplier: int = 1
  var pos: int
  var ch: char
  while true:
    pos = self.source.getPosition()
    ch = self.source.readChar()
    case ch
    of '-':
      res *= -1
    of '0' .. '9':
      if res > 0:
        res *= 10
      res += (ord(ch) - ord('0'))
      multiplier *= 10
    else:
      self.source.setPosition(pos)
      break
  result = (res, multiplier)


proc getString*(self: JsonParser, dest: var string) =
  if self.tok == tkString:
    self.parseString(dest)
    self.tok = tkError
  else:
    raise newException(ValueError, "Current token is not string: " & $self.tok)


proc isFloat*(self: JsonParser): bool = 
  var offset = 0
  var ch: char
  while true:
    ch = self.source.readChar()
    offset += 1
    if ch in '0' .. '9':
      continue
    elif ch in {'.', 'E', 'e'}:
      self.skip(-offset)
      return true
    else:
      self.skip(-offset)
      return false


proc getInt*[T:SomeInteger](self: JsonParser, dest: var T) =
  if self.tok == tkInt:
    let (i, _) = self.parseInt()
    let ch = self.source.peekChar()
    if ch in {'.', 'E', 'e'}:
      raise newException(ValueError, "Floating point number found")
    dest = T(i)
    self.tok = tkError
  else:
    raise newException(ValueError, "Current token is not integer: " & $self.tok)


proc getFloat*[T: SomeFloat](self: JsonParser, dest: var T) =
  var pos: int
  var f = 0.0
  var mantissa = 0
  var exponent = 0
  var multiplier = 0
  if self.tok == tkFloat or self.tok == tkInt:
    (mantissa, multiplier) = self.parseInt()
    f = mantissa.float
    pos = self.source.getPosition()
    let ch = self.source.readChar()
    case ch
    of '.':
      (exponent, multiplier) = self.parseInt()
      f += exponent.float / multiplier.float
    of 'E', 'e':
      (exponent, multiplier) = self.parseInt()
      if exponent > 0:
        f *= exponent.float
      elif exponent < 0:
        f /= exponent.float
    else:
      self.source.setPosition(pos)
    dest = T(f)
    self.tok = tkError
  else:
    raise newException(ValueError, "Current token is not float: " & $self.tok)


proc getBool*(self: JsonParser, dest: var bool) =
  if self.tok == tkTrue:
    dest = true
  elif self.tok == tkFalse:
    dest = false
  else:
    raise newException(ValueError, "Current token is not bool: " & $self.tok)
  self.skipIdents()
  self.tok = tkError


proc getNull*(self: JsonParser) =
  if self.tok != tkNull:
    raise newException(ValueError, "Current token is not bool: " & $self.tok)
  self.skipIdents()
  self.tok = tkError


proc getTok*(self: JsonParser) =
  self.skip() # skip whitespace, comments
  let ch = self.source.peekChar
  case ch
  of '-', '.', '0'..'9':
    self.tok = tkInt
  of '"':
    self.skip(1)
    self.tok = tkString
  of '[':
    self.skip(1)
    self.tok = tkBracketLe
  of '{':
    self.skip(1)
    self.tok = tkCurlyLe
  of ']':
    self.skip(1)
    self.tok = tkBracketRi
  of '}':
    self.skip(1)
    self.tok = tkCurlyRi
  of ',':
    self.skip(1)
    self.tok = tkComma
  of ':':
    self.skip(1)
    self.tok = tkColon
  of '\0':
    self.tok = tkEof
  of 'n', 'N':
    self.tok = tkNull
  of 't', 'T':
    self.tok = tkTrue
  of 'f', 'F':
    self.tok = tkFalse
  else:
    self.skip(1)
    self.tok = tkError


proc eat*(p: JsonParser, tok: TokKind) =
  if p.tok == tok: 
    getTok(p)
  else: 
    raise newException(ValueError, "Unexpected token " & $p.tok & ", waiting " & $tok)


template skipCurlies(self: JsonParser) =
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


template skipBrackets(self: JsonParser) =
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


template skipString(self: JsonParser) =
  var ch : char
  while true:
    ch = self.source.readChar()
    if ch == '\"':
      break
    if ch != '\\':
      continue
    else:
      ch = self.source.readChar()
      if ch == 'u':
        self.skip(4)


template skipNumber(self: JsonParser) =
  var ch : char
  while true:
    ch = self.source.readChar()
    if ch in '0' .. '9' or ch in {'.', 'E', 'e'}:
      continue
    else:
      self.skip(-1)
      break


proc skip*(s: TPacketDataSource) =
  let parser = s.toCtx.parser
  case parser.tok
  of tkCurlyLe:
    parser.skipCurlies()
    parser.tok = tkError
  of tkBracketLe:
    parser.skipBrackets()
    parser.tok = tkError
  else:
    case parser.tok
    of tkString:
      parser.skipString()
    of tkTrue, tkFalse, tkNull:
      parser.skipIdents()
    of tkInt, tkFloat:
      parser.skipNumber()
    else:
      discard
  parser.getTok()


proc open*(self: JsonParser, strm: Stream) =
  self.source = strm
  self.tok = tkNone

proc close*(self: JsonParser) =
  self.source = nil
  self.tok = tkNone
