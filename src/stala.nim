import os
include interpreter

proc main() =
  let fileName = paramStr(1)
  let fileCont = readFileStala(fileName) 
  var state = newState(fileCont, true)
  state.run()

main()
