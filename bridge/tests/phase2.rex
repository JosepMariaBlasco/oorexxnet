/* ooRexx/.NET bridge, phase 2 (collections and the rest of the type system):
   tests. Run by tests/run.sh after phase1.rex, with TestLib's path. */
parse arg testlib
.local~fails = 0; .local~count = 0
x = .net~load(testlib)
coll = .net~RexxNetTests~Coll

-- indexers and arrays (0-based)
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
bytes = .net~System~Text~Encoding~ASCII~GetBytes("abc")
call ok "byte[] element",       bytes[1], 98
bytes[1] = 120
call ok "byte[] set",           .net~System~Text~Encoding~ASCII~GetString(bytes), "axc"
call err "byte[] range",        ".local~g2[0, 0] = 1E10", "cannot store"
g = coll~Grid
call ok "int[,] element",       g[1, 2], 6
g[0, 0] = 9
call ok "int[,] set",           g[0, 0], 9
call err "wrong rank",          "x = .local~g2[1]", "takes 2 indexes, not 1"
call err "bad index",           "x = .local~g2['a', 1]", "an array index is a whole number"
call err "bad element",         ".local~g2[0, 0] = 'x'", "cannot store"
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
call ok "do with int[,]",       s~strip, "0,0=9 0,1=2 0,2=3 1,0=4 1,1=5 1,2=6"
call ok "makeArray",            l~makeArray~items, 3
call err "not enumerable",      "do x over .local~sb0; end", "is not enumerable"

-- objects of non-public types: what C# sees (public base class and interfaces)
h = coll~MakeHidden
call ok "interface member",     h~Name h~Area, "hidden 2"
call err "public member of a non-public type", "x = .local~h2~Secret", "no public instance member"
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

-- enums: names both ways, flags, the type enumerable
s = ""; do n over .net~System~DayOfWeek; s = s n; end
call ok "do over an enum type", s~word(1) s~words, "Sunday 7"
s = ""; do with index n item v over .net~RexxNetTests~Style; s = s n"="v; end
call ok "do with an enum type", s~strip, "None=0 Bold=1 Italic=2 Under=4"
call ok "enum static field",    .net~RexxNetTests~Style~Italic, "Italic"
call ok "flags from names",     gen~Styled("Bold, Italic"), "Bold, Italic"
call ok "flags to a number",    gen~StyleValue("Italic, Under") gen~StyleValue(3), "6 3"
call ok "enum forced, to int",  .net~System~Convert~ToInt32(.net~as("Friday", .net~System~DayOfWeek)), 5
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
