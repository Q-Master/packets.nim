import ../context

# ------------------- Load

proc load*(ctx: var TPacketDataSource, dest: var bool) =
  if ctx.toCtx.parser.tok != tkFalse and ctx.toCtx.parser.tok != tkTrue:
    raise newException(ValueError, "Wrong field type: " & $ctx.toCtx.parser.tok)
  dest = (ctx.toCtx.parser.tok == tkTrue)
  discard ctx.toCtx.parser.getTok()

# ------------------- Dump

proc dump*(t: bool, dest: var string) =
  dest.add((if t: strTrue else: strFalse))
