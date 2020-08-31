# An introduction to Calc2

Briefly, Calc2 is a stack based language with pattern matching. Everything is called an "expression", which is just a sequence of instructions, like pushing something onto the stack, popping something, or calling a function. There are number literals, which push themselves onto the stack:

* Integer literals. Example: `10`
* Decimal literals, with a decimal point (`.`) and digits both before *and* after it. Example: `3.14`
* Complex literals, which are an optional real part and plus/minus sign, with a required imaginary part, with the `i`. Example: `2`, `3.1+2i`

There are also string literals, which can always be multline and escape with ` \ `, and also simply push themselves onto the stack. Before going on to the next instruction, we have to talk about...

## What are objects?

Apart from the numbers, strings, and functions (more on functions later), Calc2 only has one more datatype, objects. Objects are simply a list of values with a given tag, which starts with a capital letter and can have more alphanumeric characters after. The instruction to make an object, is just any number of backticks (`` ` ``), followed by the tag. That instruction pops as many values for the object as it has backticks, and stores them in a freshly pushed object with the given tag. The element on the top of the stack will end up first in the object. For example, ``` 2 1 ``Pair ``` will push a `Pair` object onto the stack with a `1` and a `2` in it. There are several ways to get values out of objects, the simplest is destructuring. An instruction that is a tag name with a question mark (`?`) at the end, will pop an object, and if it has the same tag, then it will push its contents back onto the stack. For example, ``` 2 1 ``Pair Pair? ``` will give the same thing as `2 1`. But what if the tag isn't the same? Then it throws an error. As to why, we now have to move on to...

## Pattern matching