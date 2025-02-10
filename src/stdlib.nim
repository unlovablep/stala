import options
import tables
import math
import strformat
import strutils

# Used for determining what type a stalaType is
type stalaTypes = enum
  num
  idn
  nul

# A value on the stack, can either be a float number or an identifier (or neither - see NUL)
type stalaType = object
  typ: stalaTypes
  num: Option[float]
  idn: Option[string]

# The VM
type stalaState = object
  curline: int # the current line we are parsing
  returnstack: seq[int] # a stack of line numbers to return to (for nested function calls)
  stack: seq[stalaType] # the stack.
  labels: Table[string, int] # all labels parsed before the program was called
  file: seq[string] # the entire file contents (lines)
  funs: Table[string, proc (self: var stalaState): int] # every registered function callback
  errcode: int # unused

# Do nothing
func nop() = return

# Internal - Push a value to the stack
method push(self: var stalaState, item: stalaType) =
  self.stack.add(item)

# Internal - Pop a value from the stack
method pop(self: var stalaState): stalaType =
  return self.stack.pop()

# From the current line, skip until the line after the first "RETURN" we find
method skip(self: var stalaState): int =
  var i = self.curline
  while i < self.file.len:
    let words = self.file[i]
    if words.split(' ')[0] == "RETURN":
      break
    i += 1
  return i + 1

# Push a number to the stack
method num(self: var stalaState, num: float) =
  self.push(stalaType(typ: stalaTypes.num, num: num.some, idn: string.none))

# Push a string to the stack
# Reverse the string, then split it into its charcodes and push them
method str(self: var stalaState, str: string) =
  var strin = str[1 ..< ^1]
  while strin.len > 0:
    let ch = strin[^1]
    strin = strin[0 ..< ^1]
    self.push(stalaType(typ: stalaTypes.num, num:ch.ord.float.some, idn: string.none))

# Push a null value to the stack
method nul(self: var stalaState) =
  self.push(stalaType(typ: stalaTypes.nul, num: float.none, idn: string.none))

# Push an identifier to the stack (for funcalls)
method ident(self: var stalaState, ident: string) =
  self.push(stalaType(typ: stalaTypes.idn, num: float.none, idn: ident.some))

# Call a function from the last identifier in the stack
method call(self: var stalaState): int =
  let ident = self.pop().idn.get()
  let fun = self.funs[ident]
  # fun() should either return self.curline + 1, or if it's a goto or something, return the line of the label it's going to.
  return fun(self)

### STDLIB FUNCTIONS

# Until we reach a null value, print every number we encounter as the char it's ascii represents
# THIS WILL DIE IF WE UNDERFLOW - MAKE SURE THERE IS A NULL
proc print(self: var stalaState): int =
  var buf: seq[float] = newSeq[float](0)
  while true:
    let curval = self.pop()
    if curval.typ == stalaTypes.nul:
      break
    buf.add(curval.num.get())
  var str: string = ""
  for item in buf:
    str.add(item.char)
  echo(str)
  return self.curline + 1

# Convert a number to the ascii of its string representation
proc fchr(self: var stalaState): int =
  let val = self.pop().num.get()
  var valstr = ($val)
  while valstr.len > 0:
    let ch = valstr[^1]
    valstr = valstr[0 ..< ^1]
    self.push(stalaType(typ: stalaTypes.num, num: ch.float.some, idn: string.none))
  return self.curline + 1

# Convert a number th the ascii of its string representation (as an integer)
proc ichr(self: var stalaState): int =
  let val = self.pop().num.get().int
  var valstr = ($val)
  while valstr.len > 0:
    let ch = valstr[^1]
    valstr = valstr[0 ..< ^1]
    self.push(stalaType(typ: stalaTypes.num, num: ch.float.some, idn: string.none))
  return self.curline + 1

# Goto a label, if the second last value in the stack is 1
proc gotoif(self: var stalaState): int =
  let lbl = self.pop().idn.get()
  let cond = self.pop().num.get()
  if cond == 1.0:
    return self.labels[lbl]
  return self.curline + 1

# Goto a label
proc goto(self: var stalaState): int =
  let lbl = self.pop().idn.get()
  return self.labels[lbl]

# Goto a label, and push the next line number to the return stack
proc fngoto(self: var stalaState): int =
  let lbl = self.pop().idn.get()
  return self.labels[lbl] + 1


# BOOLEANS: true pushes 1, false pushes 0
# TOP OF THE STACK IS THE RIGHT SIDE OF THE COMPARISON

# <
proc lt(self: var stalaState): int =
  let b = self.pop().num.get()
  let a = self.pop().num.get()
  if a < b:
    self.push(stalaType(typ: stalaTypes.num, num: 1.float.some, idn: string.none))
  else:
    self.push(stalaType(typ: stalaTypes.num, num: 0.float.some, idn: string.none))
  return self.curline + 1

# <=
proc le(self: var stalaState): int =
  let b = self.pop().num.get()
  let a = self.pop().num.get()
  if a <= b:
    self.push(stalaType(typ: stalaTypes.num, num: 1.float.some, idn: string.none))
  else:
    self.push(stalaType(typ: stalaTypes.num, num: 0.float.some, idn: string.none))
  return self.curline + 1

# ==
proc eq(self: var stalaState): int =
  let b = self.pop().num.get()
  let a = self.pop().num.get()
  if a == b:
    self.push(stalaType(typ: stalaTypes.num, num: 1.float.some, idn: string.none))
  else:
    self.push(stalaType(typ: stalaTypes.num, num: 0.float.some, idn: string.none))
  return self.curline + 1

# >=
proc ge(self: var stalaState): int =
  let b = self.pop().num.get()
  let a = self.pop().num.get()
  if a >= b:
    self.push(stalaType(typ: stalaTypes.num, num: 1.float.some, idn: string.none))
  else:
    self.push(stalaType(typ: stalaTypes.num, num: 0.float.some, idn: string.none))
  return self.curline + 1

# >
proc gt(self: var stalaState): int =
  let b = self.pop().num.get()
  let a = self.pop().num.get()
  if a > b:
    self.push(stalaType(typ: stalaTypes.num, num: 1.float.some, idn: string.none))
  else:
    self.push(stalaType(typ: stalaTypes.num, num: 0.float.some, idn: string.none))
  return self.curline + 1

# !
proc no(self: var stalaState): int =
  let x = self.pop().num.get()
  if x == 1.float:
    self.push(stalaType(typ: stalaTypes.num, num: 0.float.some, idn: string.none))
  else:
    self.push(stalaType(typ: stalaTypes.num, num: 1.float.some, idn: string.none))
  return self.curline + 1

# Copy the last value on the stack
proc cpy(self: var stalaState): int =
  let x = self.pop()
  self.push(x)
  self.push(x)
  return self.curline + 1

# Maths:
# TOP OF THE STACK IS THE RIGHT SIDE OF THE OPERATION

# +
proc addi(self: var stalaState): int =
  let b = self.pop.num.get
  let a = self.pop.num.get
  self.push(stalaType(typ: stalaTypes.num, num: (a + b).float.some, idn: string.none))
  return self.curline + 1

# -
proc sub(self: var stalaState): int =
  let b = self.pop.num.get
  let a = self.pop.num.get
  self.push(stalaType(typ: stalaTypes.num, num: (a - b).float.some, idn: string.none))
  return self.curline + 1

# /
proc divi(self: var stalaState): int =
  let b = self.pop.num.get
  let a = self.pop.num.get
  self.push(stalaType(typ: stalaTypes.num, num: (a / b).float.some, idn: string.none))
  return self.curline + 1

# *
proc mul(self: var stalaState): int =
  let b = self.pop.num.get
  let a = self.pop.num.get
  self.push(stalaType(typ: stalaTypes.num, num: (a * b).float.some, idn: string.none))
  return self.curline + 1

# ^
proc pow(self: var stalaState): int =
  let b = self.pop.num.get
  let a = self.pop.num.get
  self.push(stalaType(typ: stalaTypes.num, num: (a^b).float.some, idn: string.none))
  return self.curline + 1

# Error function
proc err(self: var stalaState): int =
  echo(fmt"[{self.curline}] ERROR!")
  quit(QuitFailure)

# If the state is created with `stdlib` as true, we push all of the above functions to the state.
proc pushStdlib(state: var stalaState) =
  state.funs["error"] = err

  state.funs["print"] = print

  state.funs["chr"] = fchr
  state.funs["ichr"] = ichr

  state.funs["gotoif"] = gotoif
  state.funs["goto"] = goto
  state.funs["fngoto"] = fngoto

  state.funs["lt"] = lt 
  state.funs["le"] = le 
  state.funs["eq"] = eq 
  state.funs["ge"] = ge 
  state.funs["gt"] = gt 
  state.funs["not"] = no

  state.funs["copy"] = cpy

  state.funs["add"] = addi
  state.funs["sub"] = sub
  state.funs["mul"] = mul
  state.funs["div"] = divi
  state.funs["pow"] = pow
