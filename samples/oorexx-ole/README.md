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
- `o~dispatch(name)` → `.net~invoke(o, name)`: the exact name, sent to the
  COM object whatever the object says it has (needed for `start`, also a
  Rexx method of every object).
- An argument `auto`, for unattended runs (`samples/check-samples.rex`, the
  CI): the application stays hidden, nothing waits for the user, and what
  was opened is closed at the end. Without it, each program behaves as the
  original.

## The samples

| | |
|---|---|
| `AOO_scalc_chart.rex` | Calc: a table of random numbers and a chart; UNO constants and enums read through UNO's reflection |
| `AOO_simpress_present.rex` | Impress: a presentation on two slides, an outline on three levels, then shown |
| `AOO_swriter_paragraphs.rex` | Writer: paragraphs with four adjustments |
| `AOO_swriter_table.rex` | Writer: the DevGuide's "Quick Tour": a table, a text frame, colours |

**Running them.** Windows, with LibreOffice (or Apache OpenOffice) for the
AOO ones; the bridge's folder on the `PATH` and `REXX_PATH`, as for the
other samples. The CI runs the AOO ones on a Windows runner with
LibreOffice (`.github/workflows/libreoffice.yml`).
