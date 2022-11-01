import os, re, strutils, strformat

func ext(path: string): string =
  let extPos = path.searchExtPos
  if extPos > 0:
    path[extPos + 1 .. ^1]
  else:
    ""

func name(path: string): string =
  path.extractFilename.changeFileExt("")

func isProc(str: string): bool =
  str.startsWith("proc") or
  str.startsWith("func") or
  str.startsWith("method") or
  str.startsWith("iterator") or
  str.startsWith("template") or
  str.startsWith("macro")

func isType(str: string): bool =
  (str.startsWith("type") and str[5].isUpperAscii) or
  str.startsWith(re"[A-Z]")

proc writeBlock(doc: File, title: string, lines: seq[string]) =
  if lines.len != 0:
    doc.writeLine(&"{title}\n\n```nim")
    for line in lines:
      let pos = line.rfind('=')
      doc.writeLine(if pos != -1: line[0 ..< pos] else: line)
    doc.writeLine("```")

proc skonaki*(projectDir = ".", outputDir = ".", name = "CHEATSHEET"): int =
  ## Creates a cheatsheet for a nim project.

  result = 0
  # Check if the current directory is a Nim project.
  var projectName = ""
  for file in projectDir.walkDir:
    if file.path.ext == "nimble":
      projectName = file.path.name
      break
  if projectName.len == 0:
    return 2
  var src = joinPath(projectDir, "src")
  if not src.dirExists:
    src = joinPath(projectDir, projectName)
  if not src.dirExists:
    return 2
  let doc = open(joinPath(outputDir, name) & ".md", fmWrite)
  defer: doc.close()

  # Create module documentation.
  var types = newSeq[string]()
  var procs = newSeq[string]()
  doc.writeLine(&"# {projectName.capitalizeAscii} Cheatsheet")
  for module in src.walkDirRec:
    if module.ext != "nim":
      continue
    doc.writeLine(&"\n## {module.name}\n")
    for line in module.lines:
      if line.contains(re"\w+\*"):
        let pick = line.strip
        if pick.isProc:
          procs.add(pick)
        elif pick.isType:
          types.add(pick.replace("type", "").strip)
    doc.writeBlock("Types", types)
    if types.len != 0: doc.writeLine("")
    doc.writeBlock("Procedures", procs)
    types.setLen(0)
    procs.setLen(0)

when isMainModule:
  let args = commandLineParams()
  let code = case args.len:
  of 0: skonaki()
  of 1: skonaki(args[0])
  of 2: skonaki(args[0], args[1])
  of 3: skonaki(args[0], args[1], args[2])
  else: 7

  case code:
  of 2: echo "Directory is not a Nim project."
  of 7: echo "Argument list is too long."
  else: discard
  quit code
