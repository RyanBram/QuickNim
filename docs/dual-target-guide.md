# Writing Nim for Dual-Target Compilation

This guide explains how to write Nim code that compiles to both:

- **Native C/C++** using `nim c`
- **ES5 JavaScript** using `quicknim`

## Quick Start

```nim
## MyClass - Description
import ../libs/qn_core

type
  MyClass* {.jsExport.} = object
    ## An instance class
    queue {.jsPrivate.}: seq[int]

proc initialize*(self: var MyClass) {.jsConstructor.} =
  self.queue = @[]

proc enqueue*(self: var MyClass, value: int) =
  self.queue.add(value)
```

Compile to both targets:

```bash
nim c MyClass.nim                    # Native C
quicknim MyClass.nim MyClass.js      # ES5 JavaScript
```

---

## Pragmas Reference

Import pragmas from `qn_core`:

```nim
import ../libs/qn_core
```

| Pragma              | Purpose                     | C Effect  |
| ------------------- | --------------------------- | --------- |
| `{.jsExport.}`      | Mark type for JS export     | No effect |
| `{.jsStaticClass.}` | Static class (no instances) | No effect |
| `{.jsStatic.}`      | Static method/variable      | No effect |
| `{.jsPrivate.}`     | Private member (`_` prefix) | No effect |
| `{.jsConstructor.}` | Constructor method          | No effect |

---

## Instance Classes

For classes that can be instantiated (like RequestQueue):

```nim
type
  RequestQueue* {.jsExport.} = object
    queue {.jsPrivate.}: seq[tuple[key: string, value: int]]

proc initialize*(self: var RequestQueue) {.jsConstructor.} =
  self.queue = @[]

proc enqueue*(self: var RequestQueue, key: string, value: int) =
  self.queue.add((key: key, value: value))

proc clear*(self: var RequestQueue) =
  self.queue.setLen(0)
```

**Generates:**

```javascript
function RequestQueue() {
  this.initialize.apply(this, arguments);
}

RequestQueue.prototype.initialize = function () {
  this._queue = [];
};

RequestQueue.prototype.enqueue = function (key, value) {
  this._queue.push({ key: key, value: value });
};

RequestQueue.prototype.clear = function () {
  this._queue.splice(0);
};
```

---

## Static Classes

For utility classes that cannot be instantiated (like ProgressWatcher):

```nim
type
  ProgressWatcher* {.jsExport, jsStaticClass.} = object
    ## This is a static class

var countLoading {.jsPrivate.}: int = 0
var countLoaded {.jsPrivate.}: int = 0

proc clearProgress*() {.jsStatic.} =
  countLoading = 0
  countLoaded = 0

proc initialize*() {.jsStatic.} =
  clearProgress()
```

**Generates:**

```javascript
function ProgressWatcher() {
  throw new Error("This is a static class");
}

ProgressWatcher.clearProgress = function () {
  this._countLoading = 0;
  this._countLoaded = 0;
};

ProgressWatcher.initialize = function () {
  this.clearProgress();
};
```

---

## Type Mappings

| Nim Type       | C Target      | JS Target      |
| -------------- | ------------- | -------------- |
| `int`, `float` | Native        | `Number`       |
| `string`       | Nim string    | `String`       |
| `bool`         | `NIM_BOOL`    | `Boolean`      |
| `seq[T]`       | Dynamic array | `Array`        |
| `tuple`        | Struct        | Object literal |
| `object`       | Struct        | Object         |

---

## Array Operations

| Nim             | JavaScript   |
| --------------- | ------------ |
| `seq.add(x)`    | `.push(x)`   |
| `seq.setLen(0)` | `.splice(0)` |
| `@[]`           | `[]`         |

---

## Control Flow

### If Statements

```nim
if countLoaded != 0:
  countLoading -= countLoaded
  countLoaded = 0
```

**Generates:**

```javascript
if (this._countLoaded != 0) {
  this._countLoading = this._countLoading - this._countLoaded;
  this._countLoaded = 0;
}
```

---

## Best Practices

### DO:

- ✅ Use `self` as first parameter for instance methods
- ✅ Use `{.jsConstructor.}` for initialize methods
- ✅ Use `{.jsStatic.}` for static class methods
- ✅ Use `{.jsPrivate.}` for private members
- ✅ Keep methods simple (assignment, function calls)

### DON'T:

- ❌ Use complex Nim features (templates, macros in bodies)
- ❌ Use try/except in method bodies
- ❌ Use features unsupported by ES5

---

## File Organization

```
quicknim/src/nim/
├── libs/
│   ├── qn_core.nim    # Pragmas
│   └── PIXI.nim       # PIXI stubs
└── rpg_core/
    ├── Point.nim
    ├── Rectangle.nim
    ├── ProgressWatcher.nim
    └── RequestQueue.nim
```

---

## Troubleshooting

### "Syntax validation failed"

Run `nim check yourfile.nim` to see Nim errors.

### Methods not appearing

Ensure instance methods have `self` as first parameter.

### Missing `_` prefix

Add `{.jsPrivate.}` pragma to fields.

---

## See Also

- [feature_support.md](./feature_support.md) - Feature support matrix
- [QuickNim_Coding_Convention.md](./QuickNim_Coding_Convention.md) - JS patterns
