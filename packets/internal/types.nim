template as_name*(n: string) {.pragma.}

type 
    TPacket* {.inheritable.} = ref TPacketObj
    TPacketObj* {.inheritable.} = object
        id*: int32
    TArrayPacket* {.inheritable.} = ref TArrayPacketObj
    TArrayPacketObj* {.inheritable.} = object
        id*: int32
