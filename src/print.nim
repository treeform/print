import json, macros, strutils, tables, terminal, sets


var
  printWidth* = terminalWidth()
  haveSeen: HashSet[uint64]

proc ind(indent: int): string =
  for i in 0 ..< indent:
    result.add "  "

proc prettyPrint*(x: SomeInteger, indent=0, multiLine=false): string =
  $x.int64

proc prettyPrint*(x: SomeFloat, indent=0, multiLine=false): string =
  $x.float64

proc prettyPrint*(x: string|bool, indent=0, multiLine=false): string =
  $x

proc prettyPrint*(x: enum, indent=0, multiLine=false): string =
  $x

proc prettyPrint*(x: string, indent=0, multiLine=false): string =
  result = "\""
  for c in x:
    case c
    of '\0':
      result.add "\\0"
    of '\n':
      result.add "\\n"
    of '\r':
      result.add "\\r"
    of '\t':
      result.add "\\t"
    of '\1'..'\8', '\11'..'\12', '\14'..'\31', '\127'..'\255':
      result.add "\\x"
      const HexChars = "0123456789ABCDEF"
      let n = ord(c)
      result.add HexChars[int((n and 0xF0) shr 4)]
      result.add HexChars[int(n and 0xF)]
    of '\\': result.add "\\\\"
    of '\'': result.add "\\'"
    of '\"': result.add "\\\""
    else: result.add c
  result.add "\""

proc prettyPrint*(x: cstring, indent=0, multiLine=false): string =
  "cstring(" & prettyPrint($x) & ")"

proc prettyPrint*(x: char, indent=0, multiLine=false): string =
  "'" & $x & "'"

proc prettyPrint*(x: JsonNode, indent=0, multiLine=false): string =
  $x

template listLike(x, indent) =
  if multiLine: result.add "\n"
  for i, value in x:
    if i != 0:
      result.add(",")
      if multiLine:
        result.add "\n"
      else:
        result.add " "
    if multiLine: result.add ind(indent + 1)
    result.add prettyPrint(value, indent + 1)
  if multiLine:
    result.add "\n"
    result.add ind(indent)

proc prettyPrint*[N, T](x: array[N, T], indent=0, multiLine=false): string =
  result = "["
  listLike(x, indent)
  result.add "]"

proc prettyPrint*[T](x: seq[T], indent=0, multiLine=false): string =
  result = "@["
  listLike(x, indent)
  result.add "]"

proc prettyPrint*(x: tuple, indent=0, multiLine=false): string =
  result = "("
  var i = 0
  for _, value in x.field_pairs:
    if i != 0: result.add(", ")
    result.add(prettyPrint(value))
    inc i
  result.add(")")

type SomeTable[A, B] = Table[A, B]|OrderedTable[A, B]

template objLike(x, indent, what, keyFn) =
  if multiLine: result.add "\n"
  var i = 0
  for key, value in x.what:
    if i != 0:
      result.add(",")
      if multiLine:
        result.add "\n"
      else:
        result.add " "
    if multiLine: result.add ind(indent + 1)
    var keyStr = keyFn(key)
    result.add keyStr
    result.add ":"
    var haveSeenSave = haveSeen
    var e = prettyPrint(value)
    if e.len + indent * 2 + keyStr.len + 2 > printWidth:
      haveSeen = haveSeenSave
      result.add prettyPrint(value, indent + 1, multiLine=true)
    else:
      result.add e
    inc i
  if multiLine:
    result.add "\n"
    result.add ind(indent)

proc prettyPrint*[A, B](x: SomeTable[A, B], indent=0, multiLine=false): string =
  result = "{"
  objLike(x, indent, pairs, prettyPrint)
  result.add "}"

template justAddr(x): uint64 =
  cast[uint64](x.unsafeAddr)

proc prettyPrint*(x: object, indent=0, multiLine=false): string =
  var typeStr = $type(x)
  if ":" in typeStr:
    typeStr = typeStr.split(":")[0]
  result.add typeStr
  result.add "("
  objLike(x, indent, fieldPairs, `$`)
  result.add ")"

proc prettyPrint*[T](x: ref T, indent=0, multiLine=false): string =
  if x[].justAddr in haveSeen:
    return "..."
  else:
    if x[].justAddr != 0:
      haveSeen.incl x[].justAddr
  if x == nil:
    return "nil"
  else:
    var haveSeenSave = haveSeen
    result = prettyPrint(x[], indent, multiLine=false)
    if result.len > printWidth:
      haveSeen = haveSeenSave
      result = prettyPrint(x[], indent, multiLine=true)

proc prettyPrint*[T](x: ptr T, indent=0, multiLine=false): string =
  if cast[uint64](x) in haveSeen:
    return "..."
  else:
    if x[].justAddr != 0:
      haveSeen.incl cast[uint64](x)
  if x == nil:
    "nil"
  else:
    prettyPrint(x[])

proc prettyPrint*(x: pointer, indent=0, multiLine=false): string =
  if x == nil:
    "nil"
  else:
    "0x" & toHex(cast[uint64](x))

proc prettyPrintMain*[T](x: T): string =
  haveSeen.clear()
  result = prettyPrint(x)
  if result.len > printWidth:
    haveSeen.clear()
    result = prettyPrint(x, indent=0, multiLine=true)

macro print*(n: varargs[typed]): untyped =
  var command = nnkCommand.newTree(
    newIdentNode("echo")
  )
  for i in 0..n.len-1:
    if n[i].kind == nnkStrLit:
      command.add(n[i])
    else:
      command.add(newStrLitNode(n[i].repr))
      command.add(newStrLitNode("="))
      var prettyCall = nnkCommand.newTree(
        newIdentNode("prettyPrintMain")
      )
      prettyCall.add(n[i])
      command.add(prettyCall)

    if i != n.len-1:
      command.add(newStrLitNode(" "))
  return nnkStmtList.newTree(command)
