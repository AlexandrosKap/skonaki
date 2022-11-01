import os, re, strutils, strformat

type
  LineKind = enum
    lkType, lkProcedure, lkIterator, lkTemplate, lkMacro, lkNone

func ext(path: string): string =
  let extPos = path.searchExtPos
  if extPos > 0:
    path[extPos + 1 .. ^1]
  else:
    ""

func name(path: string): string =
  path.extractFilename.changeFileExt("")

func name(lk: LineKind): string =
  case lk:
  of lkType: "Types"
  of lkProcedure: "Procedures"
  of lkIterator: "Iterators"
  of lkTemplate: "Templates"
  of lkMacro: "Macros"
  of lkNone: "Nones"

func isType(str: string): bool =
  (str.startsWith("type") and str[5].isUpperAscii) or
  str.startsWith(re"[A-Z]")

func isProcedure(str: string): bool =
  str.startsWith("proc") or
  str.startsWith("func") or
  str.startsWith("method")

func isIterator(str: string): bool =
  str.startsWith("iterator")

func isTemplate(str: string): bool =
  str.startsWith("template")

func isMacro(str: string): bool =
  str.startsWith("macro")

func lineKind(str: string): LineKind =
  if str.isType: lkType
  elif str.isProcedure: lkProcedure
  elif str.isIterator: lkIterator
  elif str.isTemplate: lkTemplate
  elif str.isMacro: lkMacro
  else: lkNone

proc writeGroup(doc: File, title: string, lines: seq[string]) =
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
  doc.writeLine(&"# {projectName.capitalizeAscii} Cheatsheet\n")

  # Get modules.
  var modules = newSeq[string]()
  for module in src.walkDirRec:
    modules.add(module)
    doc.writeLine(&"* [{module.name}](##{module.name})")

  # Create module documentation.
  var groups = [
    newSeq[string](), newSeq[string](),
    newSeq[string](), newSeq[string](),
    newSeq[string](),
  ]
  for module in modules:
    if module.ext != "nim":
      continue
    doc.writeLine(&"\n## {module.name}")
    for line in module.lines:
      if line.contains(re"\w+\*"):
        let pick = line.replace("type", "").strip
        case pick.lineKind
        of lkNone: discard
        else: groups[pick.lineKind.ord].add(pick)
    for i in 0 ..< groups.len:
      if groups[i].len != 0:
        doc.writeLine("")
        doc.writeGroup(i.LineKind.name, groups[i])
        groups[i].setLen(0)

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
