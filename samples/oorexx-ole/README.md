# ooRexx's OLE samples, through the .NET bridge

ooRexx for Windows comes with OLE samples for Microsoft Office and
OpenOffice / LibreOffice (`samples\ole\apps` in its installation). These
are their .NET versions: the same programs, with the same names, run
through the bridge. `.net~createObject(progID)` gives a COM object reached
through IDispatch, as `.OLEObject~new(progID)` does, so most lines do not
change; where they do, a comment says so, and the header of each program
lists what differs.

    diff "%REXX_HOME%\samples\ole\apps\MSExcel.rex" MSExcel.rex

## At a glance: `.OLEObject` → the bridge

Everything a program written for `.OLEObject` needs to change, in one
table (details below, and in the guide, section 12):

| `.OLEObject` | the .NET bridge |
|---|---|
| `.OLEObject~new(progID)` | `.net~createObject(progID)`, and `::requires "net.cls"` at the end |
| `.OLEObject~GetObject(moniker)` (a file, `"winmgmts:"`) | `.net~getObject(moniker)` |
| `.OLEObject~new(progID, , .true)` (undocumented: the running one) | `.net~getActiveObject(progID)` (an error if none runs) |
| `o~method(args)`, `o~property`, `o~property = v`, `o[i]`, `DO x OVER o` | the same |
| `o~getConstant(name)` | `.net~getConstant(o, name)`; all of them: `.net~getConstant(o)` (a StringTable) |
| `o~getKnownMethods`, `o~getKnownEvents` | `.net~getKnownMethods(o)`, `.net~getKnownEvents(o)` (the same stems) |
| `o~progid`, `o~clsid` | `.net~getKnownMethods(o)`'s `!PROGID`, `!CLSID` |
| `.OLEVariant~new(v)` for an argument by reference, `~!varValue_` | `.net~ref(v)`, `~value` |
| a string that must stay a string (`"007"`) | `.net~box("string", "007")` |
| `"WITHEVENTS"`, `o~addEventMethod(name, m)`, `o~connectEvents` | `o~Name += .net~handler(object, message)` (`-=` to disconnect) |
| an event's parameter by reference (Excel's `Cancel`) | it arrives as a `Rexx.Net.ComRef`: `ref~Value = .true` |
| `call SysSleep 1` while events come | `.net~nextEvent(1)` (or `.net~eventLoop`) |
| `o~dispatch(name)` (a name Rexx also has: `start`) | `.net~invoke(o, name)` |
| — (no named arguments) | `.net~named(name, value)`, VBA's `name:=value` |
| the user's language for every call | English (US), as VBA; the user's: `.net~createObject(progID, "user")` |
| `drop o` (released at the next collection) | `.net~releaseObject(o)` (Excel's process can end now) |

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
| `MSAccessDemo_64bit.rex` | Access without Access: the database engine alone (ACE, 64-bit) through ADO, ADOX and DAO; what `MSAccessDemo_32bit_only.rex` does with Jet |
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

And from `samples\ole\apps`, the Windows objects every Windows has (run
by the CI on its Windows runner, as the folders below):

| | |
|---|---|
| `ScriptingFileSystemObject.rex` | `Scripting.FileSystemObject`: drives, folders, files, a text file written and read |
| `ShellApplication_listSystemFolders.rex` | `Shell.Application`: the paths of Windows' special folders |
| `WScriptNetwork.rex` | `WScript.Network`: computer and user names, mapped drives, printers |
| `WScriptShell.rex` | `WScript.Shell`: environment, special folders, a shortcut on the desktop, a popup |

From `samples\ole\wmi`, in `wmi/` (WMI through `.net~getObject("winmgmts:...")`):
`accounts.rex` (user accounts), `osinfo.rex` (the operating system, the
computer, its processors and disks), `process.rex` (running processes),
`services.rex` (the services; starting and stopping them, by hand). From
`samples\ole\adsi`, in `adsi/` (Active Directory Service Interfaces,
through `.net~getObject("WinNT://...")`): `adsi1`–`adsi6` read the computer,
a user, groups, the domain, the schema; `adsi7` and `adsi8` create and
remove fifteen local users and a group (by hand only, as an administrator:
`auto` skips them).

From `samples\ole\methinfo` and `samples\ole\oleinfo`, a COM object's
type information, through `.net~getKnownMethods(o)` and
`.net~getKnownEvents(o)` (the same stems as `.OLEObject`'s): `methinfo/`
prints an object's methods and properties with their signatures
(`rexx main.rex`, then a ProgID); `oleinfo/` documents an object as an
HTML page (`rexx createOleInfo.rex Excel.Application`; `rexx
createOleInfo.rex WScript.Shell 1 0`: the compact form, not opened in the
browser), writes its constants as a Rexx program (`getOleConstants.rex`),
and lists the ProgIDs in the registry (`listProgIds.rex`).

Not here: the Lotus samples (Lotus 1-2-3, Notes, Word Pro: discontinued) and
the Internet Explorer ones (IE is gone from Windows 11; `oleinfo/test.rex`
leaves out its IE part).

Not here as such: `MSAccessDemo_32bit_only.rex`. It needs the Jet engine
(`Microsoft.Jet.OLEDB.4.0`, `JRO.JetEngine`), which exists for 32-bit
processes only, and the bridge runs in 64-bit ooRexx. Its 64-bit
counterpart is `MSAccessDemo_64bit.rex`, written for the bridge: the same
program on ACE, Jet's successor (ADOX creates the database, DAO 12
compacts it), which needs no Access application; `MSAccessDemo.rex` does
the same through Access itself. Where a program does something only
because of its language or its machine (Word's style names, which are the
local ones), the .NET version does it in a way that works anywhere, and
says so.

**Running them.** Windows, with Office (Access, Excel, Outlook, PowerPoint,
Word) for the MS ones and LibreOffice (or Apache OpenOffice) for the AOO
ones; the bridge's folder on the `PATH` and `REXX_PATH`, as for the
other samples. `rexx samples\check-samples.rex [build-dir] office
libreoffice` runs them all with `auto`. The CI runs the AOO ones on a
Windows runner with LibreOffice (`.github/workflows/libreoffice.yml`).
