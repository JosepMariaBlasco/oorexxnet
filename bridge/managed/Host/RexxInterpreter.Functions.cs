// .NET -> ooRexx: functions and VALUE selectors of the application
// (notes/rexx-from-net-design.md, "Application functions and values").
//
// rexx.AddFunction("name", handler): the Rexx code's name(args) or CALL name
// args calls handler on the Rexx thread, as a command handler is called. Its
// result is the function's. A typed delegate ((double a, double b) => ...)
// gets the arguments converted to its parameters' types (RexxConvert).
//
// rexx.AddValueSelector("APP", get, set): VALUE(name, , "APP") is get(name);
// VALUE(name, new, "APP") is get(name), then set(name, new).
//
// Both through system exits, set when the instance is created (an exit
// cannot be added later): RXOFNC (object-valued external functions) and
// RXVALUE. ooRexx asks RXOFNC only for a call that is no internal routine,
// built-in function or ::ROUTINE of the program (RexxActivation::
// externalCall): before external libraries and files, which an application
// function therefore hides. One fixed native entry for both, for every
// instance ([UnmanagedCallersOnly]); a name it does not know is "not
// handled", and ooRexx goes on as without the exit.
//
// Errors: a .NET exception raises SYNTAX 40.900 with its message ("Incorrect
// call to routine"); a RexxException out of Rexx code the handler called is
// raised again as itself; too few or too many arguments for a typed delegate
// are 40.3 / 40.4. Raised as command handlers raise conditions: recorded on
// the thread context, raised when the exit returns (never an unwinding API).
using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;

namespace Rexx.Net;

/// A call of an application function (RexxInterpreter.AddFunction). Valid
/// only while its handler runs.
public sealed class RexxFunctionCall : RexxCallContext
{
    internal RexxFunctionCall(RexxInterpreter rexx, ExitCtx x, string name, object?[] args, bool subroutine) : base(rexx, x)
    {
        Name = name; Arguments = args; IsSubroutine = subroutine;
    }

    /// The name as the Rexx code called it: uppercased, unless written as a
    /// literal string (CALL 'myFunc').
    public string Name { get; }

    /// The arguments, from the first (Rexx's arg(1)): a RexxString, a
    /// RexxObject, a .NET object (a .NetObject's), null (.nil), or
    /// RexxValue.Omitted for one left out (f(1, , 3)).
    public IReadOnlyList<object?> Arguments { get; }

    /// CALL name ...: no result is needed (one given goes to RESULT).
    public bool IsSubroutine { get; }

    /// Argument i (from 0) as a T, by Rexx's rules ("42" as an int); a
    /// missing or omitted one is fallback.
    public T Arg<T>(int i, T fallback = default!) =>
        i < Arguments.Count && !ReferenceEquals(Arguments[i], RexxValue.Omitted) ? RexxConvert.To<T>(Arguments[i]) : fallback;

    public override string ToString() => Name;
}

public sealed partial class RexxInterpreter
{
    // ------------------------------------------------------------ functions

    readonly Dictionary<string, Func<RexxFunctionCall, object?>> functions = new(StringComparer.OrdinalIgnoreCase);
    readonly Dictionary<string, (Func<string, object?> Get, Action<string, object?>? Set)> selectors = new(StringComparer.OrdinalIgnoreCase);

    /// What a handler returns for "no result" (a void delegate's call).
    internal static readonly object NoResult = new();

    void CanExtend()
    {
        if (disposed) throw new ObjectDisposedException(nameof(RexxInterpreter));
        if (guest) throw new InvalidOperationException("functions and VALUE selectors need an instance made by RexxInterpreter.Create " +
                                                       "(their exits are set when it is created); this one was made by ooRexx");
    }

    /// A function of the application: name(args) and CALL name args in the
    /// Rexx code call handler on the Rexx thread; its result is the
    /// function's (null: .nil). Names are not case-sensitive; adding a name
    /// again replaces its handler. A function of the program itself (an
    /// internal routine, a built-in function, a ::ROUTINE) wins; an external
    /// one of the same name (a library's, a file) is hidden.
    public void AddFunction(string name, Func<RexxFunctionCall, object?> handler)
    {
        ArgumentException.ThrowIfNullOrEmpty(name);
        ArgumentNullException.ThrowIfNull(handler);
        CanExtend();
        lock (functions) functions[name] = handler;
    }

    /// A function with no result (for CALL; as a function, Rexx's error 44).
    public void AddFunction(string name, Action<RexxFunctionCall> handler)
    {
        ArgumentNullException.ThrowIfNull(handler);
        AddFunction(name, f => { handler(f); return NoResult; });
    }

    /// A function from any delegate or method: (double a, double b) =>
    /// Math.Sqrt(a * a + b * b). The arguments are converted to its
    /// parameters' types by Rexx's rules (RexxConvert); a parameter with a
    /// default value may be left out; a params array takes the rest; a
    /// parameter of type RexxFunctionCall gets the call (and no argument).
    /// A void method has no result.
    public void AddFunction(string name, Delegate function)
    {
        ArgumentNullException.ThrowIfNull(function);
        if (function is Func<RexxFunctionCall, object?> f) { AddFunction(name, f); return; }
        var ps = function.Method.GetParameters();
        bool hasParams = ps.Length > 0 && ps[^1].IsDefined(typeof(ParamArrayAttribute), false);
        var takes = ps.Where(p => p.ParameterType != typeof(RexxFunctionCall)).ToList();
        int min = takes.Count(p => !p.HasDefaultValue && !p.IsDefined(typeof(ParamArrayAttribute), false));
        bool isVoid = function.Method.ReturnType == typeof(void);
        AddFunction(name, call =>
        {
            var args = call.Arguments;
            int given = args.Count;
            while (given > 0 && ReferenceEquals(args[given - 1], RexxValue.Omitted)) given--;
            if (!hasParams && given > takes.Count) throw new FunctionError(40004, call.Name, takes.Count.ToString());
            var values = new object?[ps.Length];
            int next = 0;
            for (int i = 0; i < ps.Length; i++)
            {
                var p = ps[i];
                if (p.ParameterType == typeof(RexxFunctionCall)) { values[i] = call; continue; }
                if (hasParams && i == ps.Length - 1)
                {
                    var et = p.ParameterType.GetElementType()!;
                    var rest = Array.CreateInstance(et, Math.Max(0, given - next));
                    for (int j = 0; next < given; j++, next++) rest.SetValue(Value(args[next], et, call, next), j);
                    values[i] = rest;
                    continue;
                }
                if (next < given && !ReferenceEquals(args[next], RexxValue.Omitted)) values[i] = Value(args[next], p.ParameterType, call, next);
                else if (p.HasDefaultValue) values[i] = p.DefaultValue;
                else if (next >= given) throw new FunctionError(40003, call.Name, min.ToString());
                else throw new FunctionError(40005, call.Name, (next + 1).ToString());      // an omitted required argument
                next++;
            }
            object? r;
            try { r = function.DynamicInvoke(values); }
            catch (TargetInvocationException e) when (e.InnerException != null)
            {
                System.Runtime.ExceptionServices.ExceptionDispatchInfo.Capture(e.InnerException).Throw();
                throw;
            }
            return isVoid ? NoResult : r;
        });
    }

    static object? Value(object? v, Type t, RexxFunctionCall call, int i)
    {
        try { return RexxConvert.To(v, t); }
        catch (Exception e) when (e is InvalidCastException or FormatException or OverflowException or ArgumentException)
        {
            throw new FunctionError(40900, $"{call.Name}, argument {i + 1}: {e.Message}");
        }
    }

    internal Func<RexxFunctionCall, object?>? FunctionHandler(string name)
    {
        if (functions.Count == 0) return null;
        lock (functions) return functions.TryGetValue(name, out var h) ? h : null;
    }

    /// A VALUE selector of the application: VALUE(name, , selector) is
    /// get(name); VALUE(name, newValue, selector) answers get(name) and then
    /// calls set(name, newValue) (no set: an error). The name is as the Rexx
    /// code gave it. Selectors are not case-sensitive; ooRexx's own
    /// (ENVIRONMENT...) win.
    public void AddValueSelector(string selector, Func<string, object?> get, Action<string, object?>? set = null)
    {
        ArgumentException.ThrowIfNullOrEmpty(selector);
        ArgumentNullException.ThrowIfNull(get);
        CanExtend();
        lock (selectors) selectors[selector] = (get, set);
    }

    internal (Func<string, object?> Get, Action<string, object?>? Set)? Selector(string name)
    {
        if (selectors.Count == 0) return null;
        lock (selectors) return selectors.TryGetValue(name, out var s) ? s : null;
    }
}

/// A SYNTAX error for the Rexx code that called an application function.
internal sealed class FunctionError : Exception
{
    public readonly long Code;
    public readonly string[] Substitutions;
    public FunctionError(long code, params string[] subs) : base(string.Join(" ", subs)) { Code = code; Substitutions = subs; }
}

internal static unsafe class Exits
{
    internal const int RXENDLST = 0, RXOFNC = 15, RXVALUE = 14;
    const int Handled = 0, NotHandled = 1;

    internal static nint Address => (nint)(delegate* unmanaged<nint, int, int, nint, int>)&Entry;

    // RXOFNCCAL_PARM: flags (4, padded to 8), CONSTANT_RXSTRING name
    // { size_t length; const char *ptr }, size_t argc, RexxObjectPtr *argv,
    // RexxObjectPtr retc
    [StructLayout(LayoutKind.Sequential)]
    struct FunctionParm
    {
        public uint flags; public uint pad;
        public nuint nameLength; public byte* name;
        public nuint argc; public nint* argv;
        public nint retc;
    }

    // RXVALCALL_PARM: selector, variable_name, value (in: the new value or
    // null; out: the value VALUE answers)
    [StructLayout(LayoutKind.Sequential)]
    struct ValueParm { public nint selector, name, value; }

    [UnmanagedCallersOnly]
    static int Entry(nint exitContext, int function, int subfunction, nint parm)
    {
        try
        {
            return function switch
            {
                RXOFNC => Function(new ExitCtx(exitContext), (FunctionParm*)parm),
                RXVALUE => Value(new ExitCtx(exitContext), (ValueParm*)parm),
                _ => NotHandled,
            };
        }
        catch (Exception) { return NotHandled; }      // nothing may unwind into the interpreter
    }

    static int Function(ExitCtx x, FunctionParm* p)
    {
        var c = x.Thread;
        var rexx = RexxInterpreter.Find(c.Instance);
        if (rexx == null) return NotHandled;
        string name = System.Text.Encoding.UTF8.GetString(p->name, (int)p->nameLength);
        var handler = rexx.FunctionHandler(name);
        if (handler == null) return NotHandled;
        var args = new object?[(int)p->argc];
        for (int i = 0; i < args.Length; i++)
            args[i] = p->argv[i] == 0 ? RexxValue.Omitted : RexxObject.Unwrap(rexx.Wrap(c, p->argv[i], borrowed: true));
        var call = new RexxFunctionCall(rexx, x, name, args, (p->flags & 4) != 0);
        rexx.PushFrame(c.P);
        try
        {
            object? r = handler(call);
            p->retc = ReferenceEquals(r, RexxInterpreter.NoResult) ? 0 : rexx.ToRexx(c, r);
        }
        catch (Exception e) { Fail(c, e); }
        finally
        {
            call.End();
            rexx.PopFrame(c.P);
        }
        return Handled;
    }

    static int Value(ExitCtx x, ValueParm* p)
    {
        var c = x.Thread;
        var rexx = RexxInterpreter.Find(c.Instance);
        if (rexx == null) return NotHandled;
        string selector = c.ToStr(p->selector);
        var s = rexx.Selector(selector);
        if (s == null) return NotHandled;
        string name = c.ToStr(p->name);
        rexx.PushFrame(c.P);
        try
        {
            if (p->value != 0 && s.Value.Set == null)
                throw new FunctionError(40900, $"VALUE: the selector {selector} cannot set {name}");
            object? old = s.Value.Get(name);
            if (p->value != 0) s.Value.Set!(name, RexxObject.Unwrap(rexx.Wrap(c, p->value, borrowed: true)));
            p->value = rexx.ToRexx(c, old);
        }
        catch (Exception e) { Fail(c, e); p->value = c.Nil; }
        finally { rexx.PopFrame(c.P); }
        return Handled;
    }

    // The error, recorded on the context and raised when the exit returns
    static void Fail(Ctx c, Exception e)
    {
        // a Rexx condition of Rexx code the function called (or of a
        // .NetHandler's method, which rexxnet holds): raised again as itself
        if ((RexxException.Raised(e) ?? Callbacks.RexxCause(e)) is RexxException re)
        {
            if (!Callbacks.RaiseHeld(c.P, re)) RexxInterpreter.RaiseAgain(re);
            return;
        }
        var (code, subs) = e is FunctionError fe ? (fe.Code, fe.Substitutions) : (40900L, new[] { e.Message });
        nint a = c.NewArray(subs.Length);
        for (int i = 0; i < subs.Length; i++) c.ArrayPut(a, c.Str(subs[i]), i + 1);
        c.RaiseException(code, a);
    }
}
