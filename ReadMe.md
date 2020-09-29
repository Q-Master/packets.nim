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
Mostly usage examples could be seen in examples directory.
```nim
import json
import tables
import options
import packets/packets
import packets/json/serialization
import packets/json/processors/[boolean, numeric, str, datetime, enums]

packet Boolean:
  var boolean*: bool
  var booleanWithName* {.as_name: "boolean1".}: bool
  var booleanWithDefault*: bool = true
  var booleanOptional*: Option[bool]
  var booleanOptionalWithDefault*: Option[bool] = false
  var notSerialized: float

var booleanPacket = Boolean.init(boolean = true, booleanWithName = false)
var jsonData = booleanPacket.dump()
let decodedBoolean = Boolean.load(jsonData)
```

Plans
---
As for now packets system support only serialization/deserialization using JSON,
but it is not a problem, because the system is very extendable and I'm planning to add
more serialization/deserialization libraries.