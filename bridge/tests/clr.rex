/* ooRexx/.NET bridge: the CLR.CLS compatibility package (rexx/CLR.CLS):
   tests. Run by tests/run.sh after bothways.rex, with TestLib's path.
   (tests/clr-samples.sh runs CLR.CLS's own portable samples.) */
parse arg testlib
.local~fails = 0; .local~count = 0
x = .net~load(testlib)

-- clr.import: a type (static members, NEW), then the System.Type's members
math = clr.import("System.Math")
call ok "clr.import: a CLR_Class",      math~isA(.CLR_Class) math~isA(.NetType), "1 1"
call ok "static members",               math~Max(3, 7), 7
call ok "the System.Type's members",    clr.import("System.String")~Name clr.import("System.String")~FullName, "String System.String"
call ok "clr.import: NEW",              clr.import("System.Text.StringBuilder")~new("ab")~ToString, "ab"
call ok "clr.import: not in .local",    .local~hasEntry("System.Math"), 0
t = .clr~clr.import("System.Math")
call ok ".clr~clr.import: in .local by the type name", .System.Math~Abs(-3), 3
t = .clr~clr.import("System.IO.Path", "MyPath")
call ok "... or by the name given",     .MyPath~GetExtension("a.txt"), ".txt"
t = clr.import("System.Environment", "Env")
call ok "clr.import with a name: in .local", .Env~NewLine == "0a"x, 1

-- .clr~new: instances
sb = .clr~new("System.Text.StringBuilder", "ab")
call ok ".clr~new: a CLR",              sb~isA(.CLR) sb~isA(.NetObject), "1 1"
call ok "instance members",             sb~Append("c")~ToString, "abc"
call ok "results: CLR proxies",         sb~Append("d")~isA(.CLR_Proxy), 1
call ok "whole numbers as Int32 (clr.wrap)", .clr~new("System.Text.StringBuilder")~Append("007")~ToString, "7"
call ok "... so ToChar(int)",           clr.import("System.Convert")~ToChar(65), "A"
call ok "other strings as net.cls",     .clr~new("System.Text.StringBuilder")~Append("x7")~ToString, "x7"
sb~Capacity = 100
call ok "a property set",               sb~Capacity, 100
call ok "static members through an instance", .clr~new("System.DateTime")~Now~Year > 2000, 1
p = .clr~new("System.Diagnostics.Process")
call ok "clr.dispatch: a static method through an instance", -
   p~clr.dispatch("GetCurrentProcess")~Id, .net~System~Environment~ProcessId
call ok "clr.dispatch: an instance method", sb~clr.dispatch("ToString"), "abcd"
call ok "clr.object, clr.type",         (sb~clr.object == sb) sb~clr.type~FullName, "1 System.Text.StringBuilder"
call ok "an enum: = caseless (CLR_Enum)", .clr~new("System.DateTime", 2026, 10, 8)~DayOfWeek = "thursday", 1
call ok ".clr~new of a wrapper type: boxed", .clr~new("System.Int16", 5)~clr.type~FullName, "System.Int16"
call ok "... and back",                 clr.unbox(.clr~new("System.Int16", 5)), 5
call ok "a CLR goes to .NET as its object", .net~typeOf(sb), "System.Text.StringBuilder"
signal on syntax name unknown1
x = sb~NoSuchMember
unknown1:
call ok "no such member: 97.1",         condition("O")~code, "97.1"
signal off syntax

-- the routines
call ok "clr.box",                      .net~typeOf(clr.box("INT16", 5)) clr.box("ST", "x")~isA(.CLR), "System.Int16 1"
call ok "clr.box(type, .nil)",          clr.box("ST", .nil) == .nil, 1
call ok "clr.unbox",                    clr.unbox(clr.box("DOuble", 1.5)) clr.unbox("plain"), "1.5 plain"
call ok "clr.wrap: Int32, Int64, Decimal, String", -
   .net~typeOf(clr.wrap(5)) .net~typeOf(clr.wrap(5000000000)) .net~typeOf(clr.wrap(1.5)) .net~typeOf(clr.wrap("x")), -
   "System.Int32 System.Int64 System.Decimal System.String"
call ok "clr.wrap: a CLR as itself",    clr.wrap(sb) == sb, 1
a = clr.createArray("System.Byte", 4)
call ok "clr.createArray",              a~isA(.NetArray) a~items .net~typeOf(a), "1 4 System.Byte[]"
call clr.addAssembly "System.Xml"
call ok "clr.addAssembly",              clr.import("System.Xml.XmlDocument")~Name, "XmlDocument"
call ok "pp (BSF.CLS)",                 pp("x"), "[x]"

-- events: clr.createEventHandler, +=, the target's INVOKE with a slotDir
h = .Handler~new
b = .clr~new("RexxNetTests.Button")
b~Click += clr.createEventHandler(h, "my data")
b~PerformClick
call ok "an event handler: invoke(sender, e, slotDir)", h~seen, "RexxNetTests.Button System.EventArgs my data"

-- CLRThread
.local~threadRan = ""
.Runner~new~start("payload")
do 100 while .threadRan == ""; call SysSleep 0.05; end
call ok "CLRThread: run on its own thread", .threadRan, "payload 1"

-- CLRLogger
.CLRLogger~logLevel = "DEBUG"
call ok "CLRLogger",                    .CLRLogger~logLevel .CLRLogger~doLogging, "DEBUG 1"
.CLRLogger~logLevel = "OFF"
call ok "CLRLogger off",                .CLRLogger~doLogging, 0

if .fails = 0 then say "CLR.CLS compatibility: all" .count "tests passed"
else say "CLR.CLS compatibility:" .fails "of" .count "tests FAILED"
exit .fails > 0

::requires "CLR.CLS"

::routine ok
  use arg name, got, want
  .local~count += 1
  if got == want then return
  .local~fails += 1
  say "FAIL" name": got ["got"], want ["want"]"

::class Handler
::attribute seen
::method invoke
  expose seen
  use arg sender, e, slotDir
  seen = .net~typeOf(sender) .net~typeOf(e) slotDir~userData

::class Runner subclass CLRThread
::method run
  use arg slotDir
  .local~threadRan = slotDir~userData (.net~System~Threading~Thread~CurrentThread~ManagedThreadId > 0)
