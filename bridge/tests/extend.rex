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

-- self~Name:super: the base's implementation, or its protected member, as in any Rexx class
.net~extend(.SquareS, "RexxNetTests.Shape")
ss = .SquareS~new(3)
call ok ":super, public virtual (from .NET)", ss~Report, "<squareS: 9>"
call ok ":super, in the base constructor's call", ss~Created, "<squareS: 9>"
call ok ":super, protected virtual method",  ss~Greet("you"), "HELLO hello you"
call ok ":super, protected virtual property", ss~SidesSeen, 4
call ok ":super, protected member hidden by a Rexx method", ss~Hidden, "mine, hidden squareS"
call ok ":super, protected property hidden", ss~Label, "label: none"
call ok ":super, a protected setter",         ss~relabel("big"), "label: big"
call err ":super's methods are private",      ".SquareS~new(1)~secret", "does not understand message ""SECRET"""

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

-- an interface's event: raised by the object (self~raise.Name), heard by .NET and by Rexx
.net~extend(.Person, "System.ComponentModel.INotifyPropertyChanged")
person = .Person~new
person~Name = "nobody hears"                 -- no handlers yet: nothing happens
seen = probe~Watch(person)                    -- a .NET handler: a List<string>
person~Name = "Rony"; person~Age = 60
call ok "interface event, a .NET handler", seen~ToArray~makeString("L", " "), "Name Age"
listener = .Listener~new
h = .net~handler(listener, "CHANGED")
person~PropertyChanged += h                   -- a public event of the new type
person~Name = "Rick"
call ok "interface event, a Rexx handler too", listener~heard seen~Count, "Name(1) 3"
person~PropertyChanged -= h
person~Name = "Erich"
call ok "-= removes the Rexx handler",      listener~heard seen~Count, "Name(1) 4"
call err "raise.Name from outside",          ".Person~new~raise.PropertyChanged(.nil, .nil)", 'does not understand message "RAISE.PROPERTYCHANGED"'

-- parameters by reference (ref / out): a Rexx.Net.ComRef, whose Value goes back
.net~extend(.Finder, "RexxNetTests.IFinder")
f = .Finder~new
call ok "out parameter",                    probe~Find(f, "seven") "/" probe~Find(f, "eight"), "found 7 / none 0"
call ok "ref parameter",                    probe~Twice(f, 21), 42
.net~extend(.Parser2, "RexxNetTests.Parser")
call ok "out, and base. with a .NetRef",    probe~Parse(.Parser2~new, "12") "/" probe~Parse(.Parser2~new, "twelve"), "True 12 / True 12"

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

-- generic methods: their type arguments after the arguments, as NetTypes
.net~extend(.MyFactory, "RexxNetTests.Factory")
f = .MyFactory~new
call ok "generic abstract, result T",       probe~UseFactory(f), "42 [s:String] 2026 0"
call ok "generic virtual, base. given",     probe~Pair(f), "2,1 b,a"
call ok "generic constrained",              probe~Show(f), "Double: base 1.5 / Int32: base 7"
call ok "generic protected, base. inferred", probe~First(f), "4 q 5"
call ok "generic out parameter",            probe~TryGet(f), "7 -"
.net~extend(.Conv, "RexxNetTests.IConverter")
call ok "generic interface method, two type parameters", probe~Convert(.Conv~new), "System.Int32>System.String:5 7"

-- a framework class's generic method: ExpressionVisitor.VisitLambda<T>(Expression<T>), protected
.net~extend(.Lambdas, "System.Linq.Expressions.ExpressionVisitor")
v = .Lambdas~new
E = .net~System~Linq~Expressions~Expression
lam = E~Lambda(E~Constant(.net~int32(42)))
r = v~Visit(lam)
call ok "ExpressionVisitor.VisitLambda<T>", v~seen (r == lam) r~Compile~DynamicInvoke, "System.Func<System.Int32> 1 42"

-- (the lifetime of the instances, released by the two collectors: tests/lifetime.rex)

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

::class SquareS subclass NetObject   -- the same, with :super instead of base.
::method init
  expose side
  use strict arg side
  self~init:super("squareS")
::method Area
  expose side
  return side * side
::method Describe; return "<" || self~Describe:super || ">"
::method Hello
  use arg who
  return "HELLO" self~Hello:super(who)
::method Sides;    return self~Sides:super + 4
::method Hidden;   return "mine," self~Hidden:super
::method Label;    return "label:" self~Label:super
::method relabel
  use arg new
  self~"LABEL=":super(new)
  return self~Label

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

::class Person subclass NetObject
::method "NAME="
  expose name
  use arg name
  self~raise.PropertyChanged(self, .net~System~ComponentModel~PropertyChangedEventArgs~new("Name"))
::method "AGE="
  expose age
  use arg age
  self~raise.PropertyChanged(self, .net~System~ComponentModel~PropertyChangedEventArgs~new("Age"))

::class Listener
::method changed
  expose heard
  use arg sender, e
  heard = e~PropertyName"("sender~isA(.Person)")"
::method heard; expose heard; return heard

::class Finder subclass NetObject
::method TryFind
  use arg key, value                          -- value: a ComRef
  if key \== "seven" then return .false
  value~Value = 7
  return .true
::method Twice
  use arg n
  n~Value = n~Value * 2

::class Parser2 subclass NetObject
::method TryParse
  use arg s, n
  if s == "twelve" then s = 12
  r = .net~ref
  ok = self~base.TryParse(s, r)               -- the base's out parameter: a .NetRef
  n~Value = r~value
  return ok

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

::class MyFactory subclass NetObject
::method Make                    -- T Make<T>(string text)
  use strict arg text, t
  select
    when t == .net~type("string") then return "["text":".net~typeObject(t)~Name"]"
    when .net~typeOf(t)~startsWith("System.Collections.Generic.List") then return t~new
    otherwise return text            -- converted to T: 41 to an int, a date to a DateTime
  end
::method Pair                    -- virtual List<T> Pair<T>(T a, T b): base. with the arguments swapped
  use strict arg a, b, t
  return self~base.Pair(b, a, t)      -- the type arguments given: "2" alone would infer String
::method Show                    -- virtual string Show<T>(T x) where T : IFormattable
  use strict arg x, t
  return .net~typeObject(t)~Name":" self~base.Show(x, t)
::method First                   -- protected virtual T First<T>(T[] xs): the last one
  use strict arg xs, t
  if xs~items > 2 then return self~base.First(xs)    -- T inferred from the .NET array
  return xs[xs~items]
::method TryGet                  -- virtual bool TryGet<T>(string key, out T value)
  use strict arg key, value, t
  if t \== .net~type("int") then do
    r = .net~ref                       -- the base's out parameter: a .NetRef
    found = self~base.TryGet(key, r, t)
    value~Value = r~value
    return found
  end
  value~Value = 7
  return .true

::class Conv subclass NetObject
::method Convert                 -- TOut Convert<TIn, TOut>(TIn x)
  use strict arg x, tin, tout
  if tout == .net~type("string") then return .net~typeOf(tin)">"||.net~typeOf(tout)":"||x
  return x

::class Lambdas subclass NetObject
::attribute seen
::method VisitLambda             -- protected virtual Expression VisitLambda<T>(Expression<T> node)
  use strict arg node, t
  self~seen = .net~typeOf(t)
  return self~base.VisitLambda(node, t)
