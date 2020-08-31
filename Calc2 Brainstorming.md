# Calc2 Brainstorming

## Pattern Matching with a Stack

### Using predicates and question marks.

```
fib := {0=? -> 0 | 1=? -> 1 | dup 1 - fib swap 2 - fib +} ;
fib := {2<? -> | dup 1 - fib swap 2 - fib +} ;

map := {f obj-> 'obj [0 'obj tag make_obj $] {'f dip append} fold} ;

Calc2 version
maybe_map := {@swap Some? -> swap do `Some | _->} ;
With dip
maybe_map := {'Some? @dip -> do `Some | _->} ;
Haskell version
maybe_map f = \case {None -> None ; Some s -> Some $ f s}

either := {f g -> : Left? -> f | Right? -> g} ;
either := {f _ Left? -> f | _ g Right? -> g} ;

lefts := {{Left? -> `Some | Right? -> drop None} map_maybe} ;

either_map := {f Right?-> f `Right | _->} ;

partition_eithers := {
	left := {'l ()?-> (l>>,)} ;
	right := {'r ()?-> (,r>>)} ;
	((),()) {'right 'left either} foldr} ;

add_vectors := {()? x1 y1 ()? x2 y2 -> (x1 x2 +, y1 y2 +)} ;
add_vectors (x1, y1) (x2, y2) = (x1 + x2, y1 + y2)

dip := {f v-> f 'v} ;

reverse := {() {swap >>} fold} ;
rev = {[] {swap +} fold} ;
reverse := {>>?-> 'reverse dip <<} ;

# New matching method.
cons? := {dup head swap tail} ;

# Old matching method.
cons? := {dup head? swap tail? and} ;
head? := {()? h @drop -> h `Match | -> No_Match} ;
tail? := {()=? -> No_Match | -> tail `Match} ;

foldr := {k z-> go := {>>?-> 'go dip k | _-> 'z} ; go} ;

map_maybe := {f >>? x-> 'f map_maybe ['x f]: Some?-> >> | _->} ;
map_maybe := {f-> () {swap f: Some?-> >> | _->} fold} ;
cat_maybes := {() {swap: Some?-> >> | _->} fold} ;

map_maybe := {map cat_maybes} ;
cat_maybes := {'id map_maybe} ;

zip := {>>? a, >>? b-> zip ('a, 'b) >> | _ _-> ()} ;

comp := {b a-> {a b}} ;
```

Function parameters, variables, and cases are all the same thing.

```
: a
desugars to
{a} do

a := b ; c
desugars to
{b a -> c} do
(c here is everything after, not just the next expression or variable)
```

## Syntax Problems

### Variables

Variables can only be after a `->`, `{`, or `,` (specifically in parameters) because otherwise you can't tell what's stuff before the variable and what's the variable's pattern.

## DF Example Updated

```
df := {
	main := {"" split (0,()) {run_char >>? wrap >>} foldl snd} ;
	run_char := {'()? dip []: "i"=? ->i | "d"=? ->d | "s"=? ->s | "o"=? ->o | _->(,)} ;
	wrap := {256=? ->0 | 1~ =? ->0 |->} ;
	i := {(1+,)} ; d := {(1-,)} ; s := {(2^,)} ; o := {dup (,<<)} ;
"iiodddoisoisoiso" "" split df
```

## WTF are objects?

Everything in Calc2 is an object, which just a tag with a certain number of values. Object tags can contain alphanumeric characters and underscores, but *must* start with a capital letter. To make an object, you use `` `Obj_Tag ``, where you put as many backticks (`` ` ``) as you want the object to contain values. For example, an empty object (which contains no values), can be made with no backticks: `Empty_Obj`. There is one special object tag syntax and that is that `()` is equivalent to the tag `Tup`, short for tuple, but also used for making lists. So a pair of `(1, 2)` is the same as ```2 1 ``()``` or ```2 1 ``Tup```.

### WIP

Since everything is an object, even builtin types, what should those store as values? One idea is that numbers could hold a list of their bytes. Strings could hold their characters.

## The new semantics of the pattern matching

`Obj_Tag?` is called object destructuring and it pops the top element on the stack, and if the tag matches it pushes all the value onto the stack, otherwise it throws a pattern failure.

## The old semantics of the pattern matching

`Obj_Tag?` is called object destructuring and it pops the top element on the stack, and if the tag matches, it pushes a `Match` object with all of the values, otherwise it pushes an empty `No_Match` object.

When pattern matching, a simple identifier (identifiers must start with an underscore or lowercase letter) will be bound. If the top of the stack is:
* A `Match` with at least an item, the top item in the `Match` is popped and bound to the identifier.
* An empty `Match`, it gets popped and tries to bind with the next element on the stack.
* A `No_Match`, pattern matching fails.
* Anything else, it gets bound to the identifier.