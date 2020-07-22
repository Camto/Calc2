# Calc2 Brainstorming

## Pattern Matching with a Stack

### Using predicates and question marks.

```
fib := {0= -> 0 | 1= -> 1 | -> dup 1 - fib swap 2 - fib +} ;
fib := {2<? -> | -> dup 1 - fib swap 2 - fib +} ;

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
	left := {l ()?-> (l>>,)} ;
	right := {r ()?-> (,r>>)} ;
	((),()) {'right 'left either} foldr} ;

add_vectors := {()? x1 y1 ()? x2 y2 -> (x1 x2 +, y1 y2 +)} ;
add_vectors (x1, y1) (x2, y2) = (x1 + x2, y1 + y2)

dip := {f-> swap f swap} ;

reverse := {() {swap >>} fold} ;
rev = {[] {swap +} fold} ;
reverse := {>>?-> 'reverse dip <<} ;

>>? := {dup head? swap tail? and} ;
head? := {()=-> No_Match | -> head `Match} ;
tail? := {()=-> No_Match | -> tail `Match} ;

foldr := {k z-> go := {>>?-> 'go dip k | _-> z} ; go} ;

map_maybe := {f >>? x-> 'f map_maybe ['x f]: Some?-> >> | _->} ;
map_maybe := {f-> () {swap f: Some?-> >> | _->} fold} ;
cat_maybes := {() {swap: Some?-> >> | _->} fold} ;

map_maybe := {map cat_maybes} ;
cat_maybes := {'id map_maybe} ;

zip := {>>? a, >>? b-> zip (a, b) >> | _ _-> ()} ;

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
df := {(0,()) {run_char 'wrap map_fst} fold} ;
run_char := {()? -> unrot: "i"=->i | "d"=->d | "s"=->s | "o"=->o | _->(,)} ;
wrap := {256=->0 | 1~=->0} ;
i := {(1+,)} ; d := {(1-,)} ; s := {(2^,)} ; o := {dup (,<<)} ;
"iiodddoisoisoiso" df
```