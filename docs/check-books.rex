#!/usr/bin/env rexx
/* check-books.rex: runs the examples of the books (docs/books) and compares
   their output.

       rexx docs/check-books.rex [build-dir] [windows] [office]

   Every <example> of a book that holds a program (<programlisting
   language="rexx"> or language="csharp") and a <screen> is run, and its
   output compared with the screen; the C# ones are built as a small console
   project against the bridge's Rexx.Net.dll. An example whose condition
   attribute says "windows" runs on Windows only; "office" (Excel, Word...)
   only when the argument office is given; anything else in the attribute
   (or an example without a screen) is shown, never run. build-dir: the
   bridge's build, as for check-guide.rex (default $REXXNET_BUILD/rexxnet,
   else /home/claude/build/rexxnet where that exists, else ~/build/rexxnet;
   build the bridge first). Exit status 1 if any example fails. Linux,
   macOS and Windows. */

parse source . . me
here = filespec("location", me)
sep = .file~separator
platform = .rexxInfo~platform~upper
windows = platform~abbrev("WIN")
mac = platform~pos("DARWIN") > 0 | platform~pos("MAC") > 0

out = ""; office = .false
do w over arg(1)~makeArray(" ")
  select
    when w~lower == "office" then office = .true
    when w~lower == "windows" then nop                -- (the platform decides)
    otherwise out = w~strip("B", '"')
  end
end
if out == "" then out = defaultBuild() || sep || "rexxnet"
if \.file~new(out || sep || "Rexx.Net.dll")~exists then do
  say "no Rexx.Net.dll in" out "(build the bridge first)"
  exit 2
end

/* The environment every example runs in, as check-guide.rex sets it */
call env "REXX_PATH", out
call env "REXXNET_DIR", out
call env "DOTNET_CLI_TELEMETRY_OPTOUT", "1"
call env "DOTNET_NOLOGO", "1"
if env("DOTNET_ROOT") == "" then call env "DOTNET_ROOT", defaultDotnet()
pathSep = .file~pathSeparator
call env "PATH", env("DOTNET_ROOT") || pathSep || env("PATH")
if windows then do
  call env "PATH", out || pathSep || env("PATH")
  libvar = ""
end
else if mac then libvar = "DYLD_LIBRARY_PATH='"out"' "
else libvar = "LD_LIBRARY_PATH='"out"' "

/* The examples of every book: (book, id, condition, language, program, screen) */
examples = .array~new
books = here || "books"
do bookDir over .file~new(books)~listFiles
  if \bookDir~isDirectory then iterate
  enUS = .file~new(bookDir~absolutePath || sep || "en-US")
  if \enUS~isDirectory then iterate
  files = .array~new
  do f over enUS~listFiles
    if f~extension~lower == "xml" then files~append(f~absolutePath)
  end
  do path over files~sort
    s = .stream~new(path); text = s~charIn(1, s~chars); s~close
    text = text~changeStr("0d0a"x, "0a"x)
    p = 1
    do forever
      p = text~pos("<example", p)
      if p == 0 then leave
      e = text~pos("</example>", p)
      if e == 0 then leave
      ex = text~substr(p, e - p)
      p = e + 10
      parse var ex "<example" attrs ">" body
      id = attr(attrs, "id"); cond = attr(attrs, "condition")
      parse var body "<programlisting" lattrs ">" listing "</programlisting>"
      lang = attr(lattrs, "language")
      if lang \== "rexx", lang \== "csharp" then iterate
      if body~pos("<screen") == 0 then iterate
      parse var body "<screen" . ">" screen "</screen>"
      examples~append(.array~of(bookDir~name, id, cond, lang, plain(listing), plain(screen)))
    end
  end
end

work = tempDir()
fails = 0; ran = 0; skipped = 0
do n = 1 to examples~items
  parse value examples[n]~makeString("L", "09"x) with book "09"x id "09"x cond "09"x lang "09"x .
  code = examples[n][5]~makeArray("0a"x); want = examples[n][6]~makeArray("0a"x)
  name = book id "("lang")"
  run = .true
  do c over cond~space~makeArray(" ")
    select
      when c == "windows" then if \windows then run = .false
      when c == "office" then if \office then run = .false
      otherwise run = .false
    end
  end
  if \run then do
    say "skip" name "(condition" cond")"
    skipped += 1
    iterate
  end
  ran += 1
  o = .array~new; e = .array~new
  if lang == "rexx" then do
    prog = work || sep || "ex"n".rex"
    call writeLines prog, code
    old = directory()
    call directory work
    address system libvar'rexx "'prog'"' with output using (o) error using (e)
    call directory old
  end
  else do
    proj = work || sep || "cs"n
    call SysMkDir proj
    call writeLines proj || sep || "Program.cs", code
    call writeLines proj || sep || "Book.csproj", .array~of( -
      '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType>' || -
      '<TargetFramework>net8.0</TargetFramework><RollForward>LatestMajor</RollForward>' || -
      '<Nullable>enable</Nullable><ImplicitUsings>disable</ImplicitUsings></PropertyGroup>' || -
      '<ItemGroup><Reference Include="Rexx.Net"><HintPath>'out || sep'Rexx.Net.dll</HintPath></Reference>' || -
      '</ItemGroup></Project>')
    bo = .array~new
    address system 'dotnet build "'proj'" -c Release -o "'proj || sep'out" -nologo -v q' with output using (bo) error using (bo)
    if rc \== 0 then do
      fails += 1
      say "FAIL" name": does not build"
      do l over bo; say "    " l; end
      iterate
    end
    old = directory()
    call directory work
    address system libvar'dotnet "'proj || sep'out' || sep'Book.dll"' with output using (o) error using (e)
    call directory old
  end
  all = o~copy; do l over e; all~append(l); end
  got = joined(all)
  if got == joined(want) then say "ok  " name
  else do
    fails += 1
    say "FAIL" name
    say "--- want"; say joined(want)
    say "--- got";  say got
  end
end
call removeDir work
if fails = 0 then say "books: all" ran "examples match ("skipped "not run here)"
else say "books:" fails "of" ran "examples FAILED ("skipped "not run here)"
exit fails > 0

/* An attribute's value in a tag's attributes */
attr: procedure
  use arg attrs, name
  p = (" "attrs)~pos(" "name'="')
  if p == 0 then return ""
  parse value (" "attrs)~substr(p + length(name) + 3) with value '"'
  return value

/* The text of a listing or a screen: no markup, the entities resolved */
plain: procedure
  use arg x
  t = .mutableBuffer~new
  do while x \== ""
    parse var x before "<" tag ">" x
    t~append(before)
  end
  s = t~string
  s = s~changeStr("&lt;", "<")~changeStr("&gt;", ">")~changeStr("&quot;", '"')~changeStr("&apos;", "'")
  return s~changeStr("&amp;", "&")

/* An environment variable: its value, or set it */
env: procedure
  use arg name, value
  if arg(2, "o") then return value(name, , "ENVIRONMENT")
  call value name, value, "ENVIRONMENT"
  return value

/* As scripts/platform.sh: REXXNET_BUILD, else /home/claude/build, else ~/build */
defaultBuild: procedure expose sep windows
  b = env("REXXNET_BUILD")
  if b \== "" then return b
  if \windows, .file~new("/home/claude")~isDirectory then return "/home/claude/build"
  if windows then return env("USERPROFILE") || sep || "build"
  return env("HOME") || sep || "build"

/* The .NET that `dotnet --list-sdks` reports, else setup-env.sh's places,
   else Microsoft's default (as check-guide.rex) */
defaultDotnet: procedure expose sep windows mac
  if \windows then
    do d over .array~of("/home/claude/dotnet", env("HOME")"/.dotnet")
      if .file~new(d"/dotnet")~exists then return d
    end
  sdks = .array~new
  address system "dotnet --list-sdks" with output using (sdks) error using (.array~new)
  if sdks~items > 0 then do
    parse value sdks[sdks~last] with "[" root "]"
    if root~lastPos(sep) > 1 then return root~left(root~lastPos(sep) - 1)
  end
  if windows then return env("ProgramFiles") || sep || "dotnet"
  if mac then return "/usr/local/share/dotnet"
  return "/usr/share/dotnet"

/* Lines joined by line feeds, without a trailing carriage return or blanks
   on any line, nor empty lines at either end */
joined: procedure
  use arg lines
  first = 1; last = lines~items
  do while last > 0, lines[last]~strip("T", "0d"x)~strip("T") == ""
    last -= 1
  end
  do while first <= last, lines[first]~strip("T", "0d"x)~strip("T") == ""
    first += 1
  end
  s = .mutableBuffer~new
  do i = first to last
    if i > first then s~append("0a"x)
    s~append(lines[i]~strip("T", "0d"x)~strip("T"))
  end
  return s~string

writeLines: procedure
  use arg file, lines
  s = .stream~new(file)
  s~open("write replace")
  s~arrayOut(lines)
  s~close
  return

tempDir: procedure expose sep windows
  if windows then base = env("TEMP")
  else do
    base = env("TMPDIR")
    if base == "" then base = "/tmp"
  end
  d = SysTempFileName(base~strip("T", sep) || sep || "books-?????")
  call SysMkDir d
  return d

removeDir: procedure expose windows
  use arg d
  if windows then address system 'rmdir /s /q "'d'"' with output using (.array~new) error using (.array~new)
  else address system "rm -rf '"d"'"
  return
