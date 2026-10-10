/* ooRexx/.NET bridge, phase 2 (collections and the rest of the type system):
   tests. Run by tests/run.sh after phase1.rex, with TestLib's path. */
parse arg testlib
.local~fails = 0; .local~count = 0
x = .net~load(testlib)
coll = .net~RexxNetTests~Coll

-- indexers (0-based, as .NET documents them)
l = .net~type("System.Collections.Generic.List<int>")~new
l~Add(3); l~Add(1); l~Add(2)
call ok "list[0]",              l[0], 3
l[1] = 10
call ok "list[1] = v",          l[1], 10
call err "list out of range",   "x = .local~l2[7]", "ArgumentOutOfRangeException"
d = .net~type("System.Collections.Generic.Dictionary<string, int>")~new
d["a"] = 1; d["b"] = 2
call ok "dictionary[key]",      d["b"], 2
call err "missing key",         "x = .local~d2['zz']", "KeyNotFoundException"

-- arrays as Rexx Arrays (from 1 in every dimension: BSF_ARRAY_REFERENCE's protocol)
bytes = .net~System~Text~Encoding~ASCII~GetBytes("abc")
call ok "an array is a .NetArray", bytes~isA(.NetArray) bytes~isA(.NetObject), "1 1"
call ok "makeString: its elements, as Array's", bytes~makeString("L", ","), "97,98,99"
call ok "makeString's default: lines", bytes~makeString, .array~of(97, 98, 99)~makeString
call ok "makeString('C')",      bytes~makeString("C"), "979899"
call ok "toString",             bytes~toString(, "+"), "97+98+99"
call ok "say and || use it",    "[" || .net~box("string", "a,b")~Split(",")~makeString("L", " ") || "]", "[a b]"
call ok "netDisplay: the type", bytes~netDisplay, "System.Byte[]"
m = .net~System~Array~CreateInstance(.net~typeObject(.net~type("int")), 2, 2)
m[1, 2] = 5; m[2, 1] = 7
call ok "makeString of a 2-D array", m~makeString("L", ","), "0,5,7,0"
call ok "byte[] element (from 1)", bytes[1] bytes[3], "97 99"
bytes[2] = 120
call ok "byte[] set",           .net~System~Text~Encoding~ASCII~GetString(bytes), "axc"
call ok "at",                   bytes~at(2), 120
bytes~put(121, 3)
call ok "put",                  bytes~at(3), 121
call ok "at(Array of indexes)", bytes~at(.array~of(1)), 97
call ok "items, size",          bytes~items bytes~size, "3 3"
call ok "dimension",            bytes~dimension bytes~dimension(1) bytes~dimension(2), "1 3 0"
call ok ".NET members still",   bytes~Length bytes~Rank, "3 1"
call err "byte[] range",        ".local~b2[1] = 1E10", "cannot store"
call err "index 0",             "x = .local~b2[0]", "Method argument 1 must be a positive whole number"
call err "index not a number",  ".local~b2~put(1, 'x')", "Method argument 2 must be a positive whole number"
call err "past the end",        "x = .local~b2[4]", "IndexOutOfRangeException"
call err "too many subscripts", "x = .local~b2[1, 1]", "Too many subscripts for array; 1 expected"
call err "put without value",   ".local~b2~put", "Not enough arguments for method; 2 expected"
call err "dimension(0)",        "x = .local~b2~dimension(0)", "Method argument 1 must be a positive whole number"
call err "no index",            "x = .local~b2~at", "Not enough arguments for method; 1 expected"
code = 0
signal on syntax name codeOf
x = .local~b2[0]
codeOf: code = condition("O")~code
signal off syntax
call ok "the code of a Rexx Array's error", code, "93.907"
g = coll~Grid
call ok "int[,] element",       g[1, 2] g[2, 3], "2 6"
g[1, 1] = 9
call ok "int[,] set",           g[1, 1], 9
call ok "int[,] at(Array)",     g~at(.array~of(2, 1)), 4
g~put(7, .array~of(2, 2))
call ok "int[,] put(v, Array)", g[2, 2], 7
call ok "int[,] items",         g~items, 6
call ok "int[,] dimension",     g~dimension g~dimension(1) g~dimension(2) g~dimension(3), "2 2 3 0"
call err "not enough subscripts", "x = .local~g2[1]", "Not enough subscripts for array; 2 expected"
call err "too many (Array)",    "x = .local~g2~at(.array~of(1, 1, 1))", "Too many subscripts for array; 2 expected"
call err "bad position",        "x = .local~g2['a', 1]", "Invalid position argument specified; found ""a"""
call err "bad element",         ".local~g2[1, 1] = 'x'", "cannot store"
o = .net~System~Array~CreateInstance(.net~type("object"), 3)
o~putStrict("short", 5, 1)
o~putStrict(.net~type("long"), 6, 2)
o[3] = 7
call ok "putStrict: types",     coll~TypesOf(o), "Int16 Int64 String"
call err "putStrict without value", ".local~b2~putStrict('int')", "Not enough arguments for method; 3 expected"
s = .net~System~Array~CreateInstance(.net~type("string"), 3)
s[1] = "a"; s[3] = "c"
call ok "null element is .nil", s[2] == .nil, 1
call ok "items counts every element", s~items, 3
jag = coll~Jagged
call ok "jagged: an array of arrays", jag[2]~isA(.NetArray) jag[2][3], "1 6"
call ok "an array back to .NET is itself", coll~SumAll(g), 31
sb = .net~System~Text~StringBuilder~new("abc")
call ok "StringBuilder[1] (Chars)", sb[1], "b"
sb[0] = "X"
call ok "StringBuilder[0] = v", sb~ToString, "Xbc"
m = .net~RexxNetTests~Matrix~new
m[1, 2] = 5
call ok "IndexerName, 2 indices", m[1, 2], 5
call ok "overloaded indexer",   m["name"], "matrix"
call err "type has no indexer", "x = .net~System~Math[1]", "is a type: it has no indexer"
call err "no indexer",          "x = .local~sb0[1, 2, 3]", "accepts"

-- DO OVER, DO WITH
s = ""; do x over l; s = s x; end
call ok "do over List",         s~strip, "3 10 2"
s = ""; do with index i item v over l; s = s i"="v; end
call ok "do with List (0-based)", s~strip, "0=3 1=10 2=2"
s = ""; do with index k item v over d; s = s k"="v; end
call ok "do with Dictionary",   s~strip, "a=1 b=2"
s = ""; do p over d; s = s p~Key"="p~Value; end
call ok "do over Dictionary (pairs)", s~strip, "a=1 b=2"
s = ""; do with index k item v over coll~ReadOnly; s = s k"="v; end
call ok "do with IReadOnlyDictionary", s~strip, "x=1 y=2"
s = ""; do x over coll~Range(3); s = s x; end
call ok "do over iterator",     s~strip, "10 20 30"
s = ""; do with index i item v over coll~Range(2); s = s i"="v; end
call ok "do with iterator (1..n)", s~strip, "1=10 2=20"
s = ""; do with index i item v over g; s = s i~makeString("L", ",")"="v; end
call ok "do with int[,] (from 1)", s~strip, "1,1=9 1,2=2 1,3=3 2,1=4 2,2=7 2,3=6"
s = ""; do with index i item v over bytes; s = s i"="v; end
call ok "do with byte[] (from 1)", s~strip, "1=97 2=120 3=121"
s = ""; do v over g; s = s v; end
call ok "do over int[,] (row by row)", s~strip, "9 2 3 4 7 6"
call ok "makeArray of int[,]",  g~makeArray~items, 6
call ok "makeArray",            l~makeArray~items, 3
call err "not enumerable",      "do x over .local~sb0; end", "is not enumerable"

-- objects of non-public types: what C# sees (public base class and interfaces)
h = coll~MakeHidden
call ok "interface member",     h~Name h~Area, "hidden 2"
call err "public member of a non-public type", "x = .local~h2~Secret", 'does not understand message "SECRET"'
e = coll~Range(2)~GetEnumerator
call ok "iterator through IEnumerable<T>", e~MoveNext e~Current, "1 10"
ro = coll~Hidden2
call ok "IList<T> indexer, non-public type", ro[1] ro~Count, "q 2"

-- generic methods: inferred, or given (Name<T>)
gen = .net~RexxNetTests~Gen
call ok "infer from a string",  gen~Kind("x"), "String"
call ok "non-generic wins a tie", gen~Kind(.net~int32(5)), "int (non-generic)"
call ok "infer from an object", gen~Kind(.net~System~Text~StringBuilder~new), "StringBuilder"
call ok "infer through IEnumerable<T>", gen~First(l), 3
call ok "infer T[] result",     .net~typeOf(gen~Pair(.net~int32(1), .net~int32(2))), "System.Int32[]"
call ok "two type arguments",   gen~Both("a", .net~int64(2)), "String,Int64"
call ok "params T[]",           gen~Many(.net~int16(1), .net~int16(2), .net~int16(3)), "Int16 3"
call err "cannot infer",        "x = .net~RexxNetTests~Gen~Make", "cannot infer the type arguments"
call ok "given: .net~invoke Name<T>", .net~typeOf(.net~invoke(gen, "Make<System.Text.StringBuilder>")), "System.Text.StringBuilder"
call ok "given: o~'Name<T>'",   gen~"Make<int>", 0
call err "given, wrong count",  "x = .net~invoke(.net~RexxNetTests~Gen, 'Make<int, int>')", "no generic form taking 2 type arguments"
linq = .net~System~Linq~Enumerable
call ok "Enumerable.ToList",    linq~ToList(l)~Count, 3
call ok "Enumerable.Sum",       linq~Sum(l), 15
s = ""; do x over linq~Repeat(.net~int32(7), 3); s = s x; end
call ok "Enumerable.Repeat",    s~strip, "7 7 7"
call ok "Enumerable.Empty<int>", .net~invoke(linq, "Empty<int>")~makeArray~items, 0

-- enums: values as objects (.NetEnum), names to .NET, flags, the type enumerable
s = ""; do n over .net~System~DayOfWeek; s = s n; end
call ok "do over an enum type: its values", s~word(1) s~words, "Sunday 7"
x = .net~System~DayOfWeek~makeArray
call ok "makeArray: .NetEnums by number", x[2]~isA(.NetEnum) x[2]~name x[2]~ordinal, "1 Monday 1"
s = ""; do with index n item v over .net~RexxNetTests~Style; s = s n"="v; end
call ok "do with an enum type: numbers and names", s~strip, "0=None 1=Bold 2=Italic 4=Under"
ital = .net~RexxNetTests~Style~Italic
call ok "enum static field: a .NetEnum", ital~isA(.NetEnum) ital~isA(.NetObject), "1 1"
call ok "its string is its name", ital, "Italic"
call ok "say / concatenation",  "is" ital, "is Italic"
call ok "name, ordinal, value", ital~name ital~ordinal ital~value, "Italic 2 2"
call ok "= a name, caseless",   ital = "italic", 1
call ok "= its number",         ital = 2, 1
call ok "\= another name",      ital \= "Bold", 1
call ok "== exactly its name",  (ital == "Italic") (ital == "italic"), "1 0"
call ok "= another .NetEnum",   ital = .net~RexxNetTests~Style~Italic, 1
call ok "== another .NetEnum (by value)", ital == gen~StyleOf(2), 1
call ok "not = another enum type's", ital = .net~System~DayOfWeek~Tuesday, 0
dow = .net~System~DateTime~new(2026, 10, 8)~DayOfWeek
call ok "a property: a .NetEnum", dow~isA(.NetEnum) dow, "1 Thursday"
call ok "select on an enum",    pick(dow), "thu"
call ok "goes to .NET as the enum", .net~RexxNetTests~Probe~Day(dow), "Thursday"
call ok "the enum, to int",     .net~System~Convert~ToInt32(dow), 4
fs = gen~StyleOf(3)
call ok "flags: name",          fs fs~ordinal, "Bold, Italic 3"
call ok "flags = any order",    fs = "italic, bold", 1
call ok "flags: HasFlag",       fs~HasFlag(ital), 1
call ok "an undefined value: its number", gen~StyleOf(8) == "8", 1
call ok "flags from names",     gen~Styled("Bold, Italic"), "Bold, Italic"
call ok "flags to a number",    gen~StyleValue("Italic, Under") gen~StyleValue(3), "6 3"
call ok "enum forced, to int",  .net~System~Convert~ToInt32(.net~as("Friday", .net~System~DayOfWeek)), 5
call ok "unbox: its name",      .net~unbox(ital), "Italic"
call ok "as a Directory index", .directory~new~~put("x", ital)~at(.net~RexxNetTests~Style~Italic), "x"
call err "not an enum name",    "x = .net~RexxNetTests~Gen~Styled('Purple')", "accepts"

-- structs: a .NetObject holds a boxed copy
pt = .net~RexxNetTests~Probe~MakePt(1, 2)
pt~X = 5
call ok "struct field set (the box)", pt~X, 5
call ok "struct passed by value", gen~Moved(pt, 1)~X pt~X, "6 5"
c = .net~RexxNetTests~Counter~new
c~Inc; c~Inc
call ok "struct method mutates the box", c~N, 2
call ok "DateTime arithmetic",  .net~System~DateTime~new(2026, 10, 8)~AddDays(1)~Day, 9

-- ref / out / in through .NetRef
r = .net~ref
call ok "out: TryGetValue found", d~TryGetValue("b", r) r~value, "1 2"
call ok "out: TryGetValue missing", d~TryGetValue("zz", r) r~value, "0 0"
call ok "out: Int32.TryParse",  .net~System~Int32~TryParse("42", r) r~value, "1 42"
a = .net~ref(1); b = .net~ref(2)
gen~Swap(a, b)
call ok "ref: Swap",            a~value b~value, "2 1"
h = .net~ref; t = .net~ref
call ok "two outs",             gen~Split("abc", h, t) h~value t~value, "1 a bc"
call ok "in: a plain value",    gen~Twice(21), 42
call ok "in: a NetRef",         gen~Twice(.net~ref(4)), 8
n = .net~ref(5)
call ok "ref: Interlocked.Increment", .net~System~Threading~Interlocked~Increment(n) n~value, "6 6"
call err "ref needs a NetRef",  ".net~RexxNetTests~Gen~Swap(1, 2)", "ref System.Int32"
call err "NetRef where no ref", "x = .net~System~Math~Abs(.net~ref(1))", "accepts"
call ok "NetRef display",       .net~ref(3)~makeString, "a NetRef (3)"

-- Task / ValueTask: ~await
call ok "await Task<int>",      gen~AddLater(2, 3)~await, 5
gen~Later~await
call ok "await Task (no result)", var("RESULT"), 0
call ok "await ValueTask<T>",   gen~Value~await, "vt"
call err "await a failed task", "x = .net~RexxNetTests~Gen~FailLater~await", "InvalidOperationException: late boom"
call err "await a non-task",    "x = .local~sb0~await", "is not a Task"
file = .net~System~IO~Path~GetTempFileName
.net~System~IO~File~WriteAllTextAsync(file, "hola")~await
call ok "File async round trip", .net~System~IO~File~ReadAllTextAsync(file)~await, "hola"
.net~System~IO~File~Delete(file)

say
if .fails = 0 then say "phase 2: all" .count "tests passed"
else say "phase 2:" .fails "of" .count "tests FAILED"
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
  .local~l2 = .net~type("System.Collections.Generic.List<int>")~new
  .local~d2 = .net~type("System.Collections.Generic.Dictionary<string, int>")~new
  .local~g2 = .net~RexxNetTests~Coll~Grid
  .local~b2 = .net~System~Text~Encoding~ASCII~GetBytes("abc")
  .local~h2 = .net~RexxNetTests~Coll~MakeHidden
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

::routine pick                    -- SELECT with an enum value (= compares names)
  use arg d
  select
    when d = "Wednesday" then return "wed"
    when d = "Thursday" then return "thu"
    otherwise return "?"
  end
