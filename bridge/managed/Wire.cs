// Records exchanged with the native side: <tag><length>:<bytes>, the length in
// bytes of the UTF-8 payload (JDOR's format, as .JSObject). Request records:
//   S string   N nil (.nil)   O handle id   A list (payload: records)
//   L .true or .false themselves: "1" or "0", read as an S marked Logical
//   M a multidimensional Rexx Array: "d1,d2,...\t" + its items' records, in
//     Rexx's order (the first index fastest); read as an A with Dims
//   T typed: payload "kind\t" + one record (kind: a type name, "#id" of a
//     type handle, or "null")
//   R a .NetRef (ref / out argument): payload one record, its value
//   H a .NetHandler: "id\toptions" (options: words, "queued", "latest",
//     "released")
//   X any other Rexx object (phase C): its pointer, valid while the request
//     runs (a RexxObject in .NET)
//   G the same in a callback's result: "pointer\tinstance", a global
//     reference handed over to the managed side
// Response records: the same, plus
//   V void (no result)   P namespace (payload: its full name)
//   R a result with ref / out values: payload the result record, then one
//     record per R argument of the request, in order (their new values)
//   O "id\tkind\tdisplay" (kind o = object, t = type)
//   E "exceptionId\ttype\tmessage" (exceptionId 0, type empty: an error of
//     the bridge itself)
//   e a .NetEvent: "id\tkind\tdisplay\tname" (the event's owner, its name)
//   C a Rexx condition to raise again: "conditionId\tmessage"
//   X a Rexx object (a RexxObject that .NET gives back): its pointer, held
//     by a local reference of the request
//   K a Rexx condition already raised on the request's context (a
//     RexxException that the .NET code let through): rexxnet returns
// A Rexx handler's call (Callbacks.cs) sends rexxnet an A of the arguments
// and gets one record back: the result, V (none), X (no handler, no
// interpreter, or a condition reported because no Rexx caller waits) or
// E "conditionId\texceptionId\tname\tcode\trc\tline\tprogram\terrortext\t
// traceback\tmessage" (a Rexx condition; the traceback's lines joined by \n).
// The call's flags: 1 = no Rexx caller waits on this thread (report, X).
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;

namespace Rexx.Net;

/// One record of a request.
public sealed class Rec
{
    public char Tag;
    public string Text = "";
    public List<Rec> Items = new();
    public int[]? Dims;
    public bool Logical;                // S from .true or .false themselves (L)                 // A from a multidimensional Rexx Array (M): its dimensions; Items in Rexx's order
    public Rec? Inner;                  // T, R: the value
    internal RexxObject? Adopted;       // X, G: its proxy, made once (overloads try a record many times)
    internal bool? IsMap;               // X, G: a StringTable or a Directory? asked once
    internal IReadOnlyList<KeyValuePair<object?, object?>>? Pairs;   // X, G: its entries, read once

    public int Id => int.Parse(Text);
    public override string ToString() => Tag + ":" + Text;
}

public static class Wire
{
    public static List<Rec> Parse(ReadOnlySpan<byte> data)
    {
        var list = new List<Rec>();
        int i = 0;
        while (i < data.Length)
        {
            char tag = (char)data[i++];
            int len = 0;                                    // the decimal length, up to ':'
            while (i < data.Length && data[i] != (byte)':')
            {
                int d = data[i++] - '0';
                if ((uint)d > 9) throw new FormatException("bad record");
                len = len * 10 + d;
            }
            if (i >= data.Length) throw new FormatException("bad record");
            i++;
            var payload = data.Slice(i, len);
            i += len;
            var r = new Rec { Tag = tag };
            switch (tag)
            {
                case 'A': r.Items = Parse(payload); break;
                case 'L': r.Tag = 'S'; r.Logical = true; r.Text = Encoding.UTF8.GetString(payload); break;
                case 'M':                                   // "d1,d2,...\t" items: an A with dimensions
                {
                    int tab = payload.IndexOf((byte)'\t');
                    r.Tag = 'A';
                    r.Dims = Encoding.UTF8.GetString(payload.Slice(0, tab)).Split(',').Select(int.Parse).ToArray();
                    r.Items = Parse(payload.Slice(tab + 1));
                    break;
                }
                case 'R': r.Inner = Parse(payload)[0]; break;
                case 'T':
                {
                    int tab = payload.IndexOf((byte)'\t');
                    r.Text = Encoding.UTF8.GetString(payload.Slice(0, tab));
                    r.Inner = Parse(payload.Slice(tab + 1))[0];
                    break;
                }
                default: r.Text = Encoding.UTF8.GetString(payload); break;
            }
            list.Add(r);
        }
        return list;
    }
}

/// Builds a response.
public sealed class Writer
{
    readonly MemoryStream ms = new();
    public void Add(char tag, string payload) => Add(tag, Encoding.UTF8.GetBytes(payload));
    public void Add(char tag, byte[] payload)
    {
        ms.WriteByte((byte)tag);
        var len = Encoding.ASCII.GetBytes(payload.Length.ToString());
        ms.Write(len, 0, len.Length);
        ms.WriteByte((byte)':');
        ms.Write(payload, 0, payload.Length);
    }
    public byte[] ToArray() => ms.ToArray();
}
