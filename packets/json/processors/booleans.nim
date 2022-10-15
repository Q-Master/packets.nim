import ../context

# ------------------- Load

proc load*(ctx: TPacketDataSource, t: typedesc[bool]): bool =
  if ctx.toCtx.parser.tok != tkFalse and ctx.toCtx.parser.tok != tkTrue:
    raise newException(ValueError, "Wrong field type: " & $ctx.toCtx.parser.tok)
  result = (ctx.toCtx.parser.tok == tkTrue)
  discard ctx.toCtx.parser.getTok()

# ------------------- Dump

proc dump*(t: bool): string =
  result = (if t: "true" else: "false")
