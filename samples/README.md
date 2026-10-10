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

Writer and Calc, the same way, through LibreOffice's automation bridge
(`com.sun.star.ServiceManager`): see `libreoffice/README.md`.
`rexx samples\check-samples.rex [build-dir] libreoffice` runs them too.

## .NET running Rexx

- `csharp/hello/` — a C# program using the NuGet package `Rexx.Net`: Rexx
  code, a Rexx class through `dynamic`, Rexx's output captured, an `ADDRESS`
  environment, a .NET object handed to Rexx. `dotnet run`.
- `powershell/hello.ps1` — the same from PowerShell 7.

## Running them

All need ooRexx 5 (64-bit) and .NET 8 or later. From the Windows binary
package, with its folder on the `PATH` and `REXX_PATH`:
`rexx samples\rexx\01-basics.rex`. From a build of the bridge, with
`REXX_PATH` and the library path (`LD_LIBRARY_PATH`, macOS
`DYLD_LIBRARY_PATH`, Windows `PATH`) at the build directory. Or all at once:
`rexx samples/check-samples.rex [build-dir]`.
