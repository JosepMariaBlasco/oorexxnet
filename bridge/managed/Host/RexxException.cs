// A Rexx condition that ended a call made from .NET (Run, Send, a class's
// New...), or a Rexx callback (Callbacks.cs). notes/rexx-from-net-design.md,
// Errors.
using System;
using System.Collections.Generic;
using System.Linq;

namespace Rexx.Net;

public sealed class RexxException : Exception
{
    /// "SYNTAX", "HALT", ...
    public string ConditionName { get; }
    /// The error code, "88.900" (empty for a condition other than SYNTAX).
    public string Code { get; }
    /// The error number, 88.
    public int Rc { get; }
    /// The major error text ("Execution error").
    public string ErrorText { get; }
    /// The program and line where the condition was raised.
    public string Program { get; }
    public int Line { get; }
    /// The Rexx traceback, as Rexx shows it (lines joined by \n).
    public string Traceback { get; }
    /// The condition object (condition("O")), when the call was made from
    /// .NET (null for a callback's condition: rexxnet keeps that one).
    public RexxObject? Condition { get; }
    /// True for a condition that was thrown (THROW, or the Throw API: it
    /// goes from caller to caller until something catches it), false for one
    /// that was raised (RAISE, or the interpreter). Its condition object's
    /// THROWN entry; a SYNTAX error the interpreter raised is false.
    public bool Thrown { get; init; }
    /// The condition's description (DESCRIPTION, condition("D")), or null:
    /// none, a null string, or not a String.
    public string? Description { get; init; }
    internal readonly int ConditionId;            // rexxnet keeps the condition, to raise it again in Rexx
    /// What the call that left the condition answered: a RAISE ... RETURN
    /// value (a condition other than SYNTAX: the Rexx code went on and
    /// returned it). Raised again in Rexx, the call there answers it, as in
    /// plain Rexx when the condition is not trapped or a CALL ON resumes.
    internal object? Returned { get; init; }

    internal RexxException(string message, Exception? inner, string name, string code, int rc,
                           string errorText, string program, int line, string traceback, int conditionId,
                           RexxObject? condition = null)
        : base(message, inner)
    {
        ConditionName = name; Code = code; Rc = rc; ErrorText = errorText;
        Program = program; Line = line; Traceback = traceback; ConditionId = conditionId;
        Condition = condition;
    }

    // A condition that .NET code throws to its Rexx caller (Throw): what the
    // bridge throws there. ThrowRc: the RC as Rexx text, or null.
    internal bool ThrowRequested { get; private init; }
    internal string? ThrowRc { get; private init; }
    internal object? ThrowAdditional { get; private init; }

    static readonly HashSet<string> throwable =
        new(StringComparer.Ordinal) { "ERROR", "FAILURE", "HALT", "LOSTDIGITS", "NOMETHOD", "NOSTRING", "NOTREADY", "NOVALUE", "SYNTAX" };

    /// A Rexx condition for .NET code to throw to its Rexx caller, as the
    /// THROW instruction would throw it there: <c>throw
    /// RexxException.Throw("USER BADCONFIG", description: "no port")</c>.
    /// The arguments are THROW's, in its order (and the Throw API's):
    /// condition, a name THROW takes ("ERROR", "FAILURE", "HALT",
    /// "LOSTDIGITS", "NOMETHOD", "NOSTRING", "NOTREADY", "NOVALUE",
    /// "SYNTAX", or "USER" and a name); rc, needed for ERROR, FAILURE and
    /// SYNTAX and for no other (for SYNTAX the error code as Rexx writes it,
    /// "40.1"); the description; additional, any value (a one-dimensional
    /// .NET array is a Rexx Array of its items: SYNTAX's substitution
    /// values). The Rexx caller gets it as a thrown condition (THROWN 1):
    /// CATCH clauses and SIGNAL ON catch it however many callers up;
    /// uncaught, it is Error 4.901. .NET code on the way catches it as any
    /// RexxException. Needs ooRexx 5.3.0 r13546 or later (THROW); on an
    /// older ooRexx it is SYNTAX 98.900. ArgumentException for a name or an
    /// rc that THROW would not take.
    public static RexxException Throw(string condition, object? rc = null, string? description = null, object? additional = null)
    {
        ArgumentNullException.ThrowIfNull(condition);
        var words = condition.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries);
        string name = string.Join(" ", words).ToUpperInvariant();
        if (words.Length == 0)
            throw new ArgumentException("RexxException.Throw: no condition name", nameof(condition));
        if (name.StartsWith("USER", StringComparison.Ordinal) && words[0].Length == 4)
        {
            if (words.Length != 2 || !IsSymbol(words[1]))
                throw new ArgumentException($"RexxException.Throw: USER needs one condition name, a Rexx symbol; found \"{condition}\"", nameof(condition));
        }
        else if (words.Length != 1 || !throwable.Contains(name))
            throw new ArgumentException($"RexxException.Throw: \"{condition}\" is no condition THROW takes (ERROR, FAILURE, HALT, LOSTDIGITS, " +
                                        "NOMETHOD, NOSTRING, NOTREADY, NOVALUE, SYNTAX, or USER and a name)", nameof(condition));
        bool needsRc = name is "ERROR" or "FAILURE" or "SYNTAX";
        string? rcText = rc == null ? null : Convert.ToString(rc, System.Globalization.CultureInfo.InvariantCulture);
        if (needsRc && string.IsNullOrEmpty(rcText))
            throw new ArgumentException($"RexxException.Throw: {name} needs an rc", nameof(rc));
        if (!needsRc && rc != null)
            throw new ArgumentException($"RexxException.Throw: {name} takes no rc (only ERROR, FAILURE and SYNTAX do)", nameof(rc));
        string code = "";
        int number = 0;
        if (rcText != null)
        {
            string major = name == "SYNTAX" ? rcText.Split('.')[0] : rcText;
            int.TryParse(major, System.Globalization.NumberStyles.Integer, System.Globalization.CultureInfo.InvariantCulture, out number);
            if (name == "SYNTAX") code = rcText;
        }
        return new RexxException(description is { Length: > 0 } ? description : name, null, name, code, number, "", "", 0, "", 0)
               { Thrown = true, Description = description is { Length: > 0 } ? description : null,
                 ThrowRequested = true, ThrowRc = rcText, ThrowAdditional = additional };
    }

    static bool IsSymbol(string s) =>
        s.Length > 0 && s.All(ch => char.IsAsciiLetterOrDigit(ch) || ch is '.' or '!' or '?' or '_');

    /// The RexxException.Throw that a .NET call made from Rexx let through
    /// (looked for as Raised looks), or null.
    internal static RexxException? ThrowOf(Exception e)
    {
        for (Exception? x = e; x != null; )
        {
            if (x is RexxException re) return re.ThrowRequested ? re : null;
            x = x is AggregateException ae ? (ae.InnerExceptions.Count == 1 ? ae.InnerExceptions[0] : null)
              : x.InnerException;
        }
        return null;
    }

    public override string ToString() =>
        $"Rexx.Net.RexxException: {(Code.Length > 0 ? "Error " + Code : ConditionName)} in {Program} line {Line}: {Message}" +
        (Traceback.Length > 0 ? Environment.NewLine + Traceback : "") +
        (InnerException != null ? Environment.NewLine + " ---> " + InnerException : "");

    internal static string FormatCode(long code) => $"{code / 1000}.{code % 1000}";      // "98.900", "35.1", as Rexx writes them

    /// The pending condition of the context, as an exception (and cleared).
    internal static unsafe RexxException FromPending(RexxInterpreter rexx, Ctx c, nint returned = 0)
    {
        nint info = c.ConditionInfo();
        RexxConditionData k;
        c.Decode(info, &k);
        c.ClearCondition();
        string name = k.conditionName != 0 ? c.StrValue(k.conditionName) : "SYNTAX";
        string message = k.message != 0 ? c.StrValue(k.message) : k.errortext != 0 ? c.StrValue(k.errortext) : name;
        string code = name == "SYNTAX" ? FormatCode(k.code) : "";
        var lines = new List<string>();
        nint tb = c.DirectoryAt(info, "TRACEBACK");
        if (tb != 0 && tb != c.Nil)
        {
            nint none = c.NewArray(0);
            nint a = c.Send(tb, "MAKEARRAY", none);
            c.ReleaseLocal(none);
            if (!c.CheckCondition() && a != 0)
            {
                for (int i = 1, n = c.ArraySize(a); i <= n; i++)
                {
                    nint l = c.ArrayAt(a, i);
                    if (l != 0) { lines.Add(c.ToStr(l)); c.ReleaseLocal(l); }
                }
                c.ReleaseLocal(a);
            }
            else c.ClearCondition();
            c.ReleaseLocal(tb);
        }
        string errorText = k.errortext != 0 ? c.StrValue(k.errortext) : "", program = k.program != 0 ? c.StrValue(k.program) : "";
        // Round trip: a .NET exception that went to Rexx as 98.900 (a .NET
        // method called from Rexx threw) is the InnerException.
        Exception? inner = null;
        if (code == "98.900" && k.additional != 0 && c.ArraySize(k.additional) >= 2)
        {
            nint x = c.ArrayAt(k.additional, 2);
            if (x != 0) { inner = rexx.NetOf(c, x) as Exception; c.ReleaseLocal(x); }
        }
        string? description = k.description != 0 && c.IsString(k.description) ? c.StrValue(k.description) : null;
        foreach (var x in new[] { k.conditionName, k.message, k.errortext, k.program, k.description, k.additional })
            if (x != 0) c.ReleaseLocal(x);                // DecodeConditionInfo's local references
        nint thrown = c.DirectoryAt(info, "THROWN");          // (RFE #31)
        bool isThrown = thrown != 0 && thrown == c.True;
        if (thrown != 0) c.ReleaseLocal(thrown);
        var condition = rexx.Wrap(c, info) as RexxObject;
        return new RexxException(message, inner, name, code, (int)k.rc, errorText, program, (int)k.position,
                                 string.Join("\n", lines), 0, condition)
               { Returned = returned != 0 && returned != c.Nil && name != "SYNTAX" ? rexx.Wrap(c, returned) : null,
                 Thrown = isThrown, Description = description is { Length: > 0 } ? description : null };
    }

    /// The RexxException that a .NET call made from Rexx let through (Rexx
    /// code it called failed), looking through the whole chain of inner
    /// exceptions, as the callbacks' rule does (Callbacks.RexxCause): a
    /// wrapper may be the framework's (List.Sort wraps its comparer's
    /// exceptions), and the Rexx programmer wants their own error. It is
    /// raised again in Rexx as it was. Null if none, or one without
    /// its condition object.
    internal static RexxException? Raised(Exception e)
    {
        for (Exception? x = e; x != null; )
        {
            if (x is RexxException re) return re.ConditionId == 0 && re.Condition != null ? re : null;
            x = x is AggregateException ae ? (ae.InnerExceptions.Count == 1 ? ae.InnerExceptions[0] : null)  // several: no single cause
              : x.InnerException;
        }
        return null;
    }
}
