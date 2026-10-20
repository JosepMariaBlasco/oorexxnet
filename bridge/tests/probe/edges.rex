/* ooRexx/.NET: what the conversion rules do at the edges, measured.
   Rexx -> .NET depends on the parameter's type (the overload is chosen
   first), so each Rexx value is given to parameters of several types,
   through Enumerable.Repeat<T>(value, 1), and what .NET made of it comes
   back to Rexx (First): "-" when no conversion exists (the call fails).
   For object, Convert.GetTypeCode shows the .NET type it became.
   Run: rexx edges.rex (with the bridge installed, or its build on
   REXX_PATH and the library path). A test of the bridge: its output must
   be edges.out exactly (bridge/tests/probe.rex compares them, run by
   run.sh and run.ps1); mirrored in JosepMariaBlasco/oorexx-bridges,
   topics/conversion-rules/probes/net/.                                     */
e = .net~System~Linq~Enumerable
types = "int long double decimal bool char string System.Numerics.BigInteger"
hdr = left("Rexx value", 32)
do t over types~makeArray(" "); hdr = hdr left(t~substr(t~lastPos(".") + 1), 12); end
say hdr "object"
list = '0|-0|42|-7|007|+5| 5|5 |- 7|3.14|.5|5.|1E3|1e3|1E+3|1E-3|-1.5E2|1.0|7.0|12345678901234567890123456789|3.14159265358979323846264|1E999|1E-999|.|-|E3|1E|0x10|1_000|inf|NaN|Infinity|true|abc|x||1 2'
do while list \= ""
  parse var list v "|" list
  call row "'"v"'", v
end
call row ".true", .true
call row ".false", .false
call row ".LogicalWrapper~true", .LogicalWrapper~true
call row ".LogicalWrapper~false", .LogicalWrapper~false
call row ".json~true", .json~true
call row ".nil", .nil
say
say "--- other Rexx values, to an object parameter (Convert.GetTypeCode / the .NET type)"
c = .net~System~Convert
l = .net~type("System.Collections.Generic.List<object>")~new
a = .array~new(4); a[1] = 1; a[3] = "x"
call show "sparse Array [1,,x,]", a
m = .array~new(2,2); m[1,1] = 1; m[1,2] = 2; m[2,1] = 3; m[2,2] = 4
call show "2-D Array 2x2 (full)", m
call show "Array (1,'a')", .array~of(1, "a")
call back "a~append(a): [3] is itself", cyclic(1)
call back "b <-> c: [2][2] is b's copy", cyclic(2)
call back ".array~of(x, x): one array", cyclic(3)
call back "1001 Arrays deep", cyclic(4)
call show ".directory~new", .directory~new
call show ".stringtable~new", .stringtable~new
s.1 = "a"; s.0 = 1
call show "stem s.", s.
say left("Array (1,'a') to string[]", 40) shown(.net~System~String~Join("|", .array~of(1, "a")))
st = .stringtable~new; st["k"] = "007"
say left("StringTable k=007 to Dictionary<string,int>", 40) -
  shown(.net~type("System.Collections.Generic.Dictionary<string, int>")~new(st)["k"])
d = .directory~new; d~name = "x"
say left("Directory d~name='x' to Dictionary<string,string>", 40) -
  shown(.net~type("System.Collections.Generic.Dictionary<string, string>")~new(d)~Keys~makeArray~makeString("L", ","))
say left("'é' (2 UTF-8 bytes): .NET Length", 40) .net~System~Text~StringBuilder~new("é")~Length
say left("'ff'x through a .NET string and back", 40) c2x(.net~System~String~Concat("ff"x, ""))
say left("'é' through a .NET string and back", 40) c2x(.net~System~String~Concat("é", ""))
say left("'00'x inside a string, .NET Length", 40) .net~System~Text~StringBuilder~new("a" || "00"x || "b")~Length
say
say "--- .NET -> Rexx"
D = .net~System~Double
call back "double 1e16", D~Parse("1e16", .net~System~Globalization~CultureInfo~InvariantCulture)
call back "double 1e-7", D~Parse("1e-7", .net~System~Globalization~CultureInfo~InvariantCulture)
call back "double 1.0", D~Parse("1.0", .net~System~Globalization~CultureInfo~InvariantCulture)
call back "double -0.0", D~Parse("-0.0", .net~System~Globalization~CultureInfo~InvariantCulture)
call back "double 0.1 + 0.2", D~Parse("0.30000000000000004", .net~System~Globalization~CultureInfo~InvariantCulture)
call back "double NaN, +Inf, -Inf", D~NaN D~PositiveInfinity D~NegativeInfinity
call back "float 0.1f", .net~System~Single~Parse("0.1", .net~System~Globalization~CultureInfo~InvariantCulture)
call back "decimal 1.10m", .net~System~Decimal~Parse("1.10", .net~System~Globalization~CultureInfo~InvariantCulture)
call back "decimal 1/3", .net~System~Decimal~Divide(1, 3)
call back "long.MaxValue, ulong.MaxValue", .net~System~Int64~MaxValue .net~System~UInt64~MaxValue
call back "BigInteger 2**70", .net~System~Numerics~BigInteger~Pow(2, 70)
call back "bool true, false", .net~System~Boolean~TrueString~length (1 = 1) .net~System~Char~IsDigit("7") .net~System~Char~IsDigit("x")
call back "bool: its class, isA(.LogicalWrapper)", .net~System~Char~IsDigit("7")~class~id .net~System~Char~IsDigit("x")~isA(.LogicalWrapper)
call back "a bool through List<object>", boolBack()
call back "char 'A'", .net~System~Char~ToUpper("a")
call back "null", .net~System~Environment~GetEnvironmentVariable("NO_SUCH_VARIABLE_X")
call back "byte[] of 'ab'", .net~System~Text~Encoding~UTF8~GetBytes("ab")
call back "enum DayOfWeek.Friday", .net~System~DayOfWeek~Friday
call back "struct DateTime (class, ToString('s'))", dateBack()   -- ("s": the same in every culture)
call back "boxed int (List<object>[0])", boxedBack()
call back "string 'café' from .NET", .net~System~String~Concat("caf", .net~System~Char~ConvertFromUtf32(233))
say
say "--- names, positions, identity"
sb = .net~System~Text~StringBuilder~new("abc")
say left("sb~length, sb~LENGTH, .net~get(sb, 'Length')", 40) sb~length sb~LENGTH .net~get(sb, "Length")
say left("array a[1] (first), list l[0] (first)", 40) .net~System~Text~Encoding~UTF8~GetBytes("ab")[1] lst()
say left("same .NET object twice: ==, =", 40) (sb == sb~Append("")) (sb = sb~Append(""))
say left("enum value = 'friday', == 'friday'", 40) (.net~System~DayOfWeek~Friday = "friday") (.net~System~DayOfWeek~Friday == "friday")
say left("Rexx Directory to .NET and back: ==", 40) dirBack()
say
say "--- the text of a float (oorexx-bridges, topics/float-text.md): doubles made in .NET, as Rexx gets them"
say left("", 40) left("text", 26) "length datatype(N)"
d = .net~System~Double; inv = .net~System~Globalization~CultureInfo~InvariantCulture; m = .net~System~Math
call float " 1 1.0",                   d~Parse("1.0", inv)
call float " 2 1/3",                   d~Parse(.net~System~Decimal~Divide(1, 3), inv)   -- (with inv: Convert.ToDouble(text) read the machine's culture)
call float " 3 0.1 + 0.2",             m~FusedMultiplyAdd(d~Parse("0.1", inv), 1, d~Parse("0.2", inv))
call float " 4 1e16",                  m~Pow(10, 16)
call float " 5 1e21",                  m~Pow(10, 21)
call float " 6 1e-7",                  d~Parse("1e-7", inv)
call float " 7 -0.0",                  d~NegativeZero
call float " 8 2**53 + 1, a double",   d~Parse("9007199254740993", inv)
call float " 8 2**53 + 1, a long",     .net~System~Int64~Parse("9007199254740993")
call float " 9 largest finite",        d~MaxValue
call float "10 smallest subnormal",    d~Epsilon
call float "11 NaN",                   d~NaN
call float "12 +infinity",             d~PositiveInfinity
call float "12 -infinity",             d~NegativeInfinity
say '--- Rexx strings to a .NET double (List<double>~Add), and what .NET has (ToString("R"), IsNegative)'
do s over "1E+16", "1e16", "1E16", " 1.5 ", "-0", "NaN", "nan", "Infinity", "+infinity", "-infinity", "inf", -
          "1E+999", "-1E+999", "1E-999", "-1E-999", "5E-324", "1.7976931348623157E+308", "1.8E+308"
  call toDouble s
end
exit

row: procedure expose e types
  use arg label, v
  line = left(label, 32)
  do t over types~makeArray(" ")
    line = line left(conv(e, t, v), 12)
  end
  signal on syntax name objFail
  line = line .net~System~Convert~GetTypeCode(v)
  say line
  return
objFail:
  say line "-"
  return

conv: procedure
  use arg e, t, v
  signal on syntax name convFail
  r = .net~invoke(e, "Repeat<"t">", v, 1)~makeArray[1]
  if r == .nil then return ".nil"
  if r~isA(.NetObject) then return r~ToString
  return "'"r"'"
convFail:
  return "-"

show: procedure expose c e
  use arg label, v
  signal on syntax name showFail
  r = .net~invoke(e, "Repeat<object>", v, 1)~makeArray[1]
  if r~isA(.NetObject) then say left(label, 40) "a copy:" .net~typeOf(r)
  else if r == v then say left(label, 40) "by reference: a Rexx.Net.RexxObject (back: the object itself)"
  else say left(label, 40) "?" r
  return
showFail:
  msg = condition("O")~message
  if msg~pos("accepts") > 0 then msg = msg~left(msg~pos("accepts") + 7)"..."
  say left(label, 40) "error:" msg~left(70)
  return

shown: procedure
  use arg x
  if x == .nil then return ".nil"
  return "'" || x || "'"

back: procedure
  use arg label, x
  if x == .nil then say left(label, 40) ".nil"
  else if x~isA(.NetObject) then say left(label, 40) x~class~id": ToString" x~ToString
  else say left(label, 40) "'" || x || "'"
  return

boxedBack: procedure
  l = .net~type("System.Collections.Generic.List<object>")~new
  l~Add(.net~box("int", 7))
  return l[0]

cyclic: procedure                      -- Arrays in Arrays, to a List<object> and back
  l = .net~type("System.Collections.Generic.List<object>")~new
  select
    when arg(1) = 1 then do; a = .array~of(1, 2); a~append(a); l~Add(a); return l[0]~length (l[0][3] == l[0]); end
    when arg(1) = 2 then do; b = .array~of(1); c = .array~of(2, b); b~append(c); l~Add(b); return (l[0][2][2] == l[0]); end
    when arg(1) = 3 then do; x = .array~of(7); l~Add(.array~of(x, x)); return (l[0][1] == l[0][2]); end
    otherwise
      d = .array~new; t = d
      do 1001; n = .array~new; t~append(n); t = n; end
      signal on syntax name deepFails
      l~Add(d)
      return "no error"
  end
deepFails:
  return "error:" condition("O")~message
dateBack: procedure
  d = .net~System~DateTime~new(2026, 10, 16)
  return d~class~id d~ToString("s")
boolBack: procedure                    -- a .LogicalWrapper into a List<object>, and back
  l = .net~type("System.Collections.Generic.List<object>")~new
  l~Add(.LogicalWrapper~false); l~Add(.false)
  return l[0]~class~id l[1]~class~id
lst: procedure
  l = .net~type("System.Collections.Generic.List<string>")~new
  l~Add("first")
  return l[0]

dirBack: procedure
  d = .directory~new
  l = .net~type("System.Collections.Generic.List<object>")~new
  l~Add(d)
  return l[0] == d

float: procedure                       -- a .NET double (or long) as Rexx gets it
  use arg label, x
  say left(label, 40) left("'" || x || "'", 26) right(x~length, 6) " " datatype(x, "N")
  return
toDouble: procedure                    -- a Rexx string to a double parameter
  use arg s
  l = .net~type("System.Collections.Generic.List<double>")~new
  signal on syntax name noDouble
  l~Add(s)
  r = .net~invoke(.net~box("double", l[0]), "ToString", "R", .net~System~Globalization~CultureInfo~InvariantCulture)
  say left("'"s"'", 40) r .net~System~Double~IsNegative(l[0])
  return
noDouble:
  say left("'"s"'", 40) "no conversion:" condition("O")~message~left(60)
  return
::requires "net.cls"
::requires "json.cls"
