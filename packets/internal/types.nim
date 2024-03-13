template asName*(n: string) {.pragma.}

type 
  TPacket* {.inheritable.} = object
    when defined(enablePacketIDs):
      id*: int32
  TArrayPacket* {.inheritable.} = object
    when defined(enablePacketIDs):
      id*: int32
  TPacketDataSource* {.inheritable.} = object
  TPacketFieldSetFunc* = proc (packet: var TPacket, data: var TPacketDataSource)
