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
| `employe1.rex` | `tutorial\employe1.rex` | a UserDialog loading a .rc (`employe1rc.cls`); its data attributes after OK |
| `employe2.rex` | `tutorial\employe2.rex` | an RcDialog: data attributes set in initDialog, combo box and list box entries |
| `employe3.rex` | `tutorial\employe3.rex` | a button connected to a method |
| `employe4.rex` | `tutorial\employe4.rex` | infoDialog with the dialog's data |
| `employe4validate.rex` | `tutorial\employe4validate.rex` | validate: OK refused while a field is empty |
| `employe5.rex` | `tutorial\employe5.rex` | buttons connected in init; getControlData, setControlData; an Array of employees |
| `employe6.rex` | `tutorial\employe6.rex` | an up-down's DELTAPOS to browse them (a scroll bar here); timedMessage |
| `employe7.rex` | `tutorial\employe7.rex` | a button with an image list; a background bitmap |
| `employe8.rex` | `tutorial\employe8.rex` | a second dialog (the list), a parent; fonts; items enabled and disabled |
| `employe9.rex` | `tutorial\employe9.rex` | the list with tab stops |
| `employe9menuDyn.rex` | `tutorial\employe9menuDyn.rex` | a menu bar built in code: NetMenuBar and NetPopupMenu, ooDialog's methods |
| `employee10menuRc.rex` | `tutorial\employee10menuRc.rex` | a .rc's menu (`employe7rc.cls`); the controls through their .NET members; two groups of radio buttons |
| `textScroll.rex` | `tutorial\textScroll.rex` | scrollInControl: text moving across an owner-drawn button |
| `drawing1.rex` | `tutorial\drawing1.rex` | drawing on a control: System.Drawing's Graphics, Pen, DrawEllipse, DrawRectangle |
| `drawing2.rex` | `tutorial\drawing2.rex` | connectDraw: drawing on each Paint; fonts, text measured and drawn |
| `drawing3.rex` | `tutorial\drawing3.rex` | the same with the control's rectangle; centred text |
| `drawing4.rex` | `tutorial\drawing4.rex` | a UserDialog with an owner-drawn button |
| `drawing5.rex` | `tutorial\drawing5.rex` | a clock: the time drawn every second (a timer in place of an Alarm) |
| `employee11tab.rex` | `tutorial\employee11tab.rex` | a property sheet of four pages; a list view; a context menu from a .rc; a file as the database |
| `genGUID.rex` | `examples\genGUID.rex` | a GUID (.NET's Guid); an edit control without a border |
| `simpleFolderBrowse.rex` | `examples\simpleFolderBrowse.rex` | .SimpleFolderBrowse as .NET's FolderBrowserDialog |
| `fileNameDialog_demo.rex` | `examples\fileNameDialog_demo.rex` | fileNameDialog's open, save, filters and multiple files; the SingleSelection class: the original's code |
| `browsePrinters.rex` | `examples\browsePrinters.rex` | a printer picked: .NET's PrintDialog in place of the Shell's folder browser |
| `publicRoutines_demo.rex` | `examples\publicRoutines_demo.rex` | play, findWindow, msSleep, timed messages (one until cancelled, one that replies early); a modeless dialog (popup); screen size and system metrics |
| `useTools.rex` | `examples\useTools.rex` | an owned window (ownerDialog: Form.Owner), a tool palette of bitmap buttons; an overridden cancel that keeps a dialog open |
| `imageButton.rex` | `examples\imageButton.rex` | a button's images for each state (normal, hot, pushed, disabled, default) on .NET's events; HOTITEM; text above or below the picture |
| `openSaveFileDemo.rex` | `examples\openSaveFileDemo.rex` | the Common Item Dialog as .NET's OpenFileDialog and SaveFileDialog (ClientGuid, preview, filters, folders); tool tips |
| `saveFileWithFilter.rex` | `examples\saveFileWithFilter.rex` | a save dialog refusing some extensions (its FileOk event) |
| `addManyRows.rex` | `examples\addManyRows.rex` | ProgressDialog with a Cancel button (Alerter); 25,000 list view rows; .NET's sort and a sort calling a Rexx IComparer; two groups of radio buttons in one group box |

More of ooDialog's samples will follow, in batches.

## Porting at a glance

| ooDialog | here |
|---|---|
| `::requires "ooDialog.cls"` | `::requires "oodnet.cls"` (which requires `net.cls`) |
| `::class MyDialog subclass UserDialog` (or `RcDialog`) | `::class MyDialog subclass NetDialog` |
| `self~create(x, y, cx, cy, title, style, , font, size)`, `createCenter(cx, cy, ...)` | the same: dialog units, and the dialog's font (default MS Shell Dlg 2, 8: ooDialog's, so the sizes match) |
| An RcDialog's `.rc`: `DIALOG x, y, cx, cy`, `CAPTION`, `FONT` | `self~create(x, y, cx, cy, caption, style, , font, size)` in `init` |
| `.MyDialog~new("file.rc", 100)`, `::class MyDialog subclass RcDialog` | `.MyDialog~new`, `::class MyDialog subclass File_100`, from `filerc.cls` (`rc2oodnet.rex -cls file.rc`: a class for each dialog of the .rc) |
| `connect*Event` in `init`, before the controls exist | the same: made once `defineDialog` has made them |
| `.BinaryMenuBar~new(...)`, `.PopupMenu~new(id)`, `insertPopup`, `insertItem`, `insertSeparator`, `connectCommandEvent(id, m, dlg)`, `enable(id)`, `disable(id)`, `attachTo(dlg)` | `.NetMenuBar~new`, `.NetPopupMenu~new`, the same methods (a .NET `MenuStrip`; `menuBar~item(id)` is a `ToolStripMenuItem`) |
| `.ScriptMenuBar~new("file.rc", IDM_MENU)` | `.File_IDM_MENU~new`, from `filerc.cls` (rc2oodnet.rex -cls makes a NetMenuBar subclass of each MENU) |
| `self~backgroundBitmap(file)`; an `.ImageList` on a button | `self~form~BackgroundImage = .net~System~Drawing~Image~FromFile(file)`; a .NET `ImageList`, `button~ImageList`, `~ImageIndex` |
| radio buttons in group boxes (Win32 groups them by `WS_GROUP`) | the same: those inside a group box's rectangle go into it, a group of their own |
| an owner-drawn button (`BS_OWNERDRAW`, style `OWNER`) | a `Panel` to draw on |
| `connectDraw(id, m)`; `getControlDC`, `createPen(w, style, color)`, `drawArc`, `rectangle`, `createFontEx`, `writeDirect`, `getTextExtent` | `connectDraw(id, m)`: .NET's `Paint`, `e~Graphics`; `.net~System~Drawing~Pen~new(color, w)`, `g~DrawEllipse`, `g~DrawRectangle` (width and height, not right and bottom), a .NET `Font`, `g~DrawString`, `g~MeasureString`; ooDialog's colors 1 and 2 are dark red and dark green |
| `redrawControl(id)`; `scrollInControl(id, text, font, size, style)` | the same |
| ids 1, 2, 9 in a .rc | IDOK, IDCANCEL, IDHELP, as Windows takes them |
| a control's text that is one of the dialog's methods (`Fontname`) | the data attribute `DATA<id>`, as ooDialog names it |
| `PropertySheetDialog~new(pages, options, caption)`; pages `subclass RcPSPDialog` | `.NetPropertySheet~new(pages, options, caption)` (a `TabControl`, OK, Cancel, Apply unless `NOAPPLYNOW`); a page is any NetDialog: `setActive`, `killActive`, `apply`, `wasActivated`, `propSheet`, the sheet's `startPage`, `pages`, `setCurSel(, i)`, `getResult` as ooDialog's |
| `menuBar~getPopup(id)`, `popup~assignTo(dlg, .true)`, `connectContextMenu(m, hwnd)`, `show(pos)` | the same on a NetPopupMenu (a `ContextMenuStrip` when shown); `.Point` is `.NetPoint` |
| `edit~connectCharEvent(m)`, `reply` a character; `edit~showBalloon(title, text, icon)` | `edit~KeyPress += .net~handler(self, m)`: `e~KeyChar`, `e~Handled = .true` refuses it; `self~showBalloon(edit, title, text, icon)` |
| `lv~insertColumn`, `addRow`, `setItemText`, `delete`, `select`, `focus`; `SELECTCHANGED`'s (id, item, state) | `lv~Columns~Add`, a `ListViewItem` with `SubItems`, `lv~Items[i]~SubItems[j]~Text`, `lv~Items~RemoveAt(i)`, `~Selected`, `~Focused`; .NET's `ItemSelectionChanged`: `e~ItemIndex`, `e~IsSelected` |
| `self~getControlData(id)`, `setControlData(id, v)`, `addComboEntry(id, t)`, `addListEntry(id, t)` | the same |
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
`rexx rc2oodnet.rex -cls file.rc` writes `filerc.cls`, with a class for each
dialog (`File_100`, `File_101`...), each a NetDialog that creates itself and
its controls: the program's RcDialog subclasses it and keeps the rest of its
code, as the tutorial's programs here do (`employe1rc.cls`...).

A control `oodnet.cls` has no `create*` for: make it and place it with
`self~place(id, control, x, y, cx, cy)` (private: from the dialog's own
methods), or add it to `self~form~Controls` yourself. `self~px(n)` and
`self~py(n)` turn dialog units into pixels.

**Buttons are drawn by Windows** (`FlatStyle` System), as ooDialog's: a
text that fits the original's button stays on one line (Windows Forms' own
buttons wrap it, their margins being wider). A button that shows an image
list, an image or colours needs `button~FlatStyle = "Standard"` first
(`employe7.rex` does so).

**Sizes, measured.** `rexx measure-dialogs.rex [build-dir]` (Windows, with
ooDialog: ooRexx for Windows has it) opens some of ooDialog's sample dialogs
both with ooDialog and as `rc2oodnet.rex` makes them, and writes to
`measure-dialogs.log` every control's rectangle on each side, in pixels.
The CI's Windows job runs it (the log is one of its artifacts). Today the
two agree to the pixel, but for a NumericUpDown, which is an edit and its
up-down in one control.

**Unattended.** `.NetDialog~auto = .true` (each program sets it from its
argument `auto`) makes a dialog run its `autoRun` method shortly after it
shows (by default: it ends with OK), and the routines show nothing and
answer their defaults. The programs override `autoRun` to do what a user
would (click a few buttons) and print what came out; `samples/check-samples.rex`
runs them so on Windows, the CI too.

**Not yet in `oodnet.cls`**: resizable dialogs (in .NET: a control's
`Anchor` and `Dock`), dialogs inside dialogs (ControlDialog). They come with the samples
that need them.
