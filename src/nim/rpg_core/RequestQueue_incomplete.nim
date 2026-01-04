## RequestQueue - Instance class for managing request queue
## Dual-target: nim c and quicknim
## Pattern: Instance class with array operations

import ../libs/qn_core

type
  RequestQueue* {.jsExport.} = object
    ## A queue of request items
    queue {.jsPrivate.}: seq[tuple[key: string, value: int]]  # simplified for transpiler

proc initialize*(self: var RequestQueue) {.jsConstructor.} =
  ## Initialize the request queue
  self.queue = @[]

proc enqueue*(self: var RequestQueue, key: string, value: int) =
  ## Add an item to the queue
  self.queue.add((key: key, value: value))

proc clear*(self: var RequestQueue) =
  ## Clear the queue
  self.queue.setLen(0)
