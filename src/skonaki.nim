import os, re, strutils, strformat

type
  LineKind = enum
    lkProcedure, lkIterator, lkTemplate, lkMacro, lkNone

func starts(str: string, prefix: string): bool =
  ## My startsWith procedure.
  result = false
  for i in 0 ..< str.len:
    if str[i] != ' ':
      return str[i .. ^1].startsWith(prefix)

func lineKind(str: string): LineKind =
  if str.starts("proc ") or str.starts("func ") or str.starts("method "):
    return lkProcedure
  elif str.starts("iterator "):
    return lkIterator
  elif str.starts("template "):
    return lkTemplate
  elif str.starts("macro "):
    return lkMacro
  else:
    return lkNone

func `$`(lk: LineKind): string =
  case lk:
  of lkProcedure: "Procedures"
  of lkIterator: "Iterators"
  of lkTemplate: "Templates"
  of lkMacro: "Macros"
  of lkNone: "Nones"

func isPick(str: string): bool =
  str.contains(re"[a-zA-Z1-9`]\*")

func isMultiline(str: string): bool =
  str.endsWith('(') or str.endsWith(',')

func isMultilineEnd(str: string): bool =
  str.endsWith('=')

func isSpace(str: string): bool =
  str == "#"

func ext(path: string): string =
  let extPos = path.searchExtPos
  if extPos > 0: path[extPos + 1 .. ^1]
  else: ""

func name(path: string): string =
  path.extractFilename.changeFileExt("")

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
  doc.writeLine(&"# Cheatsheet\n")

  # Get modules.
  var modules = newSeq[string]()
  for module in src.walkDirRec:
    let name = module.replace(src[2 .. ^1] & '/', "").replace(".nim", "")
    if module.ext == "nim":
      modules.add(module)
      doc.writeLine(&"* [{name}](#{name})")

  # Create module documentation.
  var buffer = ""
  var group = -1
  var groups = array[4, seq[string]].default
  for module in modules:
    # Create groups.
    for line in module.lines:
      if buffer.len != 0:
        buffer.add(line.strip)
        if buffer.isMultilineEnd:
          if buffer.lineKind != lkNone:
            group = buffer.lineKind.ord
            groups[group].add(buffer)
          buffer.setLen(0)
        else:
          buffer.add(" ")
      elif line.isPick:
        if line.isMultiline:
          buffer.add(line.strip)
        elif line.lineKind != lkNone:
          group = line.lineKind.ord
          groups[group].add(line)
      elif line.isSpace and group >= 0:
        groups[group].add("")
    # Write groups in the cheatsheet.
    let name = module.replace(src[2 .. ^1] & '/', "").replace(".nim", "")
    doc.writeLine(&"\n## {name}")
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
