## Rectangle - The rectangle class
## Dual-target: nim c and quicknim

import PIXI

type
  Rectangle* = object of PIXI.Rectangle
    ## The rectangle class.

# Static variable (will be initialized later)
var emptyRectangle* {.global.}: Rectangle

proc initialize*(self: var Rectangle, x, y, width, height: float) =
  ## The x coordinate for the upper-left corner.
  ## The y coordinate for the upper-left corner.
  ## The width of the rectangle.
  ## The height of the rectangle.
  callParent(PIXI.Rectangle, self, x, y, width, height)

proc newRectangle*(x, y, width, height: float): Rectangle =
  result.initialize(x, y, width, height)

# Initialize static variable
# In JS: Rectangle.emptyRectangle = new Rectangle(0, 0, 0, 0);
# In Nim: emptyRectangle = newRectangle(0, 0, 0, 0)
when not defined(js):
  emptyRectangle = newRectangle(0, 0, 0, 0)
