## ProgressWatcher - Static class for tracking asset loading progress
## Dual-target: nim c and quicknim

import ../libs/qn_core

type
  ProgressWatcher* {.jsExport, jsStaticClass.} = object
    ## This is a static class

# Static variables
var countLoading {.jsPrivate.}: int = 0
var countLoaded {.jsPrivate.}: int = 0
var progressListener {.jsPrivate.}: proc(loaded, loading: int) {.closure.} = nil

# Static methods

proc clearProgress*() {.jsStatic.} =
  ## Reset progress counters
  countLoading = 0
  countLoaded = 0

proc bitmapListener*(bitmap: int) {.jsStatic, jsPrivate.} =
  ## Handle bitmap creation
  countLoading += 1
  # In JS: bitmap.addLoadListener(function(){...}.bind(this))
  # Callback with closure handled by transpiler

proc audioListener*(audio: int) {.jsStatic, jsPrivate.} =
  ## Handle audio creation
  countLoading += 1
  # In JS: audio.addLoadListener(function(){...}.bind(this))

proc initialize*() {.jsStatic.} =
  ## Initialize the progress watcher
  clearProgress()
  # In JS: ImageManager.setCreationHook(this._bitmapListener.bind(this))
  # In JS: AudioManager.setCreationHook(this._audioListener.bind(this))

proc setProgressListener*(listener: proc(loaded, loading: int) {.closure.}) {.jsStatic.} =
  ## Set the progress callback
  progressListener = listener

proc truncateProgress*() {.jsStatic.} =
  ## Truncate loaded progress
  if countLoaded != 0:
    countLoading -= countLoaded
    countLoaded = 0
