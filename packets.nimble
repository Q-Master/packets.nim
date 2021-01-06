# Package
description = "Pure Nim declarative packets system for serializing/deserializing"
version     = "0.4.0"
license     = "MIT"
author      = "Vladimir Berezenko <qmaster2000@gmail.com>"

# Dependencies
requires "nim >= 0.20.00", "packedjson", "crc32 >= 0.1.1"

task test, "tests":
  echo "Running stdlib json tests"
  exec "nim c -r -d:packetDumpTree tests/packets.nim"
  echo "Running packedjson tests"
  exec "nim c -r -d:packetDumpTree -d:usePackedJson tests/packets.nim"
  echo "Running no IDs stdlib json tests"
  exec "nim c -r -d:packetDumpTree -d:disablePacketIDs tests/packets.nim"
  echo "Running no IDs packedjson tests"
  exec "nim c -r -d:packetDumpTree -d:usePackedJson -d:disablePacketIDs tests/packets.nim"
  
task bench, "benchmarks":
  echo "Running stdlib benchmark"
  exec "nim c -r -d:release tests/benchmark.nim"
  echo "Running packedjson benchmark"
  exec "nim c -r -d:release -d:usePackedJson tests/benchmark.nim"
