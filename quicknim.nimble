# Package

version       = "0.1.0"
author        = "QuickNim Contributors"
description   = "Nim to ES5 JavaScript transpiler targeting microQuickJS"
license       = "MIT"
srcDir        = "src"
bin           = @["quicknim"]

# Dependencies

requires "nim >= 2.0.0"

# Tasks

task build, "Build quicknim transpiler":
  exec "nim c -d:release --opt:size src/quicknim.nim"

task debug, "Build quicknim with debug info":
  exec "nim c -g src/quicknim.nim"

task test, "Run transpiler tests":
  echo "Running tests..."
  exec "nim c -r tests/test_all.nim"
