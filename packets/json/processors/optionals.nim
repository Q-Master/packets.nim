import options
import ../context

# ------------------- Load

proc load*[T](ctx: TPacketDataSource, t: typedesc[Option[T]]): Option[T] =
  mixin load
  if ctx.toCtx.parser.tok == tkNull:
    result = none(T)
    discard ctx.toCtx.parser.getTok()
  else:
    result = ctx.load(T).option

# ------------------- Dump

proc dump*[T](t: Option[T]): string =
  mixin dump
  if t.isSome():
    result = t.get().dump()
  else:
    result = "null"
