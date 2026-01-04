## Point - The point class
## Dual-target: nim c and quicknim

import PIXI

type
  Point* = object of PIXI.Point
    ## The point class.

proc initialize*(self: var Point, x, y: float) =
  ## The x coordinate.
  ## The y coordinate.
  callParent(PIXI.Point, self, x, y)

proc newPoint*(x, y: float): Point =
  result.initialize(x, y)
