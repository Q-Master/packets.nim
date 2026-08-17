import ../context

# ------------------- Load

proc load*[T: SomeInteger](_: typedesc[T], ctx: TPacketDataSource): T =
  result = getInt[T](ctx.toCtx.parser)
  ctx.toCtx.parser.getTok()


proc load*[T: SomeFloat](_: typedesc[T], ctx: TPacketDataSource): T =
  result = getFloat[T](ctx.toCtx.parser)
  ctx.toCtx.parser.getTok()

# ------------------- Dump

proc dump*[T: SomeInteger | SomeFloat](t: T, dest: var string) =
  dest.add($t)
