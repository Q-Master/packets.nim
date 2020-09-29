when defined(usePackedJson):
  import packedjson as json
  proc isNil*[T:JsonNode | JsonTree](j: T): bool = false
  export isNil
else:
  import std/json
  type JsonTree* = JsonNode
  export JsonTree

export json
