import ../context

# ------------------- Load

proc load*(_: typedesc[bool], ctx: TPacketDataSource): bool =
  result = ctx.toCtx.parser.getBool()
  ctx.toCtx.parser.getTok()

# ------------------- Dump

proc dump*(t: bool, dest: var string) =
  dest.add((if t: strTrue else: strFalse))
