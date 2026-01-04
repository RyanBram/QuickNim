# QuickNim

**Nim to ES5 JavaScript Transpiler**

QuickNim transpiles Nim source code into human-readable ES5 JavaScript usando pragma annotations. Write once, compile to both ES5 JavaScript (via QuickNim) and native C (via `nim c`).

## Features

- **Dual-target compilation**: Same Nim code compiles to both ES5 JavaScript and native C
- **Pragma-based control**: Explicit `{.jsExport.}`, `{.jsStatic.}`, `{.jsPrivate.}` pragmas
- **Human-readable output**: Generated JavaScript follows RPG Maker MV style patterns
- **JSDoc generation**: Automatic JSDoc annotations from Nim doc comments
- **No runtime dependency**: QuickNim.exe is standalone, no Nim compiler needed at runtime

## Quick Start

```bash
# Build the transpiler
nim c -d:release src/quicknim.nim

# Transpile Nim to JavaScript
quicknim input.nim output.js

# Or just drag & drop .nim file onto quicknim.exe
```

---

## How It Works

QuickNim uses a **string-based parser** with **pragma detection** to transpile Nim code:

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  Nim File   │ ──▶ │   Parser     │ ──▶ │  JS IR      │
│  (.nim)     │     │  + Pragmas   │     │  (types.nim)│
└─────────────┘     └──────────────┘     └─────────────┘
                                               │
                                               ▼
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  JS File    │ ◀── │   Emitter    │ ◀── │  ClassDecl  │
│  (.js)      │     │  (ES5 Gen)   │     │  + Methods  │
└─────────────┘     └──────────────┘     └─────────────┘
```

### Key Components

| File                   | Purpose                           |
| ---------------------- | --------------------------------- |
| `quicknim.nim`         | Main transpiler + pragma parser   |
| `ast/types.nim`        | JavaScript IR (JSNode, ClassDecl) |
| `codegen/emitter.nim`  | ES5 code generator                |
| `nim/libs/qn_core.nim` | Pragma definitions                |

### Pragmas

Pragmas from `qn_core.nim` control transpilation:

```nim
{.pragma: jsExport.}      # Export type to JS
{.pragma: jsStaticClass.} # Static class (no instances)
{.pragma: jsStatic.}      # Static method
{.pragma: jsPrivate.}     # Private member (adds _)
{.pragma: jsConstructor.} # Constructor method
```

---

## Dual-Target Example

```nim
## RequestQueue - Instance class
import ../libs/qn_core

type
  RequestQueue* {.jsExport.} = object
    queue {.jsPrivate.}: seq[int]

proc initialize*(self: var RequestQueue) {.jsConstructor.} =
  self.queue = @[]

proc clear*(self: var RequestQueue) =
  self.queue.setLen(0)
```

**Compile to JavaScript:**

```bash
quicknim RequestQueue.nim RequestQueue.js
```

**Output:**

```javascript
function RequestQueue() {
  this.initialize.apply(this, arguments);
}

RequestQueue.prototype.initialize = function () {
  this._queue = [];
};

RequestQueue.prototype.clear = function () {
  this._queue.splice(0);
};
```

**Compile to C:**

```bash
nim c RequestQueue.nim
```

---

## Project Structure

```
quicknim/
├── src/
│   ├── quicknim.nim      # Main transpiler
│   ├── ast/
│   │   ├── types.nim     # JS IR types
│   │   └── walker.nim    # AST walker
│   ├── codegen/
│   │   └── emitter.nim   # ES5 generator
│   └── nim/
│       ├── libs/
│       │   ├── qn_core.nim   # Pragmas
│       │   └── PIXI.nim      # PIXI stubs
│       └── rpg_core/
│           ├── Point.nim
│           ├── Rectangle.nim
│           ├── ProgressWatcher.nim
│           └── RequestQueue.nim
├── docs/
│   ├── dual-target-guide.md      # Writing dual-target Nim
│   ├── QuickNim_Coding_Convention.md  # JS patterns
│   └── feature_support.md        # Supported features
└── tests/
```

---

## Supported Features

| Feature                      | Status |
| ---------------------------- | ------ |
| Instance classes             | ✅     |
| Static classes               | ✅     |
| Private members (`_` prefix) | ✅     |
| If statements                | ✅     |
| Array push/splice            | ✅     |
| Object literals              | ✅     |
| For loops                    | ❌     |
| Closures                     | ❌     |

See [docs/feature_support.md](docs/feature_support.md) for full matrix.

---

## Custom Pragmas

| Pragma              | JS Effect                    | C Effect  |
| ------------------- | ---------------------------- | --------- |
| `{.jsExport.}`      | Export class                 | No effect |
| `{.jsStaticClass.}` | `throw new Error(...)` guard | No effect |
| `{.jsStatic.}`      | `ClassName.method`           | No effect |
| `{.jsPrivate.}`     | Adds `_` prefix              | No effect |
| `{.jsConstructor.}` | `prototype.initialize`       | No effect |

---

## Target Runtime

QuickNim targets **microQuickJS** - a lightweight JavaScript engine. Generated ES5 code is:

- Human-readable (not minified)
- Compatible with ES5 strict mode
- Uses prototype-based inheritance
- Includes JSDoc annotations

---

## Documentation

- [Dual-Target Guide](docs/dual-target-guide.md) - Writing Nim for both targets
- [Coding Convention](docs/QuickNim_Coding_Convention.md) - JS pattern mappings
- [Feature Support](docs/feature_support.md) - Supported syntax roadmap

---

## License

MIT License
