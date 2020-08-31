# An introduction to Calc2

Briefly, Calc2 is a stack based language with pattern matching. Everything is an "expression", which is just a sequence of instructions, like pushing something onto the stack, popping something, or calling a function. There are number literals, which push themselves onto the stack:

* Integer literals. Example: `10`
* Decimal literals, with a decimal point (`.`) and digits both before *and* after it. Example: `3.14`
* Complex literals, which are an optional real part and plus/minus sign, with a required imaginary part, with the `i`. Example: `2`, `3.1+2i`

There are also string literals, which can always be multline and escape with ` \ `, and also simply push themselves onto the stack. Before going on to the next instruction, we have to talk about...

## What are objects?

Apart from the numbers, strings, and functions (more on functions later), Calc2 only has one more datatype, objects. Objects are simply a list of values with a given tag, which starts with a capital letter and can have more alphanumeric characters after. The instruction to make an object, is just any number of backticks (`` ` ``), followed by the tag. That instruction pops as many values for the object as it has backticks, and stores them in a freshly pushed object with the given tag. The element on the top of the stack will end up first in the object. For example, ``` 2 1 ``Pair ``` will push a `Pair` object onto the stack with a `1` and a `2` in it. There are several ways to get values out of objects, the simplest is destructuring. An instruction that is a tag name with a question mark (`?`) at the end, will pop an object, and if it has the same tag, then it will push its contents back onto the stack. For example, ``` 2 1 ``Pair Pair? ``` will give the same thing as `2 1`. But what if the tag isn't the same? Then it throws an error. As to why, we now have to move on to...

## Pattern matching

In Calc2, pattern matching is done with several cases one after the other. If the pattern in the first case throws an error, then Calc2 does as if it never ran and goes to the next case and so on. If it runs out of cases, then the whole pattern matching throws an error. Each case has an optional pattern (no pattern is the same as an empty pattern), and the body of the case. Keep in mind that errors are only caught in the pattern part of each case, if a case's pattern succeeds and it's body runs, errors will not be caught there. Now, for the actual syntax, it's wrapped in `[]`, each case is separated by `|`, and each case is just pattern, arrow (`->`), and body. If you don't want a pattern (basically a catch all case), leave out the arrow. For example: ``` 2 1 ``Pair [Triple?-> `Singleton | Pair?-> `Singleton]``` will fail to match `Pair` with `Triple`, and move on to the next case, which *does* match and then will destructure `Pair`, then it will run `` `Singleton `` making a single element object with the `1` that was left there. Of course, you can also use `[]` with only one case that doesn't have a pattern, which will act then as just parentheses. But there's one thing pattern matching can do that a normal expression can never do, and that's...

## Defining variables

A simple identifier in a pattern (starting with a lowercase letter or underscore to not confuse with an object) will pop an element from the stack and assign it to that identifier. It never mutates a variable, only shadows. Using an identifier in a normal expression will attemp to call that variable as a function, the way to push it is using a single quote (`'`) before the name. For example, `2 [a-> 'a 'a]` will duplicate the `2`!