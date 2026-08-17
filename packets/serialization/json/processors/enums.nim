import ../context

# ------------------- Load

proc load*[T: enum](_: typedesc[T], ctx: TPacketDataSource): T =
  result = T(getInt[int](ctx.toCtx.parser))
  ctx.toCtx.parser.getTok()

# ------------------- Dump

proc dump*[T: enum](en: T, dest: var string) =
  dest.add($(ord(en).int))
