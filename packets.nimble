# Package
description = "Pure Nim declarative packets system for serializing/deserializing"
version     = "0.8.1"
license     = "MIT"
author      = "Vladimir Berezenko <qmaster2000@gmail.com>"

# Dependencies
requires "nim >= 1.4.00"
task test, "tests":
  echo "Running stdlib json tests"
  exec "nim c -r -d:enablePacketIDs --nimcache=./.nimcache/ tests/packets.nim"
  exec "nim c -r tests/packets.nim"
  echo "Running no IDs stdlib json tests"
  exec "nim c -r --nimcache=./.nimcache/ tests/packets.nim"
  
task bench, "benchmarks":
  echo "Running stdlib benchmark"
  exec "nim c -r -d:release --nimcache=./.nimcache/ tests/benchmark.nim"
