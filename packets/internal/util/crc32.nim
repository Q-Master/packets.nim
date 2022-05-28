from strutils import toHex

type
  TCrc32* = uint32

proc `$`*(crc: TCrc32): string =
  result = crc.int64.toHex(8)

const InitCrc32* = TCrc32(0)

func createCrcTable(): array[0..255, TCrc32] {.inline.} =
  for i in 0..255:
    var rem = TCrc32(i)
    for j in 0..7:
      if (rem and 1) > 0'u32: rem = (rem shr 1) xor TCrc32(0xedb88320)
      else: rem = rem shr 1
    result[i] = rem


const crc32table = createCrcTable()

func updateCrc32(c: char, crc: var TCrc32) {.inline.} =
  crc = (crc shr 8) xor crc32table[(crc and 0xff) xor uint32(ord(c))]

func crc32*(s: string): TCrc32 =
  result = InitCrc32
  for c in s:
    updateCrc32(c, result)
  result = not result
