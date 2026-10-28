/* install.rex: installs the ooRexx/.NET bridge into the ooRexx that runs it,
 * so that Rexx programs find net.cls (and the bridge's native library) with
 * no environment variables to set.
 *
 *   rexx install [install] [--clr] [--from DIR]
 *   rexx install uninstall
 *   rexx install status
 *   rexx oorexxnet-uninstall [status]       (from anywhere, once installed)
 *
 * One zip for every system: the managed part (Rexx.Net.dll, net.cls,
 * CLR.CLS) is the same everywhere; the native library and the runtime
 * configuration of each system are in native/<rid> (win-x64, linux-x64,
 * osx-arm64), and this program takes the one for the system running it.
 * --from DIR installs from a build folder instead (build.sh's or build.ps1's
 * output: everything in one folder).
 *
 * Where things go:
 *   Windows:        everything in the folder of rexx.exe and rexx.dll
 *                   (C:\Program Files\ooRexx).
 *   Linux, macOS:   everything in ooRexx's lib/oorexxnet/; the native
 *                   library is linked into lib/ (where ooRexx looks for
 *                   libraries), net.cls and CLR.CLS into bin/ (on the PATH,
 *                   where ::requires looks). The library finds the rest
 *                   through the link (it looks next to its real file).
 *   CLR.CLS:        BSF4ooRexx has a CLR.CLS of its own (.NET Framework,
 *                   through Java): when another CLR.CLS is found through
 *                   REXX_PATH or the PATH, ours is not installed beside rexx,
 *                   so that the programs written for that one keep it.
 *                   --clr installs it anyway. It is always copied to the
 *                   samples folder: a program finds a CLR.CLS next to it
 *                   before any other.
 *   oodnet.cls:     (Windows) beside rexx, as ooRexx's own .cls files: the
 *                   ooDialog programs ported to .NET (samples/oodialog-net)
 *                   find it from any folder.
 *   This program:   copied as oorexxnet-uninstall.rex next to rexx, which
 *                   uninstalls by default, so the unzipped folder can go.
 *   The samples:    in ooRexx's samples folder, under dotnet/ (Windows:
 *                   samples\ beside rexx.exe; the portable builds: samples/
 *                   beside bin/; Linux packages: share/ooRexx/samples; else
 *                   lib/oorexxnet/samples), with the guide and check.rex.
 * What was installed is listed in oorexxnet-installed.txt, in that same
 * folder; uninstall removes exactly that. Installing again (a newer
 * version) replaces the files and adds to the list.
 *
 * ooRexx in a system folder needs an administrator: on Windows, a terminal
 * opened "as administrator"; on Linux and macOS, sudo rexx install.
 */
parse arg args
parse source . . me
uninstaller = "oorexxnet-uninstall.rex"
-- the copy next to rexx uninstalls by default
if .File~new(me)~name~caselessEquals(uninstaller) then command = "uninstall"
else command = "install"
forceClr = .false; fromDir = ""
do while args \= ""
  parse var args word args
  select case word~lower
    when "install", "uninstall", "status" then command = word~lower
    when "--clr", "-clr" then forceClr = .true
    when "--from", "-from" then do
      parse var args fromDir args
      if fromDir~left(1) == '"' then parse value fromDir args with '"' fromDir '"' args
      if fromDir == "" then call fail "--from needs a folder"
    end
    when "-h", "--help", "-?", "help", "/?" then call help
    otherwise call fail "unknown argument:" word "(rexx install --help)"
  end
end

platform = .RexxInfo~platform~upper
windows = platform~abbrev("WIN")
mac = platform~pos("DARWIN") > 0 | platform~pos("MAC") > 0
select
  when windows then do; native = "rexxnet.dll";      os = "win";   end
  when mac     then do; native = "librexxnet.dylib"; os = "osx";   end
  otherwise           ; native = "librexxnet.so";    os = "linux"
end
rid = os"-"cpu()

-- ooRexx: the one running this program
rexxExe = .RexxInfo~executable~absolutePath
bin = .File~new(rexxExe)~parent
lib = .RexxInfo~libraryPath~absolutePath
if windows then home = bin; else home = join(lib, "oorexxnet")
manifest = join(home, "oorexxnet-installed.txt")

select case command
  when "status"    then call status
  when "uninstall" then call uninstall
  otherwise             call install
end
exit 0

/* ------------------------------------------------------------------------ */

install:
  if .File~new(me)~name~caselessEquals(uninstaller) then
    call fail "this is the uninstaller; to install, run install.rex from the unzipped rexxnet folder"
  say "ooRexx/.NET installer"
  say "  ooRexx" .RexxInfo~version "r".RexxInfo~revision "("rexxExe")," .RexxInfo~architecture "bits"
  parse value .RexxInfo~version with major "."
  if major < 5 then call fail "ooRexx 5 or later is needed"
  if .RexxInfo~revision < 13324 then                     -- (the family's base: #2123, #2128, #2116; .CommandHandler; #2122; .LogicalWrapper; ooRexx bugs #2111, #2112, #2114: see bridge/dist/README.md)
    call fail "ooRexx 5.3.0 r13324 or later is needed (this one is r".RexxInfo~revision")"
  if .RexxInfo~architecture \= 64 then call fail "a 64-bit ooRexx is needed"
  if windows, \.File~new(join(bin, "rexx.dll"))~exists then
    call fail "rexx.dll is not next to rexx.exe in" bin": this layout of ooRexx is not supported"

  -- what to install from: the zip's folder (its native/<rid>), or a build;
  -- the samples, the guide and check.rex: the zip's, or (install.rex in a
  -- checkout's bridge/dist) the repository's
  from = .File~new(me)~parent
  pkg = from
  if .File~new(join(pkg, "samples"))~isDirectory then do
    samplesSrc = join(pkg, "samples"); guide = join(join(pkg, "docs"), "guide.md")
    compat = join(join(pkg, "docs"), "clr-compat.md")
  end
  else do
    repo = .File~new(.File~new(pkg)~parent)~parent
    samplesSrc = join(repo, "samples"); guide = join(join(repo, "docs"), "guide.md")
    compat = join(join(repo, "notes"), "clr-compat.md")
  end
  checkFile = join(pkg, "check.rex")
  if fromDir \== "" then do
    from = .File~new(fromDir)~absolutePath
    nativeDir = from
  end
  else nativeDir = join(join(from, "native"), rid)
  if \.File~new(join(nativeDir, native))~exists then do
    if fromDir \== "" then call fail "no" native "in" from": a build folder for this system is needed"
    call fail "no binaries for this system ("rid") in this package: build the bridge from its sources"
  end
  managed = .array~of("Rexx.Net.dll", "Rexx.Net.deps.json", "net.cls")
  do f over managed
    if \.File~new(join(from, f))~exists then
      call fail "no" f "next to install.rex: run it from the unzipped rexxnet folder (or give --from)"
  end
  if same(from, home) then call fail "install.rex is already in" home

  -- .NET: the bridge needs .NET 8 or later (and, for Windows Forms, the
  -- desktop framework of the newest one)
  if \dotnetCheck() then exit 1

  done = readManifest()                 -- what an earlier install left
  if \.File~new(home)~isDirectory then do
    if \.File~new(home)~makeDirs then call denied home
    done~put(home, "dir")
  end
  -- the native library and its runtime configuration (and, on Windows,
  -- System.Speech.dll: the speech samples), then the managed part
  files = .array~new
  do f over .File~new(nativeDir)~listFiles
    n = f~name
    if n~caselessEquals(native) | n~caselessAbbrev("Rexx.Net.") & n~caselessPos("runtimeconfig") > 0 -
       | n~caselessEquals("System.Speech.dll") then files~append(f~absolutePath)
  end
  do f over managed~copy~~append("Rexx.Net.pdb")
    if .File~new(join(from, f))~exists then files~append(join(from, f))
  end
  do source over files
    target = join(home, .File~new(source)~name)
    if SysFileCopy(source, target) \= 0 then call denied target
    done~put(target, "file")
  end
  say "  installed" native"," "Rexx.Net.dll and net.cls in" home
  if mac then address system "xattr -dr com.apple.quarantine '"home"' 2>/dev/null"   -- (downloaded: refused otherwise)
  if \windows then do
    call link join(home, native), join(lib, native)
    call link join(home, "net.cls"), join(bin, "net.cls")
    say "  linked" native "into" lib "and net.cls into" bin
  end

  -- CLR.CLS: beside rexx unless another one would be found first (BSF4ooRexx's)
  other = otherClr()
  haveClr = .File~new(join(from, "CLR.CLS"))~exists
  if haveClr then do
    if other == "" | forceClr then do
      target = join(home, "CLR.CLS")
      if SysFileCopy(join(from, "CLR.CLS"), target) \= 0 then call denied target
      done~put(target, "file")
      if \windows then call link target, join(bin, "CLR.CLS")
      say "  installed CLR.CLS (BSF4ooRexx's CLR.CLS API on this bridge)"
      if other \== "" then say "    (--clr: another CLR.CLS," other", may still be found first: see 'status')"
    end
    else do
      say "  CLR.CLS not installed: another one is found first:" other
      say "    (BSF4ooRexx's, probably; its programs keep it). To use ours with a"
      say "    program, put the CLR.CLS of the samples folder next to it; or install"
      say "    it anyway with: rexx install --clr"
    end
  end

  -- oodnet.cls (Windows: ooDialog's shape on Windows Forms) beside rexx, as
  -- ooRexx's own .cls files: the ported ooDialog programs, and any other,
  -- find it from any folder with ::requires "oodnet.cls"
  oodnet = join(join(samplesSrc, "oodialog-net"), "oodnet.cls")
  if windows, .File~new(oodnet)~exists then do
    target = join(home, "oodnet.cls")
    if SysFileCopy(oodnet, target) \= 0 then call denied target
    done~put(target, "file")
    say "  installed oodnet.cls in" home
  end

  -- the uninstaller, next to rexx
  target = join(bin, uninstaller)
  if SysFileCopy(me, target) \= 0 then call denied target
  done~put(target, "file")
  say "  copied this program to" target "(rexx oorexxnet-uninstall)"

  -- the samples, the guide, check.rex, CLR.CLS
  samples = join(samplesFolder(), "dotnet")
  call makeDir samples
  if .File~new(samplesSrc)~isDirectory then do
    sets = .array~of("rexx")
    if windows then sets~appendAll(.array~of("windows", "office", "libreoffice", "oorexx-ole", "oodialog-net", "powershell"))
    do s over sets
      if .File~new(join(samplesSrc, s))~isDirectory then call copyTree join(samplesSrc, s), join(samples, s)
    end
  end
  extras = .array~of(checkFile, join(samplesSrc, "README.md"), guide, compat, join(from, "CLR.CLS"))
  do source over extras
    if \.File~new(source)~exists then iterate
    target = join(samples, .File~new(source)~name)
    if SysFileCopy(source, target) \= 0 then call denied target
    done~put(target, "file")
  end
  say "  copied the samples, the guide and check.rex to" samples
  call writeManifest done

  -- check it, as another program would: from elsewhere, with no variables
  say "Checking:"
  outcome = check()
  select
    when outcome = 0 then say "ooRexx/.NET: installed and OK"
    when outcome = 2 then do
      say "ooRexx/.NET: installed and OK, but without Windows Forms: install the"
      say "  .NET Desktop Runtime (x64) of your newest .NET, from https://dotnet.microsoft.com/download"
    end
    otherwise do
      say "ooRexx/.NET: installed, but the check FAILED (above)"
      exit 1
    end
  end
  say "  (try it: rexx" join(join(samples, "rexx"), "01-basics.rex") || "; to remove it: rexx oorexxnet-uninstall)"
  return

uninstall:
  done = readManifest()
  if done~items = 0 then do
    say "ooRexx/.NET: not installed in this ooRexx ("rexxExe")"
    return
  end
  failed = .false
  self = join(bin, uninstaller)
  do kind over "link", "file"
    do path over done~allAt(kind)
      if same(path, self) then iterate   -- last: it may be the one running
      if \.File~new(path)~exists & SysIsFileLink(path) \= 1 then iterate
      if SysFileDelete(path) \= 0 then do
        say "  could not remove" path
        failed = .true
      end
      else say "  removed" path
    end
  end
  -- folders, deepest first (only if empty: nothing of the user's is lost)
  dirs = done~allAt("dir")~sortWith(.DescendingLength~new)
  do path over dirs
    if .File~new(path)~isDirectory then call SysRmDir path
  end
  if failed then call denied manifest
  call SysFileDelete manifest
  if \windows then call SysRmDir home
  if done~hasItem(self, "file") | .File~new(self)~exists then do
    if SysFileDelete(self) \= 0 then say "  could not remove" self "(delete it by hand)"
    else say "  removed" self
  end
  say "ooRexx/.NET: uninstalled"
  return

status:
  say "ooRexx" .RexxInfo~version "r".RexxInfo~revision "("rexxExe")"
  done = readManifest()
  if done~items = 0 then say "ooRexx/.NET: not installed in this ooRexx"
  else do
    say "ooRexx/.NET: installed in" home
    do kind over "file", "dir", "link"
      do path over done~allAt(kind)
        if .File~new(path)~exists then state = ""; else state = "  (MISSING)"
        say "  "kind~left(5) path || state
      end
    end
  end
  found = findFirst("CLR.CLS")
  if found == "" then say "CLR.CLS: none found through REXX_PATH or the PATH"
  else say "CLR.CLS found first (REXX_PATH, then the PATH):" found
  return

/* ------------------------------------------------------------------------ */

-- the processor, as .NET's runtime identifiers name it
cpu: procedure expose windows
  if windows then do
    p = value("PROCESSOR_ARCHITECTURE", , "ENVIRONMENT")~upper   -- (this process's: AMD64 under emulation too)
    if p == "ARM64" then return "arm64"
    return "x64"
  end
  out = .array~new
  address system "uname -m" with output using (out)
  m = out[1]~strip
  if m == "arm64" | m == "aarch64" then return "arm64"
  return "x64"

-- .NET 8 or later where the bridge looks for it (as hostfxr does: DOTNET_ROOT,
-- the global install location, the default folder); on Windows, whether the
-- newest has its desktop framework. .false (and why) if none is found.
dotnetCheck: procedure expose windows mac
  roots = .array~new
  do var over "DOTNET_ROOT_X64", "DOTNET_ROOT"
    r = value(var, , "ENVIRONMENT")
    if r \== "" then roots~append(r)
  end
  if windows then roots~append(join(value("ProgramFiles", , "ENVIRONMENT"), "dotnet"))
  else do
    do f over "/etc/dotnet/install_location_x64", "/etc/dotnet/install_location_arm64", "/etc/dotnet/install_location"
      if .File~new(f)~exists then do
        s = .Stream~new(f); line = s~lineIn~strip; s~close
        if line \== "" then roots~append(line)
      end
    end
    if mac then roots~append("/usr/local/share/dotnet")
    else roots~appendAll(.array~of("/usr/share/dotnet", "/usr/lib/dotnet", "/usr/lib64/dotnet"))
  end
  do root over roots
    core = majors(join(join(join(root, "shared"), "Microsoft.NETCore.App"), ""))
    if core~isEmpty then iterate
    newest = core~lastItem
    if newest < 8 then iterate
    say "  .NET" core~makeString("L", ", ") "in" root
    if windows then do
      desktop = majors(join(join(join(root, "shared"), "Microsoft.WindowsDesktop.App"), ""))
      if \desktop~hasItem(newest) then do
        say "  note: no .NET Desktop Runtime" newest": Windows Forms will not be available"
        say "    (install it from https://dotnet.microsoft.com/download, Windows, x64)"
      end
    end
    return .true
  end
  say "ooRexx/.NET: no .NET 8 or later found (64-bit) in" roots~makeString("L", ", ")
  if windows then say "  install the .NET Desktop Runtime, x64, from https://dotnet.microsoft.com/download"
  else say "  install the .NET Runtime from https://dotnet.microsoft.com/download (or your system's package);"
  if \windows then say "  installed elsewhere (~/.dotnet...): set DOTNET_ROOT to that folder"
  return .false

-- the major versions (sorted) of the version folders in a folder
majors: procedure
  use arg dir
  found = .array~new
  if \.File~new(dir)~isDirectory then return found
  do d over .File~new(dir)~listFiles
    parse value d~name with m "."
    if d~isDirectory, m~dataType("W"), \found~hasItem(m) then found~append(m)
  end
  return found~sortWith(.NumericComparator~new)

-- a CLR.CLS other than ours, through REXX_PATH or the PATH, or ""
otherClr: procedure expose home bin windows
  found = findFirst("CLR.CLS")
  if found == "" then return ""
  dir = .File~new(found)~parent
  if same(dir, home) | same(dir, bin) then return ""
  return found

-- the first file of that name in REXX_PATH's folders, then the PATH's, or ""
findFirst: procedure expose windows
  use arg name
  sep = .File~pathSeparator
  do var over "REXX_PATH", "PATH"
    dirs = value(var, , "ENVIRONMENT")
    do while dirs \== ""
      parse var dirs dir (sep) dirs
      dir = dir~strip~strip("B", '"')
      if dir == "" then iterate
      f = join(dir, name)
      if .File~new(f)~exists then return .File~new(f)~absolutePath
      if \windows, .File~new(join(dir, name~lower))~exists then return .File~new(join(dir, name~lower))~absolutePath
    end
  end
  return ""

-- a symbolic link at "name" to "target", replacing whatever is there
link: procedure expose done windows
  use arg target, name
  if .File~new(name)~exists | SysIsFileLink(name) = 1 then call SysFileDelete name
  address system "ln -s '"target"' '"name"'"
  if rc \= 0 then call denied name
  done~put(name, "link")
  return

-- check.rex run in a temporary folder, with REXX_PATH and the library path
-- cleared: its exit status (0 OK, 2 without Windows Forms)
check: procedure expose rexxExe checkFile windows
  temp = SysTempFileName(join(.File~temporaryPath~absolutePath, "orxnet????"))
  .File~new(temp)~makeDirs
  call SysFileCopy checkFile, join(temp, "check.rex")
  saved = .Directory~new
  do var over "REXX_PATH", "LD_LIBRARY_PATH", "DYLD_LIBRARY_PATH"
    saved[var] = value(var, , "ENVIRONMENT")
    call value var, "", "ENVIRONMENT"
  end
  here = directory()
  call directory temp
  address system quote(rexxExe) "check.rex nogui"
  outcome = rc
  call directory here
  do var over saved~allIndexes
    call value var, saved[var], "ENVIRONMENT"
  end
  call SysFileDelete join(temp, "check.rex")
  call SysRmDir temp
  return outcome

-- ooRexx's samples folder: beside rexx.exe (Windows), beside bin/ (the
-- portable builds), share/ooRexx/samples (Linux packages), else one of ours
samplesFolder: procedure expose bin home windows
  if windows then candidates = .array~of(join(bin, "samples"), join(.File~new(bin)~parent, "samples"))
  else candidates = .array~of(join(.File~new(bin)~parent, "samples"),-
                              join(join(join(.File~new(bin)~parent, "share"), "ooRexx"), "samples"))
  do c over candidates
    if .File~new(c)~isDirectory then return c
  end
  if windows then return join(bin, "samples")
  return join(home, "samples")

-- a folder (and the manifest knows it)
makeDir: procedure expose done windows
  use arg target
  if \.File~new(target)~isDirectory then do
    if \.File~new(target)~makeDirs then call denied target
  end
  done~put(target, "dir")
  return

-- copy a folder's files and subfolders, adding them to the manifest
copyTree: procedure expose done windows
  use arg source, target
  call makeDir target
  do f over .File~new(source)~listFiles
    name = join(target, f~name)
    if f~isDirectory then call copyTree f~absolutePath, name
    else do
      if SysFileCopy(f~absolutePath, name) \= 0 then call denied name
      done~put(name, "file")
    end
  end
  return

-- the manifest: lines "kind path" (kind: file, dir, link) -> a Relation
readManifest: procedure expose manifest
  done = .Relation~new
  if \.File~new(manifest)~exists then return done
  s = .Stream~new(manifest)
  do line over s~arrayIn
    parse var line kind path
    if path \== "" then done~put(path, kind)
  end
  s~close
  return done

writeManifest: procedure expose manifest windows
  use arg done
  lines = .array~new
  do kind over "file", "dir", "link"
    seen = .Set~new
    do path over done~allAt(kind)
      if seen~hasIndex(path) then iterate
      seen~put(path)
      lines~append(kind path)
    end
  end
  call SysFileDelete manifest
  s = .Stream~new(manifest)
  if s~open("write replace") \= "READY:" then call denied manifest
  s~lineOut(lines~makeString("L", "0a"x))
  s~close
  return

join: procedure                         -- dir + separator + name
  use arg dir, name
  if dir~right(1) == .File~separator then return dir || name
  return dir || .File~separator || name

same: procedure                         -- the same file or folder?
  use arg a, b
  a = .File~new(a)~absolutePath; b = .File~new(b)~absolutePath
  if .File~isCaseSensitive then return a == b
  return a~caselessEquals(b)

quote: procedure                        -- a program path for a command line
  use arg exe
  if exe~pos(" ") = 0 then return exe
  return '"'exe'"'

denied:
  use arg path
  say "ooRexx/.NET: cannot write" path
  if windows then say "  ooRexx is in a protected folder: run this from a terminal opened as administrator"
  else say "  ooRexx is in a system folder: run it as root (sudo rexx install ...)"
  exit 1

fail:
  use arg why
  say "ooRexx/.NET:" why
  exit 1

help:
  say "Usage: rexx install [install] [--clr] [--from DIR]"
  say "       rexx install uninstall"
  say "       rexx install status"
  say "       rexx oorexxnet-uninstall [status]   (once installed, from anywhere)"
  say "Installs the ooRexx/.NET bridge into the ooRexx that runs this program:"
  say "Rexx programs then find net.cls with no environment variables.  CLR.CLS"
  say "is not installed when another one (BSF4ooRexx's) is found first; --clr"
  say "installs it anyway.  --from DIR: from a build folder (build.sh's,"
  say "build.ps1's) instead of the unzipped package."
  exit 0

::class DescendingLength                -- longer paths (deeper folders) first
::method compare
  use arg a, b
  return b~length - a~length
