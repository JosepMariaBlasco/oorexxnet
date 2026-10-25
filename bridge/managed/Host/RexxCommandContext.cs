// .NET -> ooRexx: command environments (notes/rexx-from-net-design.md,
// "Command environments through ooRexx's .CommandHandler"). A .NET command
// handler is a command handler of ooRexx's (net.cls's .NetCommandHandler, a
// .CommandHandler): ooRexx sends it command(command, caller), caller a
// .CommandContext, and the handler gets the command and that context, as a
// RexxCommandContext: ooRexx's own object, with its names (in .NET's
// casing). What the handler returns is RC (null: 0); a .NET exception is
// SYNTAX 98.900, and a Rexx condition of Rexx code it called is raised again
// as itself, as for any .NET method that Rexx code calls.
//
// Also here: RexxCallContext, the base of what an application function gets.
using System;
using System.Collections.Generic;
using System.Linq;

namespace Rexx.Net;

/// The context of a command sent to a .NET command handler: ooRexx's own
/// .CommandContext (ooRexx r13288; the Open Object Rexx Reference describes
/// it), its members with their names in .NET's casing. Valid while the
/// command runs: from another thread its members raise SYNTAX 98.900, as
/// ooRexx's do, and once the handler has returned the bridge releases it
/// (ObjectDisposedException).
public sealed class RexxCommandContext
{
    readonly List<RexxObject> made = new();     // the streams, variables...: released with the context

    internal RexxCommandContext(RexxInterpreter rexx, RexxObject context) { Interpreter = rexx; Context = context; }

    // When the handler returns: the context and what it gave, released now
    // (a command makes a new context each time: left to the finalizer, they
    // would pile up).
    internal void End(object? result)
    {
        lock (made) { foreach (var o in made) if (!ReferenceEquals(o, result)) o.Dispose(); made.Clear(); }
        if (!ReferenceEquals(Context, result)) Context.Dispose();
    }

    RexxObject Keep(RexxObject? o)
    {
        if (o == null) throw new InvalidOperationException("the context gave no object");
        lock (made) made.Add(o);
        return o;
    }

    RexxObject? KeepOrNull(RexxObject? o) => o == null ? null : Keep(o);

    /// The instance whose Rexx code sent the command (to call Rexx code back).
    public RexxInterpreter Interpreter { get; }

    /// The .CommandContext itself.
    public RexxObject Context { get; }

    /// ENVIRONMENT: the name of the environment the command was sent to.
    public string Environment => Context.Send("ENVIRONMENT")?.ToString() ?? "";

    /// PENDING: the condition asked for with Raise, or null.
    public RexxObject? Pending => KeepOrNull(Context.Send("PENDING"));

    /// ISVALID: whether the command is still running.
    public bool IsValid => Truth(Context.Send("ISVALID"));

    /// ISREDIRECTED(kind): "Input", "Output", "Error", or "Same" (output and
    /// error to the same place).
    public bool IsRedirected(string kind) => Truth(Context.Send("ISREDIRECTED", kind));

    /// INPUT, OUTPUT, ERROR: the WITH redirection as streams (a .CommandInput,
    /// a .CommandOutput: Send("LINEIN"), Send("LINEOUT", line)...); without
    /// that redirection, SYNTAX 98.900. The console is Console.Out and
    /// Console.Error.
    public RexxObject Input => Keep(Context.Send("INPUT"));
    public RexxObject Output => Keep(Context.Send("OUTPUT"));
    public RexxObject Error => Keep(Context.Send("ERROR"));

    /// [] and []=: a variable of the code that sent the command (a variable
    /// with no value: its name, as in Rexx); a .NetObject's value is its
    /// .NET object.
    public object? this[string name]
    {
        get => RexxObject.Unwrap(Context.Send("[]", name));
        set => Context.Send("[]=", value, name);
    }

    /// GETVAR, SETVAR: synonyms of the indexer.
    public object? GetVar(string name) => this[name];
    public void SetVar(string name, object? value) => this[name] = value;

    /// HASVAR: whether the variable has a value.
    public bool HasVar(string name) => Truth(Context.Send("HASVAR", name));

    /// DROPVAR.
    public void DropVar(string name) => Context.Send("DROPVAR", name);

    /// VARIABLES: every variable of that code (a copy).
    public RexxObject Variables => Keep(Context.Send("VARIABLES"));

    /// RAISE: the condition the command raises when the handler returns (one
    /// per command); returns rc, so that "return ctx.Raise(...)" sets RC.
    public object? Raise(string condition, object? rc) => RexxObject.Unwrap(Context.Send("RAISE", condition, rc));
    public object? Raise(string condition, object? rc, object? description) =>
        RexxObject.Unwrap(Context.Send("RAISE", condition, rc, description));
    public object? Raise(string condition, object? rc, object? description, object? additional) =>
        RexxObject.Unwrap(Context.Send("RAISE", condition, rc, description, additional));

    /// RAISEERROR, RAISEFAILURE: Raise("ERROR", rc), Raise("FAILURE", rc).
    public object? RaiseError(object? rc) => RexxObject.Unwrap(Context.Send("RAISEERROR", rc));
    public object? RaiseFailure(object? rc) => RexxObject.Unwrap(Context.Send("RAISEFAILURE", rc));

    public override string ToString() => "a RexxCommandContext (" + Environment + ")";

    static bool Truth(RexxObject? v) => v?.ToString() == "1";
}

/// What an application function gets (RexxFunctionCall): the instance and
/// the calling Rexx code's variables. Valid only while its handler runs.
public abstract class RexxCallContext
{
    readonly ExitCtx x;
    bool live = true;

    private protected RexxCallContext(RexxInterpreter rexx, ExitCtx x) { Interpreter = rexx; this.x = x; }

    /// The instance whose Rexx code made the call.
    public RexxInterpreter Interpreter { get; }

    internal void End() => live = false;

    private protected Ctx C
    {
        get
        {
            if (!live) throw new InvalidOperationException($"a {GetType().Name} is valid only while its handler runs");
            return x.Thread;
        }
    }

    // ------------------------------------------------------------ variables

    /// A variable of the calling Rexx code (null if it has no value, or is
    /// .nil). Names as Rexx writes them, uppercased: "X", "STEM.", "STEM.1".
    /// Setting null drops nothing: it sets .nil (Drop drops).
    public object? this[string name]
    {
        get
        {
            var c = C;
            nint v = x.GetVariable(name.ToUpperInvariant());
            return v == 0 ? null : RexxObject.Unwrap(Interpreter.Wrap(c, v));     // a .NetObject: its .NET object
        }
        set
        {
            var c = C;
            nint v = Interpreter.ToRexx(c, value);
            x.SetVariable(name.ToUpperInvariant(), v);
            if (RexxInterpreter.IsNewLocal(value)) c.ReleaseLocal(v);
        }
    }

    /// Whether the variable has a value.
    public bool HasVariable(string name)
    {
        var c = C;
        nint v = x.GetVariable(name.ToUpperInvariant());
        if (v == 0) return false;
        c.ReleaseLocal(v);
        return true;
    }

    /// Drops the variable (DROP).
    public void Drop(string name) { _ = C; x.DropVariable(name.ToUpperInvariant()); }

    /// Every variable of the calling Rexx code, by name (a copy).
    public IReadOnlyDictionary<string, object?> Variables
    {
        get
        {
            var c = C;
            using var all = (RexxObject)Interpreter.Wrap(c, x.AllVariables())!;
            return all.Supplier().ToDictionary(p => p.Key?.ToString() ?? "", p => p.Value);
        }
    }
}
