/* ooRexx/.NET bridge, phase 1 (core): tests. Run by tests/run.sh, which
   builds the bridge and TestLib.dll and passes TestLib's path. */
parse arg testlib
.local~fails = 0; .local~count = 0

-- namespaces and types
call ok "namespace",            .net~System~makeString, "a NetNamespace (System)"
call ok "type",                 .net~System~Math~makeString, "a NetType (System.Math)"
call ok "caseless names",       .net~system~MATH~max(1, 2), 2
call ok ".net~type alias",      .net~type("int")~makeString, "a NetType (System.Int32)"
call ok ".net~type generic",    .net~type("System.Collections.Generic.Dictionary<string, int>")~makeString, -
                                "a NetType (System.Collections.Generic.Dictionary<System.String, System.Int32>)"
call ok ".net~type open + args", .net~type(.net~System~Collections~Generic~List, "string")~makeString, -
                                "a NetType (System.Collections.Generic.List<System.String>)"
call ok ".net~namespace",       .net~namespace("system.io")~makeString, "a NetNamespace (System.IO)"
call ok "lazy assembly",        .net~System~Text~RegularExpressions~Regex~IsMatch("abc", "b+"), 1

-- static members
call ok "static method",        .net~System~Math~Max(3, 7), 7
call ok "overload by value",    .net~System~Math~Max(3, 7.5), 7.5
call ok "static field (const)", .net~System~Math~PI~left(7), "3.14159"
call ok "static property",      .net~System~Environment~NewLine == .endOfLine, 1
-- a Rexx thread in .NET: a single-threaded apartment on Windows (GUI, common dialogs)
apartment = .net~System~Threading~Thread~CurrentThread~GetApartmentState
started = .ApartmentProbe~new~start("get")~result
if .rexxInfo~platform~upper~abbrev("WIN") then do
  call ok "the thread's apartment (Windows: STA)", apartment, "STA"
  call ok "... a thread made by START too", started, "STA"     -- (it read as MTA, the implicit MTA)
end
else do
  call ok "the thread's apartment (not Windows: Unknown)", apartment, "Unknown"
  call ok "... a thread made by START too", started, "Unknown"
end

-- instances, properties, identity
sb = .net~System~Text~StringBuilder~new
call ok "new + display",        sb~makeString~word(3) sb~makeString~word(1), "(System.Text.StringBuilder a"
call ok "say shows makeString", "" || sb == sb~makeString, 1
call ok "System.String type",   .net~System~String~makeString, "a NetType (System.String)"
call ok "string w/o member",    sb~string == sb~makeString, 1
r = sb~Append("a")~Append(42)
call ok "fluent, identity ==",  r == sb, 1
call ok "method no args",       sb~ToString, "a42"
call ok "property get",         sb~Length, 3
sb~Length = 1
call ok "property set",         sb~ToString, "a"
call ok "\== on other",         sb \== .net~System~Text~StringBuilder~new, 1
call ok "== .nil",              sb == .nil, 0
call ok "new with args",        .net~System~Text~StringBuilder~new("xyz", 100)~Capacity, 100
call ok "new String is a string", .net~System~String~new("x", 3), "xxx"
call ok "string to char[]",     .net~System~String~new("abc", 1, 2), "bc"
call ok ".net~new",             .net~new(.net~System~Text~StringBuilder, "q")~ToString, "q"

-- values .NET -> Rexx
call ok "bool",                 .net~System~String~IsNullOrEmpty(""), 1
call ok "enum as name",         .net~System~DateTime~new(2026, 10, 8)~DayOfWeek, "Thursday"
call ok "char",                 .net~System~Char~ToUpper("x"), "X"
call ok "double round-trip",    .net~System~Math~Sqrt(2), "1.4142135623730951"
call ok "null is .nil",         .net~System~Environment~GetEnvironmentVariable("NO_SUCH_VAR_XYZ") == .nil, 1

-- values Rexx -> .NET, overloads
x = .net~load(testlib)
p = .net~RexxNetTests~Probe
call ok "load + test type",     p~makeString, "a NetType (RexxNetTests.Probe)"
call ok "string stays string",  p~Kind("007"), "System.String"
call ok "007 to int",           .net~System~Int32~Parse("007"), 7
call ok "string param wins",    p~Num("3"), "string"
call ok "int before long",      p~NumOnly(3), "int"
call ok "long when too big",    p~NumOnly(3000000000), "long"
call ok "double for decimals",  p~NumOnly(3.5), "double"
call ok "Rexx exponent to int", p~NumOnly("1E3"), "int"
call ok "byte in range",        p~Small(255), "byte 255"
call err "byte out of range",   "x = .net~RexxNetTests~Probe~Small(256)", "no RexxNetTests.Probe.Small accepts"
call ok "bool from 1",          p~Flag(1), "yes"
call ok "bool from false",      p~Flag("false"), "no"
call ok "char from string",     p~Ch("z"), "char z"
call ok "enum from name",       p~Day("monday"), "Monday"
call ok "enum from number",     p~Day(2), "Tuesday"
call ok ".nil to null",         p~Kind(.nil), "null"
call ok "optional parameter",   p~Opt(1), "1,5"
call ok "params expanded",      p~Sum(1, 2, 3), 6
call ok "params empty",         p~Sum, 0
call ok "Array to int[]",       p~Arr(.array~of(1, 2, 3)), 6
call ok "Array to IEnumerable", p~Join(.array~of("a", "b")), "a+b"
call ok "Array to object",      p~Kind(.array~of(1)), "System.Object[]"
call ok "forced int16",         p~Kind(.net~int16(5)), "System.Int16"
call ok "forced decimal",       p~Kind(.net~decimal("1.5")), "System.Decimal"
call ok "forced bool",          p~Kind(.net~bool(1)), "System.Boolean"
call ok ".net~string(x)",       p~Kind(.net~string(5)), "System.String"
call ok ".net~as type",         p~Kind(.net~as(7, .net~System~Byte)), "System.Byte"
call ok ".net~as name",         p~Kind(.net~as(7, "long")), "System.Int64"
call ok ".net~null",            p~Kind(.net~null), "null"
call ok "forced settles tie",   p~Ambig(.net~int64(1), 2), "long,int"
call ok "no empty params array wins (WriteLine(string))", p~Tie("a") p~Tie("a", 1), "plain params 1"
call ok "no default filled in wins", p~Tie2("a") p~Tie2("a", 2), "plain default"
call ok "a type in an assembly named as it (System.Console)", .net~type("System.Console")~makeString, "a NetType (System.Console)"
call ok "a name resolves once: the same object", (.net~System~Math~identityHash = .net~System~Math~identityHash) -
   (.net~type("System.Math")~identityHash = .net~type("system.math")~identityHash), "1 1"
call err "a name not found is not remembered", "x = .net~NoSuchNamespaceYet", "no .NET namespace"
call err "... (asked again, the same answer)", "x = .net~NoSuchNamespaceYet", "no .NET namespace"
call ok "a namespace no assembly is named after (System.Timers)", .net~System~Timers~Timer~makeString, "a NetType (System.Timers.Timer)"
call ok "... and its types by name", .net~type("System.Timers.ElapsedEventArgs")~makeString, "a NetType (System.Timers.ElapsedEventArgs)"
call ok ".net~type(a System.Type object)", .net~type(.net~typeObject(.net~System~Text~StringBuilder~new))~makeString, -
   "a NetType (System.Text.StringBuilder)"
-- box / unbox: a .NET object holding the value (CLR.CLS's names too)
bx = .net~box("short", 5)
call ok "box: a .NetObject",    bx~isA(.NetObject) .net~typeOf(bx), "1 System.Int16"
call ok "box goes as itself",   p~Kind(bx), "System.Int16"
call ok "box, settles tie",     p~Ambig(.net~box("long", 1), 2), "long,int"
call ok "unbox",                .net~unbox(bx), 5
call ok "unbox a Rexx string",  .net~unbox("abc"), "abc"
sbx = .net~System~Text~StringBuilder~new
call ok "unbox another object", .net~unbox(sbx) == sbx, 1
call ok "box: a .NetType",      .net~typeOf(.net~box(.net~System~Byte, 7)), "System.Byte"
call ok "box: a full name",     .net~typeOf(.net~box("System.UInt32", 7)), "System.UInt32"
call ok "box: STring",          .net~typeOf(.net~box("STring", 7)), "System.String"
call ok "box: CLR.CLS indicators", -
   .net~typeOf(.net~box("BO", 1)) .net~typeOf(.net~box("SI", 1.5)) .net~typeOf(.net~box("SB", -1)) -
   .net~typeOf(.net~box("de", 2.5)) .net~typeOf(.net~box("UINT64", 1)) .net~typeOf(.net~box("CHAR", "x")), -
   "System.Boolean System.Single System.SByte System.Decimal System.UInt64 System.Char"
call ok "box: long names, shortened", -
   .net~typeOf(.net~box("Character", "x")) .net~typeOf(.net~box("bool", 0)) .net~typeOf(.net~box("Doub", 1)), -
   "System.Char System.Boolean System.Double"
call ok "box: an enum",         .net~unbox(.net~box(.net~System~DayOfWeek, "Monday")), "Monday"
call ok "box: .nil as string",  .net~box("string", .nil) == .nil, 1
call err "box: too short",      "x = .net~box('S', 1)", 'no .NET type "S"'
call err "box: out of range",   "x = .net~box('byte', 300)", "cannot be a System.Byte"
call err "ambiguous overload",  "x = .net~RexxNetTests~Probe~Ambig(1, 2)", "is ambiguous"
call ok "object passed back",   p~Same(sb, sb), "same"
call ok "static field set/get", p~Counter, 0
p~Counter = 5
call ok "static field set",     p~Counter, 5
call ok "constant",             p~Answer, 42
call ok "null return",          p~Nothing == .nil, 1
drop result
p~Void
call ok "void: no result",      var("RESULT"), 0

-- names
c = .net~RexxNetTests~Case~new
call ok "uppercase wins tie",   c~value, 1
call ok "exact get",            .net~get(c, "value"), 2
.net~set(c, "value", 9)
call ok "exact set",            .net~get(c, "value"), 9
call ok "exact invoke",         .net~invoke(sb, "ToString"), "a"
call err "exact is exact",      ".net~invoke(.local~sb0, 'tostring')", 'does not understand message "tostring"'
call err "read-only property",  ".net~RexxNetTests~Case~new~Fixed = 3", "cannot be set"
call ok "hidden by new",        .net~RexxNetTests~Derived~new~Who, "derived"
call err "unknown member",      "x = .net~System~Math~NoSuchThing", 'does not understand message "NOSUCHTHING"'

-- an unknown member: 97.1, as any Rexx object; additional: [1] receiver, [2] name, [3] the .NET exception
signal on syntax name unknown1
x = sb~NoSuchThing(1)
unknown1:
c = condition("O")
call ok "97.1",                 c~code, "97.1"
call ok "97.1: [1] the receiver", c~additional[1] == sb, 1
call ok "97.1: [2] the message", c~additional[2], "NOSUCHTHING"
call ok "97.1: [3] the exception", .net~typeOf(c~additional[3]), "System.MissingMemberException"
call ok "97.1: its message",    c~additional[3]~Message, 'System.Text.StringBuilder has no public instance member "NOSUCHTHING"'
signal on syntax name unknown2
sb~NoSuchThing = 1
unknown2:
call ok "97.1 setting: NAME=",  condition("O")~additional[2], "NOSUCHTHING="
signal on syntax name unknown3
x = .net~get(sb, "nope")
unknown3:
call ok "97.1 from .net~get: the receiver", (condition("O")~additional[1] == sb) condition("O")~additional[2], "1 nope"
signal off syntax

-- a Rexx subclass of .NetObject: its UNKNOWN (and its methods) first
l = .LoudSB~new(.net~System~Text~StringBuilder~new("abc"))
call ok "subclass: its own UNKNOWN", l~Shout, "ABC"
call ok "subclass: forward to .NET", l~Length, 3
call ok "subclass: its method wins", l~Capacity, "mine"
l~Append("d")
call ok "subclass: the same object", l~ToString, "abcd"
call ok "subclass: makeString",  l~makeString~word(2), "LOUDSB"
call ok "subclass: goes to .NET as itself", p~Kind(l), "System.Text.StringBuilder"
l2 = .LoudSB~new(sb)
call ok "subclass: == the proxy", l2 == sb, 1
signal on syntax name unknown4
x = l~Nope
unknown4:
call ok "subclass: nothing handles it, 97.1", condition("O")~code condition("O")~additional[2], "97.1 NOPE"
signal off syntax
call err "subclass: one argument", "x = .LoudSB~new(.local~sb0, 1)", "Too many arguments"

-- structs
pt = p~MakePt(1, 2)
call ok "struct by value",      pt~X pt~Y pt~ToString, "1 2 (1, 2)"

-- Rexx Object methods vs .NET members
m = .net~RexxNetTests~Machine~new
m~Start
call ok "START goes to .NET",   m~Started, 1
call ok "SEND goes to .NET",    m~Send("x"), "sent x"
call ok "COPY goes to .NET",    m~Copy, "copied"
msg = sb~start("ToString")
call ok "START without member: Rexx's", msg~result, "a"
call ok "Stopwatch~StartNew",   .net~System~Diagnostics~Stopwatch~StartNew~IsRunning, 1

-- exceptions
signal on syntax name parseError
x = .net~System~Int32~Parse("abc")
call ok "exception raised", 0, 1
parseError:
  c = condition("O")
  call ok "exception: code",      c~code, "98.900"
  call ok "exception: message",   c~message, ".NET error: System.FormatException: The input string 'abc' was not in a correct format."
  call ok "exception: object",    c~additional[2]~GetType~FullName, "System.FormatException"
signal on syntax name throwError
p~Throw
throwError:
  call ok "exception from test",  condition("O")~message, ".NET error: System.InvalidOperationException: boom."
signal off syntax
call err "bridge error, no object", "x = .net~System~NoSuchType", "no .NET namespace or type"
call err "open generic new",    "x = .net~System~Collections~Generic~List~new", "open generic"

-- introspection
call ok ".net~typeOf",          .net~typeOf(sb), "System.Text.StringBuilder"
call ok ".net~typeObject",      .net~typeObject(sb)~Name, "StringBuilder"
call ok ".net~isInstance",      .net~isInstance(sb, .net~System~Object) .net~isInstance(sb, "string"), "1 0"
call ok ".net~members",         .net~members(sb)~hasItem("Append"), 1

-- handles are released by UNINIT
before = .net~handleCount
do i = 1 to 50000; t = .net~System~Text~StringBuilder~new; end
drop t
call ok "handles released",     .net~handleCount < 25000, 1

say
if .fails = 0 then say "phase 1: all" .count "tests passed"
else say "phase 1:" .fails "of" .count "tests FAILED"
exit .fails > 0

::requires "net.cls"

::routine ok
  use arg name, got, want
  .local~count += 1
  if got == want then return
  .local~fails += 1
  say "FAIL" name": got ["got"], want ["want"]"

::routine err                     -- the code must raise an error whose message contains fragment
  use arg name, code, fragment
  .local~count += 1
  .local~sb0 = .net~System~Text~StringBuilder~new("a")
  signal on syntax
  interpret code
  .local~fails += 1
  say "FAIL" name": no error"
  return
syntax:
  msg = condition("O")~message
  if msg~pos(fragment) > 0 then return
  .local~fails += 1
  say "FAIL" name": message ["msg"], want ["fragment"]"

::class LoudSB subclass NetObject    -- a Rexx subclass of a .NET proxy (tests)
::method unknown
  use arg name, args
  if name = "SHOUT" then return self~ToString~upper
  forward class (super)
::method capacity
  return "mine"

::class ApartmentProbe
::method get
  return .net~System~Threading~Thread~CurrentThread~GetApartmentState~string
