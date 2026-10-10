# ooRexx's OLE samples, through the .NET bridge

ooRexx for Windows comes with OLE samples for Microsoft Office and
OpenOffice / LibreOffice (`samples\ole\apps` in its installation). These
are their .NET versions: the same programs, with the same names, run
through the bridge. `.net~createObject(progID)` gives a COM object reached
through IDispatch, as `.OLEObject~new(progID)` does, so most lines do not
change; where they do, a comment says so, and the header of each program
lists what differs.

    diff "%REXX_HOME%\samples\ole\apps\MSExcel.rex" MSExcel.rex

**Licence.** The originals are © Rexx Language Association, under the
Common Public License v1.0 (<https://www.oorexx.org/license.html>), and so
are these versions of them: each keeps its original header. (The rest of
this repository is under the Apache License 2.0.)

## What changes

- `.OLEObject~new(progID)` → `.net~createObject(progID)`, and
  `::requires "net.cls"` at the end.
- `o~getConstant(name)` → `.net~getConstant(o, name)`: the bridge's helpers
  live on `.net`, not on the objects, whose messages all go to the COM
  object.
- `.OLEVariant~new(...)` for an argument by reference → `.net~ref(value)`
  (a `.NetRef`, as for .NET's `ref` / `out`), and `~!varValue_` → `~value`.
- Events: `o~addEventMethod(name, method)` and `o~connectEvents` →
  `o~Name += .net~handler(object, message)` (`-=` to disconnect); COM
  delivers them while Rexx waits in .NET, so `SysSleep(1)` becomes
  `.net~nextEvent(1)`.
- `o~dispatch(name)` → `.net~invoke(o, name)`: the exact name, sent to the
  COM object whatever the object says it has (needed for `start`, also a
  Rexx method of every object).
- An argument `auto`, for unattended runs (`samples/check-samples.rex`, the
  CI): nothing waits for the user, the application stays hidden where
  that does not change what the program shows, and what was opened is
  closed at the end. Without it, each program behaves as the
  original.

## The samples

| | |
|---|---|
| `MSAccessDemo.rex` | Access: a database through ADO: a table created, filled, read, updated; compacted |
| `MSAccess_contacts.rex` | Access: a new database with a table, through DAO |
| `MSExcel.rex` | Excel: a sheet with data, formulas, colours and a number format; saved |
| `MSExcel_cURL.rex` | Excel: today's temperatures from wttr.in (here through .NET's `HttpClient`) and a chart |
| `MSExcel_usingRexxArray.rex` | Excel: sheets added and renamed; a 2-D Rexx Array as a range's value; a chart |
| `MSOutlook.rex` | Outlook: the inbox, and who sent each mail |
| `MSOutlook_monitorInbox.rex` | Outlook: a Rexx method called for each new mail (the `ItemAdd` event) |
| `MSPowerPoint_layouts.rex` | PowerPoint: slides with several layouts, their shapes listed; saved |
| `MSPowerPoint_present.rex` | PowerPoint: a presentation on two slides, an outline on three levels, then shown |
| `MSWord_createModify.rex` | Word: a document written, saved, opened again, previewed, given a table |
| `MSWord_useStyles.rex` | Word: text in several styles, then the styles' fonts changed |
| `AOO_scalc_chart.rex` | Calc: a table of random numbers and a chart; UNO constants and enums read through UNO's reflection |
| `AOO_simpress_present.rex` | Impress: a presentation on two slides, an outline on three levels, then shown |
| `AOO_swriter_paragraphs.rex` | Writer: paragraphs with four adjustments |
| `AOO_swriter_table.rex` | Writer: the DevGuide's "Quick Tour": a table, a text frame, colours |

Not here: `MSAccessDemo_32bit_only.rex`. It needs the Jet engine
(`Microsoft.Jet.OLEDB.4.0`, `JRO.JetEngine`), which exists for 32-bit
processes only, and the bridge runs in 64-bit ooRexx (`MSAccessDemo.rex`
does the same through Access itself). Where a program does something only
because of its language or its machine (Word's style names, which are the
local ones), the .NET version does it in a way that works anywhere, and
says so.

**Running them.** Windows, with Office (Access, Excel, Outlook, PowerPoint,
Word) for the MS ones and LibreOffice (or Apache OpenOffice) for the AOO
ones; the bridge's folder on the `PATH` and `REXX_PATH`, as for the
other samples. `rexx samples\check-samples.rex [build-dir] office
libreoffice` runs them all with `auto`. The CI runs the AOO ones on a
Windows runner with LibreOffice (`.github/workflows/libreoffice.yml`).
