# An introduction to Calc2

Briefly, Calc2 is a stack based language with pattern matching. Everything is called an "expression", which is just a sequence of instructions, like pushing something onto the stack, popping something, or calling a function. There are number literals, which push themselves onto the stack:

* Integer literals. Example: `10`
* Decimal literals, with a decimal point (`.`) and digits both before *and* after it. Example: `3.14`
* Complex literals, which are an optional real part and plus/minus sign, with a required imaginary part, with the `i`. Example: `2`, `3.1+2i`

There are also string literals, which can always be multline and escape with ` \ `, and also simply push themselves onto the stack. Before going on to the next instruction, we have to talk about...

## What are objects?
