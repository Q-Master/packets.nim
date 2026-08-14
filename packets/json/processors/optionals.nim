import options
import ../context


# ------------------- Load

proc load*[T: TPacket](_: typedesc[Option[T]], ctx: TPacketDataSource): Option[T] =
  mixin load
  if ctx.toCtx.parser.tok == tkNull:
    result = none(T)
    ctx.toCtx.parser.getNull()
    ctx.toCtx.parser.getTok()
  else:
    result = T.load(ctx).option

proc load*[T](_: typedesc[Option[T]], ctx: TPacketDataSource): Option[T] =
  mixin load
  if ctx.toCtx.parser.tok == tkNull:
    result = none(T)
    ctx.toCtx.parser.getNull()
    ctx.toCtx.parser.getTok()
  else:
    result = T.load(ctx).option

# ------------------- Dump

proc dump*[T](t: Option[T], dest: var string) =
  mixin dump
  if t.isSome():
    t.get().dump(dest)
  else:
    dest.add(strNull)
