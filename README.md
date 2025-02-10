# Stala
Just another stack-based language interpreter.

---

Compile with `nimble build`.

Generated executable requires one command line argument, the file to run the interpreter on.

Included `test.stala` shows a general overview of the language.

# How it works

### Functions
  - "builtin" functions - a function using the FUNCTION keyword
  - "registered" functions - a function registered to the language on the Nim side.

### The stacks
  - The normal stack - contains values (either NUL, floating point, or identifiers)
  - The return stack - contains line numbers. When "RETURN" is called, pop the stack and go to that line number - this allows for nesting of functions while keeping values on the stack.

### Instructions
  - NUM <x> - pushes a (floating point) number to the stack
  - IDENT <x> - pushes an identity (a string corresponding to a function/label name) to the stack
  - NUL - pushes a null value to the stack (used for terminating strings to print)
  - STR <x> - pushes a string (contained in double quotes) to the stack, as a series of its ascii-characters in reverse (top of the stack is the first character)
  - LABEL <x> - creates a new label with the provided identifier
  - FUNCTION <x> - same as label, but will skip over all code before the next RETURN statement when first run
  - SKIP - skips to the next RETURN statement. SKIP + LABEL = FUNCTION
  - RETURN - pop a value off the return stack and go to that line
  - CALL - call a (registered) function from the last identifier on the stack.
  - FUNCALL - call a (builtin) function from the last identifier on the stack. Pushes the linenumber immediately afterwards to the return stack, to be returned to with RETURN.

### Stdlib
There is a standard library of sorts (contained in `src/stdlib.nim`) of useful maths and control flow functions.

For maths and boolean operations, the top of the stack will act as the *right side* of the equation.
#### Maths
  - add, sub, mul, div, pow - do exactly what they sound like in maths terms, push the result to the stack
#### Booleans
  - lt, le, eq, ge, gt - compare the last two values on the stack (same order as maths). If the condition is *true*, push `1` to the stack, otherwise push `0` to the stack
  - not - if the last value on the stack is `1`, push `0`, otherwise push `1`
#### Goto
  - goto - pop an identifier from the stack, goto that label.
  - gotoif - pop an identifier and a number from the stack (in that order), if the number is `1`, act as `goto`, otherwise this is skipped
  - fngoto - `FUNCALL` in registered form. Pops a label from the stack, `goto` that label, but also push the next line number to the return stack.
#### Strings and Stack
  - chr - converts the last number on the stack to its ascii representation as a floating point number (19.0 becomes '1' '9' '.' '0' as ascii), backwards ('1' would be the top of the stack)
  - ichr - `chr`, but it rounds down to an integer number. (19.0 becomes '1' '9')
  - copy - pops from the stack, and pushes that value twice.
  - print - combines all popped numbers it incounters on the stack into a string, stopping at the first `NUL`. Once it finds `NUL` it prints the string to stdout. **BE CAREFUL - MAKE SURE TO PUSH A NUL MANUALLY, `STR` DOES NOT DO THAT ITSELF** - if this goes off the end of the stack, it will exit on error (hopefully)
#### Other
  - error - builtin error function, just prints that there was an error at the current line, then exits.
