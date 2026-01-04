## QuickNim Core - Pragma definitions for transpilation control
## These pragmas tell QuickNim how to generate JavaScript
## For C compilation, they are no-ops

# Custom pragmas for QuickNim transpiler
# These are recognized by quicknim.exe when parsing Nim files
# For native Nim compilation, they do nothing

template jsExport*() {.pragma.}
template jsStatic*() {.pragma.}
template jsPrivate*() {.pragma.}
template jsConstructor*() {.pragma.}
template jsStaticClass*() {.pragma.}
