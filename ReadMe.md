packets - pure Nim declarative packes system for serializing/deserializing
===

`packets` is my own view of declarative description of serializable/deserializable objects.

The main idea of this project is to give easiness of managing serializable objects in declarative way
without any need to implement type checking, defaults, serializing and deserializing of objects.

The project comes with own much faster reimplementation of std's json package with compatible API and 
some improvements.

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
Packets are types, supporting inheritance both single or multiple, with possible exported and non-exported fields.
Fields must be declared as `var`s with possible pragma `asName`, which tells serialization/deserialization procs to substitute
nim's var name with passed to a pragma new name.

**!!** No duplicate asName and field names possible yet as overloading not supported for now.

There are two types of packets: `packet` and `arrayPacket`.

`packet` is mapped directly to a serialized object.

`arrayPacket` is mapped not to an object, but to a serialized array.

Both types of packets can optionally include compiletime calculated `packetId` field using `packetId` pragma on type.

Mostly usage examples could be seen in tests directory.


```nim
import tables
import options
import pkg/[packets]

packet Boolean:
  var boolean*: bool
  var booleanWithName* {.asName: "boolean1".}: bool
  var booleanWithDefault*: bool = true
  var booleanOptional*: Option[bool]
  var booleanOptionalWithDefault*: Option[bool] = false
  var notSerialized: float

arrayPacket PacketAsASequence:
  var field1*: int
  var field2*: string
  var field3*: bool

var booleanPacket = Boolean.new(boolean = true, booleanWithName = false, notSerialized = 0)
var jsonData = booleanPacket.dumps()
let decodedBoolean = Boolean.loads(jsonData)

var sequentialPacket = PacketAsASequence.new(field1 = 1, field2 = "str", field3 = false)
var jsonData = sequentialPacket.dumps()
# will lead to a JSON array [1, "str", false]
var decodedSequential = PacketAsASequence.loads(jsonData)
```

Plans
---
As for now packets system support only serialization/deserialization using JSON,
but it is not a problem, because the system is very extendable and I'm planning to add
more serialization/deserialization libraries.
