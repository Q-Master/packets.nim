import ../context

# ------------------- Load

proc load*[T: SomeInteger](ctx: TPacketDataSource, dest: var T) =
  ctx.toCtx.parser.getInt(dest)
  ctx.toCtx.parser.getTok()

proc load*[T: SomeFloat](ctx: TPacketDataSource, dest: var T) =
  ctx.toCtx.parser.getFloat(dest)
  ctx.toCtx.parser.getTok()

# ------------------- Dump

proc dump*[T: SomeInteger | SomeFloat](t: T, dest: var string) =
  dest.add($t)
