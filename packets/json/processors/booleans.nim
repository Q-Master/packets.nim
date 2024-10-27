import ../context

# ------------------- Load

proc load*(ctx: TPacketDataSource, dest: var bool) =
  ctx.toCtx.parser.getBool(dest)
  ctx.toCtx.parser.getTok()

# ------------------- Dump

proc dump*(t: bool, dest: var string) =
  dest.add((if t: strTrue else: strFalse))
