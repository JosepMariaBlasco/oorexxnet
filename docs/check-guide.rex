#!/usr/bin/env rexx
/* check-guide.rex: runs the examples of docs/guide.md and compares their
   output.

       rexx docs/check-guide.rex [build-dir]

   Every ```rexx block followed by a ```text block is a program and its
   output; the same for a ```csharp block (built as a small console project
   against the bridge's Rexx.Net.dll). build-dir: the bridge's build
   (default $REXXNET_BUILD/rexxnet, else /home/claude/build/rexxnet where
   that exists, else ~/build/rexxnet: as scripts/platform.sh and
   bridge/build.ps1; build the bridge first). DOTNET_ROOT, when not set: the
   .NET of `dotnet --list-sdks`, or setup-env.sh's places. Exit status 1 if
   any example fails. Linux, macOS and Windows. */

parse source . . me
here = filespec("location", me)
sep = .file~separator
platform = .rexxInfo~platform~upper
windows = platform~abbrev("WIN")
mac = platform~pos("DARWIN") > 0 | platform~pos("MAC") > 0

parse arg out
out = out~strip~strip("B", '"')
if out == "" then out = defaultBuild() || sep || "rexxnet"
if \.file~new(out || sep || "Rexx.Net.dll")~exists then do
  say "no Rexx.Net.dll in" out "(build the bridge first)"
  exit 2
end

/* The environment every example runs in. rexxnet is found by name: through
   the PATH on Windows, the library path elsewhere; on Unix the library path
   goes into the command itself (macOS drops DYLD_* variables when it starts
   /bin/sh, which ADDRESS SYSTEM uses). */
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

/* The blocks of the guide: (language, lines), in order */
lines = .stream~new(here || "guide.md")~arrayIn
blocks = .array~new
inBlock = .false
do line over lines
  if \inBlock, line~startsWith("```") then do
    lang = line~substr(4)~strip
    body = .array~new
    inBlock = .true
  end
  else if inBlock, line~strip == "```" then do
    blocks~append(.array~of(lang, body))
    inBlock = .false
  end
  else if inBlock then body~append(line)
end

pairs = .array~new
do i = 1 to blocks~items - 1
  lang = blocks[i][1]
  if (lang == "rexx" | lang == "csharp") & blocks[i + 1][1] == "text" then
    pairs~append(.array~of(lang, blocks[i][2], blocks[i + 1][2]))
end

work = tempDir()
fails = 0
do n = 1 to pairs~items
  lang = pairs[n][1]; code = pairs[n][2]; want = pairs[n][3]
  first = firstLine(code)
  o = .array~new; e = .array~new
  if lang == "rexx" then do
    prog = work || sep || "ex"n".rex"
    call writeLines prog, code
    old = directory()
    call directory out
    address system libvar'rexx "'prog'"' with output using (o) error using (e)
    call directory old
  end
  else do
    proj = work || sep || "cs"n
    call SysMkDir proj
    call writeLines proj || sep || "Program.cs", code
    call writeLines proj || sep || "Guide.csproj", .array~of( -
      '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType>' || -
      '<TargetFramework>net8.0</TargetFramework><RollForward>LatestMajor</RollForward>' || -
      '<Nullable>enable</Nullable><ImplicitUsings>disable</ImplicitUsings></PropertyGroup>' || -
      '<ItemGroup><Reference Include="Rexx.Net"><HintPath>'out || sep'Rexx.Net.dll</HintPath></Reference>' || -
      '</ItemGroup></Project>')
    bo = .array~new
    address system 'dotnet build "'proj'" -c Release -o "'proj || sep'out" -nologo -v q' with output using (bo) error using (bo)
    if rc \== 0 then do
      fails += 1
      say "FAIL example" n "("lang":" first"): does not build"
      do l over bo; say "    " l; end
      iterate
    end
    old = directory()
    call directory work
    address system libvar'dotnet "'proj || sep'out' || sep'Guide.dll"' with output using (o) error using (e)
    call directory old
  end
  all = o~copy; do l over e; all~append(l); end
  got = joined(all)
  if got == joined(want) then say "ok   example" n "("lang":" first")"
  else do
    fails += 1
    say "FAIL example" n "("lang":" first")"
    say "--- want"; say joined(want)
    say "--- got";  say got
  end
end
call removeDir work
if fails = 0 then say "guide: all" pairs~items "examples match"
else say "guide:" fails "of" pairs~items "examples FAILED"
exit fails > 0

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

/* The .NET that `dotnet --list-sdks` reports ("10.0.401 [<root>/sdk]"),
   else setup-env.sh's places, else Microsoft's default */
defaultDotnet: procedure expose sep windows mac
  if \windows then
    do d over .array~of("/home/claude/dotnet", env("HOME")"/.dotnet")
      if .file~new(d"/dotnet")~exists then return d
    end
  sdks = .array~new
  address system "dotnet --list-sdks" with output using (sdks) error using (.array~new)
  if sdks~items > 0 then do
    parse value sdks[sdks~last] with "[" root "]"
    if root~lastPos(sep) > 1 then return root~left(root~lastPos(sep) - 1)   -- <root>/sdk -> <root>
  end
  if windows then return env("ProgramFiles") || sep || "dotnet"
  if mac then return "/usr/local/share/dotnet"
  return "/usr/share/dotnet"

/* Lines joined by line feeds, without a trailing carriage return on any line
   (Windows) nor empty lines at the end */
joined: procedure
  use arg lines
  last = lines~items
  do while last > 0, lines[last]~strip("T", "0d"x) == ""
    last -= 1
  end
  s = .mutableBuffer~new
  do i = 1 to last
    if i > 1 then s~append("0a"x)
    s~append(lines[i]~strip("T", "0d"x))
  end
  return s~string

firstLine: procedure
  use arg lines
  do l over lines
    if l~strip \== "" then return l~strip
  end
  return ""

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
  d = SysTempFileName(base~strip("T", sep) || sep || "guide-?????")
  call SysMkDir d
  return d

removeDir: procedure expose windows
  use arg d
  if windows then address system 'rmdir /s /q "'d'"' with output using (.array~new) error using (.array~new)
  else address system "rm -rf '"d"'"
  return
