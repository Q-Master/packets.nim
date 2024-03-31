import std/[sets]
import ../context

# ------------------- Load

proc load*[T: TPacket](ctx: var TPacketDataSource, dest: var T) =
  mixin load
  if ctx.toCtx.parser.tok == tkCurlyLe:
    var req = dest.requiredFields()
    discard ctx.toCtx.parser.getTok()
    var currKey: string
    var res: int
    while ctx.toCtx.parser.tok != tkCurlyRi:
      currKey.setLen(0)
      ctx.toCtx.parser.getString(currKey)
      discard ctx.toCtx.parser.getTok()
      ctx.toCtx.parser.eat(tkColon)
      res = load(currKey, dest, ctx)
      if res == 1:
        req.dec()
      elif res == -1:
        ctx.skip()
      if ctx.toCtx.parser.tok != tkComma:
        break
      discard ctx.toCtx.parser.getTok() #skipping "," token
    if req > 0:
      raise newException(ValueError, $req & " required field(s) missing for " & $T)
    eat(ctx.toCtx.parser, tkCurlyRi)
  else:
    raise newException(ValueError, "Not an object")

proc load*[T: TArrayPacket](ctx: var TPacketDataSource, dest: var T) =
  mixin load
  if ctx.toCtx.parser.tok == tkBracketLe:
    var idx = 0
    var req = dest.requiredFields()
    discard ctx.toCtx.parser.getTok()
    while ctx.toCtx.parser.tok != tkBracketRi:
      #ArrayPacket's fields are all required fields
      if idx < req:
        discard load(idx, dest, ctx)
      else:
        discard ctx.toCtx.parser.getTok() #skipping extra data
      if ctx.toCtx.parser.tok != tkComma:
        break
      idx.inc()
      discard ctx.toCtx.parser.getTok() #skipping "," token
    eat(ctx.toCtx.parser, tkBracketRi)
    if idx < req-1:
      raise newException(ValueError, $(req - idx) & " required field(s) missing for " & $T)
  else:
    raise newException(ValueError, "Not an object")

# ------------------- Dump

proc dump*[T: TPacket](p: T, dest: var string) =
  mixin dump
  dest.add(strLCurly)
  var first: bool = true
  var d: string
  for k,v in p.fields:
    d.setLen(0)
    if v == false:
      dump(k, p, d)
      if d == strNull:
        continue
      if first:
        first = false
      else:
        dest.add(strComma)
      dest.add(strQuote & k & strQuoteColon & d)
    else:
      if first:
        first = false
      else:
        dest.add(strComma)
      dest.add(strQuote & k & strQuoteColon)
      dump(k, p, dest)
  dest.add(strRCurly)

proc dump*[T: TArrayPacket](p: T, dest: var string) =
  mixin dump
  dest.add(strLBracket)
  var first: bool = true
  for idx in 0 ..< p.requiredFields:
    if first:
        first = false
    else:
      dest.add(strComma) 
    dump(idx, p, dest)
  dest.add(strRBracket)