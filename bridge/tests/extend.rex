/* ooRexx/.NET bridge: Rexx classes extending .NET classes (.net~extend).
   Run by tests/run.sh with TestLib's path. */
parse arg testlib
.local~fails = 0; .local~count = 0
x = .net~load(testlib)
probe = .net~RexxNetTests~ExtendProbe

-- a .NET class of our own: abstract, a virtual call in its constructor
t = .net~extend(.Square, "RexxNetTests.Shape")
call ok "extend gives a .NetType",   t~isA(.NetType), 1
call ok "its name",                  t~makeString, "a NetType (SQUARE extending RexxNetTests.Shape)"
s = .Square~new(3)
call ok "the Rexx class",            s~class~id, "SQUARE"
call ok "is the .NET type",          .net~isInstance(s, "RexxNetTests.Shape"), 1
call ok "abstract member from .NET", s~Area, 9
call ok "virtual call in the base constructor", s~Created, "<square: 9>"
call ok "override from .NET",        s~Report, "<square: 9>"
call ok "base.Describe",             s~plain, "square: 9"
call ok "public members",            s~Name, "square"
call ok "a list of them, from .NET", probe~TotalArea(.array~of(s, .Square~new(2))), 13
call ok "back from .NET: itself",    probe~Same(s) == s, 1
call ok "back from .NET: its class", probe~Same(s)~class~id, "SQUARE"
call ok "from another thread",       probe~OnAnotherThread(s), "<square: 9>"
call ok "protected virtual property", s~SidesSeen, 4
call ok "protected virtual method",  s~Greet("you"), "HELLO YOU (was hello you)"

-- protected members: from the object's own methods only
call ok "protected field",           s~field, 42
call ok "protected field set",       s~setField(7), 7
call ok "protected static field",    s~kindOf, "shape"
call ok "protected method (overloads)", s~hiddenBoth, "hidden square hidden 5"
call ok "protected property",        s~relabel("big"), "none big"
call ok "public member through self", s~selfName, "square"
call err "protected from outside",   ".Square~new(1)~secret", "does not understand message ""SECRET"""
call err "protected method from outside", ".Square~new(1)~Hidden", "does not understand message ""HIDDEN"""
call err "readonly protected field: no set", ".Square~new(1)~setFixed", "does not understand message ""FIXEDNAME="""

-- errors in overrides, and what overrides return
.local~failing = .Bad~new
.failing~arm
call err "a Rexx error in an override", ".failing~Report", "Fails on purpose"
call ok "seen by .NET as an exception", probe~Fail(.failing), "RexxException"
.net~extend(.Wrong, "RexxNetTests.Shape")
call err "a wrong result",           "x = .Wrong~new", "must return a System.Double"

-- an abstract member left out: the constructor's virtual call fails
.net~extend(.Lazy, "RexxNetTests.Shape")
call err "abstract member not defined", "x = .Lazy~new", "LAZY does not define AREA"

-- a subclass of a Rexx class that extends: its methods win, the same .NET type
s2 = .Square2~new(2)
call ok "Rexx subclass, inherited extension", s2~Report, "[square: 4]"
call ok "Rexx subclass's .NET type", .net~typeOf(s2), "SQUARE extending RexxNetTests.Shape"

-- interfaces (with an inherited one), properties included
.net~extend(.Counter, "RexxNetTests.ICounter")
c = .Counter~new
call ok "interface property get/set and method", probe~UseValue(c), "v=10 10"
call ok "inherited interface",       probe~Count(c), "11 12 12"
call ok "interface from Rexx",       c~Value, 12

-- framework classes: Collection<T> (protected virtual + base.), TextWriter
-- (abstract, protected field), IComparer<T> (List.Sort)
.net~extend(.Upper, "System.Collections.ObjectModel.Collection<System.String>")
u = .Upper~new
u~Add("hello"); u~Insert(0, "World")
call ok "Collection<T>.InsertItem",  u[0] u[1] u~Count u~inserts, "WORLD HELLO 2 2"
.net~extend(.Shout, "System.IO.TextWriter")
w = .Shout~new
w~Write("abc"); w~Write(12)
call ok "TextWriter.Write(char)",    w~text, "ABC12"
call ok "TextWriter's protected CoreNewLine", w~newlineChars, "0A"
l = .net~type("System.Collections.Generic.List<System.String>")~new
do x over "ccc a bb dddd"~makeArray(" "); l~Add(x); end
l~Sort(.ByLength~new)
call ok "IComparer<T> in List.Sort", l~ToArray~makeString("L", " "), "a bb ccc dddd"

-- .net~detach: no more calls into Rexx; virtual members are the base's again
d = .Square~new(5)
.net~detach(d)
call ok "detached: base Describe",   probe~Fail(d), "NotImplementedException"
call ok "detached: back from .NET is a plain proxy", probe~Same(d)~class~id, "NETOBJECT"
call ok "detached: the same object", probe~Same(d) == d, 1
.net~detach(d)                       -- twice: nothing

-- errors of .net~extend
call err "not a NetObject subclass", ".net~extend(.Plain, 'RexxNetTests.Shape')", "must be a subclass of NetObject"
call err "twice",                    ".net~extend(.Square, 'RexxNetTests.Shape')", "already extends"
call err "sealed",                   ".net~extend(.Other, 'System.String')", "cannot be extended"
call err "a class after the first",  ".net~extend(.Other, 'RexxNetTests.Shape', 'System.Object')", "is not an interface"
call err "already implemented",      ".net~extend(.Other, 'System.Collections.Generic.List<int>', 'System.Collections.IList')", "already implements"
call err "no type",                  ".net~extend(.Other)", "Missing argument"
call err ".net~new on it",           ".net~new(.net~extendedType(.Square))", "create it with the Rexx class's NEW"

-- Windows: a Form whose protected virtual OnLoad, OnPaint, OnShown are Rexx methods
if .rexxInfo~platform~upper~abbrev("WIN") then call windowsForm

if .fails = 0 then say "extend: all" .count "tests passed"
else say "extend:" .fails "of" .count "tests FAILED"
exit .fails > 0

windowsForm: procedure
  .net~extend(.Window, "System.Windows.Forms.Form")
  f = .Window~new("extended")
  .net~System~Windows~Forms~Application~Run(f)     -- OnShown paints it, then closes it
  call ok "Windows Forms: OnLoad, OnPaint, OnShown", f~seen, "load paint shown"
  call ok "Windows Forms: a protected property set", f~buffered, 1
  call ok "Windows Forms: its Text, in OnLoad", f~title, "extended"
  return

::requires "net.cls"

::class Square subclass NetObject
::method init
  expose side
  use strict arg side
  self~init:super("square")            -- after side is set: the base constructor calls Area
::method Area
  expose side
  return side * side
::method Describe
  return "<" || self~base.Describe || ">"
::method plain;    return self~base.Describe
::method Sides;    return 4
::method Hello
  use arg who
  return "HELLO" who~upper "(was" self~base.Hello(who)")"
::method field;    return self~secret
::method setField
  use arg n
  self~secret = n
  return self~secret
::method setFixed; self~fixedName = "x"
::method kindOf;   return self~Kind
::method hiddenBoth; return self~Hidden self~Hidden(5)
::method relabel
  use arg new
  old = self~Label
  self~Label = new
  return old self~Label
::method selfName; return self~Name

::class Square2 subclass Square
::method Describe
  return "[" || self~base.Describe || "]"

::class Bad subclass Square
::method init;     self~init:super(1)
::method arm;      expose armed; armed = 1
::method Describe
  expose armed
  if var("ARMED") then raise syntax 98.900 array("Fails on purpose")
  return self~base.Describe

::class Wrong subclass NetObject
::method Area;     return "abc"

::class Lazy subclass NetObject

::class Counter subclass NetObject
::method init
  expose value
  value = 0
  self~init:super
::method Value;    expose value; return value
::method "VALUE="; expose value; use arg value
::method Describe; expose value; use arg prefix; return prefix || value
::method Next;     expose value; value += 1; return value

::class Upper subclass NetObject
::method inserts unguarded
  expose n
  return n
::method InsertItem
  expose n
  use arg index, item
  if \var("N") then n = 0
  n += 1
  self~base.InsertItem(index, item~upper)

::class Shout subclass NetObject
::method init
  expose text
  text = ""
  self~init:super
  self~CoreNewLine = .net~type("System.Char[]")~new(1)   -- protected field
  self~CoreNewLine[1] = "0a"x
::method text;     expose text; return text
::method newlineChars; return self~CoreNewLine~makeString("L", "")~c2x
::method Encoding; return .net~System~Text~Encoding~UTF8
::method Write
  expose text
  use arg ch
  text ||= ch~upper

::class ByLength subclass NetObject
::method activate class               -- the usual place: when the class is created
  .net~extend(self, .net~type("System.Collections.Generic.IComparer<System.String>"))
::method Compare
  use arg a, b
  return sign(a~length - b~length)

::class Window subclass NetObject           -- (Windows)
::method init
  expose seen
  use strict arg title
  seen = ""
  self~init:super
  self~Text = title
  self~DoubleBuffered = .true                     -- protected
::method seen;     expose seen; return seen~strip
::method title;    expose title; return title
::method buffered; return self~DoubleBuffered
::method OnLoad
  expose seen title
  use arg e
  seen = seen "load"
  title = self~Text
  self~base.OnLoad(e)
::method OnPaint
  expose seen
  use arg e
  if seen~wordPos("paint") = 0 then seen = seen "paint"
  e~Graphics~DrawString(self~Text, self~Font, .net~System~Drawing~Brushes~Black, 10, 10)
  self~base.OnPaint(e)
::method OnShown
  expose seen
  use arg e
  self~base.OnShown(e)
  self~Refresh                                    -- paints now
  seen = seen "shown"
  self~Close

::class Plain
::class Other subclass NetObject

::routine ok
  use arg name, got, want
  .local~count += 1
  if got == want then return
  .local~fails += 1
  say "FAIL" name": got ["got"], want ["want"]"

::routine err                     -- the code must raise an error whose message contains fragment
  use arg name, code, fragment
  .local~count += 1
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
