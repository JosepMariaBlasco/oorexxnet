# SourceForge bug report — ready to paste

Tracker: <https://sourceforge.net/p/oorexx/bugs/new/>

| Field | Value |
|---|---|
| **Title** | OLEObject events: returning a value for an out parameter crashes the interpreter; arguments arrive in reverse order |
| **Milestone** | 5.3.0 |
| **Priority** | 7 |
| **Labels** | windows, ole |
| **Attachments** | `ole-events-crash.rex`, `ole-events-repro.rex` |

## Description (Markdown, paste as is)

Two problems in the event methods of an `.OLEObject` created with `"WITHEVENTS"`, both in `OLEObjectEvent::Invoke` (`extensions/platform/windows/ole/events.cpp`). The attached programs show them with `ADODB.Recordset`, present on every Windows, whose events come synchronously, during the call that raises them. ADO declares

```
WillMove([in] EventReasonEnum adReason, [in, out] EventStatusEnum* adStatus, [in] _Recordset* pRecordset)
```

Seen with ooRexx 5.3.0 trunk (`REXX-ooRexx_5.3.0(MT)_64-bit 6.06 9 Oct 2026`), Windows 11.

### 1. Returning a value for an out parameter crashes the interpreter

`ole-events-crash.rex MODE` adds two records with a `WillMove` method that returns nothing (`none`), returns 1 (`one`: `adStatusOK`, a valid value for `adStatus`), or only reads its arguments (`args`):

```
for %m in (none one args) do @rexx ole-events-crash.rex %m & echo %m: exit code %errorlevel%

none: done, 5 WillMove calls
none: exit code 0
one: exit code -1073741819
args: done, 5 WillMove calls
args: exit code 0
```

(-1073741819 is 0xC0000005, an access violation. Run it with `cmd /v:on` and `!errorlevel!` inside a FOR.)

The method's return value goes to the out parameter through `Rexx2Variant(context, rxResult, &pDispParams->rgvarg[i], pDispParams->rgvarg[i].vt, -1)`. There `rgvarg[i]` is `VT_BYREF | VT_I4`, pointing to the caller's storage. `Rexx2Variant` strips `VT_BYREF` and, for a number, ends in `VariantChangeType(pVariant, &sVariant, 0, VT_I4)`, which overwrites the caller's `VARIANT` itself with a `VT_I4` by value. The pointer is replaced by the value (1), the caller's storage never changes, and the caller then dereferences what it still takes for its pointer. (`VT_BOOL`, `VT_R8` and `VT_R4` are written through the pointer; the other types go through `VariantChangeType` like this.) A value for an out parameter should be converted into a temporary `VARIANT` and then stored through `V_BYREF(&rgvarg[i])` according to its `VT`, leaving `rgvarg[i]` as it was.

Related, not explained yet: with Excel, returning `.true` from `WorkbookBeforeClose(Wb, Cancel)` (a `VT_BOOL`) does not stop the workbook from closing either.

### 2. The arguments arrive in reverse order

`ole-events-repro.rex` prints `WillMove`'s arguments on `MoveFirst`. Expected `12, 1, <the Recordset>`; got (from an earlier version of the program, which also printed the Recordset's RecordCount):

```
WillMove got 3 arguments:
  arg 1: an OLEObject (RecordCount 2)
  arg 2: 1
  arg 3: 12
```

`OLEObjectEvent::Invoke` converts `pDispParams->rgvarg[i]` into argument `i + 1`. COM passes positional arguments in reverse order (`rgvarg[0]` is the last one), and named arguments (`cNamedArgs`, `rgdispidNamedArgs`) first, so argument `k` (from 0) is `rgvarg[cArgs - 1 - k]` when there are no named ones. The same loop looks for out parameters with `pList->pusOptFlags[i]`, in declaration order, and writes into `rgvarg[i]`, in reverse order: with more than one parameter it picks the wrong argument (with ADO's three, the middle one, by chance the right one). Excel's events did arrive in order in our tests, perhaps because Excel passes them as named arguments.

A patch for both can follow if wanted.
