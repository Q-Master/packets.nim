import ../context

# ------------------- Load

proc load*[T: enum](ctx: var TPacketDataSource, dest: var T) =
  var i: int
  ctx.toCtx.parser.getInt(i)
  dest = T(i)
  discard ctx.toCtx.parser.getTok()

# ------------------- Dump

proc dump*[T: enum](en: T, dest: var string) =
  dest.add($(ord(en).int))
