template asName*(n: string) {.pragma.}

type 
  TPacket* {.inheritable.} = ref object
  TArrayPacket* {.inheritable.} = ref object
  TPacketDataSource* {.inheritable.} = ref object
  TPacketFieldSetFunc* = proc (packet: var TPacket, data: TPacketDataSource)
