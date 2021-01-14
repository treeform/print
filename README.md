# Print

Print is a set of pretty print macros, useful for print-debugging.

```nim
import print

let a = 3
print a
```
```
a = 3
```

It prints data structures in a way you would create them in nim source code.

```nim
let
  a = 3
  b = "hi there"
  c = "oh\nthis\0isit!"
  d = @[1, 2, 3]
  d2 = [1, 2, 3]
  f = Foo(a:"hi", b:@["a", "abc"], c:1234)

print a, b, c, d, d2, f
```
```
a=3 b="hi there" c="oh\nthis\0isit!" d=@[1, 2, 3] d2=[1, 2, 3] f=Foo(a:"hi", b:@["a", "abc"], c:1234)
```

It will try to print out everything in one line, but it if it does not fit it will create indentation levels.

```nim
g2 = Bar(a: "hi a really really long string", b: @["a", "abc"], c: 1234)
print g2
```

```
g2=Bar(
  a: "hi a really really long string",
  b: @["a", "abc"],
  c: 1234
)
```

It will also print nil refs and pointers.

```nim
let
  p1: ptr int = nil
  p2: ref Foo = nil
print p1, p2
```
```
p1=nil p2=nil
```

```nim
var three = 3
var pointerToThree = cast[pointer](addr three)
print pointerToThree
```
```
pointerToThree=0x00000000004360A0
```

It will also stop recursing repeating structures:
```nim
type Node = ref object
  data: string
  next: Node
var n = Node(data:"hi")
n.next = n
print n
```
```
n=Node(data: "hi", next: ...)
```
