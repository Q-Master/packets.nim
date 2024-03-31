import ../context

# ------------------- Load

proc load*[T: SomeInteger](ctx: var TPacketDataSource, dest: var T) =
  getInt[T](ctx.toCtx.parser, dest)
  discard ctx.toCtx.parser.getTok()

proc load*[T: SomeFloat](ctx: var TPacketDataSource, dest: var T) =
  getFloat[T](ctx.toCtx.parser, dest)
  discard ctx.toCtx.parser.getTok()

# ------------------- Dump

proc dump*[T: SomeInteger | SomeFloat](t: T, dest: var string) =
  dest.add($t)
