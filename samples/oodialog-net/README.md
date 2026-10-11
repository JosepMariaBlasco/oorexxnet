# ooDialog programs in pure .NET

ooDialog's samples (`samples\oodialog` in an ooRexx for Windows
installation), rewritten for Windows Forms through the ooRexx/.NET bridge,
with no ooDialog and none of its resources: a Rosetta stone for porting
ooDialog programs to .NET. Each program does for its user what the original
does, and its header says how the original's ooDialog became .NET.

`oodnet.cls` is the small utility package that makes the porting short: a
class, `NetDialog`, with ooDialog's shape (create, defineDialog, the
create* methods with their arguments in dialog units, initDialog, the
connect*Event methods, execute, ok / cancel / validate / leaving), built on a
Windows Forms `Form`, and ooDialog's public routines (infoDialog, askDialog,
messageDialog, inputBox, fileNameDialog...) with their names, arguments and
results. A ported program keeps its structure and most of its lines; what
changes is what each control is: a .NET control, used with .NET's members.

    rexx calculator.rex          (Windows; the bridge's folder on the PATH and REXX_PATH)
    rexx calculator.rex auto     (unattended: it runs by itself and closes)

**Licence.** The ported programs are © Rexx Language Association, under the
Common Public License v1.0 (<https://www.oorexx.org/license.html>), as their
originals, whose headers they keep. `oodnet.cls` is under the Apache License
2.0, as the rest of this repository.

## The programs

| Here | ooDialog's original | What it shows |
|---|---|---|
| `SimpleUpDown.rex` | `simple\SimpleUpDown.rex` | a UserDialog in code; an edit control with an up-down (one NumericUpDown) |
| `SimpleMonthCalendar.rex` | `simple\SimpleMonthCalendar.rex` | an RcDialog (its .rc built in code); a month calendar and its SELECT event |
| `ChangeFont.rex` | `simple\ChangeFont.rex` | a multi-line edit control; fileNameDialog; a font set; buttons enabled and disabled |
| `calculator.rex` | `calculator.rex` | a dialog from a .rc (30 buttons); buttons sent to UNKNOWN; RxMath as System.Math |
| `stopWatch.rex` | `examples\stopWatch.rex` | a menu bar; a timer in place of REPLY and a loop; colours and fonts; the clipboard |
| `columnClickListView.rex` | `controls\ListView\columnClickListView.rex` | a report list view, 200 rows; which row and column a click hit |
| `oodStandardRoutines.rex` | `oodStandardRoutines.rex` | every public routine (askDialog, checkList, messageDialog, multiInputBox...): the original's code, unchanged |

More of ooDialog's samples will follow, in batches.

## Porting at a glance

| ooDialog | here |
|---|---|
| `::requires "ooDialog.cls"` | `::requires "oodnet.cls"` (which requires `net.cls`) |
| `::class MyDialog subclass UserDialog` (or `RcDialog`) | `::class MyDialog subclass NetDialog` |
| `self~create(x, y, cx, cy, title, style, , font, size)`, `createCenter(cx, cy, ...)` | the same: dialog units, and the dialog's font (default MS Shell Dlg 2, 8: ooDialog's, so the sizes match) |
| An RcDialog's `.rc`: `DIALOG x, y, cx, cy`, `CAPTION`, `FONT` | `self~create(x, y, cx, cy, caption, style, , font, size)` in `init` |
| The `.rc`'s controls (`LTEXT`, `EDITTEXT`, `PUSHBUTTON`, `DEFPUSHBUTTON`, `AUTORADIOBUTTON`, `AUTOCHECKBOX`, `GROUPBOX`, `LISTBOX`, `COMBOBOX`, `CONTROL ... MONTHCAL_CLASS / WC_LISTVIEW / ...`) | in `defineDialog`: `createStatic`, `createEdit`, `createPushButton` (`DEFAULT`), `createRadioButton`, `createCheckBox`, `createGroupBox`, `createListBox`, `createComboBox`, `createMonthCalendar`, `createListView`... with the same coordinates |
| Numeric resource ids, `constDir`, `.h` files | names: any string or symbol (`IDC_EDIT`, `"box"`); `IDOK` and `IDCANCEL` are OK and Cancel |
| `self~newEdit(id)`, `newPushButton(id)`... | the same, giving the .NET control (`TextBox`, `Button`...) |
| `edit~setText(t)`, `edit~getText` | `edit~Text = t`, `edit~Text` |
| `button~setTitle(t)`, `~enable`, `~disable` | `button~Text = t`, `~Enabled = .true` / `.false` |
| `radio~check`, `radio~checked`, `checkBox~isChecked` | `~Checked = .true`, `~Checked` |
| `self~createFontEx(name, size)`, `ctl~setFont(f)`, `deleteFont` | `ctl~Font = .net~System~Drawing~Font~new(name, .net~single(size))` (.NET frees it) |
| `ctl~setColor(bg, fg)` | `ctl~BackColor = .net~System~Drawing~Color~Black`, `~ForeColor = ...` |
| `upDown~setRange(lo, hi)`, `~setPosition(n)`; an edit with an AUTOBUDDY up-down | `~Minimum = lo`, `~Maximum = hi`, `~Value = n`: one `NumericUpDown`, under both ids |
| `list~insertColumn(i, text, width)`, `~addRow(...)`, `~addExtendedStyle("FULLROWSELECT GRIDLINES")` | `list~Columns~Add(text, self~px(width))`, a `ListViewItem` with `SubItems`, `list~FullRowSelect = .true`, `~GridLines = .true` |
| `connectButtonEvent(id, "CLICKED", m)` | the same; `m` gets .NET's `(sender, e)` (ooDialog's: `(id, hwnd)`) |
| `connectListViewEvent(id, "CLICK", m)` | the same (.NET's `MouseClick`: `listView~HitTest(e~X, e~Y)` gives the row and column) |
| `connectMonthCalendarEvent(id, "SELECT", m)` | the same (.NET's `DateSelected`: `e~Start`, a .NET `DateTime`) |
| any other event | `self~connectEvent(id, ".NET event name", m)` |
| `.BinaryMenuBar`, `.PopupMenu`, `menuBar~attachTo(self)` | a `MenuStrip`, `self~menuItem(text, method)`, `self~attachMenu(menu)` |
| `REPLY` and a loop that updates the dialog | `self~startTimer(ms, method)` (the dialog's own thread; stop it with `timer~Stop`) |
| `.WindowsClipboard~new~copy(text)` | `.net~System~Windows~Forms~Clipboard~SetText(text)` |
| `RxCalcSqrt(x)` and RxMath's kin | `.net~System~Math~Sqrt(x)` (trigonometry in radians) |
| `dlg~execute("SHOWTOP")`: 1 (OK) or 2 (Cancel) | the same |
| `ok`, `cancel`, `validate`, `leaving`, `initDialog` overridden | the same; `self~ok:super` ends the dialog when `validate` answers `.true` |
| data attributes (`createEdit(id, ..., "TLINE")`, then `self~TLine`) | the same |
| `infoDialog`, `errorDialog`, `askDialog`, `messageDialog`, `inputBox`, `integerBox`, `passwordBox`, `listChoice`, `multiListChoice`, `checkList`, `singleSelection`, `multiInputBox`, `fileNameDialog`, `browseForFolder`, `timedMessage` | the same names, arguments and results; `self~IDOK`... `self~IDCONTINUE` as ooDialog's |

**Indexers by number and by key** (`ListView.Items`, `SubItems`,
`Controls`...): a Rexx whole number is a position, from 0 as in .NET
(`list~Items[2]` is the third item); a key that looks like a number takes
`.net~string("2")`.

**From a .rc.** `rexx rc2oodnet.rex file.rc [dialogId] [file.h]` prints the
`create` line for `init` and a `defineDialog` with one `create*` per control
of the .rc's dialog, at the same coordinates, with the data attribute
names that ooDialog would give them: the start of a port of an RcDialog.

A control `oodnet.cls` has no `create*` for: make it and place it with
`self~place(id, control, x, y, cx, cy)` (private: from the dialog's own
methods), or add it to `self~form~Controls` yourself. `self~px(n)` and
`self~py(n)` turn dialog units into pixels.

**Unattended.** `.NetDialog~auto = .true` (each program sets it from its
argument `auto`) makes a dialog run its `autoRun` method shortly after it
shows (by default: it ends with OK), and the routines show nothing and
answer their defaults. The programs override `autoRun` to do what a user
would (click a few buttons) and print what came out; `samples/check-samples.rex`
runs them so on Windows, the CI too.

**Not yet in `oodnet.cls`**: property sheets and tab pages, resizable
dialogs (in .NET: a control's `Anchor` and `Dock`), owner drawing, image
lists, dialogs inside dialogs (ControlDialog). They come with the samples
that need them.
