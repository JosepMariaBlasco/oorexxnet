// Values across the bridge (notes/netobject-design.md, Values).
//
// Rexx -> .NET: an argument is converted to the type of the parameter it goes
// to; TryConvert says whether it can be, at what cost (lower is better: the
// overload with the lowest total wins, a tie is an error), and makes the value.
// Rexx -> .NET costs:
//   0      exact: an object of that very type, a forced (typed) value of it
//   1      reference / boxing conversion of an object, .nil to a reference
//   2      numeric widening of a boxed number (int -> long)
//   10     a Rexx string to string
//   11     a Rexx string to object (or an interface string implements)
//   12..25 a Rexx string to a number: int, long, double, decimal, uint,
//          ulong, float, short, ushort, byte, sbyte, nint, nuint (in this order)
//   1+     a .NetHandler to a delegate type: 1 + 2 per parameter, + 1 if
//          it returns a value
//   40     a .NetHandler to Delegate (an Action)
//   0 / 1  a Rexx object (X, G) to RexxObject (its own proxy type) / to a
//          type its proxy is (object, IEnumerable<object?>, ...)
//   25, 26 a Rexx string to RexxString, to RexxObject (a RexxString): after
//          string, object and the numbers, so that an overload taking one
//          of those wins
//   27     a Rexx string that is a whole number to BigInteger (exactly, any
//          number of digits, an exponent too: "1E40")
//   30     a Rexx string to bool, char, char[], an enum
//   0 / 1  a .LogicalWrapper (B) to bool / to object, ValueType or an interface bool
//          implements (a boxed bool); to anything else, as its string "1"/"0"
//   31     a Rexx string to DateTime, DateTimeOffset, TimeSpan, Guid
//   +1 per item when a Rexx Array becomes an array; +2 for a List<T> or an
//   interface; a params array expanded: +1
// .NET -> Rexx: strings, numbers (culture-invariant; BigInteger, Int128,
// UInt128 and Half too), chars and
// enums (their names) as Rexx strings, bools as .LogicalWrapper~true / ~false (B),
// null as .nil, void as nothing; a
// RexxObject as the Rexx object itself (X), a RexxString as its string;
// everything else by reference (a handle).
using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Numerics;

namespace Rexx.Net;

public static class Conv
{
    public const int Fail = int.MaxValue;
    static readonly CultureInfo Inv = CultureInfo.InvariantCulture;

    static readonly Type[] numberOrder =
    {
        typeof(int), typeof(long), typeof(double), typeof(decimal), typeof(uint),
        typeof(ulong), typeof(float), typeof(short), typeof(ushort), typeof(byte),
        typeof(sbyte), typeof(nint), typeof(nuint),
    };

    public static bool IsNumber(Type t) => Array.IndexOf(numberOrder, t) >= 0;

    /// A Rexx whole number in the range of a long ("2", " 2 ", "007", "1E3", "7.0").
    public static bool IsWholeNumber(string s) => TryNumber(s.Trim(), typeof(long), out _);

    // ------------------------------------------------------------ Rexx -> .NET

    // An Array's copy, kept on its record (Rec.Copy) as soon as it is made,
    // before its items are converted: a Q item (Wire: Target, that Array's
    // record) gets that very copy, so an Array that contains itself is an
    // object[] that contains itself. Every conversion of the record (each
    // overload tried) makes its copy afresh, before any Q can ask for it.
    static void Copied(Rec r, object copy) => r.Copy = copy;

    /// Converts a request record to the type `to`. Returns the cost, or Fail.
    public static int TryConvert(Rec r, Type to, out object? value)
    {
        value = null;
        var under = Nullable.GetUnderlyingType(to);
        if (to.IsByRef) to = to.GetElementType()!;
        switch (r.Tag)
        {
            case 'N':
                return !to.IsValueType || under != null ? 1 : Fail;
            case 'O':
            {
                var o = Handles.Get(r.Id);
                if (o is StaticOf so) o = so.Type;          // a type given as an argument: its System.Type
                return FromObject(o, under ?? to, out value);
            }
            case 'T':
                return FromTyped(r, under ?? to, out value);
            case 'A':
                // A RexxObject parameter: the Rexx Array itself (its pointer: valid during the request)
                if (r.Text.Length > 0 && typeof(RexxObject).IsAssignableFrom(under ?? to))
                {
                    r.Adopted ??= RexxInterpreter.FromRequest((nint)nuint.Parse(r.Text));
                    value = r.Adopted;
                    return (under ?? to).IsInstanceOfType(value) ? 0 : Fail;
                }
                return r.Dims == null ? FromArray(r, to, out value) : FromMultiArray(r, to, out value);
            case 'Q':                                       // an Array met before in this value: its copy, if it fits
            {
                if (r.Target?.Copy is not { } copy || !(under ?? to).IsInstanceOfType(copy)) return Fail;
                value = copy;
                return 1;
            }
            case 'S':
                if (r.Boolean)
                {
                    var t = under ?? to;
                    if (t == typeof(bool)) { value = r.Text == "1"; return 0; }
                    if (t == typeof(object) || t == typeof(ValueType) || (t.IsInterface && t.IsAssignableFrom(typeof(bool))))
                    { value = r.Text == "1"; return 1; }
                }
                return FromString(r.Text, under ?? to, out value);
            case 'H':
                return FromHandler(r, under ?? to, out value);
            case 'X':
            case 'G':
                if (DictionaryOf(under ?? to) is Type vt) return FromMap(r, vt, out value);
                if (SequenceOf(under ?? to) is Type et && FromSequence(r, under ?? to, et, out value) is int sc && sc != Fail) return sc;
                return FromRexx(r, under ?? to, out value);
        }
        return Fail;
    }

    static int FromObject(object o, Type to, out object? value)
    {
        value = o;
        var from = o.GetType();
        if (from == to) return 0;
        if (to.IsInstanceOfType(o)) return 1;
        if (IsNumber(from) && IsNumber(to) && Widens(from, to))
        {
            value = System.Convert.ChangeType(o, to, Inv);
            return 2;
        }
        value = null;
        return Fail;
    }

    // Implicit numeric conversions of C# (the ones that lose nothing, plus the
    // integer -> float/double ones C# allows).
    static bool Widens(Type from, Type to)
    {
        static int Rank(Type t) =>
            t == typeof(sbyte) ? 1 : t == typeof(byte) ? 1 : t == typeof(short) ? 2 : t == typeof(ushort) ? 2 :
            t == typeof(int) ? 3 : t == typeof(uint) ? 3 : t == typeof(long) ? 4 : t == typeof(ulong) ? 4 : 0;
        bool signedFrom = from == typeof(sbyte) || from == typeof(short) || from == typeof(int) || from == typeof(long);
        if (to == typeof(double) || to == typeof(float) || to == typeof(decimal))
            return Rank(from) > 0 || (from == typeof(float) && to == typeof(double));
        int rf = Rank(from), rt = Rank(to);
        if (rf == 0 || rt == 0 || rt <= rf) return false;
        bool signedTo = to == typeof(sbyte) || to == typeof(short) || to == typeof(int) || to == typeof(long);
        return signedTo || !signedFrom;
    }

    static int FromTyped(Rec r, Type to, out object? value)
    {
        value = null;
        if (r.Text == "null") return !to.IsValueType ? 0 : Fail;
        if (r.Text.StartsWith("named:"))
            throw new BridgeException($".net~named (the argument {r.Text.Substring(6)}): named arguments are for COM objects only");
        Type forced = r.Text.StartsWith('#') ? ((StaticOf)Handles.Get(int.Parse(r.Text.Substring(1)))).Type
                                             : Types.Parse(r.Text);
        // First the value as the forced type, then the forced type to `to`.
        ClearRangeError();
        int c = TryConvert(r.Inner!, forced, out var v);
        if (c == Fail) throw new BridgeException(TakeRangeError() ?? $"cannot make a {Types.Display(forced)} of \"{Describe(r.Inner!)}\"");
        if (forced == to) { value = v; return 0; }
        if (v == null) return !to.IsValueType ? 1 : Fail;
        int k = FromObject(v, to, out value);
        return k == Fail ? Fail : k;
    }

    static int FromArray(Rec r, Type to, out object? value)
    {
        var items = r.Items;
        value = null;
        Type? elem = null;
        int extra;
        bool asArray;
        if (to.IsArray && to.GetArrayRank() == 1) { elem = to.GetElementType(); asArray = true; extra = 1; }
        else if (to == typeof(object)) { elem = typeof(object); asArray = true; extra = 3; }
        else
        {
            asArray = false; extra = 2;
            if (to.IsGenericType)
            {
                var def = to.GetGenericTypeDefinition();
                if (def == typeof(List<>) || def == typeof(IEnumerable<>) || def == typeof(IList<>) ||
                    def == typeof(ICollection<>) || def == typeof(IReadOnlyList<>) || def == typeof(IReadOnlyCollection<>))
                    elem = to.GetGenericArguments()[0];
            }
            else if (to == typeof(IEnumerable) || to == typeof(IList) || to == typeof(ICollection))
                elem = typeof(object);
            if (elem == null) return Fail;
        }
        // made first, and known (Copied) before its items are converted: an
        // item that is this very Array (Q) gets it
        Array? arr = null;
        IList? list = null;
        if (asArray || to.IsArray) { arr = Array.CreateInstance(elem!, items.Count); Copied(r, arr); }
        else { list = (IList)Activator.CreateInstance(typeof(List<>).MakeGenericType(elem!))!; Copied(r, list); }
        int cost = 0;
        for (int i = 0; i < items.Count; i++)
        {
            int c = TryConvert(items[i], elem!, out var item);
            if (c == Fail) return Fail;
            cost += c + extra;
            if (arr != null) arr.SetValue(item, i); else list!.Add(item);
        }
        value = (object?)arr ?? list;
        return cost + (items.Count == 0 ? extra : 0);
    }

    // A multidimensional Rexx Array: a rectangular .NET array of the same rank
    // (T[,] for a parameter of that type, object[,] for object or Array),
    // a[i, j] at [i - 1, j - 1]. Nothing else: a list would lose the shape.
    static int FromMultiArray(Rec r, Type to, out object? value)
    {
        value = null;
        var dims = r.Dims!;
        Type elem;
        int extra;
        if (to.IsArray && to.GetArrayRank() == dims.Length) { elem = to.GetElementType()!; extra = 1; }
        else if (to == typeof(object) || to == typeof(Array)) { elem = typeof(object); extra = 3; }
        else return Fail;
        var arr = Array.CreateInstance(elem, dims);
        Copied(r, arr);
        var idx = new int[dims.Length];
        int cost = 0;
        for (int k = 0; k < r.Items.Count; k++)
        {
            int c = TryConvert(r.Items[k], elem, out var v);
            if (c == Fail) return Fail;
            cost += c + extra;
            for (int d = 0, q = k; d < dims.Length; d++) { idx[d] = q % dims[d]; q /= dims[d]; }   // the first index fastest
            arr.SetValue(v, idx);
        }
        value = arr;
        return cost + (r.Items.Count == 0 ? extra : 0);
    }

    // A .NetHandler: a delegate of the parameter's type. C# chooses among
    // delegate overloads by the lambda's parameters and body; a Rexx method
    // declares neither, so: fewer delegate parameters first (Where(Func<T,
    // bool>) before Where(Func<T, int, bool>)), then returning void before
    // returning a value (Task.Run(Action) before Task.Run(Func<Task>)).
    // Another one: .net~as(h, "System.Func<...>"). A parameter of type
    // Delegate (Control.Invoke) gets an Action, after any concrete delegate.
    static int FromHandler(Rec r, Type to, out object? value)
    {
        value = null;
        if (to.ContainsGenericParameters) return Fail;
        var h = Callbacks.HandlerOf(r);
        if (Callbacks.IsDelegateType(to))
        {
            value = Callbacks.DelegateFor(h, to);
            var inv = to.GetMethod("Invoke")!;
            return 1 + 2 * inv.GetParameters().Length + (inv.ReturnType == typeof(void) ? 0 : 1);
        }
        if (to == typeof(Delegate) || to == typeof(MulticastDelegate))
        {
            value = Callbacks.DelegateFor(h, typeof(Action));
            return 40;
        }
        return Fail;
    }

    // A Rexx object (phase C): its RexxObject proxy, for a parameter that
    // takes one. X: a pointer valid during the request; G: a global reference
    // handed over (a callback's result), adopted once.
    internal static RexxObject AdoptRexx(Rec r) => Adopt(r);

    /// An X record known to be a plain Rexx object (not a String, a routine,
    /// a class, a package or a .NetObject: the .CommandContext): its proxy
    /// with no questions about its type.
    internal static RexxObject AdoptRexxPlain(Rec r) =>
        r.Adopted ??= r.Tag == 'X' ? RexxInterpreter.FromRequestPlain((nint)nuint.Parse(r.Text)) : Adopt(r);

    static RexxObject Adopt(Rec r)
    {
        if (r.Adopted == null)
        {
            if (r.Tag == 'X') r.Adopted = RexxInterpreter.FromRequest((nint)nuint.Parse(r.Text));
            else
            {
                int tab = r.Text.IndexOf('\t');
                r.Adopted = RexxInterpreter.Adopt((nint)nuint.Parse(r.Text.Substring(0, tab)), (nint)nuint.Parse(r.Text.Substring(tab + 1)));
            }
        }
        return r.Adopted;
    }

    static int FromRexx(Rec r, Type to, out object? value)
    {
        value = null;
        if (!to.IsAssignableFrom(typeof(RexxObject)) && !typeof(RexxObject).IsAssignableFrom(to)) return Fail;
        var proxy = Adopt(r);
        if (!to.IsInstanceOfType(proxy)) return Fail;
        value = proxy;
        return proxy.GetType() == to ? 0 : 1;
    }

    // A dictionary with string keys that a StringTable can become: its value
    // type (Dictionary<string, T>, IDictionary<string, T>,
    // IReadOnlyDictionary<string, T>: T; the non-generic IDictionary: object).
    internal static Type? DictionaryOf(Type to)
    {
        if (to == typeof(IDictionary)) return typeof(object);
        if (!to.IsGenericType) return null;
        var d = to.GetGenericTypeDefinition();
        if (d != typeof(Dictionary<,>) && d != typeof(IDictionary<,>) && d != typeof(IReadOnlyDictionary<,>)) return null;
        var a = to.GetGenericArguments();
        return a[0] == typeof(string) ? a[1] : null;
    }

    // A StringTable or a Directory to a dictionary: a copy (a new
    // Dictionary<string, T>, the values converted as for an argument of type
    // T). Any other Rexx object is no dictionary.
    static int FromMap(Rec r, Type vt, out object? value)
    {
        value = null;
        var o = Adopt(r);
        r.IsMap ??= IsMap(o);
        if (r.IsMap != true) return Fail;
        r.Pairs ??= o.Supplier();
        try { value = DictionaryCopy(r.Pairs, vt, o); }
        catch (InvalidCastException) { return Fail; }
        return 20;
    }

    // An instance of an Array subclass (the Array class itself comes as an A
    // record) to a .NET array or list: a copy, as for an Array (ArrayCopy:
    // read by DIMENSIONS and SUPPLIER). Ranked as a dictionary copy, so an
    // overload taking a RexxObject wins; among copies, as FromArray prefers
    // them: an array before a list or interface, a typed element before
    // object (String.Join: string[] before IEnumerable<string>, object[]).
    static int FromSequence(Rec r, Type to, Type et, out object? value)
    {
        value = null;
        var o = Adopt(r);
        r.IsSequence ??= IsRexxArray(o);
        if (r.IsSequence != true) return Fail;
        try { value = ArrayCopy(o, to, et); }
        catch (Exception e) when (e is InvalidCastException or FormatException or OverflowException) { return Fail; }
        return 20 + (to.IsArray ? 0 : 2) + (et == typeof(object) ? 3 : 0);
    }

    // The element type of a .NET array or list a Rexx Array can become as a
    // result or a value (T[], List<T>, and the interfaces a T[] has).
    internal static Type? SequenceOf(Type t)
    {
        if (t.IsArray) return t.GetArrayRank() == 1 ? t.GetElementType() : null;
        if (!t.IsGenericType) return null;
        var d = t.GetGenericTypeDefinition();
        return d == typeof(List<>) || d == typeof(IList<>) || d == typeof(ICollection<>) || d == typeof(IEnumerable<>) ||
               d == typeof(IReadOnlyList<>) || d == typeof(IReadOnlyCollection<>) ? t.GetGenericArguments()[0] : null;
    }

    internal static bool IsRexxArray(RexxObject o) =>
        o.Interpreter.FindClass("Array") is RexxClass a && o.Is(a) && o.Send<int>("DIMENSION") <= 1;

    // The copies made so far in one conversion (RexxConvert.To of one value),
    // by the Rexx object they copy: an Array met again (one that contains
    // itself, or one in it twice) is its copy again, as for an argument
    // (Rec.Copy). Made by the outermost copy; nested more than
    // MaxArrayDepth deep: an error (the copy recurses).
    [ThreadStatic] static Dictionary<RexxObject, object>? hostCopies;
    [ThreadStatic] static int hostDepth;
    const int MaxArrayDepth = 1000;

    static T Copying<T>(Func<Dictionary<RexxObject, object>, T> copy)
    {
        bool outermost = hostCopies == null;
        hostCopies ??= new(ReferenceEqualityComparer.Instance);
        if (++hostDepth > MaxArrayDepth)
        {
            hostDepth--;
            if (outermost) hostCopies = null;
            throw new InvalidCastException($"Arrays nested more than {MaxArrayDepth} deep cannot become .NET arrays");
        }
        try { return copy(hostCopies); }
        finally { hostDepth--; if (outermost) hostCopies = null; }
    }

    // A one-dimensional Rexx Array's items, converted as Rexx results, in a
    // new T[] (a List<T> for a List<T>). An omitted item: null, where T takes
    // one (the size is kept, as when the Array goes to .NET as an argument).
    // An instance of a subclass is read by messages, the family's rule
    // (oorexx-bridges, directory-crossing): DIMENSIONS for its size and
    // SUPPLIER for its items, what DO WITH ... OVER sees (an own SUPPLIER is
    // honoured; an own AT only as far as that SUPPLIER uses it).
    internal static object ArrayCopy(RexxObject a, Type t, Type et) => Copying(memo =>
    {
        bool list = t.IsGenericType && t.GetGenericTypeDefinition() == typeof(List<>);
        if (memo.TryGetValue(a, out var made) && t.IsInstanceOfType(made)) return made;
        if (!a.IsPlainArray) return SubclassCopy(a, t, et, list, memo);
        int n = a.Send("SIZE") is RexxString size ? int.Parse(size.Value) : 0;
        var arr = Array.CreateInstance(et, n);
        var lst = list ? (IList)Activator.CreateInstance(t)! : null;
        memo[a] = lst ?? (object)arr;                       // (before its items: one of them may be a itself)
        bool takesNull = !et.IsValueType || Nullable.GetUnderlyingType(et) != null;
        for (int i = 1; i <= n; i++)
        {
            object? item;
            if (!a.Send<bool>("HASINDEX", i))
            {
                if (!takesNull) throw new InvalidCastException($"an Array with omitted items cannot become a .NET array or list of {et.Name}");
                item = null;
            }
            else
            {
                try { item = RexxConvert.To(a.Send("AT", i), et); }
                catch (Exception e) when (e is FormatException or OverflowException) { throw new InvalidCastException(e.Message, e); }
            }
            if (lst != null) lst.Add(item); else arr.SetValue(item, i - 1);
        }
        return lst ?? (object)arr;
    });

    // ArrayCopy for an instance of an Array subclass: its size from
    // DIMENSIONS, its items from SUPPLIER (a position it gives outside 1 to
    // that size, or not a whole number, makes the copy fail).
    static object SubclassCopy(RexxObject a, Type t, Type et, bool list, Dictionary<RexxObject, object> memo)
    {
        var dims = a.Send("DIMENSIONS") as RexxObject;
        int rank = dims?.Send("ITEMS") is RexxString rk ? int.Parse(rk.Value) : 0;
        if (rank > 1) throw new InvalidCastException($"a {rank}-dimensional Array cannot become a .NET array or list of {et.Name}");
        int n = rank == 1 && dims!.Send("AT", 1) is RexxString d1 ? int.Parse(d1.Value) : 0;
        var items = new object?[n];
        var given = new bool[n];
        var arr = Array.CreateInstance(et, n);
        var lst = list ? (IList)Activator.CreateInstance(t)! : null;
        memo[a] = lst ?? (object)arr;                       // (before its items: one of them may be a itself)
        foreach (var (k, v) in a.Supplier())
        {
            string ks = k is RexxString s ? s.Value : k?.ToString() ?? "";
            if (!int.TryParse(ks.Trim(), out int i) || i < 1 || i > n)
                throw new InvalidCastException($"an Array whose supplier gives the position \"{ks}\" (its size is {n}) cannot become a .NET array or list");
            try { items[i - 1] = RexxConvert.To(v, et); }
            catch (Exception e) when (e is FormatException or OverflowException) { throw new InvalidCastException(e.Message, e); }
            given[i - 1] = true;
        }
        bool takesNull = !et.IsValueType || Nullable.GetUnderlyingType(et) != null;
        for (int i = 0; i < n; i++)
        {
            if (!given[i] && !takesNull) throw new InvalidCastException($"an Array with omitted items cannot become a .NET array or list of {et.Name}");
            if (lst != null) lst.Add(items[i]); else arr.SetValue(items[i], i);
        }
        return lst ?? (object)arr;
    }

    // A StringTable or a Directory (or an instance of a subclass): what
    // becomes a dictionary with string keys.
    internal static bool IsMap(RexxObject o) =>
        (o.Interpreter.FindClass("StringTable") is RexxClass st && o.Is(st)) ||
        (o.Interpreter.FindClass("Directory") is RexxClass d && o.Is(d));

    // A new Dictionary<string, vt> with a StringTable's or Directory's pairs
    // (its supplier's: a Directory's setMethod entries with their results), the values
    // converted as Rexx results (InvalidCastException: one does not convert).
    internal static IDictionary DictionaryCopy(IReadOnlyList<KeyValuePair<object?, object?>> pairs, Type vt, RexxObject? of = null) => Copying(memo =>
    {
        var t = typeof(Dictionary<,>).MakeGenericType(typeof(string), vt);
        if (of != null && memo.TryGetValue(of, out var made) && t.IsInstanceOfType(made)) return (IDictionary)made;
        var d = (IDictionary)Activator.CreateInstance(t)!;
        if (of != null) memo[of] = d;                       // (before its values: one of them may hold it)
        foreach (var (k, v) in pairs)
        {
            object? item;
            try { item = vt == typeof(object) && v is RexxString s ? s.Value : RexxConvert.To(v, vt); }
            catch (Exception e) when (e is FormatException or OverflowException) { throw new InvalidCastException(e.Message, e); }
            d[k is RexxString ks ? ks.Value : k?.ToString() ?? ""] = item;
        }
        return d;
    });

    static int FromString(string s, Type to, out object? value)
    {
        value = null;
        if (to == typeof(string)) { value = s; return 10; }
        if (to == typeof(RexxString) || to == typeof(RexxObject))
        { value = new RexxString(s, RexxInterpreter.Current); return to == typeof(RexxString) ? 25 : 26; }
        if (to == typeof(object) || (to.IsInterface && to.IsAssignableFrom(typeof(string))))
        { value = s; return 11; }
        int n = Array.IndexOf(numberOrder, to);
        if (n >= 0) return TryNumber(s.Trim(), to, out value) ? 12 + n : Fail;
        if (to == typeof(bool))
        {
            var t = s.Trim();
            if (t == "1" || t.Equals("true", StringComparison.OrdinalIgnoreCase)) { value = true; return 30; }
            if (t == "0" || t.Equals("false", StringComparison.OrdinalIgnoreCase)) { value = false; return 30; }
            return Fail;
        }
        if (to == typeof(BigInteger))
        {
            if (TryWhole(s.Trim(), out var big)) { value = big; return 27; }
            return Fail;
        }
        if (to == typeof(char)) { if (s.Length == 1) { value = s[0]; return 30; } return Fail; }
        if (to == typeof(char[])) { value = s.ToCharArray(); return 30; }
        if (to.IsEnum)
        {
            if (Enum.TryParse(to, s.Trim(), true, out var e)) { value = e; return 30; }
            return Fail;
        }
        try
        {
            if (to == typeof(DateTime)) { value = DateTime.Parse(s, Inv); return 31; }
            if (to == typeof(DateTimeOffset)) { value = DateTimeOffset.Parse(s, Inv); return 31; }
            if (to == typeof(TimeSpan)) { value = TimeSpan.Parse(s, Inv); return 31; }
            if (to == typeof(Guid)) { value = Guid.Parse(s); return 31; }
        }
        catch (FormatException) { }
        return Fail;
    }

    // A Rexx number string to a .NET number: exactly, or not at all (no
    // silent truncation; integers must be whole and in range).
    static bool TryNumber(string s, Type to, out object? value)
    {
        value = null;
        if (s.Length == 0) return false;
        // a Rexx number may have blanks after its sign ("- 7")
        if (s.Length > 1 && (s[0] == '+' || s[0] == '-') && s[1] == ' ') s = s[0] + s.Substring(1).TrimStart();
        const NumberStyles st = NumberStyles.Float;
        // A Rexx number that does not fit: refused, the reason kept for the
        // error (oorexx-bridges, topics/explicit-float-range.md): too large
        // ("1E999" would be an infinity), or not zero but read as zero
        // ("1E-999"); nan, +infinity, -infinity by name are fine.
        if (to == typeof(double))
        {
            if (!double.TryParse(s, st, Inv, out var d)) return false;
            if (double.IsInfinity(d) && HasDigit(s) || d == 0 && !IsZero(s)) return OutOfRange(s, to);
            value = d; return true;
        }
        if (to == typeof(float))
        {
            if (!float.TryParse(s, st, Inv, out var f)) return false;
            if (float.IsInfinity(f) && HasDigit(s) || f == 0 && !IsZero(s)) return OutOfRange(s, to);
            value = f; return true;
        }
        if (to == typeof(decimal))
        {
            if (!decimal.TryParse(s, st, Inv, out var m)) return HasDigit(s) && IsRexxNumberText(s) ? OutOfRange(s, to) : false;
            if (m == 0 && !IsZero(s)) return OutOfRange(s, to);
            value = m; return true;
        }
        // Integers: plain digits through long (fast), else exactly through
        // TryWhole ("1E3", "18446744073709551615", "7.0"; not "1E-999", which
        // is no whole number). Range checks without exceptions: an overload
        // test that fails must be cheap (Math.Max tries 13 overloads; an
        // OverflowException costs ~10 µs).
        BigInteger b;
        if (long.TryParse(s, NumberStyles.AllowLeadingSign, Inv, out var l)) b = l;
        else if (!TryWhole(s, out b)) return false;
        value = IntegerOf(b, to);
        return value != null;
    }

    /// Why the last Rexx number was refused for a floating type on this
    /// thread ("1E-999 is out of range for a Double"), for the error that
    /// follows (Members, .net~box, a forced type); null if none. Cleared by
    /// TakeRangeError.
    [ThreadStatic] static string? rangeError;
    static bool OutOfRange(string s, Type to)
    {
        rangeError ??= $"{s.Trim()} is out of range for a {to.Name}";      // (the first one, as overloads are tried)
        return false;
    }
    internal static string? TakeRangeError() { var e = rangeError; rangeError = null; return e; }
    internal static void ClearRangeError() => rangeError = null;

    // A Rexx number whose digits are all zeros (before any exponent): "0",
    // "-0.000", "0E5"
    internal static bool IsZero(string s)
    {
        foreach (char ch in s)
        {
            if (ch is 'e' or 'E') break;
            if (ch is >= '1' and <= '9') return false;
        }
        return true;
    }

    static bool IsRexxNumberText(string s)
    {
        var t = s.Trim();
        return t.Length > 0 && (char.IsAsciiDigit(t[^1]) || t[^1] == '.') && t.All(ch => char.IsAsciiDigit(ch) || ch is '.' or 'e' or 'E' or '+' or '-' or ' ');
    }

    static bool HasDigit(string s)
    {
        foreach (var c in s) if (char.IsAsciiDigit(c)) return true;
        return false;
    }

    // A Rexx number that is a whole number, exactly, as a BigInteger: digits
    // of any length, a sign (blanks after it allowed), a fraction of zeros,
    // an exponent ("1E40", "12.5E1"). Anything else (a fraction, not a
    // number) is false.
    internal static bool TryWhole(string s, out BigInteger b)
    {
        b = BigInteger.Zero;
        if (s.Length > 1 && (s[0] == '+' || s[0] == '-')) s = s[0] + s.Substring(1).TrimStart();
        int i = 0;
        bool negative = false;
        if (i < s.Length && (s[i] == '+' || s[i] == '-')) negative = s[i++] == '-';
        int start = i;
        while (i < s.Length && char.IsAsciiDigit(s[i])) i++;
        string whole = s.Substring(start, i - start), fraction = "";
        if (i < s.Length && s[i] == '.')
        {
            int f = ++i;
            while (i < s.Length && char.IsAsciiDigit(s[i])) i++;
            fraction = s.Substring(f, i - f);
        }
        if (whole.Length + fraction.Length == 0) return false;
        int exponent = 0;
        if (i < s.Length && (s[i] == 'e' || s[i] == 'E'))
        {
            i++;
            int e = i;
            if (i < s.Length && (s[i] == '+' || s[i] == '-')) i++;
            int d = i;
            while (i < s.Length && char.IsAsciiDigit(s[i])) i++;
            if (i == d || !int.TryParse(s.AsSpan(e, i - e), NumberStyles.AllowLeadingSign, Inv, out exponent)) return false;
        }
        if (i != s.Length) return false;
        string digits = whole + fraction;               // the value is digits * 10^(exponent - fraction.Length)
        int scale = exponent - fraction.Length;
        if (scale < 0)
        {
            int drop = Math.Min(-scale, digits.Length);  // the digits dropped must be zeros
            for (int k = digits.Length - drop; k < digits.Length; k++) if (digits[k] != '0') return false;
            digits = digits.Substring(0, digits.Length - drop);
            scale += drop;
            if (scale < 0) { b = BigInteger.Zero; return digits.Trim('0').Length == 0; }
        }
        if (scale > 100000) return false;               // (a number no one means)
        b = digits.Length == 0 ? BigInteger.Zero : BigInteger.Parse(digits, Inv) * BigInteger.Pow(10, scale);
        if (negative) b = -b;
        return true;
    }

    // b as the integer type `to`, or null if it does not fit.
    internal static object? IntegerOf(BigInteger b, Type to)
    {
        if (to == typeof(ulong) || to == typeof(nuint))
        {
            if (b.Sign < 0 || b > ulong.MaxValue) return null;
            ulong u = (ulong)b;
            return to == typeof(ulong) ? u : (nuint.MaxValue >= u ? (nuint)u : null);
        }
        if (b < long.MinValue || b > long.MaxValue) return null;
        long v = (long)b;
        if (to == typeof(int)) return v is >= int.MinValue and <= int.MaxValue ? (int)v : null;
        if (to == typeof(long)) return v;
        if (to == typeof(uint)) return v is >= 0 and <= uint.MaxValue ? (uint)v : null;
        if (to == typeof(short)) return v is >= short.MinValue and <= short.MaxValue ? (short)v : null;
        if (to == typeof(ushort)) return v is >= 0 and <= ushort.MaxValue ? (ushort)v : null;
        if (to == typeof(byte)) return v is >= 0 and <= byte.MaxValue ? (byte)v : null;
        if (to == typeof(sbyte)) return v is >= sbyte.MinValue and <= sbyte.MaxValue ? (sbyte)v : null;
        if (to == typeof(nint)) return v >= nint.MinValue && v <= nint.MaxValue ? (nint)v : null;
        return null;
    }

    public static string Describe(Rec r) => r.Tag switch
    {
        'S' => r.Text, 'N' => ".nil", 'O' => Types.Display(Handles.Get(r.Id) is StaticOf so ? so.Type : Handles.Get(r.Id).GetType()),
        'A' => r.Dims == null ? "an Array" : $"a {r.Dims.Length}-dimensional Array", 'Q' => "an Array that is already in the value", 'T' => r.Text + " " + Describe(r.Inner!), 'R' => "a NetRef", 'H' => "a NetHandler",
        'X' or 'G' => r.IsMap == true ? "a StringTable or Directory (whose values do not all convert)" : "a Rexx object",
        _ => r.Tag.ToString(),
    };

    // ------------------------------------------------------------ .NET -> Rexx

    /// Writes a .NET value as a response record.
    public static void ToRexx(Writer w, object? v, Type? declared = null)
    {
        if (declared == typeof(void)) { w.Add('V', ""); return; }
        switch (v)
        {
            case null: w.Add('N', ""); return;
            case string s: w.Add('S', s); return;
            case bool b: w.Add('B', b ? "1" : "0"); return;   // .LogicalWrapper~true / ~false
            case char c: w.Add('S', c.ToString()); return;
            case double d: w.Add('S', FloatText(d.ToString("R", Inv))); return;
            case float f: w.Add('S', FloatText(f.ToString("R", Inv))); return;
            case decimal m: w.Add('S', m.ToString(Inv)); return;
            case Half h: w.Add('S', FloatText(h.ToString(Inv))); return;
            case sbyte or byte or short or ushort or int or uint or long or ulong or nint or nuint
                 or Int128 or UInt128 or BigInteger:              // every integer type: all its digits
                w.Add('S', System.Convert.ToString(v, Inv)!); return;
            case RexxString rs: w.Add('S', rs.Value); return;
            case RexxObject ro: w.Add('X', RexxInterpreter.Lend(ro)); return;   // the Rexx object itself
        }
        AddObject(w, v);
    }

    /// A .NET float as Rexx gets it (oorexx-bridges, topics/float-text.md):
    /// its shortest digits (.NET's round-trip text, given), written as ooRexx
    /// writes x + 0 under NUMERIC DIGITS 17: plain digits unless the integer
    /// part needs more than 17 places or the decimals more than 34; else one
    /// digit, the point, the rest, and E with its sign and no leading zeros
    /// (1E+17, 1E-35). No ".0" (.NET's side of the decision); -0 kept; NaN
    /// and the infinities in ooRexx's own spelling, nan, +infinity and
    /// -infinity (what ooRexx writes for a double: DoubleToObject), which go
    /// back to a double as they are (Double.Parse reads them).
    internal static string FloatText(string roundTrip)
    {
        string s = roundTrip;
        switch (s)
        {
            case "NaN": return "nan";
            case "Infinity": return "+infinity";
            case "-Infinity": return "-infinity";
            case "0" or "-0": return s;
        }
        bool negative = s[0] == '-';
        if (negative) s = s.Substring(1);
        int exp = 0, e = s.IndexOfAny(new[] { 'E', 'e' });
        if (e >= 0) { exp = int.Parse(s.Substring(e + 1), Inv); s = s.Substring(0, e); }
        int point = s.IndexOf('.');
        if (point >= 0) { exp -= s.Length - point - 1; s = s.Remove(point, 1); }
        // s: the digits, the value s * 10^exp; no leading or trailing zeros
        s = s.TrimStart('0');
        int trailing = s.Length - s.TrimEnd('0').Length;
        s = s.Substring(0, s.Length - trailing); exp += trailing;
        if (s.Length == 0) return negative ? "-0" : "0";
        int before = s.Length + exp;                     // the places before the point
        string text;
        if (before > 17 || -exp > 34)
        {
            int x = before - 1;
            text = s.Substring(0, 1) + (s.Length > 1 ? "." + s.Substring(1) : "") + "E" + (x < 0 ? "-" : "+") + Math.Abs(x).ToString(Inv);
        }
        else if (exp >= 0) text = s + new string('0', exp);
        else if (before > 0) text = s.Substring(0, before) + "." + s.Substring(before);
        else text = "0." + new string('0', -before) + s;
        return negative ? "-" + text : text;
    }

    public static void AddObject(Writer w, object o)
    {
        if (Extend.CrossingOf(o) is RexxHandler peer) { w.Add('p', peer.Id.ToString()); return; }   // its Rexx object itself
        int id = Handles.Add(o);
        if (o is StaticOf so) w.Add('O', $"{id}\tt\t{Extend.Display(so.Type)}");
        else w.Add('O', $"{id}\t{(o is Array ? 'a' : o is Enum ? 'e' : 'o')}\t{Extend.Display(o.GetType())}");
    }
}
