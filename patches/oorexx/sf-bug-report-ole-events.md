# SourceForge bug report — ready to paste

Tracker: <https://sourceforge.net/p/oorexx/bugs/new/>

| Field | Value |
|---|---|
| **Title** | OLEObject events: the event method gets its arguments in reverse order, and out parameters are not given back |
| **Milestone** | 5.3.0 |
| **Priority** | 5 |
| **Labels** | windows, ole |
| **Attachments** | `ole-events-repro.rex` |

## Description (Markdown, paste as is)

An `.OLEObject` created with `"WITHEVENTS"` calls its methods named after the events, but with the event's arguments **in reverse order** when the event source passes them positionally, as COM sources usually do. The attached program shows it with `ADODB.Recordset` (present on every Windows; its events come synchronously, during the call that raises them).

ADO declares `WillMove([in] adReason, [in, out] adStatus*, [in] pRecordset)`. On `MoveFirst` the method should get `12, 1, <the Recordset>`; it gets them the other way round:

```
1. The order of the arguments (MoveFirst)
   WillMove got 3 arguments (expected: 12, 1, an OLEObject):
     arg 1: an OLEObject
     arg 2: 1
     arg 3: 12
```

(Seen with ooRexx 5.3.0 r13267, 64-bit, Windows 11.)

**Where.** `extensions/platform/windows/ole/events.cpp`, `OLEObjectEvent::Invoke`, converts `pDispParams->rgvarg[i]` into argument `i + 1`. COM passes positional arguments in reverse order (`rgvarg[0]` is the last one), and named arguments (`cNamedArgs`, `rgdispidNamedArgs`) first, so argument `k` (from 0) is `rgvarg[cArgs - 1 - k]` when there are no named ones. The same loop then looks for out parameters with `pList->pusOptFlags[i]`, which is in declaration order, and writes the method's return value into `rgvarg[i]`, which is in reverse order: with more than one parameter, the value goes into the wrong argument.

**Out parameters.** Related, and less clear to us: returning a value for an out parameter does not reach the event's source.

- In the attached program, part 2 returns 4 (`adStatusCancel`) for `adStatus`. The `MoveNext` should then fail as cancelled; on our machine the program ended there without any further output.
- With Excel, `WorkbookBeforeClose(Wb, Cancel)` on an `.OLEObject` of `Excel.Application`: returning `.true` does not stop the workbook from closing. Excel's arguments did arrive in order there; perhaps Excel passes them as named arguments.

The second point may be a separate problem; we report it here because it is the same code path.

A patch for the order (positional and named arguments, and the out parameters' positions) can follow if wanted.
