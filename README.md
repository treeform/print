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

It will print basic types and even objects that don't have a defined `$`.

```nim
let
  a = 3
  b = "hi there"
  c = "oh\nthis\0isit!"
  d = @[1, 2, 3]
  d2 = [1, 2, 3]
  f = Foo(a:"hi", b: @["a", "abc"], c:1234)

print a, b, c, d, d2, f
```
```
a=3 b="hi there" c="oh\nthis\0isit!" d=@[1, 2, 3] d2=[1, 2, 3] f=Foo(a: "hi", b: @["a", "abc"], c: 1234)
```

It will also print nil refs and pointers without crashing.

```nim
let
  p1: ptr int = nil
  p2: ref Foo = nil
print p1, p2
```
```
p1=nil p2=nil
```
