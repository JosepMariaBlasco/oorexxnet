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
//   30     a Rexx string to bool, char, char[], an enum
//   31     a Rexx string to DateTime, DateTimeOffset, TimeSpan, Guid
//   +1 per item when a Rexx Array becomes an array; +2 for a List<T> or an
//   interface; a params array expanded: +1
// .NET -> Rexx: strings, numbers (culture-invariant), bools (1/0), chars and
// enums (their names) as Rexx strings, null as .nil, void as nothing; a
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

    // ------------------------------------------------------------ Rexx -> .NET

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
                return FromArray(r.Items, to, out value);
            case 'S':
                return FromString(r.Text, under ?? to, out value);
            case 'H':
                return FromHandler(r, under ?? to, out value);
            case 'X':
            case 'G':
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
        Type forced = r.Text.StartsWith('#') ? ((StaticOf)Handles.Get(int.Parse(r.Text.Substring(1)))).Type
                                             : Types.Parse(r.Text);
        // First the value as the forced type, then the forced type to `to`.
        int c = TryConvert(r.Inner!, forced, out var v);
        if (c == Fail) throw new BridgeException($"cannot make a {Types.Display(forced)} of \"{Describe(r.Inner!)}\"");
        if (forced == to) { value = v; return 0; }
        if (v == null) return !to.IsValueType ? 1 : Fail;
        int k = FromObject(v, to, out value);
        return k == Fail ? Fail : k;
    }

    static int FromArray(List<Rec> items, Type to, out object? value)
    {
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
        var conv = new object?[items.Count];
        int cost = 0;
        for (int i = 0; i < items.Count; i++)
        {
            int c = TryConvert(items[i], elem!, out conv[i]);
            if (c == Fail) return Fail;
            cost += c + extra;
        }
        if (asArray || to.IsArray)
        {
            var arr = Array.CreateInstance(elem!, conv.Length);
            for (int i = 0; i < conv.Length; i++) arr.SetValue(conv[i], i);
            value = arr;
        }
        else
        {
            var list = (IList)Activator.CreateInstance(typeof(List<>).MakeGenericType(elem!))!;
            foreach (var x in conv) list.Add(x);
            value = list;
        }
        return cost + (items.Count == 0 ? extra : 0);
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
    static int FromRexx(Rec r, Type to, out object? value)
    {
        value = null;
        if (!to.IsAssignableFrom(typeof(RexxObject)) && !typeof(RexxObject).IsAssignableFrom(to)) return Fail;
        if (r.Adopted == null)
        {
            if (r.Tag == 'X') r.Adopted = RexxInterpreter.FromRequest((nint)nuint.Parse(r.Text));
            else
            {
                int tab = r.Text.IndexOf('\t');
                r.Adopted = RexxInterpreter.Adopt((nint)nuint.Parse(r.Text.Substring(0, tab)), (nint)nuint.Parse(r.Text.Substring(tab + 1)));
            }
        }
        var proxy = r.Adopted;
        if (!to.IsInstanceOfType(proxy)) return Fail;
        value = proxy;
        return proxy.GetType() == to ? 0 : 1;
    }

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
        const NumberStyles st = NumberStyles.Float;
        if (to == typeof(double))
        {
            if (!double.TryParse(s, st, Inv, out var d)) return false;
            value = d; return true;
        }
        if (to == typeof(float))
        {
            if (!float.TryParse(s, st, Inv, out var f)) return false;
            value = f; return true;
        }
        if (to == typeof(decimal))
        {
            if (!decimal.TryParse(s, st, Inv, out var m)) return false;
            value = m; return true;
        }
        // Integers: plain digits through long / ulong (fast), else through
        // BigInteger or decimal ("1E3", "18446744073709551615", "7.0"). Range
        // checks without exceptions: an overload test that fails must be cheap
        // (Math.Max tries 13 overloads; an OverflowException costs ~10 µs).
        BigInteger b;
        if (long.TryParse(s, NumberStyles.AllowLeadingSign, Inv, out var l)) b = l;
        else if (BigInteger.TryParse(s, NumberStyles.AllowLeadingSign, Inv, out b)) { }
        else if (decimal.TryParse(s, st, Inv, out var m) && decimal.Truncate(m) == m) b = new BigInteger(m);
        else return false;
        value = IntegerOf(b, to);
        return value != null;
    }

    // b as the integer type `to`, or null if it does not fit.
    static object? IntegerOf(BigInteger b, Type to)
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
        'A' => "an Array", 'T' => r.Text + " " + Describe(r.Inner!), 'R' => "a NetRef", 'H' => "a NetHandler",
        'X' or 'G' => "a Rexx object", _ => r.Tag.ToString(),
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
            case bool b: w.Add('S', b ? "1" : "0"); return;
            case char c: w.Add('S', c.ToString()); return;
            case Enum e: w.Add('S', e.ToString()); return;
            case double d: w.Add('S', d.ToString("R", Inv)); return;
            case float f: w.Add('S', f.ToString("R", Inv)); return;
            case decimal m: w.Add('S', m.ToString(Inv)); return;
            case sbyte or byte or short or ushort or int or uint or long or ulong or nint or nuint:
                w.Add('S', System.Convert.ToString(v, Inv)!); return;
            case RexxString rs: w.Add('S', rs.Value); return;
            case RexxObject ro: w.Add('X', RexxInterpreter.Lend(ro)); return;   // the Rexx object itself
        }
        AddObject(w, v);
    }

    public static void AddObject(Writer w, object o)
    {
        int id = Handles.Add(o);
        if (o is StaticOf so) w.Add('O', $"{id}\tt\t{Types.Display(so.Type)}");
        else w.Add('O', $"{id}\to\t{Types.Display(o.GetType())}");
    }
}
