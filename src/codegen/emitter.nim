## ES5 Code Emitter - Generate JavaScript from IR
## Produces clean, readable ES5 code

import std/[strutils, tables]
import ../ast/types

proc indent(level: int): string =
  return "    ".repeat(level)

proc emit*(node: JSNode, indentLevel: int = 0): string

proc emitMethodDecl*(node: JSNode, className: string): string =
  ## Emit prototype method: ClassName.prototype.method = function() {}
  let prefix = if node.methodIsPrivate: "_" else: ""
  let methodName = prefix & node.methodName
  
  let target = if node.methodIsStatic:
    className & "." & methodName
  else:
    className & ".prototype." & methodName
  
  var params = node.methodParams.join(", ")
  
  result = target & " = function(" & params & ") {\n"
  
  for stmt in node.methodBody:
    result &= emit(stmt, 1) & "\n"
  
  result &= "};"

proc emitBlock*(nodes: seq[JSNode], indentLevel: int): string =
  ## Emit a sequence of statements
  result = ""
  for node in nodes:
    let line = emit(node, indentLevel)
    if line.len > 0:
      result &= line & "\n"

proc emit*(node: JSNode, indentLevel: int = 0): string =
  ## Main emitter - convert JS IR to JavaScript code
  if node == nil:
    return ""
  
  let ind = indent(indentLevel)
  
  case node.kind
  of jsProgram:
    return emitBlock(node.body, 0)
  
  of jsFunctionDecl:
    result = ind & "function " & node.fnName & "(" & node.fnParams.join(", ") & ") {\n"
    result &= emitBlock(node.fnBody, indentLevel + 1)
    result &= ind & "}"
  
  of jsMethodDecl:
    # Should be emitted by class handler, but can handle standalone
    return emitMethodDecl(node, node.methodClass)
  
  of jsVarDecl:
    let prefix = if node.varIsPrivate: "_" else: ""
    result = ind & "var " & prefix & node.varName
    if node.varValue != nil:
      result &= " = " & emit(node.varValue, 0)
    result &= ";"
  
  of jsIfStmt:
    result = ind & "if (" & emit(node.ifCond, 0) & ") {\n"
    result &= emitBlock(node.ifThen, indentLevel + 1)
    
    if node.ifElse.len > 0:
      result &= ind & "} else {\n"
      result &= emitBlock(node.ifElse, indentLevel + 1)
    
    result &= ind & "}"
  
  of jsForStmt:
    result = ind & "for ("
    if node.forInit != nil: result &= emit(node.forInit, 0)
    result &= "; "
    if node.forCond != nil: result &= emit(node.forCond, 0)
    result &= "; "
    if node.forUpdate != nil: result &= emit(node.forUpdate, 0)
    result &= ") {\n"
    result &= emitBlock(node.forBody, indentLevel + 1)
    result &= ind & "}"
  
  of jsWhileStmt:
    result = ind & "while (" & emit(node.whileCond, 0) & ") {\n"
    result &= emitBlock(node.whileBody, indentLevel + 1)
    result &= ind & "}"
  
  of jsReturnStmt:
    result = ind & "return"
    if node.returnValue != nil:
      result &= " " & emit(node.returnValue, 0)
    result &= ";"
  
  of jsExprStmt:
    result = ind & emit(node.expr, 0) & ";"
  
  of jsBlockStmt:
    result = ind & "{\n"
    result &= emitBlock(node.blockBody, indentLevel + 1)
    result &= ind & "}"
  
  of jsCallExpr:
    result = emit(node.callee, 0) & "("
    for i, arg in node.args:
      if i > 0: result &= ", "
      result &= emit(arg, 0)
    result &= ")"
  
  of jsAssignExpr:
    result = emit(node.assignLeft, 0) & " = " & emit(node.assignRight, 0)
  
  of jsBinaryExpr:
    result = emit(node.binaryLeft, 0) & " " & node.binaryOp & " " & emit(node.binaryRight, 0)
  
  of jsIdentifier:
    result = node.identName
  
  of jsLiteral:
    result = node.litValue
  
  of jsMemberExpr:
    result = emit(node.memberObject, 0) & "." & node.memberProperty
  
  of jsArrayExpr:
    result = "["
    for i, elem in node.arrayElements:
      if i > 0: result &= ", "
      result &= emit(elem, 0)
    result &= "]"
  
  of jsObjectExpr:
    result = "{\n"
    var first = true
    for key, value in node.objectProps:
      if not first: result &= ",\n"
      result &= indent(indentLevel + 1) & key & ": " & emit(value, 0)
      first = false
    result &= "\n" & ind & "}"

proc emitClassDecl*(classDecl: ClassDecl, isStaticClass: bool = false): string =
  ## Emit complete ES5 class declaration
  ## For static classes: constructor throws error, all methods are static
  ## For instance classes: constructor + prototype chain + methods
  result = ""
  
  if isStaticClass:
    # Static class pattern - constructor throws error
    result &= "function " & classDecl.name & "() {\n"
    result &= "    throw new Error('This is a static class');\n"
    result &= "}\n\n"
    
    # Static methods only
    for meth in classDecl.staticMethods:
      let prefix = if meth.methodIsPrivate: "_" else: ""
      result &= classDecl.name & "." & prefix & meth.methodName & " = function("
      result &= meth.methodParams.join(", ") & ") {\n"
      for stmt in meth.methodBody:
        result &= emit(stmt, 1) & "\n"
      result &= "};\n\n"
  else:
    # Instance class pattern
    # 1. Constructor
    result &= "function " & classDecl.name & "() {\n"
    result &= "    this.initialize.apply(this, arguments);\n"
    result &= "}\n\n"
    
    # 2. Prototype chain (if has parent)
    if classDecl.parent.len > 0:
      result &= classDecl.name & ".prototype = Object.create(" & classDecl.parent & ".prototype);\n"
      result &= classDecl.name & ".prototype.constructor = " & classDecl.name & ";\n\n"
    
    # 3. Instance methods
    for meth in classDecl.methods:
      result &= emitMethodDecl(meth, classDecl.name) & "\n\n"
    
    # 4. Static methods
    for meth in classDecl.staticMethods:
      result &= emitMethodDecl(meth, classDecl.name) & "\n\n"
    
    # 5. Static variables
    for varNode in classDecl.staticVars:
      let prefix = if varNode.varIsPrivate: "_" else: ""
      result &= classDecl.name & "." & prefix & varNode.varName
      if varNode.varValue != nil:
        result &= " = " & emit(varNode.varValue, 0)
      result &= ";\n"
