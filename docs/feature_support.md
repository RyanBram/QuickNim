# QuickNim Feature Support Roadmap

This document tracks which JavaScript syntax features are supported by QuickNim transpiler.

**Last Updated:** January 2026

---

## Pragma System

QuickNim uses pragmas from `qn_core` to control transpilation.

| Pragma              | Purpose                           | Status       |
| ------------------- | --------------------------------- | ------------ |
| `{.jsExport.}`      | Mark type for JS export           | ✅ Supported |
| `{.jsStaticClass.}` | Static class (cannot instantiate) | ✅ Supported |
| `{.jsStatic.}`      | Static method/variable            | ✅ Supported |
| `{.jsPrivate.}`     | Private member (adds `_` prefix)  | ✅ Supported |
| `{.jsConstructor.}` | Constructor method                | ✅ Supported |

---

## Class Patterns

### Instance Classes (RequestQueue pattern)

| Feature           | Nim Syntax                      | JS Output                                       | Status |
| ----------------- | ------------------------------- | ----------------------------------------------- | ------ |
| Constructor       | `type T* {.jsExport.} = object` | `function T() { this.initialize.apply(...) }`   | ✅     |
| Prototype chain   | `object of Parent`              | `T.prototype = Object.create(Parent.prototype)` | ✅     |
| Initialize method | `proc initialize*(self: var T)` | `T.prototype.initialize = function()`           | ✅     |
| Instance methods  | `proc method*(self: var T)`     | `T.prototype.method = function()`               | ✅     |
| Field assignment  | `self.field = value`            | `this._field = value`                           | ✅     |
| Array init        | `self.queue = @[]`              | `this._queue = []`                              | ✅     |

### Static Classes (ProgressWatcher pattern)

| Feature               | Nim Syntax                               | JS Output                               | Status |
| --------------------- | ---------------------------------------- | --------------------------------------- | ------ |
| Static class          | `type T* {.jsExport, jsStaticClass.}`    | `function T() { throw new Error(...) }` | ✅     |
| Static method         | `proc method*() {.jsStatic.}`            | `T.method = function()`                 | ✅     |
| Private static method | `proc method*() {.jsStatic, jsPrivate.}` | `T._method = function()`                | ✅     |
| Static variable       | `var x {.jsPrivate.}: int`               | `this._x`                               | ✅     |

---

## Expressions & Statements

### Assignments

| Feature           | Nim Syntax           | JS Output              | Status |
| ----------------- | -------------------- | ---------------------- | ------ |
| Simple assignment | `x = 0`              | `x = 0;`               | ✅     |
| Self field        | `self.field = value` | `this._field = value;` | ✅     |
| Compound -=       | `x -= y`             | `x = x - y;`           | ✅     |
| Compound +=       | `x += 1`             | `x++;`                 | ✅     |
| Array init        | `@[]`                | `[]`                   | ✅     |

### Control Flow

| Feature      | Nim Syntax            | JS Output                      | Status |
| ------------ | --------------------- | ------------------------------ | ------ |
| If statement | `if condition:`       | `if (condition) { }`           | ✅     |
| If-else      | `if x: ... else: ...` | `if (x) { } else { }`          | ❌     |
| Early return | `if x: return`        | `if (x) return;`               | ❌     |
| For loop     | `for n in 0 ..< len:` | `for(var n = 0; n < len; n++)` | ❌     |
| While loop   | `while condition:`    | `while (condition) { }`        | ❌     |
| Break        | `break`               | `break;`                       | ❌     |

### Function Calls

| Feature            | Nim Syntax                    | JS Output               | Status |
| ------------------ | ----------------------------- | ----------------------- | ------ |
| Simple call        | `foo()`                       | `foo();`                | ✅     |
| Method call        | `self.queue.add(x)`           | `this._queue.push(x);`  | ✅     |
| Static method call | `clearProgress()`             | `this.clearProgress();` | ✅     |
| Parent call        | `callParent(Parent, self, x)` | `Parent.call(this, x);` | ✅     |

### Object Literals

| Feature         | Nim Syntax           | JS Output            | Status |
| --------------- | -------------------- | -------------------- | ------ |
| Tuple as object | `(key: k, value: v)` | `{key: k, value: v}` | ✅     |

---

## Array Operations

| Nim Method         | JS Method       | Status |
| ------------------ | --------------- | ------ |
| `seq.add(x)`       | `.push(x)`      | ✅     |
| `seq.setLen(0)`    | `.splice(0)`    | ✅     |
| `seq.delete(0)`    | `.shift()`      | ❌     |
| `seq.delete(n)`    | `.splice(n, 1)` | ❌     |
| `seq.insert(x, 0)` | `.unshift(x)`   | ❌     |
| `seq.len`          | `.length`       | ❌     |
| `seq[n]`           | `[n]`           | ❌     |

---

## JSDoc Generation

| Feature           | Status |
| ----------------- | ------ |
| Class description | ✅     |
| @class tag        | ✅     |
| @constructor tag  | ✅     |
| @param tags       | ✅     |
| @static tag       | ❌     |
| @private tag      | ❌     |
| @property tag     | ❌     |

---

## Advanced Features

| Feature             | Status | Notes                     |
| ------------------- | ------ | ------------------------- |
| Closure binding     | ❌     | `.bind(this)` pattern     |
| Anonymous functions | ❌     | Inline callbacks          |
| Method chaining     | ❌     | `obj.method1().method2()` |
| Ternary operator    | ❌     | `x if c else y`           |
| Property access     | ❌     | `obj.prop.method()`       |
| Error handling      | ❌     | try/except                |

---

## File Structure

```
quicknim/src/
├── nim/
│   ├── libs/
│   │   ├── qn_core.nim      # Pragma definitions
│   │   └── PIXI.nim         # PIXI stubs
│   └── rpg_core/
│       ├── Point.nim
│       ├── Rectangle.nim
│       ├── ProgressWatcher.nim  ✅ Complete
│       └── RequestQueue.nim     ✅ Basic (missing update/raisePriority)
├── ast/
│   ├── types.nim            # JS IR types
│   └── walker.nim           # AST walker
├── codegen/
│   └── emitter.nim          # JS code generator
└── quicknim.nim             # Main transpiler
```

---

## Legend

- ✅ Supported and tested
- ❌ Not yet implemented
- 🚧 Partially implemented

---

## Next Priorities

1. **Early return** - `if x: return` pattern
2. **For loops** - Basic numeric iteration
3. **Array indexing** - `seq[n]` access
4. **If-else** - Complete conditional branching
