# Package
description = "Pure Nim declarative packets system for serializing/deserializing"
version     = "2.3.0"
license     = "MIT"
author      = "Vladimir Berezenko <qmaster2000@gmail.com>"

# Dependencies
requires "nim >= 2.0.2"
task test, "tests":
  echo "Running stdlib json tests"
  #exec "nim c -r -d:enablePacketIDs --nimcache=./.nimcache/ tests/packets.nim"
  #exec "nim c -r tests/packets.nim"
  echo "Running no IDs stdlib json tests"
  exec "nim c -r --nimcache=./.nimcache/ tests/packets.nim"
  echo "Running JSON test"
  exec "nim c -r --nimcache=./.nimcache/ tests/json.nim"
  
task bench, "benchmarks":
  echo "Running stdlib benchmark"
  exec "nim c -r -d:release --nimcache=./.nimcache/ tests/benchmark.nim"
