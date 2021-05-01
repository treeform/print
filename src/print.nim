import json, macros, strutils, tables, sets

when defined(js):
  var
    printWidth* = 120
    printColors* = false
    haveSeen: HashSet[uint64]
    line: string
  type
    ForegroundColor = enum  ## terminal's foreground colors
      fgBlack = 30,         ## black
      fgRed,                ## red
      fgGreen,              ## green
      fgYellow,             ## yellow
      fgBlue,               ## blue
      fgMagenta,            ## magenta
      fgCyan,               ## cyan
      fgWhite,              ## white
      fg8Bit,               ## 256-color (not supported, see ``enableTrueColors`` instead.)
      fgDefault             ## default terminal foreground color
else:
  import terminal
  var
    printWidth* = terminalWidth()
    printColors* = stdout.isatty()
    haveSeen: HashSet[uint64]

type
  NodeKind = enum
    nkSupport
    nkTopLevel
    nkName
    nkNumber
    nkProc
    nkString
    nkChar
    nkPointer
    nkSeq
    nkArray
    nkTuple
    nkTable
    nkObject
    nkTopPair
    nkFieldPair
    nkNil
    nkRepeat

  Node = ref object
    kind: NodeKind
    value: string
    nodes: seq[Node]

template justAddr(x): uint64 =
  cast[uint64](x.unsafeAddr)

macro `$`(a: proc): untyped =
  let procDef = a.getTypeInst
  procDef.insert 0, ident($a)
  newLit(procDef.repr)

proc escapeString*(v: string): string =
  result.add '"'
  for c in v:
    case c:
    of '\\': result.add r"\\"
    of '\b': result.add r"\b"
    of '\f': result.add r"\f"
    of '\n': result.add r"\n"
    of '\r': result.add r"\r"
    of '\t': result.add r"\t"
    else:
      result.add c
  result.add '"'

proc newSupportNode*(value: string): Node =
  Node(kind: nkSupport, value: value)

proc newNameNode*(name: string): Node =
  Node(kind: nkName, value: name)

proc newTopPairNode*(k, v: Node): Node =
  Node(kind: nkTopPair, nodes: @[k, v])

proc newFieldPairNode*(k, v: Node): Node =
  Node(kind: nkFieldPair, nodes: @[k, v])

#proc newNode[K, V](t: Table[K, V]): Node
proc newNode*[T](x: seq[T]): Node
proc newNode*[N, T](x: array[N, T]): Node
proc newNode*(x: SomeNumber): Node
proc newNode*(x: string): Node
proc newNode*(x: char): Node
#proc newNode[T: object](s: T): Node

proc newNode*(x: SomeNumber): Node =
  Node(kind: nkNumber, value: $x)

proc newNode*(x: string): Node =
  Node(kind: nkString, value: x)

proc newNode*(x: cstring): Node =
  Node(kind: nkString, value: $x)

proc newNode*(x: char): Node =
  Node(kind: nkChar, value: $x)

proc newNode*(x: proc): Node =
  Node(kind: nkProc, value: $x)

proc newNode*[T](x: seq[T]): Node =
  var nodes: seq[Node]
  for e in x:
    nodes.add(newNode(e))
  Node(kind: nkSeq, nodes:nodes)

proc newNode*[N, T](x: array[N, T]): Node =
  var nodes: seq[Node]
  for e in x:
    nodes.add(newNode(e))
  Node(kind: nkArray, nodes:nodes)

proc newNode*[K, V](x: Table[K, V]): Node =
  var nodes: seq[Node]
  for k, v in x.pairs():
   nodes.add(newFieldPairNode(newNode(k), newNode(v)))
  Node(kind: nkTable, nodes:nodes)

proc newNode*[T: tuple](x: T): Node =
  var nodes: seq[Node]
  for _, e in x.fieldPairs:
    nodes.add(newNode(e))
  Node(kind: nkTuple, nodes:nodes)

proc newNode*[T: object](x: T): Node =
  var nodes: seq[Node]
  for n, e in x.fieldPairs:
    nodes.add(newFieldPairNode(newNameNode(n), newNode(e)))
  Node(kind: nkObject, value: $type(x), nodes:nodes)

proc newNode*[T](x: ref T): Node =
  if x != nil:
    when not defined(js):
      if x[].justAddr in haveSeen:
        Node(kind: nkRepeat, value:"...")
      else:
        if x[].justAddr != 0:
          haveSeen.incl x[].justAddr
        newNode(x[])
    else:
      newNode(x[])
  else:
    Node(kind: nkNil, value:"nil")

proc newNode*[T](x: ptr T): Node =
  if x != nil:
    newNode(x[])
  else:
    Node(kind: nkNil, value:"nil")

proc newNode*(x: pointer): Node =
  if x != nil:
    Node(kind: nkPointer, value:"0x" & toHex(cast[uint64](x)))
  else:
    Node(kind: nkNil, value:"nil")

proc newNode*[T](x: ptr UncheckedArray[T]): Node =
  newNode(cast[pointer](x))

proc newNode*(x: enum): Node =
  newNode($x)

proc textLine(node: Node): string =
  case node.kind:
    of nkNumber, nkNil, nkRepeat, nkPointer, nkProc:
      result.add node.value
    of nkString, nkChar:
      result.add node.value.escapeString()
    of nkSeq, nkArray:
      if node.kind == nkSeq:
        result.add "@"
      result.add "["
      for i, e in node.nodes:
        if i != 0:
          result.add ", "
        result.add textLine(e)
      result.add "]"
    of nkTable:
      result.add "{"
      for i, e in node.nodes:
        if i != 0:
          result.add ", "
        result.add textLine(e)
      result.add "}"
    of nkObject, nkTuple:
      result.add node.value
      result.add "("
      for i, e in node.nodes:
        if i != 0:
          result.add ", "
        result.add textLine(e)
      result.add ")"
    of nkTopLevel:
      result.add node.value
      for i, e in node.nodes:
        if i != 0:
          result.add " "
        result.add textLine(e)
    of nkTopPair:
      result.add textLine(node.nodes[0])
      result.add "="
      result.add textLine(node.nodes[1])
    of nkFieldPair:
      result.add textLine(node.nodes[0])
      result.add ": "
      result.add textLine(node.nodes[1])
    else:
      result.add node.value

proc printStr(s: string) =
  when defined(js):
    line.add(s)
  else:
    stdout.write(s)

proc printStr(c: ForeGroundColor, s: string) =
  when defined(js):
    line.add(s)
  else:
    stdout.styledWrite(c, s)

proc printNode*(node: Node, indent: int) =

  let wrap = textLine(node).len + indent >= printWidth

  case node.kind:
    of nkNumber:
      printStr(fgBlue, node.value)
    of nkRepeat, nkNil, nkPointer:
      printStr(fgRed, node.value)
    of nkProc:
      printStr(fgMagenta, node.value)
    of nkString:
      printStr(fgGreen, node.value.escapeString())
    of nkChar:
      printStr(fgGreen, "'" & node.value.escapeString()[1..^2] & "'")
    of nkSeq, nkArray:
      if node.kind == nkSeq:
        printStr "@"
      if wrap:
        printStr "[\n"
        for i, e in node.nodes:
          printStr "  ".repeat(indent + 1)
          printNode(e, indent + 1)
          if i != node.nodes.len - 1:
            printStr ",\n"
        printStr "\n"
        printStr "  ".repeat(indent)
        printStr "]"
      else:
        printStr "["
        for i, e in node.nodes:
          if i != 0:
            printStr ", "
          printNode(e, 0)
        printStr "]"
    of nkTable, nkObject, nkTuple:
      if node.kind in [nkObject, nkTuple]:
        printStr(fgCyan, node.value)
        printStr "("
      else:
        printStr "{"
      if wrap:
        printStr "\n"
        for i, e in node.nodes:
          printNode(e, indent + 1)
          if i != node.nodes.len - 1:
            printStr ",\n"
        printStr "\n"
        printStr "  ".repeat(indent)
      else:
        for i, e in node.nodes:
          if i != 0:
            printStr ", "
          printNode(e, 0)
      if node.kind in [nkObject, nkTuple]:
        printStr ")"
      else:
        printStr "}"

    of nkTopLevel:
      if wrap:
        for i, e in node.nodes:
          printNode(e, 0)
          if i != node.nodes.len - 1:
            printStr "\n"
      else:
        for i, e in node.nodes:
          if i != 0:
            printStr " "
          printNode(e, 0)
      printStr "\n"

    of nkTopPair:
      printNode(node.nodes[0], 0)
      printStr "="
      printNode(node.nodes[1], 0)

    of nkFieldPair:
      printStr "  ".repeat(indent)
      printNode(node.nodes[0], indent)
      printStr ": "
      printNode(node.nodes[1], indent)

    else:
      printStr(node.value)

proc printNodes*(s: varargs[Node]) =
  var nodes: seq[Node]
  for e in s:
    nodes.add(e)
  var node = Node(kind: nkTopLevel, nodes: nodes)
  printNode(node, 0)
  when defined(js):
    echo line[0 .. ^2]
    line = ""

macro print*(n: varargs[untyped]): untyped =
  var command = nnkCommand.newTree(
    newIdentNode("printNodes")
  )
  for i in 0..n.len-1:
    if n[i].kind == nnkStrLit:
      command.add nnkCommand.newTree(
        newIdentNode("newSupportNode"),
        n[i]
      )
    else:
      command.add nnkCommand.newTree(
        newIdentNode("newTopPairNode"),
        nnkCommand.newTree(
          newIdentNode("newNameNode"),
          newStrLitNode(n[i].repr)
        ),
        nnkCommand.newTree(
          newIdentNode("newNode"),
          n[i]
        )
      )

  var s = nnkStmtList.newTree(command)
  return s
