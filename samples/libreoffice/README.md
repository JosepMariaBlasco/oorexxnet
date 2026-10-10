# LibreOffice from Rexx: a Rosetta stone

The counterpart of `samples/office/` for LibreOffice: short programs, each
written twice, with ooRexx's own `.OLEObject` (COM) and through the .NET
bridge. On Windows, LibreOffice's automation bridge gives its whole UNO API
to COM clients: `com.sun.star.ServiceManager` is the way in, as
`Excel.Application` is Excel's. So `.net~createObject` reaches LibreOffice
as `.OLEObject~new` does, and the rest of the program does not change.

| | `.OLEObject` | .NET bridge |
|---|---|---|
| Writer: a heading, a paragraph, a table, saved as .odt | `writer-ole.rex` | `writer-net.rex` |
| Calc: a table, formulas, formatting, saved as .ods | `calc-ole.rex` | `calc-net.rex` |

`diff calc-ole.rex calc-net.rex` shows everything that differs.

**UNO through COM.** The programs use UNO's API as its documentation writes
it: `loadComponentFromURL`, `getCellRangeByName`, `setPropertyValue`;
indexes from 0; style names and formulas in English, whatever the user's
language (unlike Excel's `Formula`, see `samples/office/README.md`). A UNO
struct comes from the service manager, `sm~Bridge_GetStruct(name)`; a
sequence is a Rexx Array (Calc's `setDataArray` takes an Array of rows).
LibreOffice's documents are file URLs: the .NET versions make them with
`System.Uri`.

**Why COM and not UNO's .NET binding.** LibreOffice has a newer .NET binding
of UNO (`net_ure`: .NET Standard assemblies, not tied to Windows), which would reach
LibreOffice from .NET without COM, Linux included. LibreOffice's binary
releases do not ship it yet (26.8.1: neither the SDK's NuGet package nor
the native bridge libraries); it takes a LibreOffice built from source.
Its older binding, CLI-UNO, needs the .NET Framework, which the bridge
does not host. When the new binding ships, a third column can follow.

**Running them.** Windows with LibreOffice installed; the .NET versions,
the bridge (its folder on the `PATH` and `REXX_PATH`, as for the other
samples). Each saves its file in the temporary folder and closes the
document; LibreOffice itself is closed only if no other document is open.
With the argument `auto`, LibreOffice stays hidden. The CI runs them on a
Windows runner with LibreOffice installed
(`.github/workflows/libreoffice.yml`).
