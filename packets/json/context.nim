import std/parsejson
import ../internal/types

export parsejson, types

type
  TPacketDataSourceJson* = ref object of TPacketDataSource
    parser*: JsonParser

template toCtx*(s: TPacketDataSource): TPacketDataSourceJson = cast[TPacketDataSourceJson](s)

