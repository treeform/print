import json, macros, strutils, tables

proc prettyPrint*(x: SomeInteger|SomeFloat|string|bool): string =
  $x

proc prettyPrint*(x: enum): string =
  $x

proc prettyPrint*(x: string): string =
  result = "\""
  for c in x:
    case c
    of '\0':
      result &= "\\0"
    of '\n':
      result &= "\\n"
    of '\r':
      result &= "\\r"
    of '\t':
      result &= "\\t"
    of '\1'..'\8', '\11'..'\12', '\14'..'\31', '\127'..'\255':
      result &= "\\x"
      const HexChars = "0123456789ABCDEF"
      let n = ord(c)
      result &= HexChars[int((n and 0xF0) shr 4)]
      result &= HexChars[int(n and 0xF)]
    of '\\': result &= "\\\\"
    of '\'': result &= "\\'"
    of '\"': result &= "\\\""
    else: result &= c
  result &= "\""

proc prettyPrint*(x: cstring): string =
  "cstring(" & prettyPrint($x) & ")"

proc prettyPrint*(x: char): string =
  "'" & $x & "'"

proc prettyPrint*(x: JsonNode): string =
  $x

proc prettyPrint*[N, T](x: array[N, T]): string =
  result = "["
  for i, value in x:
    if i != 0: result.add(", ")
    result.add(prettyPrint(value))
  result.add("]")

proc prettyPrint*[T](x: seq[T]): string =
  result = "@["
  for i, value in x:
    if i != 0: result.add(", ")
    result.add(prettyPrint(value))
  result.add("]")

proc prettyPrint*(x: tuple): string =
  result = "("
  var i = 0
  for _, value in x.field_pairs:
    if i != 0: result.add(", ")
    result.add(prettyPrint(value))
    inc i
  result.add(")")

func prettyPrint*[A, B](table: TableRef[A, B]): string =
  if table == nil:
    return "nil"
  result = "{"
  var i = 0
  for k, v in table.pairs:
    result &= prettyPrint(k)
    result &= ": "
    result &= prettyPrint(v)
    if i != table.len - 1:
      result &= ", "
    inc i
  result &= "}"

proc prettyObj(x: object): string =
  result.add "("
  var i = 0
  for name, value in x.fieldPairs:
    if i != 0: result.add(", ")
    result.add name
    result.add ": "
    result.add prettyPrint(value)
    inc i
  result.add ")"

proc prettyPrint*(x: object): string =
  $type(x) & prettyObj(x)

proc prettyPrint*(x: ref object): string =
  if x.isNil:
    "nil"
  else:
    ($typeof(x[])).split(":")[0] & prettyObj(x[])

proc prettyPrint*[T](x: ref T): string =
  if x == nil:
    "nil"
  else:
    $type(x[]) & prettyPrint(x[])

proc prettyPrint*[T](x: ptr T): string =
  if x == nil:
    "nil"
  else:
    $type(x[]) & prettyPrint(x[])

proc prettyPrint*(x: pointer): string =
  if x == nil:
    "nil"
  else:
    "0x" & toHex(cast[uint64](x))

macro print*(n: varargs[typed]): untyped =
  var command = nnkCommand.newTree(
    newIdentNode("echo")
  )
  for i in 0..n.len-1:
    if n[i].kind == nnkStrLit:
      command.add(n[i])
    else:
      command.add(toStrLit(n[i]))
      command.add(newStrLitNode("="))
      var prettyCall = nnkCommand.newTree(
        newIdentNode("prettyPrint")
      )
      prettyCall.add(n[i])
      command.add(prettyCall)

    if i != n.len-1:
      command.add(newStrLitNode(" "))
  return nnkStmtList.newTree(command)
