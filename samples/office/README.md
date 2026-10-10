# Office from Rexx: a Rosetta stone

Short programs, each written twice: with ooRexx's own `.OLEObject`
(COM) and through the .NET bridge. Side by side they show that the bridge
reaches Office as `.OLEObject` does: `.net~createObject("Excel.Application")`
gives a COM object driven through `IDispatch`, late-bound and caseless,
and the rest of the program does not change. What the .NET version adds is
the rest of .NET at hand (here, only `Path`), and `.net~releaseObject` to
let Office's process end at once.

| | `.OLEObject` | .NET bridge |
|---|---|---|
| Excel: a table, formulas, formatting, saved as .xlsx | `excel-ole.rex` | `excel-net.rex` |
| Word: a heading, a paragraph, a table, saved as .docx | `word-ole.rex` | `word-net.rex` |
| PowerPoint: two slides, saved as .pptx | `powerpoint-ole.rex` | `powerpoint-net.rex` |
| Excel's events: cells changed, a Close refused | `excel-events-ole.rex` | `excel-events-net.rex` |

`diff excel-ole.rex excel-net.rex` shows everything that differs.

**One real difference: the language.** Each COM call carries a language
(a locale). `.OLEObject` gives the user's; the bridge always gives English
(US), as VBA does. Excel reads `Formula` in that language: through the
bridge `=SUM(D2:D4)` works on any Windows, through `.OLEObject` on a
Spanish Windows it must be `=SUMA(D2:D4)` (so `excel-ole.rex` writes
`=D2+D3+D4`). And Excel refuses a call whose language it does not know.
A program written for `.OLEObject` with formulas in the user's language
keeps working through the bridge with
`.net~createObject("Excel.Application", "user")`: its calls, and those to
the objects it returns, then carry the user's language, as `.OLEObject`'s.

**Events** are where the two differ most. `.OLEObject` created
`"WITHEVENTS"` calls its own methods named after the events (a subclass of
`.OLEObject`), and a method's return value goes to the event's out
parameter (`Cancel`). Through the bridge, COM events are .NET events:
`excel~SheetChange += .net~handler(obj, "MESSAGE")`, any object, any
method name, added and removed at any time; a parameter passed by
reference arrives as a `Rexx.Net.ComRef` (`cancel~Value = .true`). While
waiting for Excel's events, the `.OLEObject` version sleeps (`SysSleep`),
the bridge's waits in .NET (`.net~nextEvent(1)`).

On ooRexx 5.x (r13267), `.OLEObject` does not give `Cancel` back to Excel:
the workbook closes anyway, and `excel-events-ole.rex` says so. With
`ADODB.Recordset`, `.OLEObject` also passes an event's arguments in reverse
order (`bridge/tests/windows/ole-event-out.rex` shows both); Excel's come in
order. The bridge gives the arguments in their order and `Cancel` back
(`excel-events-net.rex`, `bridge/tests/com.rex`).

They need Windows with Office installed; the .NET versions, the bridge (its
folder on the `PATH` and `REXX_PATH`, as for the other samples). Each saves
its file in the temporary folder and closes Office again. With the
argument `auto`, Excel and Word stay hidden and PowerPoint opens no window.

**Style.** VBA lets `Worksheets(1)` or `Cells(r, c)` reach a collection's
default member; through `IDispatch` the explicit form, `Worksheets~Item(1)`,
`Cells~Item(r, c)`, works with every server, so both versions use it.
Office's constants (`wdStyleHeading1` = -2, `ppLayoutTitle` = 1, `msoTrue`
= -1) are written as numbers.
