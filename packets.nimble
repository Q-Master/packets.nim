# Package
description = "Pure Nim declarative packets system for serializing/deserializing"
version     = "0.6"
license     = "MIT"
author      = "Vladimir Berezenko <qmaster2000@gmail.com>"

# Dependencies
requires "nim >= 1.4.00"
task test, "tests":
  echo "Running stdlib json tests"
  exec "nim c -r -d:packetDumpTree tests/packets.nim"
  exec "nim c -r tests/packets.nim"
  echo "Running no IDs stdlib json tests"
  exec "nim c -r -d:packetDumpTree -d:disablePacketIDs tests/packets.nim"
  
task bench, "benchmarks":
  echo "Running stdlib benchmark"
  exec "nim c -r -d:release -d:disablePacketIDs tests/benchmark.nim"
