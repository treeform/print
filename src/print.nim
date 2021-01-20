import json, macros, strutils, tables, sets

when not defined(js):
  import terminal, re

  var
    printWidth* = terminalWidth()
    haveSeen: HashSet[uint64]
    printColors* = stdout.isatty()

  proc lenAscii(s: string): int =
    s.replace(re"\x1B\[[0-9;]*[a-zA-Z]", "").len

  template color(x) =
    if printColors: result.add ansiForegroundColorCode(x)

else:
  var
    printWidth* = 140
    haveSeen: HashSet[uint64]
    printColors* = false

  proc lenAscii(s: string): int =
    s.len

  template color(x) =
    discard

# var s1 = "hi there"
# echo s1.len

# var s2 = ansiForegroundColorCode(fgBlue) & "hi there" & ansiForegroundColorCode(fgDefault)
# echo s2.len
# echo s2.lenAscii

# quit()

proc ind(indent: int): string =
  for i in 0 ..< indent:
    result.add "  "



proc prettyPrint*(x: SomeInteger, indent=0, multiLine=false): string =
  color(fgCyan)
  result.add $x.int64
  color(fgDefault)

proc prettyPrint*(x: SomeFloat, indent=0, multiLine=false): string =
  color(fgCyan)
  result.add $x.float64
  color(fgDefault)

proc prettyPrint*(x: bool, indent=0, multiLine=false): string =
  color(fgCyan)
  result.add $x
  color(fgDefault)

proc prettyPrint*(x: enum, indent=0, multiLine=false): string =
  color(fgBlue)
  result.add $x
  color(fgDefault)

proc prettyPrint*(x: string, indent=0, multiLine=false): string =
  color(fgGreen)
  result.add "\""
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
  color(fgDefault)

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
  result.add "["
  listLike(x, indent)
  result.add "]"

proc prettyPrint*[T](x: seq[T], indent=0, multiLine=false): string =
  result.add "@["
  listLike(x, indent)
  result.add "]"

proc prettyPrint*(x: tuple, indent=0, multiLine=false): string =
  result.add "("
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
    if e.lenAscii + indent * 2 + keyStr.lenAscii + 2 > printWidth:
      haveSeen = haveSeenSave
      result.add prettyPrint(value, indent + 1, multiLine=true)
    else:
      result.add e
    inc i
  if multiLine:
    result.add "\n"
    result.add ind(indent)

proc prettyPrint*[A, B](x: SomeTable[A, B], indent=0, multiLine=false): string =
  result.add "{"
  objLike(x, indent, pairs, prettyPrint)
  result.add "}"

template justAddr(x): uint64 =
  cast[uint64](x.unsafeAddr)

proc prettyPrint*(x: object, indent=0, multiLine=false): string =
  var typeStr = $type(x)
  if ":" in typeStr:
    typeStr = typeStr.split(":")[0]
  color(fgBlue)
  result.add typeStr
  color(fgDefault)
  result.add "("
  objLike(x, indent, fieldPairs, `$`)
  result.add ")"

proc prettyPrint*[T](x: ref T, indent=0, multiLine=false): string =
  if x[].justAddr in haveSeen:
    color(fgRed)
    result.add "..."
    color(fgDefault)
    return
  else:
    if x[].justAddr != 0:
      haveSeen.incl x[].justAddr
  if x == nil:
    color(fgRed)
    result.add "nil"
    color(fgDefault)
  else:
    var haveSeenSave = haveSeen
    result = prettyPrint(x[], indent, multiLine=false)
    if result.lenAscii > printWidth:
      haveSeen = haveSeenSave
      result = prettyPrint(x[], indent, multiLine=true)

proc prettyPrint*[T](x: ptr T, indent=0, multiLine=false): string =
  if cast[uint64](x) in haveSeen:
    color(fgRed)
    result.add "..."
    color(fgDefault)
    return
  else:
    if x[].justAddr != 0:
      haveSeen.incl cast[uint64](x)
  if x == nil:
    color(fgRed)
    result.add "nil"
    color(fgDefault)
  else:
    result.add prettyPrint(x[])

proc prettyPrint*(x: pointer, indent=0, multiLine=false): string =
  if x == nil:
    color(fgRed)
    result.add "nil"
    color(fgDefault)
  else:
    color(fgRed)
    result.add "0x" & toHex(cast[uint64](x))
    color(fgDefault)

proc prettyPrintMain*[T](x: T): string =
  haveSeen.clear()
  result = prettyPrint(x)
  if result.lenAscii > printWidth:
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
