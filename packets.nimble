# Package
description = "Pure Nim declarative packets system for serializing/deserializing"
version     = "0.1"
license     = "MIT"
author      = "Vladimir Berezenko <qmaster2000@gmail.com>"

# Dependencies
requires "nim >= 0.20.00"

proc runTest(input: string) =
  let cmd = "nim c -r -d:packetDumpTree=1 " & input
  echo "running: " & cmd
  exec cmd

task test, "tests":
  runTest "tests/packets.nim"
