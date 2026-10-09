// A Rexx condition that ended a call made from .NET (Run, Send, a class's
// New...), or a Rexx callback (Callbacks.cs). notes/rexx-from-net-design.md,
// Errors.
using System;
using System.Collections.Generic;

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
    internal readonly int ConditionId;            // rexxnet keeps the condition, to raise it again in Rexx

    internal RexxException(string message, Exception? inner, string name, string code, int rc,
                           string errorText, string program, int line, string traceback, int conditionId,
                           RexxObject? condition = null)
        : base(message, inner)
    {
        ConditionName = name; Code = code; Rc = rc; ErrorText = errorText;
        Program = program; Line = line; Traceback = traceback; ConditionId = conditionId;
        Condition = condition;
    }

    public override string ToString() =>
        $"Rexx.Net.RexxException: {(Code.Length > 0 ? "Error " + Code : ConditionName)} in {Program} line {Line}: {Message}" +
        (Traceback.Length > 0 ? Environment.NewLine + Traceback : "") +
        (InnerException != null ? Environment.NewLine + " ---> " + InnerException : "");

    internal static string FormatCode(long code) => $"{code / 1000}.{code % 1000}";      // "98.900", "35.1", as Rexx writes them

    /// The pending condition of the context, as an exception (and cleared).
    internal static unsafe RexxException FromPending(RexxInterpreter rexx, Ctx c)
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
        foreach (var x in new[] { k.conditionName, k.message, k.errortext, k.program, k.description, k.additional })
            if (x != 0) c.ReleaseLocal(x);                // DecodeConditionInfo's local references
        var condition = rexx.Wrap(c, info) as RexxObject;
        return new RexxException(message, inner, name, code, (int)k.rc, errorText, program, (int)k.position,
                                 string.Join("\n", lines), 0, condition);
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
