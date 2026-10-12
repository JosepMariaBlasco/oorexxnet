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
| `toolBar.rex` | `controls\ToolBar\toolBar.rex` | a tool bar from a .rc (a ToolStrip), its buttons added and inserted |
| `comboBoxTypes.rex` | `controls\ComboBox\comboBoxTypes.rex` | the three kinds of combo box; their colours (setFullColor: BackColor, ForeColor) |
| `customPositionToolTip.rex` | `controls\ToolTip\customPositionToolTip.rex` | a tree view's tips placed by the program (NodeMouseHover, ToolTip.Show) |
| `columnIcons.rex` | `controls\ListView\columnIcons.rex` | a list view's four views; icons in the subitems (drawn: OwnerDraw); sorting by a clicked column |
| `PaidHolidays.rex` | `controls\PaidHolidays.rex` | a month calendar: its range, its optimal size, dates in bold |
| `incrementalSearch.rex` | `controls\ListBox\incrementalSearch.rex` | a list box's own incremental search, with a longer interval (KeyPress, a Timer) |
| `editControl.rex` | `controls\ListView\subitem.editing\editControl.rex` | a list view's subitems edited in place (a TextBox inside the ListView) |
| `dropDownComboBox.rex` | `controls\ListView\subitem.editing\dropDownComboBox.rex` | the same with a drop-down combo box |
| `dropDownListComboBox.rex` | `controls\ListView\subitem.editing\dropDownListComboBox.rex` | the same with a drop-down list |
| `importList.rex` | `controls\ListView\subitem.editing\importList.rex` | a combo box and an edit control inside a list view; two resizable dialogs (ResizingAdmin); a .rc's menu |
| `customDrawListview.rex` | `controls\ListView\customDrawListview.rex` | rows in colours and fonts of their own (a ListViewItem's ForeColor, BackColor, Font), changed when a row is checked |
| `toolTip.rex` | `controls\ToolTip\toolTip.rex` | tool tips on buttons (a balloon; one in lines) and on the dialog's quadrants, placed by the program; NEEDTEXT |
| `manageControlTool.rex` | `controls\ToolTip\manageControlTool.rex` | one tip for every tree-view item: the tree's MouseMove as ooDialog's relay, a timer as the tip's wait |
| `comboBoxToolTip.rex` | `controls\ToolTip\comboBoxToolTip.rex` | tips for a combo box's items, selection field and button, the list down or up (an owner-drawn ComboBox) |
| `customizeToolBar.rex` | `controls\ToolBar\customizeToolBar.rex` | a tool bar of images; Windows' Customize Toolbar dialog, with the tool bar's notifications |
| `upDown.rex` | `controls\upDown.rex` | decimal and hexadecimal NumericUpDowns: range, position, acceleration; an up down browsing records |
| `userStringDTP.rex` | `controls\userStringDTP.rex` | a date and time picker typed in (USERSTRING); F1; ooDialog's colour numbers; a timer |
| `fiscalReports.rex` | `controls\fiscalReports.rex` | a date and time picker with call back fields (FORMAT, FORMATQUERY, KEYDOWN): a Rexx class extending DateTimePicker, its WndProc |
| `treeViewCustomDraw.rex` | `controls\TreeView\treeViewCustomDraw.rex` | a tree view's items in their colours (OwnerDrawText), images, label editing, info tips, items added on expanding, a Rexx sort |
| `BinaryMenuBar.rex` | `menus\BinaryMenuBar.rex` | a menu bar built in code; items checked, grayed, radio items; connectAllCommandEvents (the methods named from the items' text) |
| `ScriptMenuBar.rex` | `menus\ScriptMenuBar.rex` | a .rc's menu (`ScriptMenuBarrc.cls`), its popups found by id or position, the commands connected |
| `UserMenuBar.rex` | `menus\UserMenuBar.rex` | ooDialog's UserMenuBar: addPopup, addItem, addSeparator, complete; a bitmap in the dialog |
| `ContextMenu.rex` | `menus\ContextMenu.rex` | context menus on the dialog, a list view and its items (connectContextMenu, show); popups taken from a menu bar |
| `dragNdrop.rex` | `mouse\dragNdrop.rex` | dragging list-view and tree-view items (BEGINDRAG with DefListDragHandler, DefTreeDragHandler: .NET's DoDragDrop); a cursor of its own |
| `mouseWheel.rex` | `mouse\mouseWheel.rex` | the mouse wheel over the dialog and an edit control, with Shift and Control; EM_SCROLL sent to the edit control |
| `basicResize.rex` | `resizableDialogs\ResizingAdmin\basicResize.rex` | ResizingAdmin with its defaults: every control proportional |
| `augmentedResize.rex` | `resizableDialogs\ResizingAdmin\augmentedResize.rex` | ResizingAdmin's pins control by control; minimum and maximum sizes; the sizing ended |
| `gbStationary.rex` | `resizableDialogs\ResizingAdmin\gbStationary.rex` | group boxes that keep their size, their controls pinned to them |
| `dlgAreaUDemo.rex` | `resizableDialogs\DialogAreaU\dlgAreaUDemo.rex` | DlgArea and DlgAreaU: controls laid out in areas of the dialog, moved and sized on connectResize |
| `dlgAreaUDemoTwo.rex` | `resizableDialogs\DialogAreaU\dlgAreaUDemoTwo.rex` | the same with controls that do not resize or do not move (noResizePut, noMovePut) |
| `dlgAreaUDemoThree.rex` | `resizableDialogs\DialogAreaU\dlgAreaUDemoThree.rex` | DlgAreaU with a dialog of its own areas; WM_SIZING (connectResizing), the sizing ended |
| `PropertySheetDemo.rex` | `propertysheet.tabControls\PropertySheetDemo.rex` | a property sheet whose pages show a list view, a tree view (dragging), vertical progress bars, track bars, a tab control with an owner-drawn display area |
| `TabDemo.rex` | `propertysheet.tabControls\TabDemo.rex` | the same pages as control dialogs (ControlDialog) over a tab control's display area; Previous and Next; the tab control's keys |
| `TabOwnerDemo.rex` | `propertysheet.tabControls\TabOwnerDemo.rex` | TabOwnerDialog: control dialogs managed as a tab control's pages (ManagedTab, TabOwnerDlgInfo, ControlDlgInfo) |
| `UserTabDemo.rex` | `propertysheet.tabControls\UserTabDemo.rex` | the same with the dialog and its pages built in code; a default font; keys connected (connectKeyPress) |
| `oodListViews.rex` | `propertysheet.tabControls\oodListViews.rex` | a list view's four views on four tabs; records added and edited in a second dialog; info tips |
| `ticketWizard.rex` | `propertysheet.tabControls\ticketWizard.rex` | a wizard (Wizard97): header and watermark bitmaps, Back, Next, Finish set by the pages, pages querying each other |
| `resizablePropertySheetDemo.rex` | `resizableDialogs\ResizingAdmin\PropertySheetDemo.rex` | `PropertySheetDemo.rex` resizable: the sheet and each page with ResizingAdmin |
| `resizableTabDemo.rex` | `resizableDialogs\ResizingAdmin\TabDemo.rex` | `TabDemo.rex` resizable: the control dialogs sized with the tab control (pagedTab) |
| `ftyperex.rex` | `ftyperex.rex` | the registry (.NET's `Microsoft.Win32.Registry` for winsystm.cls's WindowsRegistry); SingleSelection, or the console |
| `editrex.rex` | `editrex.rex` | the same for the Edit command; fileNameDialog for the editor |
| `oodStandardDialogs.rex` | `oodStandardDialogs.rex` | the standard dialog classes (CheckList, InputBox, IntegerBox, ListChoice, MultiInputBox, MultiListChoice, PasswordBox, SingleSelection, TimedMessage); a default icon |
| `oovideo.rex` | `oovideo.rex` | a dialog's data stem (new's dlgData.) in and out; CONNECTBUTTONS; validate, a cancel that asks; sounds |
| `oodpbar.rex` | `oodpbar.rex` | vertical progress bars stepped (PBM_STEPIT); the Help button |
| `GUI_Template.rex` | `GUI_Template.rex` | the template for a UserDialog, as a NetDialog's |
| `oobmpvu.rex` | `oobmpvu.rex` | a bitmap viewer: a bitmap button changed, a combo box of a directory's files |
| `oograph.rex` | `oograph.rex` | bitmaps scrolled into bitmap buttons (scrollBitmapFromTo), scrolling text, a thread of the program's own; the bitmap viewer and the drawing program started from it |
| `oobandit.rex` | `oobandit.rex` | a slot machine: bitmap buttons changed from a thread of its own while the dialog runs; text written on the dialog |
| `oophil.rex` | `oophil.rex` | the philosophers' forks: five threads, guarded forks, bitmap buttons of a .rc; executeAsync |
| `AnimalGame.rex` | `AnimalGame.rex` | buttons with images (one for the pressed state); data stems; timed messages placed on the screen |
| `oowalker.rex` | `oowalker.rex` | ooDialog's AnimatedButton (`AnimatedButton.cls`): a walking man, on a thread of his own |
| `oowalk2.rex` | `oowalk2.rex` | the same, its bitmaps those of a .rc's BITMAP resources |
| `oodraw.rex` | `oodraw.rex` | drawing through a device context: pens, brushes, rectangles, lines, pixels, arcs, pies, a flood fill |
| `sample.rex` | `sample.rex` | the samples' launcher: bitmap buttons on a background bitmap, each starting a program here |
| `registry.rex` | `winsystem\registry.rex` | the registry, .NET's `Microsoft.Win32.Registry`: keys listed, created and deleted, values of each kind; a key saved to a `.reg` file and restored from it |
| `eventlog.rex` | `winsystem\eventlog.rex` | the event logs, .NET's `EventLog`: records read forwards and backwards, written under a source registered for them; a log cleared after a backup (`EventLogSession`) |
| `desktop.rex` | `winsystem\desktop.rex` | Program Manager's groups as folders of the Start menu; shortcuts made by WScript.Shell (COM, through the bridge) |
| `deskicon.rex` | `winsystem\deskicon.rex` | shortcuts on the user's or everybody's desktop: arguments, icon, hot key, window state |
| `getTheWindow.rex` | `winsystem\getTheWindow.rex` | windows found by part of their title: UI Automation's root element and TreeWalker; what a window can do (its patterns) |
| `displayWindowTree.rex` | `winsystem\displayWindowTree.rex` | a window picked in a list view, its elements (as UI Automation sees them) in a tree view |
| `writeWithNotepad.rex` | `winsystem\writeWithNotepad.rex` | Notepad driven: text typed (SendKeys) and read back (TextPattern), the window resized and closed, its Save dialog shown and answered (InvokePattern) |
| `menuNotepad.rex` | `winsystem\menuNotepad.rex` | Notepad's menus, read by opening them (ExpandCollapsePattern), printed and shown in a tree view |
| `menuCalc.rex` | `winsystem\menuCalc.rex` | the Calculator's menus, in two of its views (the classic's View menu; today's navigation pane) |
| `quickCalc.rex` | `winsystem\quickCalc.rex` | two calculations made by pushing the Calculator's buttons, the answers read from its display |
| `usewmgr.rex` | `winsystem\usewmgr.rex` | the Calculator and Notepad driven: views, answers through .NET's Clipboard, hexadecimal; Notepad minimized, maximized, restored, resized |
| `quickShowAllMenus.rex` | `winsystem\quickShowAllMenus.rex` | the menus of every window that has one |
| `displayAnyMenu.rex` | `winsystem\displayAnyMenu.rex` | the menus of a window given by its title, in a tree view |

**winsystem/: other programs' windows.** Those samples use winsystm.cls,
whose WindowsManager, WindowObject and MenuObject work with other programs'
windows through their handles, ids and Win32 menus. Here they use .NET's UI
Automation (`System.Windows.Automation`): a window, or anything in it, is an
`AutomationElement`, found from the root element, with what it can do as its
patterns (Invoke, Value, Text, ExpandCollapse, Window, Transform...). Their
framework, `windowsSystem.frm` (ooDialog's, ported), has the table from one
to the other and the routines the programs share. UI Automation sees what a
user sees, so it also drives the programs that draw their own controls (the
Windows 11 Notepad and Calculator, which winsystm.cls cannot); and it does
what a user can do: it reads a menu by opening it, and it does not disable,
hide or retitle another program's windows. The Calculator's buttons are
pushed by their AutomationIds, which differ between the classic Calculator
(Windows Server's) and today's: `calcKey` knows both.

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
| `::class D subclass RcDialog inherit ResizingAdmin`, `defineSizing` with `defaultLeft`..., `controlLeft`..., `controlSizing`, `useDefaultSizing`, `minSize`, `maxSize`, `wantSizeEnded` | the same: `inherit ResizingAdmin` (oodnet.cls's), with ooDialog's pins and arithmetic (STATIONARY, PROPORTIONAL, MYLEFT, MYTOP; to the dialog or a control named before); the dialog gets a sizing border |
| an edit control or combo box made a child of a list view (`setParent`, `isGrandChild`): Enter, Escape | `self~wantKeys(ctl)`: Enter and Escape go to its `KeyDown`, not to the dialog's default and Cancel buttons |
| `connectDateTimePickerEvent(id, "DATETIMECHANGE"...)`; `"USERSTRING"` (CANPARSE) | the same (.NET's `ValueChanged`...); USERSTRING: F2 puts an edit control over the picker, the method gets a Rexx `.DateTime` and the text and answers the new `.DateTime` |
| `connectHelp(m)` (F1); `setControlColor(id, bg, fg)` with ooDialog's colour numbers | the same (.NET's `HelpRequested`; Windows' default palette: 3 dark yellow, 13 red...) |
| any control's `HIDDEN`, `DISABLED` (a .rc's `NOT WS_VISIBLE`, `WS_DISABLED`) | the same, in every `create*` |
| `connectListViewEvent(id, "CLICK", m)` | the same (.NET's `MouseClick`: `listView~HitTest(e~X, e~Y)` gives the row and column) |
| `connectMonthCalendarEvent(id, "SELECT", m)` | the same (.NET's `DateSelected`: `e~Start`, a .NET `DateTime`) |
| any other event | `self~connectEvent(id, ".NET event name", m)` |
| `.BinaryMenuBar`, `.PopupMenu`, `menuBar~attachTo(self)` | a `MenuStrip`, `self~menuItem(text, method)`, `self~attachMenu(menu)` |
| `REPLY` and a loop that updates the dialog | `self~startTimer(ms, method)` (the dialog's own thread; stop it with `timer~Stop`) |
| `RxCalcSqrt(x)` and RxMath's kin | `.net~System~Math~Sqrt(x)` (trigonometry in radians) |
| `dlg~execute("SHOWTOP")`: 1 (OK) or 2 (Cancel) | the same |
| `ok`, `cancel`, `validate`, `leaving`, `initDialog` overridden | the same; `self~ok:super` ends the dialog when `validate` answers `.true` |
| data attributes (`createEdit(id, ..., "TLINE")`, then `self~TLine`) | the same |
| `infoDialog`, `errorDialog`, `askDialog`, `messageDialog`, `inputBox`, `integerBox`, `passwordBox`, `listChoice`, `multiListChoice`, `checkList`, `singleSelection`, `multiInputBox`, `fileNameDialog`, `browseForFolder`, `timedMessage` | the same names, arguments and results; `self~IDOK`... `self~IDCONTINUE` as ooDialog's |
| `.UserMenuBar~new`, `addPopup`, `addItem`, `addSeparator`, `complete`; `connectAllCommandEvents`; `checkRadio`, `check`, `gray` | the same on a NetMenuBar (the methods named from the items' text, as ooDialog's) |
| `.Mouse`'s events (`connectWheel`...), dragging with `DefListDragHandler`, `DefTreeDragHandler` | the controls' .NET events (`MouseWheel`, `ItemDrag`, `DragOver`, `DragDrop`); `connectListViewEvent(id, "BEGINDRAG", "DefListDragHandler")`, `connectTreeViewEvent(id, "BEGINDRAG", "DefTreeDragHandler")` as ooDialog's |
| `sendWinIntMsg(hwnd, msg, wParam, lParam)` (Windows' messages to a control) | `sendWinIntMsg(control, msg, wParam, lParam)` (a public routine of oodnet.cls) |
| `connectResize`, `connectResizing`, `connectSizeMoveEnded`; `DlgArea`, `DlgAreaU` | the same (.NET's `Resize`, WM_SIZING, `ResizeEnd`; ooDialog's arithmetic) |
| `::class P subclass ResControlDialog` (a dialog inside another); `TabOwnerDialog` with `ManagedTab`, `TabOwnerDlgInfo`, `ControlDlgInfo` | `::class P subclass ... inherit ControlDialog`, a `Panel` of its owner; `inherit TabOwnerDialog` and the same classes |
| `ResizingAdmin`'s `pagedTab(tabID, dlgIDs)` | the same: the control dialogs started in the dialog follow the tab control's display area |
| `PropertySheetDialog` with `WIZARD97` (`AERO`...), pages `subclass UserPSPDialog`, `setWizButtons`, `wizNext`, `wizBack`, `wizFinish`, `querySiblings` | `.NetPropertySheet~new(pages, "WIZARD97", caption)`, pages `subclass UserPSPDialog`: the same methods; `header` and `watermark` (.NET Images), as ooDialog's |
| `.PlainBaseDialog~setDefaultFont(name, size)` | `.NetDialog~defaultFont(name, size)` |
| a dialog method called from a thread of the program's own (`start`, a REPLY): ooDialog's go to the window | the same: from another thread, oodnet.cls's dialog methods run on the dialog's thread (the bridge's `.NetEventThread~runLater`); those that only change what it shows return at once |
| `createBitmapButton`, `installBitmapButton`, `changeBitmapButton`, `setBitmapPosition`, `scrollBitmapFromTo`, `loadBitmap`, `removeBitmap` | the same (a Panel drawing its bitmaps; a bitmap is a file's name or a .NET Image) |
| `getButtonDC`, `createPen`, `createBrush`, `objectToDC`, `rectangle`, `drawLine`, `drawArc`, `drawPie`, `fillDrawing`, `writeDirect` | the same, on a bitmap the control shows |
| `.CheckList~new(...)`, `.InputBox~new(...)` and the other standard dialog classes; `.application~defaultIcon(file)` | the same classes; `.NetDialog~defaultIcon(file)` |
| `new(..., dlgData., ...)`, `setDataStem`, `getDataStem`; `CONNECTBUTTONS` | the same (the stem's tails the controls' ids) |
| `executeAsync`, `endAsyncExecution`; `self~hide`, `show`, `enable`, `disable` | the same (a modeless form; a modal one hidden is made transparent) |
| `.WindowsRegistry` (winsystm.cls) | `.net~Microsoft~Win32~Registry` (`Save` and `Restore`: a `.reg` file, as `registry.rex` writes and reads it) |
| `.WindowsEventLog` | `.net~System~Diagnostics~EventLog`; `Eventing~Reader~EventLogSession` (`IsLogFull`, `ClearLog` with a backup) |
| `.WindowsProgramManager`: `AddGroup`, `AddItem`, `AddDesktopIcon` | the Start menu's and the desktop's folders (`Environment~GetFolderPath`), shortcuts by `.net~createObject("WScript.Shell")` |
| `.WindowsManager`, `.WindowObject`: `find(title)`, `desktopWindow`, `firstChild`, `next`, `title`, `wClass`, `coordinates` | UI Automation: `AutomationElement~RootElement`, `FindFirst` with a `PropertyCondition`, `TreeWalker~ControlViewWalker`, `~Current`'s `Name`, `ClassName`, `BoundingRectangle` (`windowsSystem.frm`'s table) |
| `wnd~menu`, `.MenuObject`; `processMenuCommand(menu, item)`; `sendCommand(id)`, `pushButton(label)` | the window's MenuBar element, its menus opened with their `ExpandCollapsePattern`; `menuCommand`, `pushButton` (a control's `InvokePattern`) in `windowsSystem.frm` |
| `sendText`, `sendKey`; `minimize`, `maximize`, `restore`, `resize`, `sendSysCommand("Close")` | the element's `SetFocus`, then .NET's `SendKeys`; the window's `WindowPattern` (`SetWindowVisualState`, `Close`) and `TransformPattern` (`Resize`) |
| `.WindowsClipboard`: `copy`, `paste`, `empty`, `isDataAvailable` | `.net~System~Windows~Forms~Clipboard`: `SetText`, `GetText`, `Clear`, `ContainsText` |
| `::requires "samplesSetup.rex"` (the sound path), `play("WHISTLE.WAV")` | the same: `samplesSetup.rex` here sets SOUNDPATH, which oodnet.cls's `play` searches |

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
