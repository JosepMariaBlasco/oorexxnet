/* check-samples.rex: runs every sample and reports which end with an error.

       rexx samples/check-samples.rex [build-dir]

   The samples in samples/rexx run on every platform; those in
   samples/windows only on Windows. Each runs with the argument "auto", which
   makes the interactive ones (windows, dialogs) finish by themselves; a
   sample passes when its exit status is 0. The output is shown. build-dir:
   the bridge's build, as for docs/check-guide.rex. Linux, macOS and Windows. */

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

/* As in check-guide.rex: net.cls through REXX_PATH; rexxnet through the PATH
   on Windows, the library path (inside the command: macOS drops DYLD_*
   variables when it starts /bin/sh) elsewhere */
call env "REXX_PATH", out
pathSep = .file~pathSeparator
if windows then do
  call env "PATH", out || pathSep || env("PATH")
  libvar = ""
end
else if mac then libvar = "DYLD_LIBRARY_PATH='"out"' "
else libvar = "LD_LIBRARY_PATH='"out"' "

dirs = .array~of("rexx")
if windows then dirs~append("windows")
count = 0; fails = 0
do d over dirs
  files = .array~new
  call sysFileTree here || d || sep || "*.rex", "found.", "FO"
  do i = 1 to found.0; files~append(found.i); end
  do f over files~sort
    count += 1
    name = d"/"filespec("name", f)
    say "=====" name
    address system libvar'rexx "'f'" auto'
    if rc \= 0 then do
      fails += 1
      say "FAIL" name "(exit status" rc")"
    end
    else say "ok  " name
  end
end
if fails = 0 then say "samples: all" count "ran"
else say "samples:" fails "of" count "FAILED"
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
