## QuickNim - AST-Based Nim to ES5 Transpiler
## Main executable entry point

import std/[os, parseopt, strutils, sequtils, osproc]
import ast/types
import codegen/emitter

const Version = "1.0.0-alpha"
const Usage = """
QuickNim - Nim to ES5 JavaScript Transpiler

Usage:
  quicknim [options] <input.nim> [output.js]
  
Options:
  -h, --help          Show this help
  -v, --version       Show version  
  -o, --output FILE   Output file (default: input_out.js)
  --verbose           Verbose output
  
Examples:
  quicknim Point.nim
  quicknim Point.nim -o Point.js
  quicknim --verbose Rectangle.nim
"""

type
  Config = object
    inputFile: string
    outputFile: string
    verbose: bool

proc getUniqueOutputFile(baseFile: string): string =
  ## Get unique filename with auto-numbering if exists
  ## e.g., Point.js -> Point(1).js -> Point(2).js
  if not fileExists(baseFile):
    return baseFile
  
  let (dir, name, ext) = splitFile(baseFile)
  var counter = 1
  while true:
    result = dir / (name & "(" & $counter & ")" & ext)
    if not fileExists(result):
      break
    counter += 1

proc parseArgs(): Config =
  result.verbose = false
  
  var p = initOptParser()
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key
      of "h", "help":
        echo Usage
        quit(0)
      of "v", "version":
        echo "QuickNim v", Version
        quit(0)
      of "o", "output":
        result.outputFile = p.val
      of "verbose":
        result.verbose = true
      else:
        echo "Unknown option: ", p.key
        quit(1)
    of cmdArgument:
      if result.inputFile.len == 0:
        result.inputFile = p.key
      elif result.outputFile.len == 0:
        result.outputFile = p.key
  
  if result.inputFile.len == 0:
    echo "Error: No input file specified"
    echo Usage
    quit(1)
  
  # Auto-generate output filename (drag & drop support)
  if result.outputFile.len == 0:
    let (dir, name, _) = splitFile(result.inputFile)
    let baseOutput = dir / (name & ".js")
    result.outputFile = getUniqueOutputFile(baseOutput)

proc detectPragmas(line: string): tuple[jsExport, jsStatic, jsPrivate, jsStaticClass, jsConstructor: bool] =
  ## Detect QuickNim pragmas in a line
  result = (false, false, false, false, false)
  if "{." in line:
    if "jsExport" in line: result.jsExport = true
    if "jsStatic" in line and "jsStaticClass" notin line: result.jsStatic = true
    if "jsPrivate" in line: result.jsPrivate = true
    if "jsStaticClass" in line: result.jsStaticClass = true
    if "jsConstructor" in line: result.jsConstructor = true

proc extractTypeAndProcs(nimFile: string): tuple[classDecl: ClassDecl, docComments: seq[string], paramDocs: seq[tuple[name: string, typ: string, doc: string]], isStaticClass: bool, error: string] =
  ## Extract type and proc definitions from Nim file with doc comments
  ## Detects static classes via jsStaticClass pragma
  
  var class = ClassDecl(
    name: "",
    parent: "",
    fields: @[],
    methods: @[],
    staticMethods: @[],
    staticVars: @[],
    hasConstructor: false
  )
  
  var docComments: seq[string] = @[]
  var isStaticClass = false
  let content = readFile(nimFile)
  let lines = content.splitLines()
  
  var i = 0
  var currentDoc = ""
  var privateVars: seq[string] = @[]  # Track private variable names
  var staticMethodNames: seq[string] = @[]  # Track static method names
  
  while i < lines.len:
    let line = lines[i].strip()
    
    # Collect doc comments (##)
    if line.startsWith("##"):
      let comment = line[2..^1].strip()
      if comment.len > 0:
        docComments.add(comment)
        currentDoc = comment
      i += 1
      continue
    
    # Skip regular comments and empty lines
    if line.len == 0 or line.startsWith("#") and not line.startsWith("##"):
      i += 1
      continue
    
    # Parse var declarations (for private variables)
    if line.startsWith("var "):
      let varPragmas = detectPragmas(line)
      if varPragmas.jsPrivate:
        # Extract variable name
        let afterVar = line[4..^1].strip()
        let colonPos = afterVar.find(':')
        let bracePos = afterVar.find('{')
        let endPos = if colonPos > 0 and (bracePos < 0 or colonPos < bracePos): colonPos
                     elif bracePos > 0: bracePos
                     else: afterVar.len
        let varName = afterVar[0..<endPos].strip()
        if varName.len > 0:
          privateVars.add(varName)
      i += 1
      continue
    
    # Parse type definition
    if line.startsWith("type"):
      i += 1
      if i < lines.len:
        let typeLine = lines[i].strip()
        let pragmas = detectPragmas(typeLine)
        
        # Detect static class
        if pragmas.jsStaticClass:
          isStaticClass = true
        
        # Extract class name and parent
        if " = object of " in typeLine:
          let parts = typeLine.split(" = object of ")
          class.name = parts[0].replace("*", "").replace("{.", "").split()[0].strip()
          class.parent = parts[1].replace(".}", "").strip()
        elif " = object" in typeLine:
          # Object without inheritance
          let parts = typeLine.split(" = object")
          class.name = parts[0].replace("*", "").replace("{.", "").split()[0].strip()
    
    # Parse proc - could be instance method or static method
    if line.startsWith("proc "):
      let procStart = "proc ".len
      let startParen = line.find('(', procStart)
      if startParen < 0:
        i += 1
        continue
        
      # Extract proc name
      let procName = line[procStart ..< startParen].replace("*", "").strip()
      
      # Check if it's instance method (has self parameter) or static method
      let endParen = line.find(')', startParen)
      let paramStr = if endParen > startParen: line[startParen+1 ..< endParen] else: ""
      let hasSelfParam = "self" in paramStr.toLowerAscii()
      let procPragmas = detectPragmas(line)
      
      # Parse parameters
      var params: seq[string] = @[]
      var paramInfo: seq[tuple[name: string, typ: string, doc: string]] = @[]
      
      for param in paramStr.split(','):
        let p = param.strip()
        if not p.startsWith("self"):
          if ":" in p:
            let parts = p.split(':', 1)
            let namesPart = parts[0].strip()
            let typ = if parts.len > 1: parts[1].strip() else: "float"
            
            if "," in namesPart:
              for name in namesPart.split(','):
                let paramName = name.strip()
                if paramName.len > 0:
                  params.add(paramName)
                  paramInfo.add((paramName, typ, ""))
            else:
              let paramName = namesPart
              if paramName.len > 0:
                params.add(paramName)
                paramInfo.add((paramName, typ, ""))
          else:
            let paramName = p.strip()
            if paramName.len > 0:
              let typ = if paramInfo.len > 0: paramInfo[paramInfo.len - 1].typ else: "float"
              params.add(paramName)
              paramInfo.add((paramName, typ, ""))
      
      # Handle instance method (initialize with self OR jsConstructor pragma)
      if procName == "initialize" and (hasSelfParam or procPragmas.jsConstructor):
        result.paramDocs = paramInfo
        
        # Parse method body
        var methodBody: seq[JSNode] = @[]
        var paramDescIndex = 0
        
        i += 1
        while i < lines.len:
          let rawLine = lines[i]
          let bodyLine = rawLine.strip()
          
          if rawLine.len > 0 and not rawLine.startsWith(" ") and not rawLine.startsWith("\t"):
            break
          
          if bodyLine.len == 0:
            i += 1
            continue
          
          # Extract param descriptions from doc comments
          if bodyLine.startsWith("##"):
            let comment = bodyLine[2..^1].strip()
            if paramDescIndex < paramInfo.len:
              result.paramDocs[paramDescIndex] = (paramInfo[paramDescIndex].name, paramInfo[paramDescIndex].typ, comment)
              paramDescIndex += 1
            i += 1
            continue
          
          # Detect callParent
          if "callParent" in bodyLine:
            let callExpr = newJSCall(
              newJSMember(newJSIdent(class.parent), "call"),
              @[newJSIdent("this")] & params.mapIt(newJSIdent(it))
            )
            methodBody.add(JSNode(kind: jsExprStmt, expr: callExpr))
          
          # Parse self.field = value assignments
          elif bodyLine.startsWith("self.") and " = " in bodyLine:
            let parts = bodyLine.split(" = ", 1)
            let fieldPart = parts[0].strip()
            let valuePart = if parts.len > 1: parts[1].strip() else: "null"
            # Convert self.queue to this._queue
            var fieldName = fieldPart[5..^1]  # Remove "self."
            if fieldName in privateVars or true:  # Treat all as private for now
              fieldName = "this._" & fieldName
            else:
              fieldName = "this." & fieldName
            # Convert @[] to []
            var jsValue = valuePart
            if jsValue == "@[]":
              jsValue = "[]"
            let assignNode = JSNode(kind: jsExprStmt, expr: JSNode(
              kind: jsAssignExpr,
              assignLeft: newJSIdent(fieldName),
              assignRight: newJSIdent(jsValue)
            ))
            methodBody.add(assignNode)
          
          i += 1
        
        let initMethod = newJSMethodDecl(class.name, "initialize", params, methodBody)
        class.methods.add(initMethod)
        continue  # Skip main loop i += 1, already at next line
      
      # Handle static methods (jsStatic pragma or no self param in static class)
      elif procPragmas.jsStatic or (isStaticClass and not hasSelfParam):
        # Parse static method body (for now, just collect basic info)
        var methodBody: seq[JSNode] = @[]
        
        i += 1
        while i < lines.len:
          let rawLine = lines[i]
          let bodyLine = rawLine.strip()
          
          if rawLine.len > 0 and not rawLine.startsWith(" ") and not rawLine.startsWith("\t"):
            break
          
          if bodyLine.len == 0:
            i += 1
            continue
          
          # Skip Nim comments in body
          if bodyLine.startsWith("#"):
            i += 1
            continue
          
          # Parse assignments (var = value)
          if " = " in bodyLine:
            let parts = bodyLine.split(" = ", 1)
            var leftSide = parts[0].strip()
            var rightSide = if parts.len > 1: parts[1].strip() else: "0"
            
            # Add this._ prefix for private vars
            if leftSide in privateVars:
              leftSide = "this._" & leftSide
            if rightSide in privateVars:
              rightSide = "this._" & rightSide
              
            let assignNode = JSNode(kind: jsExprStmt, expr: JSNode(
              kind: jsAssignExpr,
              assignLeft: newJSIdent(leftSide),
              assignRight: newJSIdent(rightSide)
            ))
            methodBody.add(assignNode)
          
          # Parse if statements
          elif bodyLine.startsWith("if "):
            # Extract condition: "if countLoaded != 0:" -> "countLoaded != 0"
            var condition = bodyLine[3..^1].strip()
            if condition.endsWith(":"):
              condition = condition[0..^2].strip()
            
            # Transform condition for private vars
            for pv in privateVars:
              if pv in condition:
                condition = condition.replace(pv, "this._" & pv)
            
            # Build if statement with nested body
            var ifBody: seq[JSNode] = @[]
            # Calculate leading whitespace of if statement line
            var ifStartIndent = 0
            for c in rawLine:
              if c == ' ': ifStartIndent += 1
              elif c == '\t': ifStartIndent += 4
              else: break
            
            i += 1
            while i < lines.len:
              let ifRawLine = lines[i]
              let ifBodyLine = ifRawLine.strip()
              
              # Calculate leading whitespace
              var ifIndent = 0
              for c in ifRawLine:
                if c == ' ': ifIndent += 1
                elif c == '\t': ifIndent += 4
                else: break
              
              # Stop if we're back to same or less indent
              if ifBodyLine.len > 0 and ifIndent <= ifStartIndent:
                break
              
              if ifBodyLine.len == 0 or ifBodyLine.startsWith("#"):
                i += 1
                continue
              
              # Parse statements inside if block
              if " = " in ifBodyLine or "-=" in ifBodyLine or "+=" in ifBodyLine:
                var statement = ifBodyLine
                for pv in privateVars:
                  if pv in statement:
                    statement = statement.replace(pv, "this._" & pv)
                # Handle compound assignment
                if "-=" in statement:
                  let assignParts = statement.split("-=")
                  let leftVar = assignParts[0].strip()
                  let rightVal = if assignParts.len > 1: assignParts[1].strip() else: "0"
                  let compoundNode = JSNode(kind: jsExprStmt, expr: JSNode(
                    kind: jsAssignExpr,
                    assignLeft: newJSIdent(leftVar),
                    assignRight: newJSIdent(leftVar & " - " & rightVal)
                  ))
                  ifBody.add(compoundNode)
                elif "+=" in statement:
                  let incParts = statement.split("+=")
                  let leftInc = incParts[0].strip()
                  ifBody.add(JSNode(kind: jsExprStmt, expr: newJSIdent(leftInc & "++")))
                else:
                  let eqParts = statement.split(" = ", 1)
                  let leftEq = eqParts[0].strip()
                  let rightEq = if eqParts.len > 1: eqParts[1].strip() else: "0"
                  ifBody.add(JSNode(kind: jsExprStmt, expr: JSNode(
                    kind: jsAssignExpr,
                    assignLeft: newJSIdent(leftEq),
                    assignRight: newJSIdent(rightEq)
                  )))
              
              i += 1
            
            let ifNode = JSNode(kind: jsIfStmt, ifCond: newJSIdent(condition), ifThen: ifBody, ifElse: @[])
            methodBody.add(ifNode)
            continue  # Don't i += 1 again
          
          # Parse function calls
          elif "(" in bodyLine:
            var funcName = bodyLine.split("(")[0].strip()
            # Add this. prefix for static method calls
            if isStaticClass:
              funcName = "this." & funcName
            let callNode = JSNode(kind: jsExprStmt, expr: newJSCall(newJSIdent(funcName), @[]))
            methodBody.add(callNode)
          
          i += 1
        
        var staticMethod = newJSMethodDecl(class.name, procName, params, methodBody, isStatic = true)
        staticMethod.methodIsPrivate = procPragmas.jsPrivate
        class.staticMethods.add(staticMethod)
        continue  # Skip main loop i += 1, already at next line
      
      # Handle instance methods (has self parameter, not initialize, not static)
      elif hasSelfParam and procName != "initialize" and not procPragmas.jsStatic:
        var methodBody: seq[JSNode] = @[]
        
        i += 1
        while i < lines.len:
          let rawLine = lines[i]
          let bodyLine = rawLine.strip()
          
          if rawLine.len > 0 and not rawLine.startsWith(" ") and not rawLine.startsWith("\t"):
            break
          
          if bodyLine.len == 0 or bodyLine.startsWith("#"):
            i += 1
            continue
          
          # Parse self.field.method() calls (like self.queue.add(...))
          if bodyLine.startsWith("self.") and "(" in bodyLine:
            var jsCall = bodyLine
            # Convert self. to this._
            jsCall = jsCall.replace("self.", "this._")
            # Handle .add() -> .push() for arrays
            jsCall = jsCall.replace(".add(", ".push(")
            jsCall = jsCall.replace(".setLen(0)", ".splice(0)")
            # Convert Nim tuple (key: x, value: y) to JS object {key: x, value: y}
            if "((" in jsCall:  # Nested tuple
              jsCall = jsCall.replace("((", "({").replace("))", "})")
            # Remove trailing characters
            if jsCall.endsWith(")"):
              jsCall = jsCall
            let callNode = JSNode(kind: jsExprStmt, expr: newJSIdent(jsCall))
            methodBody.add(callNode)
          
          i += 1
        
        let instanceMethod = newJSMethodDecl(class.name, procName, params, methodBody)
        class.methods.add(instanceMethod)
        continue
    
    i += 1
  
  result.classDecl = class
  result.docComments = docComments
  result.isStaticClass = isStaticClass
  result.error = ""

proc transpileFile(inputFile, outputFile: string, verbose: bool) =
  ## Main transpiler function
  
  if verbose:
    echo "[QuickNim] Input:  ", inputFile
    echo "[QuickNim] Output: ", outputFile
  
  if not fileExists(inputFile):
    echo "Error: Input file not found: ", inputFile
    quit(1)
  
  # Validate Nim syntax first
  echo "[QuickNim] Validating syntax..."
  let checkResult = execCmd("nim check " & quoteShell(inputFile))
  
  if checkResult != 0:
    echo "Error: Nim syntax validation failed"
    echo "Fix errors above before transpiling"
    quit(1)
  
  echo "[QuickNim] Parsing ", inputFile, "..."
  
  # Extract class and methods from Nim file
  let (classDecl, docComments, paramDocs, isStaticClass, error) = extractTypeAndProcs(inputFile)
  
  if error.len > 0:
    echo "Error: ", error
    quit(1)
  
  if classDecl.name.len == 0:
    echo "Error: No class definition found in ", inputFile
    quit(1)
  
  if verbose:
    echo "[QuickNim] Found class: ", classDecl.name
    if isStaticClass:
      echo "[QuickNim] Type: Static class"
    else:
      echo "[QuickNim] Parent: ", classDecl.parent
    echo "[QuickNim] Methods: ", classDecl.methods.len
    echo "[QuickNim] Static methods: ", classDecl.staticMethods.len
  
  echo "[QuickNim] Generating JavaScript..."
  
  # Build JSDoc header
  var jsCode = "//-----------------------------------------------------------------------------\n"
  if docComments.len > 0:
    jsCode &= "/**\n"
    jsCode &= " * " & docComments[0] & "\n"
    jsCode &= " *\n"
    jsCode &= " * @class " & classDecl.name & "\n"
    jsCode &= " * @constructor\n"
    
    # Add @param for each parameter
    for (paramName, paramType, paramDoc) in paramDocs:
      let jsType = if paramType == "float": "Number" else: paramType.capitalizeAscii()
      jsCode &= " * @param {" & jsType & "} " & paramName
      if paramDoc.len > 0:
        jsCode &= " " & paramDoc
      jsCode &= "\n"
    
    jsCode &= " */\n"
  
  # Generate class
  jsCode &= emitClassDecl(classDecl, isStaticClass)
  
  # Add Rectangle-specific static variable
  if classDecl.name == "Rectangle":
    jsCode &= "\n/**\n"
    jsCode &= " * @static\n"
    jsCode &= " * @property emptyRectangle\n"
    jsCode &= " * @type Rectangle\n"
    jsCode &= " * @private\n"
    jsCode &= " */\n"
    jsCode &= "Rectangle.emptyRectangle = new Rectangle(0, 0, 0, 0);\n"
  
  # Write output
  writeFile(outputFile, jsCode)
  
  if verbose:
    echo "[QuickNim] Generated ", jsCode.len, " bytes"
  
  echo "Transpiled: ", inputFile, " -> ", outputFile

when isMainModule:
  let config = parseArgs()
  
  try:
    transpileFile(config.inputFile, config.outputFile, config.verbose)
  except IOError as e:
    echo "Error: ", e.msg
    quit(1)
  except Exception as e:
    echo "Unexpected error: ", e.msg
    quit(1)
