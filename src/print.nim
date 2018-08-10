import macros
import tables
import typetraits
import strutils


func prettyLine*(str: string): string
func prettyLine*(number: SomeNumber): string
func prettyLine*[T, N](arr: array[T, N]): string
func prettyLine*[T](seq: seq[T]): string
func prettyLine*[A, B](table: Table[A, B]): string
func prettyLine*[A, B](table: TableRef[A, B]): string
func prettyLine*[A](v: A): string


func prettyStr(str: string): string =
  #if str == nil:
  #  return "nil"
  result = "\""
  for c in str:
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


func prettyNumber*(number: SomeNumber): string = $number


func prettyArr[T](arr: seq[T]): string =
  if arr == nil:
    return "nil"
  result = "["
  for i, element in arr:
    result &= prettyLine(element)
    if i != arr.len - 1:
      result &= ", "
  result &= "]"


func prettyTable[A, B](table: TableRef[A, B]): string =
  if table == nil:
    return "nil"
  result = "{"
  var i = 0
  for k, v in table.pairs:
    result &= prettyLine(k)
    result &= ": "
    result &= prettyLine(v)
    if i != table.len - 1:
      result &= ", "
    inc i
  result &= "}"


func prettyOrderedTable[A, B](table: OrderedTableRef[A, B]): string =
  result = "{"
  var i = 0
  for k, v in table.pairs:
    result &= prettyLine(k)
    result &= ": "
    result &= prettyLine(v)
    if i != table.len - 1:
      result &= ", "
    inc i
  result &= "}"


func prettyAny*[A](v: A): string =
  when compiles($v):
    $v
  elif compiles(repr($v)):
    v.type.name & repr(v)
  elif compiles(v.type.name):
    v.type.name
  else:
    "???"


func prettyLine*[A, B](table: OrderedTableRef[A, B]): string = prettyOrderedTable(table)
func prettyLine*(str: string): string = prettyStr(str)
func prettyLine*(number: SomeNumber): string = prettyNumber(number)
func prettyLine*[T, N](arr: array[T, N]): string = prettyArr(arr)
func prettyLine*[T](seq: seq[T]): string = "@" & prettyArr(seq)
func prettyLine*[A, B](table: Table[A, B]): string = prettyTable(table) & ".toTable"
func prettyLine*[A, B](table: TableRef[A, B]): string = prettyTable(table) & ".newTable"
func prettyLine*[A](v: A): string = prettyAny(v)



func prettyWrap*(str: string): string =
  # split things using:
  # [] () {} and ,,, or :::
  var indent = ""
  var data = ""
  var inString = false
  var nextEsc = false
  for i in 0..<str.len:
    var c = str[i]
    if inString:
      data &= c
      if c == '"' and not nextEsc:
        inString = false
      if c == '\\':
        nextEsc = true
      else:
        nextEsc = false
    elif c in {'{', '['}:
      indent &= "  "
      data &= c & "\n" & indent
    elif c in {'}', ']'}:
      indent = indent[0..^3]
      data &= "\n" & indent & c
    elif c == ',':
      data &= c & "\n" & indent
    elif c == '"':
      data &= c
      inString = true
    elif c == ' ':
      if data[^1] != ' ':
        data &= c
    else:
      data &= c
  return data


func pretty*[A](v: A): string =
  var oneLine = prettyLine(v)
  if oneLine.len > 80:
    return prettyWrap(oneLine)
  else:
    return oneLine


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
        newIdentNode("pretty")
      )
      prettyCall.add(n[i])
      command.add(prettyCall)

    if i != n.len-1:
      command.add(newStrLitNode(" "))
  return nnkStmtList.newTree(command)


when defined(js):
  # TODO remove workaround: https://github.com/nim-lang/Nim/issues/7499
  proc toString(x: uint64): cstring {.importcpp.}
  proc `$`*(x: uint64): string = $(x.toString())


