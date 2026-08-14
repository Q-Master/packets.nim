import ../context

# ------------------- Load

proc load*[T: SomeInteger](_: typedesc[T], ctx: TPacketDataSource): T =
  result = ctx.toCtx.parser.getInt()
  ctx.toCtx.parser.getTok()

proc load*[T: SomeFloat](_: typedesc[T], ctx: TPacketDataSource): T =
  result = ctx.toCtx.parser.getFloat()
  ctx.toCtx.parser.getTok()

# ------------------- Dump

proc dump*[T: SomeInteger | SomeFloat](t: T, dest: var string) =
  dest.add($t)
