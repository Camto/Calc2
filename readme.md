# An introduction to Calc2

Briefly, Calc2 is a stack based language with pattern matching. Everything is an "expression", which is just a sequence of instructions, like pushing something onto the stack, popping something, or calling a function. There are number literals, which push themselves onto the stack:

* Integer literals. Example: `10`

* Decimal literals, with a decimal point (`.`) and digits both before *and* after it. Example: `3.14`
* Complex literals, which are an optional real part and plus/minus sign, with a required imaginary part, with the `i`. Example: `2i`, `3.1+2i`

There are also string literals using `"`, which can always be multline and escape with ` \ `, and also simply push themselves onto the stack. Before going on to the next instruction, we have to talk about...

## What are objects?

Apart from the numbers, strings, and functions (more on functions later), Calc2 only has one more datatype, objects. Objects are simply a list of values with a given tag, which starts with a capital letter and can have more alphanumeric characters after. The instruction to make an object, is just any number of backticks (`` ` ``), followed by the tag. That instruction pops as many values for the object as it has backticks, and stores them in a freshly pushed object with the given tag. The element on the top of the stack will end up first in the object. For example, `2 1 ``Pair` will push a `Pair` object onto the stack with a `1` and a `2` in it.

A nice piece of syntax sugar for objects is the `Tup` object, which can use `()` as its name. For example `2 1 ``()`. Run that example, and you'll notice the output is formatted differently, and that's because `Tup` has additional infix syntax on top of that: `(1, 2)` gives you the same thing as the above example (first item in the tuple = top item of the stack when being created). The tuple's values are expressions though, and can access outside values. They will run left-to-right, as shown in this example: ```3 2 1 (``Pair, 0, `Singleton)``` gives ```(2 1 ``Pair, 0, 3 `Singleton)```. This syntax only makes `Tup` objects ever, which are essentially the language's form of lists.

There are several ways to get values out of objects, the simplest is destructuring. An instruction that is a tag name with a question mark (`?`) at the end, will pop an object, and if it has the same tag (`()?` is the same as `Tup?`), then it will push its contents back onto the stack. For example, `2 1 ``Pair Pair?` gives the same thing as `2 1`. But what if the tag isn't the same? Then it throws an error. As to why, we now have to move on to...

## Pattern matching

In Calc2, pattern matching is done with several cases one after the other. If the pattern in the first case throws an error, then Calc2 does as if it never ran and goes to the next case and so on. If it runs out of cases, then the whole pattern matching throws an error. Each case has an optional pattern (no pattern is the same as an empty pattern), and the body of the case. Keep in mind that errors are only caught in the pattern part of each case, if a case's pattern succeeds and it's body runs, errors will not be caught there. Now, for the actual syntax, it's wrapped in `[]`, each case is separated by pipes (`|`), and each case is just pattern, arrow (`->`), and body. If you don't want a pattern (basically a catch all case), leave out the arrow. For example: ```2 1 ``Pair [Triple?-> `Singleton | Pair?-> `Singleton]``` will fail to match `Pair` with `Triple`, and move on to the next case, which *does* match and then will destructure `Pair`, then it will run `` `Singleton `` making a single element object with the `1` that was left there. Of course, you can also use `[]` with only one case that doesn't have a pattern, which will act then as just parentheses. But there's one thing pattern matching can do that a normal expression can never do, and that's...

## Defining variables

A simple identifier in a pattern (starting with a lowercase letter or underscore to not confuse with an object) will pop an element from the stack and assign it to that identifier. It never mutates a variable, only shadows. Using an identifier in a normal expression will attemp to call that variable as a function, the way to push it is using a single quote (`'`) before the name. For example, `2 [a-> 'a 'a]` will duplicate the `2`! The `_` is conventionally assigned to just to discard a value.

## Back to pattern matching

This same pipes and arrows syntax for pattern matching can be used in other places than just `[]`. Very useful syntax sugar if variable definition syntax, which looks like `a := 2 ; 'a 'a`, rewriting the example from earlier. You can have any number of definitions right before the body of any case, or on the top level expression. On the right side of the `:=` is the value, which is a simple expression and is run *before* the pattern on the left of the `:=`. The single variable definition is terminated by a `;`, and many of them can be chained together. The left side of the definition being a pattern, it can use destructuring, for example: `Pair? first second := 2 1 ``Pair ; 'first` will assign `first` to `1` and `second` to `2`, then push `first` onto the stack. But there's still a very important place where pattern matching is used...

## Functions

Wrapping a pattern match in `{}` instead of `[]` will not call it, but will push a function to the stack that can then be called. To actually call it, you can use the predefined variable `do`, which is itself defined as `do := {fn-> fn} ;` (pop something, name it `fn`, then call it). Remember that using a variables name without a leading quote will call it rather than push it. Taking the duplication example from earlier, we can now use `2 {a-> 'a 'a} do`, which would be better as its own function. There actually one like that in the prelude, near `do`! It's called `dup`, and it's defined as `dup := {a-> 'a 'a} ;`. After reading all this, be sure to check out the prelude (`Prelude.c2`), which has plenty of useful functions and example of Calc2 code. All this talk of functions leads us to...

## The built-in functions

Many functions in the prelude depend on certain functions and operators you *won't* find in the prelude, those are the built-ins, and are hardwired into the Calc2 source. Here they will *all* be described, starting with the operators:

* `+`/`-`/`*`/`/` - These are the normal math operators, except that now their right argument is the top element of the stack and their left argument the element under that one. (`3 1 -` gives `2`, the left argument being `3` and the right argument being `1`)

* `~` - This is just unary negation.
* `^` - Same as the normal math operators, but now it's exponentiation.
* `%` - Same again, but now it's modulus.
* `%%` - Same again, but returns an empty `True` object if the left argument is divisible by the right argument, otherwise an empty `False` object.
* `<`/`>`/`<=`/`>=` - Same again, but checking for less than/more than/less than or equal to/more than or equal to.
* `=`/`/=` - Deep equality/disequality check between anything but two functions.
* `<<`/`>>` - The right argument is appended to the left argument, which must be an object. The arrows point towards what end the element is being appended to. For example, `(1, 2) 3 <<` gives `(1, 2, 3)` and `2 1 ``List 3 <<` gives `3 2 1 ```List`, because the `3` was appended to the end of both objects.
* `<>` - The left and right objects are merged. It throws if their tags are different. For example, `(1, 2) (3, 4) <>` gives `(1, 2, 3, 4)` and `2 1 ``List 4 3 ``List <>` gives `4 3 2 1 ````List`.
* `&` - This runs the function on the top of the stack in a safe environment, on a *copy* of the current stack. If the function throws, `&` returns an empty `None` object. Otherwise is removes the items that were touched, and pack them in a `Some` object. For example, `3 2 1 'swap &` will leave the stack as ``3 2 1 (2, 1) `Some`` because `swap` only touched `1` and `2`, but left `3` alone. The numbers in `(2, 1)` were effectively swapped as the first item represents the top of the stack. On the other hand, `3 2 1 'Pair? &` will leave the stack as `3 2 1 None` since `Pair?` throws on `1`.

These next operators are typically used for pattern matching:

* `=?` - Pop the top two elements, if they are equal, do nothing, otherwise throw.

* `/=?` - Pop the top two elements, if they are *not* equal, leave the left argument on the stack, otherwise throw.
* `<?`/`>?`/`<=?`/`>=?` - Compare the top two numbers, if the comparison would be true, leave the left argument on the stack, otherwise throw.
* `<<?`/`>>?` - Pop the top element. Throw if it's not an object or is an empty object. Otherwise, separate the last/first element from the rest of the object, leaving the individual element above the rest of the object. Essentially the inverse of `<<`/`>>`. For example, `(1, 2, 3) >>?` gives `(2, 3) 1` and ``1 `Singleton >>?`` gives `Singleton 1`.

Now for the normally named builtins:

`eval` - Runs the string on the top of the stack as a Calc2 program with a fresh stack and variables. `eval` does not catch anything if the program errors and the program has no access to the prelude. The prelude has some `eval` variants you can check out.

Here are built-ins for manipulating objects:

* `any?` - Destructure an object regardless of tag.

* `tag` - Return the tag of the top of the stack, which must be an object.
* `len` - Return the number of values in element on top of the stack, which must be an object.
* `make_obj` - Pops a tag and a length, and makes an object with that tag and that many values. For example `2 1 2 "Pair" make_obj` gives `2 1 ``Pair` and `"c" "b" "a" 3 "Tup" make_obj` gives `("a", "b", "c")`

Here are built-in math functions, which only take numbers:

* `re` - Gives the real component of the top of the stack.

* `im` - Same but for the imaginary component.
* `round` - Rounds the top item of the stack.
* `ceil` - Same but rounds up.
* `floor` - Same but rounds down.
* `rand` - Gives a random number between 0 and the top of the stack.
* `cos` - Gives the cosine of the top of the stack.
* `sin` - Same but for sine.
* `tan` - Same but for tangent.
* `sec` - Same but for secant.
* `csc` - Same but for cosecant.
* `cot` - Same but for cotangent.
* `log` - Returns the log base right argument of the left argument.
* `ln` - Returns the natural logarithm of the top of the stack.

Here are built-ins for objects and strings:

* `nth` - Return the value at index right argument of the object left argument, 0 indexed. For example, `("a", "b", "c") 1 nth` gives `"b"`, then value at index `1`.

* `slice` - The left and right argument form a range, that's used to slice the object under them on the stack. For example, `("a", "b", "c", "d", "e", "f") 2 5 slice` gives `("c", "d", "e")`, from index `2`, to the right under index `5`.
* `join` - Joins the strings in the left argument into one string using the right argument as the joiner.
* `split` - Splits the left argument into a list a strings using the right argument as the splitter.
* `num_to_str` - Turn the top item of the stack, which must be a number, into a string.
* `str_to_num` - Parse the top item of the stack, which must be a string, as a Calc2 number literal, and convert it to the correct number type.

Here are the built-ins for I/O:

* `input` - Get a line input as a string.

* `print` - Pop and print the top of the stack (doesn't have to be a string).
* `print_no_nl` - Same but doesn't terminate with a newline.
* `read` - Read a file with the given name.
* `write` - Write the left argument to the file named the right argument.