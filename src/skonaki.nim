import os, re, strutils, strformat

type
  LineKind = enum
    lkType, lkProcedure, lkIterator, lkTemplate, lkMacro, lkNone

func `$`(lk: LineKind): string =
  case lk:
  of lkType: "Types"
  of lkProcedure: "Procedures"
  of lkIterator: "Iterators"
  of lkTemplate: "Templates"
  of lkMacro: "Macros"
  of lkNone: "Nones"

func myStartsWith(str: string, prefix: string): bool =
  result = false
  for i in 0 ..< str.len:
    if str[i] != ' ':
      return str[i .. ^1].startsWith(prefix)

func myStartsWith(str: string, prefix: Regex): bool =
  result = false
  for i in 0 ..< str.len:
    if str[i] != ' ':
      return str[i .. ^1].startsWith(prefix)

func isPick(str: string): bool =
  str.contains(re"[a-zA-Z1-9`]\*")

func isType(str: string): bool =
  str.myStartsWith("type") or str.myStartsWith(re"[A-Z]")

func isProcedure(str: string): bool =
  str.myStartsWith("proc") or
  str.myStartsWith("func") or
  str.myStartsWith("method")

func isIterator(str: string): bool =
  str.myStartsWith("iterator")

func isTemplate(str: string): bool =
  str.myStartsWith("template")

func isMacro(str: string): bool =
  str.myStartsWith("macro")

func isMultiline(str: string): bool =
  str.endsWith('(') or str.endsWith(',')

func isEndOfMultiline(str: string): bool =
  str.endsWith('=')

func lineKind(str: string): LineKind =
  if str.isType: lkType
  elif str.isProcedure: lkProcedure
  elif str.isIterator: lkIterator
  elif str.isTemplate: lkTemplate
  elif str.isMacro: lkMacro
  else: lkNone

func ext(path: string): string =
  let extPos = path.searchExtPos
  if extPos > 0: path[extPos + 1 .. ^1]
  else: ""

func name(path: string): string =
  path.extractFilename.changeFileExt("")

func clean(str: string): string =
  str.replace("type", "").strip

proc writeGroup(doc: File, title: string, group: seq[string]) =
  doc.writeLine(&"{title}\n\n```nim")
  for line in group:
    let pos = line.rfind('=')
    let line = if pos != -1: line[0 ..< pos - 1] else: line
    doc.writeLine(line)
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
    if module.ext == "nim":
      modules.add(module)
      doc.writeLine(&"* [{module.name}](#{module.name})")

  # Create module documentation.
  var buffer = ""
  var groups = [
    newSeq[string](), newSeq[string](), newSeq[string](),
    newSeq[string](), newSeq[string]()
  ]
  for module in modules:
    for line in module.lines:
      if buffer.len != 0:
        # Adds multiline line to group.
        buffer.add(" ")
        buffer.add(line.strip)
        if buffer.isEndOfMultiline:
          case buffer.lineKind
          of lkNone: discard
          of lkType: groups[buffer.lineKind.ord].add(buffer.clean)
          else: groups[buffer.lineKind.ord].add(buffer)
          buffer.setLen(0)
      elif line.isPick:
        # Add line to group.
        if line.isMultiline:
          buffer.add(line.strip)
        else:
          case line.lineKind
          of lkNone: discard
          of lkType: groups[line.lineKind.ord].add(line.clean)
          else: groups[line.lineKind.ord].add(line)
    # Write groups in the cheatsheet.
    doc.writeLine(&"\n## {module.name}")
    for i in 0 ..< groups.len:
      if groups[i].len != 0:
        doc.writeLine("")
        doc.writeGroup($i.LineKind, groups[i])
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
