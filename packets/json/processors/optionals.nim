import options
import ../context


# ------------------- Load

proc load*[T: TPacket](ctx: var TPacketDataSource, dest: var Option[T]) =
  mixin load
  if ctx.toCtx.parser.tok == tkNull:
    dest = none(T)
    discard ctx.toCtx.parser.getTok()
  else:
    try:
      var dd: T
      ctx.load(dd)
      dest = dd.option
    except ValueError:
      dest = none(T)
      discard ctx.toCtx.parser.getTok()



proc load*[T](ctx: var TPacketDataSource, dest: var Option[T]) =
  mixin load
  if ctx.toCtx.parser.tok == tkNull:
    dest = none(T)
    discard ctx.toCtx.parser.getTok()
  else:
    var dd: T
    ctx.load(dd)
    dest = dd.option

# ------------------- Dump

proc dump*[T](t: Option[T], dest: var string) =
  mixin dump
  if t.isSome():
    t.get().dump(dest)
  else:
    dest.add(strNull)
