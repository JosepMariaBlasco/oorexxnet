# Samples

Small, complete programs, each commented at the top. They are run on every
change on Linux, macOS and Windows (`check-samples.rex`, in the CI), so they
stay true.

## Rexx using .NET (`rexx/`, every platform)

| | |
|---|---|
| `01-basics.rex` | namespaces, types, static members, objects, properties; dates, the environment |
| `02-collections.rex` | `Dictionary`, `List` (sorted by .NET and by a Rexx comparison), arrays as Rexx Arrays, `HashSet`, `Queue` |
| `03-files.rex` | `File`, `Directory`, `Path`, `FileInfo`; Rexx Arrays as `string[]` and back |
| `04-regex.rex` | regular expressions: matches, named groups, split, replace with a Rexx method |
| `05-json.rex` | `System.Text.Json`: parse and walk a document; serialize a dictionary |
| `06-events.rex` | a timer's events queued and run by `.net~eventLoop`; a file watcher's, with `.net~nextEvent` |
| `07-tasks.rex` | `~await`; Rexx methods on .NET's thread pool through `Task.Run` |
| `08-event-thread.rex` | the event thread with no windows: `runLater`, `runLaterLatest` and their `GUIMessage`s from another Rexx thread |

## Windows (`windows/`)

| | |
|---|---|
| `forms-hello.rex` | a Windows Forms window: label, text box, button, a Click handler in Rexx |
| `forms-paint.rex` | drawing with `System.Drawing` in the Paint event; repainting on resize |
| `forms-extend.rex` | a Rexx class extending `Form` (`.net~extend`): `OnPaint`, `OnResize`, `ProcessDialogKey`, `OnFormClosed` as Rexx methods, `base.` calls, a protected property |
| `forms-progress.rex` | a progress bar updated from another Rexx thread with `runLaterLatest`; `GUIMessage`s: a result, an error |
| `forms-two-threads.rex` | two windows on two UI threads, each served by its own Rexx object; `runLater` routed to each, `GUIMessage`s |
| `dialogs.rex` | `MessageBox` with buttons and icons; the open-file dialog |
| `windows-info.rex` | the registry, special folders, drives, the clipboard, system sounds |

They need the .NET Desktop Runtime (see the guide, "Which .NET on Windows").
With the argument `auto` the interactive ones finish by themselves.

## Office (`office/`, Windows with Office)

Excel, Word and PowerPoint, each program written twice, with `.OLEObject`
and through the bridge (`.net~createObject`): see `office/README.md`.
`rexx samples\check-samples.rex [build-dir] office` runs them too.

## LibreOffice (`libreoffice/`, Windows with LibreOffice)

Writer, Calc and Impress, the same way, through LibreOffice's automation
bridge (`com.sun.star.ServiceManager`): see `libreoffice/README.md`.
`rexx samples\check-samples.rex [build-dir] libreoffice` runs them too.

## ooRexx's OLE samples (`oorexx-ole/`, Windows)

The OLE samples that come with ooRexx for Windows (`samples\ole\apps`:
Access, Excel, Outlook, PowerPoint, Word; OpenOffice / LibreOffice), with
the same names, through the bridge: see `oorexx-ole/README.md` (they keep
ooRexx's licence, the CPL). `check-samples.rex` runs the AOO ones with
`libreoffice` and the MS ones with `office`.

## ooDialog's samples in pure .NET (`oodialog-net/`, Windows)

ooDialog programs rewritten for Windows Forms, with no ooDialog: the same
dialogs and behaviour, through `oodnet.cls`, a small package with
ooDialog's shape (`NetDialog`: create, defineDialog, create* in dialog
units, connect*Event, execute; and ooDialog's public routines). The porting
guide, a table from ooDialog to .NET, is `oodialog-net/README.md`. Among
them, the winsystem programs work with other programs' windows (Notepad,
the Calculator) through .NET's UI Automation, and with the registry, the
event logs and shortcuts.

## .NET running Rexx

- `csharp/tour/` and `vbnet/tour/` — a tour in C# and its twin in VB.NET,
  one file per topic: running Rexx code and its results, Rexx objects
  (`dynamic` / late binding, `Send`, collections), messages by name as in
  BSF4ooRexx (`SendMessage`, `SendMessage0..5`, `SendMessageScope`), an
  `ADDRESS` environment, Rexx's standard streams, .NET objects and
  delegates used by the Rexx code, and functions and `VALUE` selectors of
  the application. `dotnet run` (every topic) or
  `dotnet run -- sendmessage` (one); the bridge from a build
  (`-p:RexxNetDir=DIR`, else `$REXXNET_BUILD/rexxnet` or `~/build/rexxnet`)
  or else from NuGet.
- `csharp/hello/` — a C# program using the NuGet package `Rexx.Net`: Rexx
  code, a Rexx class through `dynamic`, Rexx's output captured, an `ADDRESS`
  environment, a .NET object handed to Rexx. `dotnet run`.
- `powershell/hello.ps1` — the same from PowerShell 7.

## Running them

All need ooRexx 5 (64-bit) and .NET 8 or later. Installed from the binary
zip (`rexx install`), the samples are in ooRexx's samples folder, under
`dotnet`, and run from anywhere: `rexx 01-basics.rex` in its `rexx` folder. From a build of the bridge, with
`REXX_PATH` and the library path (`LD_LIBRARY_PATH`, macOS
`DYLD_LIBRARY_PATH`, Windows `PATH`) at the build directory. Or all at once:
`rexx samples/check-samples.rex [build-dir]`.
