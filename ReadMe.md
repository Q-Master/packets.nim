packets - pure Nim declarative packes system for serializing/deserializing
===

`packets` is my own view of declarative description of serializable/deserializable objects.

The main idea of this project is to give easiness of managing serializable objects in declarative way
without any need to implement type checking, defaults, serializing and deserializing of objects.

Installation
---
You can use `nimble` package manager to install `packets`. The most recent
version of the library can be installed like this:

```bash
$ nimble install packets
```

or directly from Git repo:

```bash
$ nimble install https://github.com/Q-Master/packets.nim.git
```

Usage
---
Mostly usage examples could be seen in tests directory.
The building is by default with std json, as benchmarks showed it is faster 3 times than packedjson.

`-d:usePackedJson` enables packedjson.

`-d:enablePacketIDs` enables auto packet ID generation (enables additional field `id` in packets and enables its serialization/deserialization)

```nim
import tables
import options
import packets/packets
import packets/json/serialization

packet Boolean:
  var boolean*: bool
  var booleanWithName* {.as_name: "boolean1".}: bool
  var booleanWithDefault*: bool = true
  var booleanOptional*: Option[bool]
  var booleanOptionalWithDefault*: Option[bool] = false
  var notSerialized: float

arrayPacket PacketAsASequence:
  var field1*: int
  var field2*: string
  var field3*: bool

var booleanPacket = Boolean.init(boolean = true, booleanWithName = false)
var jsonData = booleanPacket.dump()
let decodedBoolean = Boolean.load(jsonData)

var sequentialPacket = PacketAsASequence.init(field1 = 1, field2 = "str", field3 = false)
var jsonData = sequentialPacket.dump()
# will lead to a JSON array [1, "str", false]
var decodedSequential = PacketAsASequence.load(jsonData)
```

Plans
---
As for now packets system support only serialization/deserialization using JSON,
but it is not a problem, because the system is very extendable and I'm planning to add
more serialization/deserialization libraries.