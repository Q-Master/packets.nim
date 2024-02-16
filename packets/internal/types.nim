template asName*(n: string) {.pragma.}

type 
  TPacket* {.inheritable.} = ref TPacketObj
  TPacketObj* {.inheritable.} = object
    when defined(enablePacketIDs):
      id*: int32
  TArrayPacket* {.inheritable.} = ref TArrayPacketObj
  TArrayPacketObj* {.inheritable.} = object
    when defined(enablePacketIDs):
      id*: int32
  TPacketDataSource* = ref object of RootObj
  TPacketFieldSetFunc* = proc (packet: TPacket, data: TPacketDataSource)
