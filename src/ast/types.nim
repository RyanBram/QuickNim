## AST Type Definitions for QuickNim v2
## JavaScript Intermediate Representation (IR)

import std/tables

type
  JSNodeKind* = enum
    jsProgram
    jsFunctionDecl
    jsMethodDecl
    jsVarDecl
    jsIfStmt
    jsForStmt
    jsWhileStmt
    jsReturnStmt
    jsExprStmt
    jsBlockStmt
    jsCallExpr
    jsAssignExpr
    jsBinaryExpr
    jsIdentifier
    jsLiteral
    jsMemberExpr
    jsArrayExpr
    jsObjectExpr

  JSNode* = ref object
    case kind*: JSNodeKind
    of jsProgram:
      body*: seq[JSNode]
    of jsFunctionDecl:
      fnName*: string
      fnParams*: seq[string]
      fnBody*: seq[JSNode]
      isMethod*: bool
      className*: string  # For prototype methods
    of jsMethodDecl:
      methodName*: string
      methodParams*: seq[string]
      methodBody*: seq[JSNode]
      methodClass*: string
      methodIsStatic*: bool
      methodIsPrivate*: bool
    of jsVarDecl:
      varName*: string
      varValue*: JSNode
      varIsStatic*: bool
      varIsPrivate*: bool
    of jsIfStmt:
      ifCond*: JSNode
      ifThen*: seq[JSNode]
      ifElse*: seq[JSNode]
    of jsForStmt:
      forInit*: JSNode
      forCond*: JSNode
      forUpdate*: JSNode
      forBody*: seq[JSNode]
    of jsWhileStmt:
      whileCond*: JSNode
      whileBody*: seq[JSNode]
    of jsReturnStmt:
      returnValue*: JSNode
    of jsExprStmt:
      expr*: JSNode
    of jsBlockStmt:
      blockBody*: seq[JSNode]
    of jsCallExpr:
      callee*: JSNode
      args*: seq[JSNode]
    of jsAssignExpr:
      assignLeft*: JSNode
      assignRight*: JSNode
    of jsBinaryExpr:
      binaryOp*: string
      binaryLeft*: JSNode
      binaryRight*: JSNode
    of jsIdentifier:
      identName*: string
    of jsLiteral:
      litValue*: string
      litType*: string  # "number", "string", "boolean", "null"
    of jsMemberExpr:
      memberObject*: JSNode
      memberProperty*: string
    of jsArrayExpr:
      arrayElements*: seq[JSNode]
    of jsObjectExpr:
      objectProps*: Table[string, JSNode]

  ClassDecl* = object
    name*: string
    parent*: string
    fields*: seq[tuple[name: string, typ: string]]
    methods*: seq[JSNode]
    staticMethods*: seq[JSNode]
    staticVars*: seq[JSNode]
    hasConstructor*: bool

# Helper constructors
proc newJSIdent*(name: string): JSNode =
  JSNode(kind: jsIdentifier, identName: name)

proc newJSLiteral*(value: string, typ: string = "number"): JSNode =
  JSNode(kind: jsLiteral, litValue: value, litType: typ)

proc newJSCall*(callee: JSNode, args: seq[JSNode] = @[]): JSNode =
  JSNode(kind: jsCallExpr, callee: callee, args: args)

proc newJSMember*(obj: JSNode, prop: string): JSNode =
  JSNode(kind: jsMemberExpr, memberObject: obj, memberProperty: prop)

proc newJSAssign*(left, right: JSNode): JSNode =
  JSNode(kind: jsAssignExpr, assignLeft: left, assignRight: right)

proc newJSMethodDecl*(className, name: string, params: seq[string], body: seq[JSNode], 
                      isStatic = false, isPrivate = false): JSNode =
  JSNode(kind: jsMethodDecl, methodClass: className, methodName: name,
         methodParams: params, methodBody: body, methodIsStatic: isStatic, methodIsPrivate: isPrivate)
