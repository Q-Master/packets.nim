import ../context

# ------------------- Load

proc load*[T: enum](ctx: TPacketDataSource, dest: var T) =
  var i: int
  ctx.toCtx.parser.getInt(i)
  dest = T(i)
  ctx.toCtx.parser.getTok()

# ------------------- Dump

proc dump*[T: enum](en: T, dest: var string) =
  dest.add($(ord(en).int))
