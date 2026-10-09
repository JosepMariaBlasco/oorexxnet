/* ooRexx/.NET bridge: COM objects through IDispatch (managed/Com.cs):
   tests, on Windows (elsewhere they are skipped). Run by tests/run.ps1, with
   COM servers every Windows has: Scripting.Dictionary,
   Scripting.FileSystemObject, WScript.Shell. */
.local~fails = 0; .local~count = 0
if \.rexxInfo~platform~upper~abbrev("WIN") then do
  say "COM objects: skipped (Windows only)"
  exit 0
end

-- creation, methods, properties, results
d = .net~createObject("Scripting.Dictionary")
call ok "createObject: a .NetObject",      d~isA(.NetObject), 1
d~Add("a", 1)
d~Add("b", "two")
call ok "a method; a property read",       d~Count, 2
call ok "a method with an argument",       d~Item("b"), "two"
call ok "names are caseless",              d~ITEM("b") d~item("b"), "two two"
call ok "a Boolean result",                d~Exists("a") d~Exists("zz"), "1 0"
call ok "Rexx numbers go as numbers",      d~Item("a") + 1, 2
d~Add("z", .net~box("string", "007"))
call ok "... and a boxed string as a string", d~Item("z"), "007"
d~Add("n", "007")
call ok "... unboxed, 007 is a number",    d~Item("n"), 7
keys = d~Keys
call ok "an array result: a Rexx Array",   keys~items keys[1], "4 a"

-- the default member: o[i], o[i] = v
call ok "o[key]: the default member",      d["b"], "two"
d["c"] = 3
call ok "o[key] = v",                      d~Count d["c"], "4 3"
d~CompareMode = 1
call ok "a property set",                  d~CompareMode, 1

-- another server; COM objects returned by COM objects; enumeration
fso = .net~createObject("Scripting.FileSystemObject")
temp = fso~GetSpecialFolder(2)                            -- TemporaryFolder: a COM object
call ok "a COM object from a COM object",  temp~isA(.NetObject) fso~FolderExists(temp~Path), "1 1"
file = temp~Path || "\" || fso~GetTempName
ts = fso~OpenTextFile(file, , .true)                       -- iomode omitted (optional), create
ts~Close
call ok "an omitted argument (optional)",  fso~FileExists(file), 1
ts = fso~OpenTextFile(file, 8)                            -- ForAppending
ts~WriteLine("hello")
ts~Close
call ok "a file written through COM",      fso~OpenTextFile(file)~ReadAll~strip("T", "0a"x)~strip("T", "0d"x), "hello"
fso~DeleteFile(file)
call ok "... and deleted",                 fso~FileExists(file), 0
n = 0
do drive over fso~Drives
  n += 1
end
call ok "DO OVER a COM collection",        n > 0 & n = fso~Drives~Count, 1

-- errors
signal on syntax name unknown
x = fso~NoSuchMember
call ok "an unknown member", "no error", "97.1"
unknown:
call ok "an unknown member: 97.1",         condition("O")~code, "97.1"
signal on syntax name failing
x = fso~GetFile("Z:\no\such\file.txt")
call ok "a failing call", "no error", "98.900"
failing:
call ok "a failing call: 98.900",          condition("O")~code, "98.900"
signal off syntax

sh = .net~createObject("WScript.Shell")
call ok "WScript.Shell",                   sh~ExpandEnvironmentStrings("%SystemRoot%")~upper~pos("WINDOWS") > 0, 1
.net~releaseObject(sh)
signal on syntax name released
x = sh~ExpandEnvironmentStrings("%SystemRoot%")
call ok "a released object", "usable", "98.900"
released:
call ok "releaseObject: unusable after",   condition("O")~code, "98.900"
signal on syntax name noClass
x = .net~createObject("No.Such.ProgID")
noClass:
call ok "an unknown ProgID: 98.900",       condition("O")~code, "98.900"

if .fails = 0 then say "COM objects: all" .count "tests passed"
else say "COM objects:" .fails "of" .count "tests FAILED"
exit .fails > 0

::requires "net.cls"

::routine ok
  use arg name, got, want
  .local~count += 1
  if got == want then return
  .local~fails += 1
  say "FAIL" name": got ["got"], want ["want"]"
