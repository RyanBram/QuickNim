## AST Walker - Convert Nim AST to JS IR
## This module walks Nim AST nodes and converts them to JavaScript IR

import std/[macros, strutils, sequtils]
import types

# Forward declarations
proc walkNode*(node: NimNode): JSNode
proc walkStmtList*(stmts: NimNode): seq[JSNode]

proc walkIdentDefs*(node: NimNode): tuple[name: string, typ: string] =
  ## Extract variable name and type from IdentDefs
  # IdentDefs has structure: [name(s), type, default_value]
  if node.len >= 2:
    let nameNode = node[0]
    let typeNode = node[1]
    result.name = $nameNode
    result.typ = if typeNode.kind != nnkEmpty: $typeNode else: "auto"
  else:
    result = ("", "auto")

proc extractParams*(formalParams: NimNode): tuple[params: seq[string], hasSelf: bool] =
  ## Extract parameter names from FormalParams
  ## Returns (param_names, has_self_param)
  result.params = @[]
  result.hasSelf = false
  
  if formalParams.kind == nnkEmpty:
    return
  
  # Skip first element (return type)
  for i in 1 ..< formalParams.len:
    let identDef = formalParams[i]
    if identDef.kind == nnkIdentDefs:
      let paramName = $identDef[0]
      if paramName == "self":
        result.hasSelf = true
      else:
        result.params.add(paramName)

proc walkProcDef*(node: NimNode): JSNode =
  ## Convert proc definition to JS function/method
  # ProcDef structure:
  # 0: name
  # 1: empty
  # 2: empty  
  # 3: FormalParams
  # 4: pragmas
  # 5: empty
  # 6: body (StmtList)
  
  let name = $node[0]
  let params = extractParams(node[3])
  let body = walkStmtList(node[6])
  
  # Check if this is a method (has self parameter)
  if params.hasSelf:
    # Instance method - will be ClassName.prototype.methodName
    result = newJSMethodDecl("", name, params.params, body)
  else:
    # Could be static method or standalone function
    # For now, treat as function declaration
    result = JSNode(kind: jsFunctionDecl, fnName: name, 
                    fnParams: params.params, fnBody: body)

proc walkAsgn*(node: NimNode): JSNode =
  ## Convert assignment: a = b
  let left = walkNode(node[0])
  let right = walkNode(node[1])
  return newJSAssign(left, right)

proc walkDotExpr*(node: NimNode): JSNode =
  ## Convert dot expression: a.b
  let obj = walkNode(node[0])
  let prop = $node[1]
  return newJSMember(obj, prop)

proc walkIdent*(node: NimNode): JSNode =
  ## Convert identifier
  let name = $node
  # Translate Nim keywords to JS
  case name
  of "self": return newJSIdent("this")
  of "true": return newJSLiteral("true", "boolean")
  of "false": return newJSLiteral("false", "boolean")
  of "nil": return newJSLiteral("null", "null")
  else: return newJSIdent(name)

proc walkIntLit*(node: NimNode): JSNode =
  return newJSLiteral($node.intVal, "number")

proc walkFloatLit*(node: NimNode): JSNode =
  return newJSLiteral($node.floatVal, "number")

proc walkStrLit*(node: NimNode): JSNode =
  return newJSLiteral("\"" & $node.strVal & "\"", "string")

proc walkCall*(node: NimNode): JSNode =
  ## Convert function call
  let callee = walkNode(node[0])
  var args: seq[JSNode] = @[]
  for i in 1 ..< node.len:
    args.add(walkNode(node[i]))
  return newJSCall(callee, args)

proc walkIfStmt*(node: NimNode): JSNode =
  ## Convert if statement
  # IfStmt contains ElifBranch nodes
  # ElifBranch: [condition, body]
  let elifBranch = node[0]
  let cond = walkNode(elifBranch[0])
  let thenBody = walkStmtList(elifBranch[1])
  var elseBody: seq[JSNode] = @[]
  
  # Check for else clause (second ElifBranch or Else)
  if node.len > 1:
    let elseNode = node[1]
    if elseNode.kind == nnkElse:
      elseBody = walkStmtList(elseNode[0])
    elif elseNode.kind == nnkElifBranch:
      # Chain elif as nested if-else
      elseBody = @[walkIfStmt(newTree(nnkIfStmt, elseNode))]
  
  return JSNode(kind: jsIfStmt, ifCond: cond, ifThen: thenBody, ifElse: elseBody)

proc walkReturnStmt*(node: NimNode): JSNode =
  ## Convert return statement
  if node.len > 0:
    let value = walkNode(node[0])
    return JSNode(kind: jsReturnStmt, returnValue: value)
  else:
    return JSNode(kind: jsReturnStmt, returnValue: nil)

proc walkStmtList*(stmts: NimNode): seq[JSNode] =
  ## Walk a list of statements
  result = @[]
  for stmt in stmts:
    let jsNode = walkNode(stmt)
    if jsNode != nil:
      result.add(jsNode)

proc walkNode*(node: NimNode): JSNode =
  ## Main dispatcher - walk any Nim AST node
  case node.kind
  of nnkEmpty:
    return nil
  of nnkStmtList:
    # Return block statement
    let body = walkStmtList(node)
    return JSNode(kind: jsBlockStmt, blockBody: body)
  of nnkProcDef:
    return walkProcDef(node)
  of nnkAsgn:
    return walkAsgn(node)
  of nnkDotExpr:
    return walkDotExpr(node)
  of nnkIdent:
    return walkIdent(node)
  of nnkIntLit:
    return walkIntLit(node)
  of nnkFloatLit:
    return walkFloatLit(node)
  of nnkStrLit:
    return walkStrLit(node)
  of nnkCall, nnkCommand:
    return walkCall(node)
  of nnkIfStmt:
    return walkIfStmt(node)
  of nnkReturnStmt:
    return walkReturnStmt(node)
  of nnkDiscardStmt:
    return nil  # Discard statements become empty
  else:
    # Unknown node - emit comment for debugging
    echo "Warning: unhandled node kind: ", node.kind
    return JSNode(kind: jsExprStmt, 
                  expr: newJSIdent("/* TODO: " & $node.kind & " */"))

# Main entry point for testing
when isMainModule:
  import macros
  
  macro testWalk(body: untyped): untyped =
    echo "=== Nim AST ==="
    echo body.treeRepr
    echo "\n=== Walking AST ==="
    let jsNode = walkNode(body)
    echo "JS IR created: ", jsNode.kind
    result = body  # Return original for compilation
  
  testWalk:
    proc initialize(self: var Point, x, y: float) =
      self.x = x
      self.y = y
