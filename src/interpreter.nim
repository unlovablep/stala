import strutils
import options
import tables
import unicode
include stdlib

# Run a state
method run(self: var stalaState) =
  self.curline = 0
  while self.curline < self.file.len:
    let line = self.file[self.curline]
    let words = line.split(' ')
    case words[0]:
      of "NUM":
        self.num(words[1].parseFloat())
        self.curline += 1
      of "STR":
        self.str(words[1..words.len-1].join(" "))
        self.curline += 1
      of "IDENT":
        self.ident(words[1])
        self.curline += 1
      of "LABEL":
        self.curline += 1
      of "FUNCTION":
        self.curline = self.skip() # LABEL but also SKIP
      of "CALL":
        self.curline = self.call()
      of "NUL":
        self.nul()
        self.curline += 1
      of "FUNCALL": # call, but push the next line number to the return stack
        self.returnstack.add(self.curline + 1)
        self.push(stalaType(typ: stalaTypes.idn, num: float.none, idn: "fngoto".some))
        self.curline = self.call()
      of "RETURN":
        self.curline = self.returnstack.pop
      of "SKIP":
        self.curline = self.skip()

proc fileLines(fname: string): seq[string] =
  let f = open(fname)
  defer: f.close()
  return f.readAll().split('\n')

# reads a file to a format stala can read
# specifically, remove all whitespace, then remove all comments and blank lines
proc readFileStala(fileName: string): seq[string] =
  let file = fileLines(fileName)
  var realFile = newSeq[string](0)
  for line in file:
    let trimmed = line.strip(true, true)
    if not trimmed.startsWith('#') and trimmed.len > 0:
      realFile.add(trimmed)
  return realFile

# initialize a new state
# parse all label statments
proc newState(file: seq[string], stdlib: bool): stalaState =
  var state = stalaState(stack: @[], file: file)
  var i: int = 0
  while i < file.len:
    let words = file[i].split(' ')
    if words[0] == "LABEL" or words[0] == "FUNCTION":
      state.labels[words[1]] = i
    i += 1
  state.funs["error"] = proc (self: var stalaState): int = quit(QuitFailure)
  if stdlib:
    state.pushStdlib()
  return state
