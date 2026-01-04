## PIXI - Stub types for dual-target compilation
## Provides PIXI.js type stubs for both native C and JavaScript targets

# PIXI namespace marker
type
  PIXIModule* = object
    ## PIXI namespace for type organization

# Create PIXI namespace at compile time
var PIXI*: PIXIModule

# PIXI base types
type
  Point* = object of RootObj
    ## PIXI Point stub
    x*, y*: float
  
  Rectangle* = object of RootObj
    ## PIXI Rectangle stub
    x*, y*, width*, height*: float

# Parent constructor call template
template callParent*(ParentType: typedesc, self: var auto, args: varargs[untyped]) =
  ## Call parent constructor
  ## JS: ParentClass.call(this, args)
  ## C: Initialize parent fields
  when ParentType is Point:
    when compiles(args[0]):
      self.x = args[0]
    when compiles(args[1]):
      self.y = args[1]
  elif ParentType is Rectangle:
    when compiles(args[0]):
      self.x = args[0]
    when compiles(args[1]):
      self.y = args[1]
    when compiles(args[2]):
      self.width = args[2]
    when compiles(args[3]):
      self.height = args[3]
