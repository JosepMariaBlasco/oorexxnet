// Rexx objects in .NET (notes/rexx-from-net-design.md, C# surface, Values).
//
// A RexxObject is any Rexx object, by reference: Send("name", args) or,
// through dynamic, d.Name(args), d.Name, d.Name = v, d[i], d + 1 (Rexx's
// operators as messages), conversions, foreach. Names are uppercased, as
// Rexx does with every message. A RexxString is a Rexx string: copied (no
// reference), equal by value, converting to string, numbers and bool by
// Rexx's rules (explicitly, or implicitly through dynamic).
//
// A .NetObject (phase C) is the .NET object itself wherever a result is
// typed object (dynamic, the indexer, foreach, Supplier, Send<T> / Run<T>);
// where the type is RexxObject (Send, Run...) it is a proxy whose NetValue is
// the .NET object.
using System;
using System.Collections;
using System.Collections.Generic;
using System.Dynamic;
using System.Globalization;
using System.Linq;
using System.Linq.Expressions;
using System.Threading;

namespace Rexx.Net;

public class RexxObject : DynamicObject, IEnumerable<object?>, IDisposable
{
    internal readonly RexxInterpreter? Rexx;
    readonly nint ptr;
    int disposed;

    internal RexxObject(RexxInterpreter? rexx, nint p) { Rexx = rexx; ptr = p; }

    /// The .NET object, when this Rexx object is a .NetObject (for a .NetType,
    /// its System.Type); null for any other Rexx object.
    public object? NetValue => Net;
    internal object? Net { get; init; }

    /// A result as .NET code wants it where any object fits: a .NetObject's
    /// proxy becomes its .NET object.
    internal static object? Unwrap(object? v) => v is RexxObject { Net: { } n } ? n : v;

    /// The interpreter instance this object lives in.
    public RexxInterpreter Interpreter => Rexx ?? throw new InvalidOperationException("this RexxString belongs to no interpreter");

    internal bool Disposed => Volatile.Read(ref disposed) != 0;

    /// The Rexx object (a global reference); a RexxString has none.
    internal nint Live
    {
        get
        {
            if (Disposed) throw new ObjectDisposedException(nameof(RexxObject), "this Rexx object was disposed");
            return ptr;
        }
    }

    // The receiver of a message, in this context.
    internal virtual nint Target(Ctx c) => Live;

    /// Releases the Rexx object now (else the finalizer queues it).
    public void Dispose()
    {
        if (ptr == 0 || Interlocked.Exchange(ref disposed, 1) != 0) return;
        GC.SuppressFinalize(this);
        var r = Rexx!;
        if (r.IsDisposed) return;
        try { using var u = r.Context(); r.Drop(u.C, ptr); }
        catch (InvalidOperationException) { r.Queue(ptr); }          // no context possible now: later
    }

    ~RexxObject()
    {
        if (ptr != 0 && Volatile.Read(ref disposed) == 0) Rexx?.Queue(ptr);
    }

    // ------------------------------------------------------------- messages

    /// o~name(args...); its result (null for .nil or none).
    public RexxObject? Send(string name, params object?[] args) => (RexxObject?)SendRaw(name.ToUpperInvariant(), args);

    /// Send, the result converted (Send<int>, Send<string>...).
    public T Send<T>(string name, params object?[] args) => RexxConvert.To<T>(SendRaw(name.ToUpperInvariant(), args));

    /// Send, halted if cancel is cancelled (OperationCanceledException; its
    /// InnerException the RexxException 4.1), as Run and RexxRoutine.Call.
    public RexxObject? Send(string name, CancellationToken cancel, params object?[] args) =>
        (RexxObject?)Interpreter.Cancellable(cancel, () => SendRaw(name.ToUpperInvariant(), args));
    public T Send<T>(string name, CancellationToken cancel, params object?[] args) =>
        RexxConvert.To<T>(Interpreter.Cancellable(cancel, () => SendRaw(name.ToUpperInvariant(), args)));

    // ------------------------------------------- BSF4ooRexx's RexxProxy names

    // The methods of BSF4ooRexx's RexxProxy (Java), under the same names, as
    // ooRexx/Python has them: the name is any string (one held in a
    // variable, or one that is no C# name: "[]=", "||", "<>"), uppercased as
    // Send's. They are .NET methods, so through dynamic o.SendMessage(...)
    // never sends a Rexx message of that name; o.SendMessage("SendMessage")
    // does.

    /// o~name(args...): args an array (or none) of the arguments.
    public RexxObject? SendMessage(string name, params object?[]? args) => Send(name, args ?? Array.Empty<object?>());
    public RexxObject? SendMessage0(string name) => Send(name);
    public RexxObject? SendMessage1(string name, object? a1) => Send(name, a1);
    public RexxObject? SendMessage2(string name, object? a1, object? a2) => Send(name, a1, a2);
    public RexxObject? SendMessage3(string name, object? a1, object? a2, object? a3) => Send(name, a1, a2, a3);
    public RexxObject? SendMessage4(string name, object? a1, object? a2, object? a3, object? a4) => Send(name, a1, a2, a3, a4);
    public RexxObject? SendMessage5(string name, object? a1, object? a2, object? a3, object? a4, object? a5) => Send(name, a1, a2, a3, a4, a5);

    /// o~name:scope(args...): the method search starts at the class scope
    /// (one of the object's classes or superclasses), as Rexx's o~name:super.
    public RexxObject? SendMessageScope(string name, RexxClass scope, params object?[]? args) =>
        (RexxObject?)SendRaw(name.ToUpperInvariant(), args ?? Array.Empty<object?>(), scope);

    internal object? SendRaw(string name, object?[]? args, RexxClass? scope = null)
    {
        var r = Interpreter;
        using var u = r.Context();
        var c = u.C;
        nint target = Target(c), a = r.Args(c, args);
        nint result = scope == null ? c.Send(target, name, a) : c.SendScoped(target, name, scope.Live, a);
        c.ReleaseLocal(a);
        Done(c, target);
        r.Check(c);
        return r.Wrap(c, result);
    }

    // A receiver made for one message (a RexxString's) is released after it.
    internal void Done(Ctx c, nint target) { if (ptr == 0) c.ReleaseLocal(target); }

    /// o[index...] and o[index...] = value: Rexx's own [] and []= (1-based
    /// for Arrays). Typed object so that any value can be set; what it gets
    /// is a RexxObject (a RexxString for a string) or null.
    public object? this[params object?[] index]
    {
        get => Unwrap(SendRaw("[]", index));
        set
        {
            var a = new object?[index.Length + 1];
            a[0] = value;
            Array.Copy(index, 0, a, 1, index.Length);
            SendRaw("[]=", a);
        }
    }

    /// Whether the object is an instance of the class (IsInstanceOf).
    public bool Is(RexxClass cls)
    {
        var r = Interpreter;
        using var u = r.Context();
        nint t = Target(u.C);
        bool b = u.C.IsInstanceOf(t, cls.Live);
        Done(u.C, t);
        return b;
    }

    /// Whether the object has a method of that name.
    public bool HasMethod(string name)
    {
        var r = Interpreter;
        using var u = r.Context();
        nint t = Target(u.C);
        bool b = u.C.HasMethod(t, name.ToUpperInvariant());
        Done(u.C, t);
        return b;
    }

    /// o~string.
    public override string ToString()
    {
        if (Rexx == null || Disposed) return base.ToString()!;
        using var u = Rexx.Context();
        var c = u.C;
        nint t = Target(c);
        var s = c.ToStr(t);
        Done(c, t);
        Rexx.Check(c);
        return s;
    }

    /// o~supplier's (index, item) pairs, a snapshot.
    public IReadOnlyList<KeyValuePair<object?, object?>> Supplier()
    {
        var r = Interpreter;
        using var u = r.Context();
        var c = u.C;
        nint t = Target(c), none = c.NewArray(0);
        nint s = c.Send(t, "SUPPLIER", none);
        c.ReleaseLocal(none);
        Done(c, t);
        r.Check(c);
        var list = new List<KeyValuePair<object?, object?>>();
        while (c.SupplierAvailable(s))
        {
            list.Add(new(Unwrap(r.Wrap(c, c.SupplierIndex(s))), Unwrap(r.Wrap(c, c.SupplierItem(s)))));
            c.SupplierNext(s);
            r.Check(c);
        }
        c.ReleaseLocal(s);
        return list;
    }

    /// foreach: the items of o~supplier (a snapshot).
    public IEnumerator<object?> GetEnumerator() => Supplier().Select(p => p.Value).GetEnumerator();
    IEnumerator IEnumerable.GetEnumerator() => GetEnumerator();

    // -------------------------------------------------------------- dynamic

    public override bool TryGetMember(GetMemberBinder binder, out object? result)
    {
        result = Unwrap(SendRaw(binder.Name.ToUpperInvariant(), null));
        return true;
    }

    public override bool TrySetMember(SetMemberBinder binder, object? value)
    {
        SendRaw(binder.Name.ToUpperInvariant() + "=", new[] { value });
        return true;
    }

    public override bool TryInvokeMember(InvokeMemberBinder binder, object?[]? args, out object? result)
    {
        if (binder.CallInfo.ArgumentNames.Count > 0)
            throw new NotSupportedException("named arguments cannot be sent to Rexx (ooRexx's API has none)");
        result = Unwrap(SendRaw(binder.Name.ToUpperInvariant(), args));
        return true;
    }

    public override bool TryGetIndex(GetIndexBinder binder, object?[] indexes, out object? result)
    {
        result = Unwrap(SendRaw("[]", indexes));
        return true;
    }

    public override bool TrySetIndex(SetIndexBinder binder, object?[] indexes, object? value)
    {
        var a = new object?[indexes.Length + 1];
        a[0] = value;
        Array.Copy(indexes, 0, a, 1, indexes.Length);
        SendRaw("[]=", a);
        return true;
    }

    static readonly Dictionary<ExpressionType, string> binary = new()
    {
        [ExpressionType.Add] = "+", [ExpressionType.Subtract] = "-", [ExpressionType.Multiply] = "*",
        [ExpressionType.Divide] = "/", [ExpressionType.Modulo] = "//", [ExpressionType.Power] = "**",
        [ExpressionType.Equal] = "==", [ExpressionType.NotEqual] = "\\==",
        [ExpressionType.LessThan] = "<", [ExpressionType.LessThanOrEqual] = "<=",
        [ExpressionType.GreaterThan] = ">", [ExpressionType.GreaterThanOrEqual] = ">=",
        [ExpressionType.And] = "&", [ExpressionType.Or] = "|", [ExpressionType.ExclusiveOr] = "&&",
        [ExpressionType.AddAssign] = "+", [ExpressionType.SubtractAssign] = "-", [ExpressionType.MultiplyAssign] = "*",
        [ExpressionType.DivideAssign] = "/", [ExpressionType.ModuloAssign] = "//",
    };

    public override bool TryBinaryOperation(BinaryOperationBinder binder, object? arg, out object? result)
    {
        if (!binary.TryGetValue(binder.Operation, out var op)) { result = null; return false; }
        result = Unwrap(SendRaw(op, new[] { arg }));
        return true;
    }

    public override bool TryUnaryOperation(UnaryOperationBinder binder, out object? result)
    {
        switch (binder.Operation)
        {
            case ExpressionType.Negate: result = Unwrap(SendRaw("-", null)); return true;
            case ExpressionType.UnaryPlus: result = Unwrap(SendRaw("+", null)); return true;
            case ExpressionType.Not: result = Unwrap(SendRaw("\\", null)); return true;
            case ExpressionType.IsTrue: result = RexxConvert.ToBool(ToString()); return true;
            case ExpressionType.IsFalse: result = !RexxConvert.ToBool(ToString()); return true;
        }
        result = null;
        return false;
    }

    public override bool TryConvert(ConvertBinder binder, out object? result)
    {
        result = RexxConvert.To(this, binder.Type);
        return true;
    }
}

/// A Rexx string: its value, copied. Equal by value (Rexx's strict ==).
public sealed class RexxString : RexxObject, IEquatable<RexxString>, IConvertible
{
    public string Value { get; }

    /// A Rexx string not yet tied to an instance (its operators need one).
    public RexxString(string value) : base(null, 0) { Value = value; }
    internal RexxString(string value, RexxInterpreter? rexx) : base(rexx, 0) { Value = value; }

    internal override nint Target(Ctx c) => c.Str(Value);

    public override string ToString() => Value;
    public bool Equals(RexxString? other) => other is not null && other.Value == Value;
    public override bool Equals(object? obj) => obj is RexxString s ? s.Value == Value : obj is string t && t == Value;
    public override int GetHashCode() => Value.GetHashCode();
    public static bool operator ==(RexxString? a, RexxString? b) => a is null ? b is null : a.Equals(b);
    public static bool operator !=(RexxString? a, RexxString? b) => !(a == b);

    // Explicit only: with dynamic, C#'s own binding comes before the object's,
    // and an implicit string conversion would make d + 1 a concatenation
    // ("150" + 1 = "1501") instead of Rexx's +. Through dynamic, string s =
    // d.Balance and int n = d.Balance still work (TryConvert).
    public static explicit operator string(RexxString s) => s.Value;
    public static explicit operator int(RexxString s) => (int)RexxConvert.To(s, typeof(int))!;
    public static explicit operator long(RexxString s) => (long)RexxConvert.To(s, typeof(long))!;
    public static explicit operator double(RexxString s) => (double)RexxConvert.To(s, typeof(double))!;
    public static explicit operator decimal(RexxString s) => (decimal)RexxConvert.To(s, typeof(decimal))!;
    public static explicit operator bool(RexxString s) => RexxConvert.ToBool(s.Value);
    public static explicit operator char(RexxString s) => (char)RexxConvert.To(s, typeof(char))!;

    // IConvertible: Convert.ToInt32(s) and friends, by Rexx's rules. Its
    // type code is String: VB's late binding (Dim n As Integer = o.Balance)
    // converts by the type code, and a String's it converts from its text.
    TypeCode IConvertible.GetTypeCode() => TypeCode.String;
    object IConvertible.ToType(Type t, IFormatProvider? p) => RexxConvert.To(this, t)!;
    bool IConvertible.ToBoolean(IFormatProvider? p) => RexxConvert.ToBool(Value);
    char IConvertible.ToChar(IFormatProvider? p) => (char)this;
    sbyte IConvertible.ToSByte(IFormatProvider? p) => (sbyte)RexxConvert.To(this, typeof(sbyte))!;
    byte IConvertible.ToByte(IFormatProvider? p) => (byte)RexxConvert.To(this, typeof(byte))!;
    short IConvertible.ToInt16(IFormatProvider? p) => (short)RexxConvert.To(this, typeof(short))!;
    ushort IConvertible.ToUInt16(IFormatProvider? p) => (ushort)RexxConvert.To(this, typeof(ushort))!;
    int IConvertible.ToInt32(IFormatProvider? p) => (int)this;
    uint IConvertible.ToUInt32(IFormatProvider? p) => (uint)RexxConvert.To(this, typeof(uint))!;
    long IConvertible.ToInt64(IFormatProvider? p) => (long)this;
    ulong IConvertible.ToUInt64(IFormatProvider? p) => (ulong)RexxConvert.To(this, typeof(ulong))!;
    float IConvertible.ToSingle(IFormatProvider? p) => (float)RexxConvert.To(this, typeof(float))!;
    double IConvertible.ToDouble(IFormatProvider? p) => (double)this;
    decimal IConvertible.ToDecimal(IFormatProvider? p) => (decimal)this;
    DateTime IConvertible.ToDateTime(IFormatProvider? p) => (DateTime)RexxConvert.To(this, typeof(DateTime))!;
    string IConvertible.ToString(IFormatProvider? p) => Value;
}

/// A Rexx class: New(args) is ~new.
public sealed class RexxClass : RexxObject
{
    internal RexxClass(RexxInterpreter rexx, nint p) : base(rexx, p) { }
    public RexxObject? New(params object?[] args) => Send("NEW", args);
    /// The class's id ("Account").
    public string Name => Send<string>("ID");
    /// Its (first) superclass; null for Object.
    public RexxClass? SuperClass => Send("SUPERCLASS") as RexxClass;
}

/// A Rexx routine: Call(args), or r(args) through dynamic.
public sealed class RexxRoutine : RexxObject
{
    internal RexxRoutine(RexxInterpreter rexx, nint p) : base(rexx, p) { }

    public RexxObject? Call(params object?[] args) => (RexxObject?)CallRaw(args);
    public T Call<T>(params object?[] args) => RexxConvert.To<T>(CallRaw(args));

    /// Call, halted if cancel is cancelled (OperationCanceledException).
    public RexxObject? Call(CancellationToken cancel, params object?[] args) =>
        (RexxObject?)Interpreter.Cancellable(cancel, () => CallRaw(args));
    public T Call<T>(CancellationToken cancel, params object?[] args) =>
        RexxConvert.To<T>(Interpreter.Cancellable(cancel, () => CallRaw(args)));

    internal object? CallRaw(object?[]? args)
    {
        var r = Interpreter;
        using var u = r.Context();
        var c = u.C;
        nint a = r.Args(c, args);
        nint result = c.CallRoutine(Live, a);
        c.ReleaseLocal(a);
        r.Check(c);
        return r.Wrap(c, result);
    }

    public override bool TryInvoke(InvokeBinder binder, object?[]? args, out object? result)
    {
        result = Unwrap(CallRaw(args));
        return true;
    }
}

/// A Rexx package: its classes and routines.
public sealed class RexxPackage : RexxObject
{
    internal RexxPackage(RexxInterpreter rexx, nint p) : base(rexx, p) { }

    /// The package's name (its file, or the name given).
    public string Name => Send<string>("NAME");

    /// A class this package defines or can see (its ::requires); null if none.
    public RexxClass? FindClass(string name)
    {
        var r = Interpreter;
        using var u = r.Context();
        var c = u.C;
        nint k = c.FindPackageClass(Live, name.ToUpperInvariant());
        r.Check(c);
        return r.Wrap(c, k) as RexxClass;
    }

    public IReadOnlyDictionary<string, RexxObject?> Classes => Directory(ThreadInterface.GetPackageClasses);
    public IReadOnlyDictionary<string, RexxObject?> PublicClasses => Directory(ThreadInterface.GetPackagePublicClasses);
    public IReadOnlyDictionary<string, RexxObject?> Routines => Directory(ThreadInterface.GetPackageRoutines);
    public IReadOnlyDictionary<string, RexxObject?> PublicRoutines => Directory(ThreadInterface.GetPackagePublicRoutines);

    IReadOnlyDictionary<string, RexxObject?> Directory(int slot)
    {
        RexxObject d;
        {
            var r = Interpreter;
            using var u = r.Context();
            var c = u.C;
            nint p = c.PackageDirectory(slot, Live);
            r.Check(c);
            d = (RexxObject)r.Wrap(c, p)!;
        }
        using (d)
            return d.Supplier().ToDictionary(p => p.Key?.ToString() ?? "", p => (RexxObject?)p.Value);
    }
}

/// Rexx values to .NET types, by Rexx's rules.
public static class RexxConvert
{
    static readonly CultureInfo Inv = CultureInfo.InvariantCulture;

    public static T To<T>(object? v) => (T)To(v, typeof(T))!;

    /// v (a Rexx result: null, a RexxString, a RexxObject) as a t.
    public static object? To(object? v, Type t)
    {
        // A .NetObject: its .NET object, unless its proxy is what is asked for
        if (v is RexxObject { Net: { } net } && (t == typeof(object) || !t.IsInstanceOfType(v))) v = net;
        var under = Nullable.GetUnderlyingType(t);
        if (v == null)
        {
            if (!t.IsValueType || under != null) return null;
            throw new InvalidCastException($"Rexx gave .nil or nothing; a {t.Name} is needed");
        }
        if (t.IsInstanceOfType(v) && t != typeof(object) || t == typeof(object)) return v;
        // A StringTable or Directory where a dictionary with string keys is asked for: a copy
        if (v is RexxObject ro && v is not RexxString && Conv.DictionaryOf(t) is Type vt)
        {
            if (Conv.IsMap(ro)) return Conv.DictionaryCopy(ro.Supplier(), vt, ro);
            throw new InvalidCastException($"a Rexx object ({v}) is not a {t.Name}: only a StringTable or a Directory becomes a dictionary");
        }
        // A one-dimensional Rexx Array where a .NET array or list is asked for: a copy
        if (v is RexxObject ra && v is not RexxString && Conv.SequenceOf(t) is Type et)
        {
            if (Conv.IsRexxArray(ra)) return Conv.ArrayCopy(ra, t, et);
            throw new InvalidCastException($"a Rexx object ({v}) is not a {t.Name}: only a Rexx Array becomes a .NET array or list");
        }
        if (under != null) t = under;
        var s = v is RexxString rs ? rs.Value : t == typeof(string) ? v.ToString() : null;
        if (s == null) throw new InvalidCastException($"a Rexx object ({v}) is not a {t.Name}");
        if (t == typeof(string)) return s;
        if (t == typeof(bool)) return ToBool(s);
        if (t == typeof(char))
            return s.Length == 1 ? s[0] : throw new InvalidCastException($"\"{s}\" is not one character");
        if (t.IsEnum) return Enum.Parse(t, s.Trim(), true);
        if (t == typeof(DateTime)) return DateTime.Parse(s, Inv);
        if (t == typeof(TimeSpan)) return TimeSpan.Parse(s, Inv);
        if (t == typeof(Guid)) return Guid.Parse(s);
        // a double or float: read as one, not through a decimal (which made
        // anything below 1E-28 zero: 5E-324, 1E-30); NaN and the infinities by
        // name, as ooRexx writes them (nan, +infinity, -infinity; .NET's own
        // spellings too: oorexx-bridges, topics/float-text.md, point 6)
        if (t == typeof(double))
        {
            if (FloatName(s) is double named) return named;
            double d = double.Parse(RexxNumber(s), NumberStyles.Float, Inv);
            return double.IsInfinity(d) ? throw new InvalidCastException($"{s} is too large for a Double") : d;
        }
        if (t == typeof(float))
        {
            if (FloatName(s) is double named) return (float)named;
            float f = float.Parse(RexxNumber(s), NumberStyles.Float, Inv);
            return float.IsInfinity(f) ? throw new InvalidCastException($"{s} is too large for a Single") : f;
        }
        var n = Number(s);
        if (t == typeof(decimal)) return n is decimal m ? m : throw new InvalidCastException($"{s} is too large for a Decimal");
        if (t == typeof(System.Numerics.BigInteger) || Conv.IsNumber(t))
        {
            // exactly: "1E-999" is no whole number (a decimal would read it as 0)
            if (!Conv.TryWhole(s.Trim(), out var whole))
                throw new InvalidCastException($"{s} is not a whole number, as a {t.Name} needs");
            if (t == typeof(System.Numerics.BigInteger)) return whole;
            return Conv.IntegerOf(whole, t) ?? throw new InvalidCastException($"{s} does not fit in a {t.Name}");
        }
        throw new InvalidCastException($"a Rexx string cannot become a {t.Name}");
    }

    /// Rexx's logical values: 1 and 0 (blanks around allowed); nothing else.
    public static bool ToBool(string s)
    {
        var t = s.Trim();
        if (t == "1") return true;
        if (t == "0") return false;
        throw new InvalidCastException($"\"{s}\" is not a Rexx logical value (1 or 0)");
    }

    // A Rexx number: blanks around, a sign (blanks after it allowed), digits
    // with an optional point, an optional exponent. A decimal when it fits,
    // else a double.
    static double? FloatName(string s) => s.Trim().ToLowerInvariant() switch
    {
        "nan" => double.NaN,
        "+infinity" or "infinity" => double.PositiveInfinity,
        "-infinity" => double.NegativeInfinity,
        _ => null,
    };

    static object Number(string s)
    {
        var t = RexxNumber(s);
        if (decimal.TryParse(t, NumberStyles.Float, Inv, out var m)) return m;
        return double.Parse(t, NumberStyles.Float, Inv);
    }

    // s if it is a Rexx number (blanks around, and after a sign, removed);
    // else an InvalidCastException
    static string RexxNumber(string s)
    {
        var t = s.Trim();
        if (t.Length > 1 && (t[0] == '+' || t[0] == '-')) t = t[0] + t.Substring(1).TrimStart();
        bool ok = t.Length > 0;
        int i = 0;
        if (ok && (t[0] == '+' || t[0] == '-')) i++;
        int digits = 0;
        while (i < t.Length && char.IsAsciiDigit(t[i])) { i++; digits++; }
        if (i < t.Length && t[i] == '.') { i++; while (i < t.Length && char.IsAsciiDigit(t[i])) { i++; digits++; } }
        if (digits == 0) ok = false;
        if (ok && i < t.Length && (t[i] == 'e' || t[i] == 'E'))
        {
            i++;
            if (i < t.Length && (t[i] == '+' || t[i] == '-')) i++;
            int e = 0;
            while (i < t.Length && char.IsAsciiDigit(t[i])) { i++; e++; }
            if (e == 0) ok = false;
        }
        if (!ok || i != t.Length) throw new InvalidCastException($"\"{s}\" is not a Rexx number");
        return t;
    }
}
