# QuickNim Coding Convention

This document describes the JavaScript patterns used by Yoji Ojima in RPG Maker MV's ES5 codebase and how they map to Nim in the QuickNim transpiler.

## Overview

RPG Maker MV uses ES5 JavaScript with a consistent coding style. QuickNim transpiles Nim code to match this style exactly.

---

## Class Patterns

### 1. Instance Classes (with Inheritance)

**JavaScript Pattern:**

```javascript
//-----------------------------------------------------------------------------
/**
 * Description of the class.
 *
 * @class ClassName
 * @constructor
 * @param {Type} param Description
 */
function ClassName() {
  this.initialize.apply(this, arguments);
}

ClassName.prototype = Object.create(ParentClass.prototype);
ClassName.prototype.constructor = ClassName;

ClassName.prototype.initialize = function (param) {
  ParentClass.call(this, param);
  this._privateField = value;
};

ClassName.prototype.publicMethod = function () {
  // implementation
};
```

**Nim Mapping:**

```nim
## Description of the class.

type
  ClassName* = object of ParentClass
    ## Description
    privateField* {.jsPrivate.}: FieldType

proc initialize*(self: var ClassName, param: ParamType) =
  callParent(ParentClass, self, param)
  self.privateField = value

proc publicMethod*(self: var ClassName) =
  # implementation
```

**Key Mappings:**
| JavaScript | Nim |
|------------|-----|
| `function ClassName()` | `type ClassName* = object` |
| `Object.create(Parent.prototype)` | `object of ParentClass` |
| `this.initialize.apply(this, arguments)` | Auto-generated |
| `Parent.call(this, args)` | `callParent(Parent, self, args)` |
| `this._field` (private) | `field {.jsPrivate.}` |

---

### 2. Static Classes (No Instantiation)

**JavaScript Pattern:**

```javascript
function ClassName() {
  throw new Error("This is a static class");
}

ClassName.initialize = function () {
  this.clearProgress();
};

ClassName._privateMethod = function () {
  // implementation
};

ClassName.publicMethod = function () {
  // implementation
};
```

**Nim Mapping:**

```nim
## Note: This is a static class (cannot be instantiated)

var privateVar* {.jsStatic, jsPrivate.}: Type

proc initialize*() {.jsStatic.} =
  clearProgress()

proc privateMethod*() {.jsStatic, jsPrivate.} =
  # implementation

proc publicMethod*() {.jsStatic.} =
  # implementation
```

**Key Mappings:**
| JavaScript | Nim |
|------------|-----|
| `throw new Error('This is a static class')` | Auto-generated for static classes |
| `ClassName.method = function()` | `proc method() {.jsStatic.}` |
| `ClassName._privateMethod` | `proc privateMethod {.jsStatic, jsPrivate.}` |
| `this._field` | Variable with `{.jsStatic, jsPrivate.}` |

---

## Naming Conventions

### Private Members (Underscore Prefix)

**JavaScript:** Private members use `_` prefix

```javascript
this._count = 0;
this._queue = [];
```

**Nim:** Use `jsPrivate` pragma

```nim
var count* {.jsStatic, jsPrivate.}: int
queue* {.jsPrivate.}: seq[T]
```

**Output:** `this._count`, `this._queue`

---

## Control Flow Patterns

### Early Return Pattern

**JavaScript:**

```javascript
if (this._queue.length === 0) return;
```

**Nim:**

```nim
if self.queue.len == 0:
  return
```

### Truthy Check with && Short-circuit

**JavaScript:**

```javascript
this._callback && this._callback(args);
```

**Nim:**

```nim
callback.callIfSet(args)
```

### Array Length Check

**JavaScript:**

```javascript
if (this._queue.length !== 0) {
  // not empty
}
```

**Nim:**

```nim
if self.queue.len != 0:
  # not empty
```

> **Note:** `.length !== 0` is preserved in output (not optimized to truthy)

---

## Callback Patterns

### Function Binding

**JavaScript:**

```javascript
ImageManager.setCreationHook(this._bitmapListener.bind(this));
```

**Nim:**

```nim
ImageManager.setCreationHook(bitmapListener.bindThis())
```

### Anonymous Function with .bind(this)

**JavaScript:**

```javascript
bitmap.addLoadListener(
  function () {
    this._countLoaded++;
    this._progressListener &&
      this._progressListener(this._countLoaded, this._countLoading);
  }.bind(this)
);
```

**Nim:**

```nim
bitmap.addLoadListener(proc() =
  countLoaded += 1
  theProgressListener.callIfSet(countLoaded, countLoading)
)
```

---

## Array Operations

| JavaScript          | Nim                   |
| ------------------- | --------------------- |
| `arr.push(item)`    | `arr.add(item)`       |
| `arr.shift()`       | `arr.delete(0)`       |
| `arr.unshift(item)` | `arr.insert(item, 0)` |
| `arr.splice(n, 1)`  | `arr.delete(n)`       |
| `arr.splice(0)`     | `arr.setLen(0)`       |
| `arr.length`        | `arr.len`             |
| `arr[0]`            | `arr[0]`              |

---

## Static Properties

**JavaScript:**

```javascript
/**
 * @static
 * @property propertyName
 * @type TypeName
 * @private
 */
ClassName.propertyName = value;
```

**Nim:**

```nim
var propertyName* {.jsStatic.}: TypeName = value
# Add jsPrivate if @private is specified
```

---

## JSDoc Comments

**JavaScript Pattern:**

```javascript
//-----------------------------------------------------------------------------
/**
 * Class description.
 *
 * @class ClassName
 * @constructor
 * @param {Type} paramName Description
 */
```

**Nim Pattern:**

```nim
## Class description.

type
  ClassName* = object of RootObj
    ## Class description (for type doc)
```

### Property Documentation

**JavaScript:**

```javascript
/**
 * Property description.
 *
 * @property propertyName
 * @type TypeName
 */
```

**Nim:** Use doc comments on fields

```nim
fieldName*: TypeName  ## Property description
```

---

## Ojima Inconsistencies Observed

1. **Whitespace in function declarations:** Some files use `function(){}` while others use `function() {}`
2. **Early return style:** Some use `if(x) return;` on one line, others use block form
3. **JSDoc completeness:** Some classes have full JSDoc, others have minimal or none (e.g., RequestQueue, ProgressWatcher)
4. **Trailing commas:** Object literals sometimes have trailing commas

**QuickNim normalizes these:** Output always uses consistent spacing and block formatting.

---

## Forward Declarations

**When needed in Nim:**

- When a proc calls another proc defined later in the file
- For mutual recursion

**JavaScript:** No forward declarations needed

**Nim:**

```nim
# Forward declarations
proc clearProgress*() {.jsStatic.}
proc bitmapListener*(bitmap: Bitmap) {.jsStatic, jsPrivate.}

# Implementations
proc initialize*() {.jsStatic.} =
  clearProgress()  # Uses forward declared proc
```

---

## File Structure Template

```nim
## ModuleName - Brief description
## Dual-target: nim c and quicknim

import qn_core  # or PIXI for classes inheriting PIXI types

type
  ClassName* = object of ParentType
    ## Class documentation
    publicField*: Type
    privateField* {.jsPrivate.}: Type

# Forward declarations (if needed)
proc helperProc*()

# Instance methods
proc initialize*(self: var ClassName, args) =
  # constructor body

proc publicMethod*(self: var ClassName) =
  # method body

# Constructor helper
proc newClassName*(args): ClassName =
  result.initialize(args)
```

---

## Pragmas Reference

| Pragma              | Purpose                     | JS Output                |
| ------------------- | --------------------------- | ------------------------ |
| `{.jsExport.}`      | Mark type for JS export     | Standard class structure |
| `{.jsStaticClass.}` | Static class (no instances) | Constructor throws Error |
| `{.jsStatic.}`      | Static method/variable      | `ClassName.method`       |
| `{.jsPrivate.}`     | Private member              | Adds `_` prefix          |
| `{.jsConstructor.}` | Constructor method          | `prototype.initialize`   |

---

## Best Practices

1. **Always add `## Dual-target: nim c and quicknim`** comment at top
2. **Use `callParent` for parent constructor calls** instead of direct field assignment
3. **Use `callIfSet` for truthy callback invocation** instead of `if != nil`
4. **Use `bindThis()` for callback binding** instead of manual this reference
5. **Keep method order consistent** with original JS for easier comparison
6. **Document static classes** with `## Note: This is a static class` comment
