import ../src/print, tables

#printWidth = 40
var s = ""
for i in 0 ..< printWidth:
  s.add "#"
echo s

block:
  let
    a = true
    b = 1
    c = 1.34
  print a, b, c

type Foo = object
  a: string
  b: seq[string]
  c: int

type Bar = ref object
  a: string
  b: seq[string]
  c: int

type Colors = enum
  Red, White, Blue

var g: Bar
var g2 = Bar(a: "hi", b: @[], c: 1234)
print g, g2

g2 = Bar(a: "hi a really really long string", b: @["a", "abc"], c: 1234)
print g, g2

g2 = Bar(a: "hi", b: @["a", "abc", "a really really long string"], c: 1234)
print g, g2

proc hi() =
  echo "hi"
print hi

proc hi2(a: int, s:string): bool =
  echo "hi"
print hi2

let what = "\0\tworld\n\r"
print "hello", what

print 12

let whatc = cstring "hi there c string"
print whatc

let
  a = 3
  b = "hi there"
  c = "oh\nthis\0isit!"
  d = @[1, 2, 3]
  d2 = [1, 2, 3]
  f = Foo(a: "hi", b: @["a", "abc"], c: 1234)

print a, b, c, d, d2, f

when not defined(js):
  let
    p1: ptr int = nil
    p2: ref Foo = nil
    p3: pointer = nil
  print p1, p2, p3

  var three = 3
  var pointerToThree = cast[pointer](addr three)
  print pointerToThree

var t = ("hi", 1, (2, 3))
print t

let smallArr = [1, 2, 3]
print "array", smallArr

let smallSeq = @[1, 2, 3]
print "seq", smallSeq

let smallTable = {1: "one", 2: "two"}.toTable
print "table", smallTable

let smallTableRef = {1: "one", 2: "two"}.newTable
print "table", smallTableRef

type
  SomeObj = object
    id: string
    year: int
let someThing = SomeObj(id: "xy8", year: 2017)
print someThing

# Really big lines should wrap:
let bigTable = newTable[string, int]()
for i in 0..<10:
  bigTable["id" & $i] = i
print "table", bigTable

# Really Nested Stuff
let bigTable2 = newTable[string, SomeObj]()
for i in 0..<10:
  bigTable2["id" & $i] = SomeObj(id: "xy{8}", year: i)
print "table", bigTable2

let color = Red
print "Colors", color

when not defined(js):
  # Test circular structures
  block:
    type Node = ref object
      data: string
      next: Node
    var n = Node(data:"hi")
    n.next = n
    print n

  block:
    type Node = ref object
      data: string
      next: ptr[Node]
    var n = Node(data:"hi")
    n.next = n.addr
    print n

  block:
    type Node = ref object
      data: string
      next: pointer
    var n = Node(data:"hi")
    n.next = n.addr
    print n

  var file = open("tests/test.nim")
  print file

  var ua: ptr UncheckedArray[int]
  print ua
