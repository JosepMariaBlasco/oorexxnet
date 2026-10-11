/* oodnet.cls: ooDialog's shape on Windows Forms, for porting ooDialog
   programs to pure .NET (through the ooRexx/.NET bridge).

   A dialog is a subclass of NetDialog, written as an ooDialog UserDialog is:
   create (or createCenter) in INIT, the controls in DEFINEDIALOG with the
   same create* methods and arguments (dialog units, as ooDialog: the
   coordinates of a .rc or a UserDialog are copied as they are), the setup in
   INITDIALOG, event methods connected with connect*Event, EXECUTE to show it
   (1 for OK, 2 for Cancel), OK / CANCEL / LEAVING to override. What differs:
   newXxx(id) gives the Windows Forms control itself, whose members are
   .NET's (edit~Text = "x", not edit~setText("x")); ids are names (strings or
   symbols), not numbers; an event method gets .NET's (sender, e). The
   public routines (infoDialog, askDialog, messageDialog, inputBox,
   fileNameDialog...) have ooDialog's names, arguments and results.

   .NetDialog~auto = .true makes everything unattended (the samples'
   argument "auto"): a dialog runs its autoRun method shortly after it shows
   (by default: it ends with OK), and the routines show nothing and answer
   their defaults.

   See README.md: the porting guide.                                          */

::requires "net.cls"

/* ------------------------------------------------------------------ dialog */
::class NetDialog public
::method auto class                    -- unattended (see the header)
  expose auto
  if \var("AUTO") then auto = .false
  return auto
::method "AUTO=" class
  expose auto
  use strict arg auto
::attribute form get                   -- the System.Windows.Forms.Form
-- ooDialog's constants for the answers of messageDialog and the buttons
::constant IDOK 1
::constant IDCANCEL 2
::constant IDABORT 3
::constant IDRETRY 4
::constant IDIGNORE 5
::constant IDYES 6
::constant IDNO 7
::constant IDTRYAGAIN 10
::constant IDCONTINUE 11
::method hwnd                          -- the window's handle (the routines take it, as ooDialog's, and need not)
  return self~form~Handle
::attribute initCode                   -- as ooDialog's (0: fine)

::method init
  expose controls data pending ending deferred defined
  controls = .directory~new            -- id (uppercased) -> control
  data = .directory~new                -- data attribute (uppercased) -> control id
  pending = .directory~new             -- data attribute values set before the control exists
  deferred = .array~new                -- connect*Event before defineDialog: made after it
  defined = .false
  ending = .false
  self~initCode = 0

/* create(x, y, cx, cy [, title [, style [, dlgClass [, fontName [, fontSize]]]]]),
   as ooDialog's; style: CENTER, MINIMIZEBOX, MAXIMIZEBOX, SIZEBOX, ...      */
::method create
  expose form bx by sizeX sizeY fontName fontSize
  use arg x, y, cx, cy, title = "", style = "", dlgClass, fontName = "MS Shell Dlg 2", fontSize = 8
  sizeX = cx; sizeY = cy
  F = .net~System~Windows~Forms
  D = .net~System~Drawing
  F~Application~EnableVisualStyles
  if .NetDialog~auto then call NetDialogThrow   -- unattended: an error in an event ends the run, no dialog about it
  form = F~Form~new
  dpi = form~DeviceDpi
  form~Font = NetDialogFont(fontName, fontSize, dpi)
  -- dialog base units, as Windows computes them for a dialog's font (GdiGetCharDimensions):
  -- the average width of a..z A..Z, rounded as integers, and the font's tmHeight
  if fontName~caselessEquals("System") then do   -- (its own, not its stand-in's: 8 x 16 at 96 dpi)
    bx = (8 * dpi + 48) % 96
    by = (16 * dpi + 48) % 96
  end
  else do
    flags = F~TextFormatFlags~NoPadding
    big = D~Size~new(32000, 32000)
    ext = F~TextRenderer~MeasureText("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz", form~Font, big, flags)~Width
    bx = (ext % 26 + 1) % 2
    by = F~TextRenderer~MeasureText("A", form~Font, big, flags)~Height
  end
  form~Text = title
  form~ClientSize = D~Size~new(self~px(cx), self~py(cy))
  style = style~upper
  if style~wordPos("SIZEBOX") > 0 | style~wordPos("THICKFRAME") > 0 then form~FormBorderStyle = "Sizable"
  else form~FormBorderStyle = "FixedDialog"
  form~MaximizeBox = style~wordPos("MAXIMIZEBOX") > 0
  form~MinimizeBox = style~wordPos("MINIMIZEBOX") > 0
  if style~wordPos("CENTER") > 0 then form~StartPosition = "CenterScreen"
  else do
    form~StartPosition = "Manual"
    form~Location = D~Point~new(self~px(x), self~py(y))
  end
  form~FormClosing += .net~handler(self, "NETDIALOG.CLOSING")
  return 0

/* createCenter(cx, cy [, title [, style [, dlgClass [, fontName [, fontSize]]]]]) */
::method createCenter
  use arg cx, cy, title = "", style = "", dlgClass, fontName = "MS Shell Dlg 2", fontSize = 8
  return self~create(0, 0, cx, cy, title, style "CENTER", , fontName, fontSize)

::method fontName                      -- the dialog's font, as create was given it
  expose fontName
  return fontName
::method fontSize
  expose fontSize
  return fontSize
::method sizeX                         -- the dialog's size, in dialog units (ooDialog's sizeX, sizeY)
  expose sizeX
  return sizeX
::method sizeY
  expose sizeY
  return sizeY
::method px                            -- dialog units to pixels, across
  expose bx
  return trunc(arg(1) * bx / 4 + 0.5)
::method py                            -- and down
  expose by
  return trunc(arg(1) * by / 8 + 0.5)

/* the controls, as ooDialog's create* methods (x, y, cx, cy in dialog units) */
::method createStatic
  use arg id, x, y, cx, cy, style = "", text = ""
  c = self~place(id, .net~System~Windows~Forms~Label~new, x, y, cx, cy)
  c~Text = text
  style = style~upper
  if style~wordPos("RIGHT") > 0 then c~TextAlign = "TopRight"
  if style~wordPos("CENTER") > 0 then c~TextAlign = "TopCenter"
  if style~wordPos("BORDER") > 0 | style~pos("FRAME") > 0 then c~BorderStyle = "FixedSingle"   -- (GRAYFRAME, BLACKFRAME...)
  if style~pos("FRAME") > 0 then self~frame(c)                 -- a frame: behind what it frames
  return 0
::method createStaticText
  forward message "CREATESTATIC"
::method createEdit
  use arg id, x, y, cx, cy, style = "", attributeName
  e = .net~System~Windows~Forms~TextBox~new
  e~AutoSize = .false                  -- (the .rc's height, not its font's)
  c = self~place(id, e, x, y, cx, cy)
  style = style~upper
  if style~wordPos("MULTILINE") > 0 then do
    c~Multiline = .true
    c~AcceptsReturn = .true
  end
  v = style~wordPos("VSCROLL") > 0; h = style~wordPos("HSCROLL") > 0
  if v & h then c~ScrollBars = "Both"; else if v then c~ScrollBars = "Vertical"; else if h then c~ScrollBars = "Horizontal"
  if h then c~WordWrap = .false
  if style~wordPos("READONLY") > 0 then do
    c~ReadOnly = .true
    c~GotFocus += .net~handler(.NetDialogNoSelect~new, "DESELECT")   -- (Windows Forms selects the text)
  end
  if style~wordPos("PASSWORD") > 0 then c~UseSystemPasswordChar = .true
  if style~wordPos("RIGHT") > 0 then c~TextAlign = "Right"
  if style~wordPos("CENTER") > 0 then c~TextAlign = "Center"
  if arg(7, "E") then self~dataAttribute(attributeName, id)
  return 0
::method createPushButton
  use arg id, x, y, cx, cy, style = "", label = "", methodName
  if style~upper~wordPos("OWNERDRAW") > 0 | style~upper~wordPos("OWNER") > 0 then do   -- a surface to draw on (connectDraw: its Paint)
    c = self~place(id, .net~System~Windows~Forms~Panel~new, x, y, cx, cy)
    if arg(8, "E") then self~connectButtonEvent(id, "CLICKED", methodName)
    return 0
  end
  c = self~place(id, .net~System~Windows~Forms~Button~new, x, y, cx, cy)
  id = NetDialogKey(id)                -- (1, 2, 9: IDOK, IDCANCEL, IDHELP)
  c~Text = label
  c~Padding = .net~System~Windows~Forms~Padding~new(0)   -- a Win32 button's margins: "ArcCos" in one line
  style = style~upper
  if .net~isInstance(self~form, "System.Windows.Forms.Form") then do   -- (not on a property sheet's page)
    if style~wordPos("DEFAULT") > 0 | id~string~upper == "IDOK" then self~form~AcceptButton = c
    if id~string~upper == "IDCANCEL" then self~form~CancelButton = c
  end
  if style~wordPos("DISABLED") > 0 then c~Enabled = .false
  select
    when arg(8, "E") then self~connectButtonEvent(id, "CLICKED", methodName)
    when id~string~upper == "IDOK" then self~connectButtonEvent(id, "CLICKED", "OK")
    when id~string~upper == "IDCANCEL" then self~connectButtonEvent(id, "CLICKED", "CANCEL")
    when id~string~upper == "IDHELP" then self~connectButtonEvent(id, "CLICKED", "HELP")
    otherwise nop
  end
  return 0
::method createCheckBox
  use arg id, x, y, cx, cy, style = "", label = "", attributeName
  c = self~place(id, .net~System~Windows~Forms~CheckBox~new, x, y, cx, cy)
  c~Text = label
  if arg(8, "E") then self~dataAttribute(attributeName, id)
  return 0
::method createRadioButton
  use arg id, x, y, cx, cy, style = "", label = "", attributeName
  c = self~place(id, .net~System~Windows~Forms~RadioButton~new, x, y, cx, cy)
  c~Text = label
  if arg(8, "E") then self~dataAttribute(attributeName, id)
  return 0
::method createGroupBox
  use arg id, x, y, cx, cy, style = "", text = ""
  c = self~place(id, .net~System~Windows~Forms~GroupBox~new, x, y, cx, cy)
  c~Text = text
  self~frame(c)                        -- behind the controls drawn over it
  return 0
::method createListBox
  use arg id, x, y, cx, cy, style = "", attributeName
  c = self~place(id, .net~System~Windows~Forms~ListBox~new, x, y, cx, cy)
  style = style~upper
  if style~wordPos("MULTI") > 0 | style~wordPos("EXTSEL") > 0 then c~SelectionMode = "MultiExtended"
  if style~wordPos("SORT") > 0 | style~wordPos("STANDARD") > 0 then c~Sorted = .true   -- (LBS_STANDARD sorts)
  if style~wordPos("USETAB") > 0 then c~UseTabStops = .true
  if style~wordPos("COLUMNS") > 0 then c~MultiColumn = .true
  c~IntegralHeight = .false
  if style~wordPos("PARTIAL") = 0 then do  -- as Win32 (LBS_NOINTEGRALHEIGHT: PARTIAL): whole rows of the dialog font's
    by = self~py(8000) / 1000                -- height (its tmHeight, the base unit), within a 2-pixel border
    c~Height = (c~Height - 4) % by * by + 4
  end
  if arg(7, "E") then self~dataAttribute(attributeName, id)
  return 0
::method createComboBox
  use arg id, x, y, cx, cy, style = "", attributeName
  c = self~place(id, .net~System~Windows~Forms~ComboBox~new, x, y, cx, cy)
  style = style~upper
  select
    when style~wordPos("LIST") > 0 then c~DropDownStyle = "DropDownList"
    when style~wordPos("SIMPLE") > 0 then c~DropDownStyle = "Simple"
    otherwise c~DropDownStyle = "DropDown"
  end
  if style~wordPos("SORT") > 0 then c~Sorted = .true
  if arg(7, "E") then self~dataAttribute(attributeName, id)
  return 0
/* An up-down control with AUTOBUDDY and SETBUDDYINT joins the edit control
   before it (a number): Windows Forms has both in one, a NumericUpDown, which
   takes the edit's place and both ids. */
::method createUpDown
  expose last
  use arg id, x, y, cx, cy, style = ""
  F = .net~System~Windows~Forms
  if style~upper~wordPos("AUTOBUDDY") > 0, style~upper~wordPos("SETBUDDYINT") > 0, var("LAST"), .net~isInstance(last~ctl, "System.Windows.Forms.TextBox") then do
    old = last~ctl
    c = F~NumericUpDown~new
    c~Location = old~Location
    c~Size = old~Size
    c~TextAlign = old~TextAlign
    c~ThousandsSeparator = .true       -- as Windows' up-down shows its buddy's number
    self~form~Controls~Remove(old)
    self~form~Controls~Add(c)
    self~register(last~id, c)
    self~register(id, c)
    return 0
  end
  /* no number in a buddy: Windows Forms has no up-down alone; a small
     vertical scroll bar, whose arrows give connectUpDownEvent's DELTAPOS
     (ooDialog's setRange / setPosition: ~Minimum, ~Maximum, ~Value) */
  buddy = .nil
  if var("LAST") then buddy = last~ctl  -- (the control made before: place changes LAST)
  c = self~place(id, F~VScrollBar~new, x, y, cx, cy)
  c~LargeChange = 1
  st = style~upper
  if st~wordPos("AUTOBUDDY") > 0, (st~wordPos("ALIGNRIGHT") > 0 | st~wordPos("ALIGNLEFT") > 0), -
     .net~isInstance(buddy, "System.Windows.Forms.TextBox") then do   -- as Win32: at the buddy's edge, the buddy narrower
    b = buddy                          -- (comctl32: the up-down as wide as a scroll bar and 1, whatever
    w = F~SystemInformation~VerticalScrollBarWidth + 1   -- the .rc says, over the buddy's 2-pixel border)
    c~Width = w
    b~Width = b~Width - (w - 2)
    if st~wordPos("ALIGNLEFT") > 0 then do
      c~Location = .net~System~Drawing~Point~new(b~Left, b~Top)
      b~Left = b~Left + (w - 2)
    end
    else c~Location = .net~System~Drawing~Point~new(b~Right - 2, b~Top)
    c~Height = b~Height
    c~BringToFront
  end
  return 0
::method createScrollBar                -- VERTICAL, else horizontal (ooDialog: setRange, setPosition; here ~Minimum, ~Maximum, ~Value)
  use arg id, x, y, cx, cy, style = ""
  F = .net~System~Windows~Forms
  bar = (style~upper~wordPos("VERTICAL") > 0)~?(F~VScrollBar~new, F~HScrollBar~new)
  c = self~place(id, bar, x, y, cx, cy)
  c~LargeChange = 1
  return 0
::method createMonthCalendar
  use arg id, x, y, cx, cy, style = ""
  c = self~place(id, .net~System~Windows~Forms~MonthCalendar~new, x, y, cx, cy)
  c~MaxSelectionCount = 1
  return 0
::method createDateTimePicker
  use arg id, x, y, cx, cy, style = ""
  self~place(id, .net~System~Windows~Forms~DateTimePicker~new, x, y, cx, cy)
  return 0
::method createProgressBar
  use arg id, x, y, cx, cy, style = ""
  self~place(id, .net~System~Windows~Forms~ProgressBar~new, x, y, cx, cy)
  return 0
::method createTrackBar
  use arg id, x, y, cx, cy, style = ""
  c = self~place(id, .net~System~Windows~Forms~TrackBar~new, x, y, cx, cy)
  if style~upper~wordPos("VERTICAL") > 0 then c~Orientation = "Vertical"
  return 0
::method createListView
  use arg id, x, y, cx, cy, style = ""
  c = self~place(id, .net~System~Windows~Forms~ListView~new, x, y, cx, cy)
  style = style~upper
  select
    when style~wordPos("REPORT") > 0 then c~View = "Details"
    when style~wordPos("LIST") > 0 then c~View = "List"
    when style~wordPos("SMALLICON") > 0 then c~View = "SmallIcon"
    otherwise c~View = "LargeIcon"
  end
  if style~wordPos("SHOWSELALWAYS") > 0 then c~HideSelection = .false
  if style~wordPos("SINGLESEL") > 0 then c~MultiSelect = .false
  return 0
::method createTreeView
  use arg id, x, y, cx, cy, style = ""
  c = self~place(id, .net~System~Windows~Forms~TreeView~new, x, y, cx, cy)
  style = style~upper
  c~ShowLines = style~wordPos("LINES") > 0 | style~wordPos("HASLINES") > 0
  c~ShowPlusMinus = style~wordPos("BUTTONS") > 0 | style~wordPos("HASBUTTONS") > 0
  c~ShowRootLines = style~wordPos("ATROOT") > 0 | style~wordPos("LINESATROOT") > 0
  return 0
::method createTab
  use arg id, x, y, cx, cy, style = ""
  self~place(id, .net~System~Windows~Forms~TabControl~new, x, y, cx, cy)
  return 0

/* ooDialog's newXxx(id): here the Windows Forms control itself */
::method control
  expose controls
  use strict arg id
  c = controls[NetDialogKey(id)]
  if c == .nil then raise syntax 93.900 array("this dialog has no control" id)
  return c
::method newStatic;       forward message "CONTROL"
::method newEdit;         forward message "CONTROL"
::method newPushButton;   forward message "CONTROL"
::method newCheckBox;     forward message "CONTROL"
::method newRadioButton;  forward message "CONTROL"
::method newGroupBox;     forward message "CONTROL"
::method newListBox;      forward message "CONTROL"
::method newComboBox;     forward message "CONTROL"
::method newUpDown;       forward message "CONTROL"
::method newScrollBar;    forward message "CONTROL"
::method newMonthCalendar; forward message "CONTROL"
::method newDateTimePicker; forward message "CONTROL"
::method newProgressBar;  forward message "CONTROL"
::method newTrackBar;     forward message "CONTROL"
::method newListView;     forward message "CONTROL"
::method newTreeView;     forward message "CONTROL"
::method newTab;          forward message "CONTROL"

/* events: ooDialog's names; the method gets .NET's (sender, e) */
::method connectButtonEvent
  use arg id, event = "CLICKED", methodName
  if arg(3, "O") then methodName = id
  select case event~upper
    when "DBLCLK" then e = "DoubleClick"
    when "GOTFOCUS" then e = "GotFocus"
    when "LOSTFOCUS" then e = "LostFocus"
    otherwise e = "Click"
  end
  return self~connectEvent(id, e, methodName)
::method connectListViewEvent
  use arg id, event, methodName
  select case event~upper
    when "CLICK" then e = "MouseClick"
    when "DBLCLK", "ACTIVATE" then e = "DoubleClick"
    when "COLUMNCLICK" then e = "ColumnClick"
    when "SELECTCHANGED", "SELCHANGE" then e = "ItemSelectionChanged"   -- (e~ItemIndex, e~IsSelected)
    when "CHECKBOXCHANGED" then e = "ItemChecked"
    otherwise e = event
  end
  return self~connectEvent(id, e, methodName)
::method connectMonthCalendarEvent
  use arg id, event, methodName
  select case event~upper
    when "SELECT" then e = "DateSelected"
    when "SELCHANGE" then e = "DateChanged"
    otherwise e = event
  end
  return self~connectEvent(id, e, methodName)
/* DELTAPOS: the method gets ooDialog's (position, delta): delta +1 for the up
   arrow, -1 for the down one (of a NumericUpDown: its ValueChanged, the
   change); its result is not used */
::method connectUpDownEvent
  expose defined deferred
  use arg id, event, methodName
  if \defined then do                  -- in INIT (an RcDialog's way): once the controls exist
    deferred~append(.array~of("CONNECTUPDOWNEVENT", .array~of(id, event, methodName)))
    return 0
  end
  c = self~control(id)
  relay = .NetDialogUpDownRelay~new(self, methodName)
  if .net~isInstance(c, "System.Windows.Forms.ScrollBar") then c~Scroll += .net~handler(relay, "SCROLL")
  else c~ValueChanged += .net~handler(relay, "CHANGED")
  return 0
::method connectEditEvent
  use arg id, event, methodName
  select case event~upper
    when "CHANGE", "UPDATE" then e = "TextChanged"
    when "GOTFOCUS", "SETFOCUS" then e = "GotFocus"
    when "LOSTFOCUS", "KILLFOCUS" then e = "LostFocus"
    otherwise e = event
  end
  return self~connectEvent(id, e, methodName)
::method connectListBoxEvent
  use arg id, event, methodName
  select case event~upper
    when "SELCHANGE" then e = "SelectedIndexChanged"
    when "DBLCLK" then e = "DoubleClick"
    otherwise e = event
  end
  return self~connectEvent(id, e, methodName)
::method connectComboBoxEvent
  forward message "CONNECTLISTBOXEVENT"
/* any .NET event of a control, by its .NET name */
::method connectEvent
  expose defined deferred
  use strict arg id, netEvent, methodName
  if \defined then do                  -- in INIT (an RcDialog's way): once the controls exist
    deferred~append(.array~of("CONNECTEVENT", .array~of(id, netEvent, methodName)))
    return 0
  end
  .net~addHandler(self~control(id), netEvent, .net~handler(self, methodName))
  return 0

/* owner drawing: methodName gets .NET's Paint (sender, e): e~Graphics draws
   on the control (System.Drawing: Pen, DrawEllipse, DrawRectangle,
   DrawString...), each time it must be drawn; redrawControl asks for it */
::method connectDraw
  use strict arg id, methodName
  return self~connectEvent(id, "Paint", methodName)
::method redrawControl
  use arg id, erase = 1
  c = self~control(id)
  c~Invalidate
  c~Update
  return 0

/* scrollInControl(id, text [, fontName [, fontSize [, fontStyle [, displaceY
   [, step [, sleep [, color]]]]]]]): the text crosses the control from right
   to left, step pixels every sleep milliseconds (a timer: the dialog goes on
   meanwhile); fontStyle BOLD, ITALIC, UNDERLINE; color a .NET Color or an
   ooDialog palette index (0 black). self~scrolling: whether it still runs. */
::method scrollInControl
  expose scroller
  use arg id, text, fontName = "MS Shell Dlg 2", fontSize = 8, fontStyle = "", displaceY = 0, step = 4, sleep = 10, color = 0
  if var("SCROLLER") then scroller~stop
  st = ""
  do w over fontStyle~upper~makeArray(" ")
    if wordPos(w, "BOLD ITALIC UNDERLINE STRIKEOUT") > 0 then st = st w~left(1) || w~substr(2)~lower
  end
  if st == "" then st = "Regular"
  font = NetDialogFont(fontName, fontSize, self~form~DeviceDpi, st~strip~changeStr(" ", ", "))
  if \.net~isInstance(color, "System.Drawing.Color") then color = .net~System~Drawing~Color~Black
  scroller = .NetDialogScroller~new(self~control(id), text, font, displaceY, step, sleep, color)
  return 0
::method scrolling
  expose scroller
  return var("SCROLLER") & scroller~running

/* a Windows Forms timer calling methodName every ms milliseconds (stop it: timer~Stop) */
::method startTimer
  use strict arg ms, methodName
  t = .net~System~Windows~Forms~Timer~new
  t~Interval = ms
  t~Tick += .net~handler(self, methodName)
  t~Start
  return t

/* a menu bar (a .NET MenuStrip) on top of the dialog: the controls move down
   and the dialog grows by its height (ooDialog's menuBar~attachTo(dlg)) */
::method attachMenu
  use strict arg menu
  f = self~form
  h = menu~PreferredSize~Height
  do c over f~Controls~makeArray       -- (a copy: the collection changes below)
    c~Top = c~Top + h
  end
  f~Controls~Add(menu)
  f~MainMenuStrip = menu
  f~ClientSize = .net~System~Drawing~Size~new(f~ClientSize~Width, f~ClientSize~Height + h)
  return menu
/* a menu item (a ToolStripMenuItem) whose click runs methodName, if given */
::method menuItem
  use arg text, methodName
  item = .net~System~Windows~Forms~ToolStripMenuItem~new(text)
  if arg(2, "E") then item~Click += .net~handler(self, methodName)
  return item

/* ooDialog's helpers on controls by id */
::method getControlData                -- a control's value: an edit's text, a check's 1 / 0, a list's selected item
  use strict arg id
  return NetDialogValue(self~control(id))
::method setControlData
  use strict arg id, value
  call NetDialogSetValue self~control(id), value
  return 0
::method addComboEntry
  use strict arg id, text
  return self~control(id)~Items~Add(text) + 1
::method addListEntry
  forward message "ADDCOMBOENTRY"
::method enableItem
  self~control(arg(1))~Enabled = .true
  return 0
::method disableItem
  self~control(arg(1))~Enabled = .false
  return 0
::method createFontEx                  -- createFontEx(name, size [, additional]): a .NET Font (weight >= 600: bold)
  expose form
  use arg name, size = 8, additional = .nil
  style = "Regular"
  if additional \== .nil then do
    if additional~hasIndex("WEIGHT"), additional~weight >= 600 then style = "Bold"
    if additional~hasIndex("ITALIC"), additional~italic == .true then style = style~changeStr("Regular", "") "Italic"
  end
  dpi = 96
  if var("FORM") then dpi = form~DeviceDpi
  return NetDialogFont(name, size, dpi, style~strip~changeStr(" ", ", "))
::method setControlFont
  use strict arg id, font
  self~control(id)~Font = font
  return 0
::method setListTabulators             -- setListTabulators(id, tab...): tab stops, in dialog units
  use arg id
  c = self~control(id)
  c~UseCustomTabOffsets = .true
  do i = 2 to arg(); c~CustomTabOffsets~Add(.net~int32(self~px(arg(i)))); end
  return 0
/* showBalloon(control, title, text [, icon]): a balloon tip on a control
   (ooDialog's edit~showBalloon(title, text, icon)); icon INFO, WARNING, ERROR */
::method showBalloon
  use arg ctl, title, text, icon = "INFO"
  if NetDialogAuto("balloon:" title "-" text) then return 0
  tip = .net~System~Windows~Forms~ToolTip~new
  tip~IsBalloon = .true
  tip~ToolTipTitle = title
  select case icon~upper
    when "ERROR" then tip~ToolTipIcon = "Error"
    when "WARNING" then tip~ToolTipIcon = "Warning"
    when "NONE" then nop
    otherwise tip~ToolTipIcon = "Info"
  end
  tip~Show(text, ctl, ctl~Width % 2, ctl~Height, 4000)
  return 0
::method deleteFont                    -- (.NET frees fonts itself)
  return 0
::method getData                       -- (ooDialog copies attributes and controls; here they are one)
  return 0
::method setData
  return 0
::method help unguarded                -- (to override) the Help button (IDHELP)
  return 0

::method setTitle
  self~form~Text = arg(1)
::method title
  return self~form~Text

/* ------------------------------------------------------- property sheet pages
   Any NetDialog can be a page of a NetPropertySheet (ooDialog's RcPSPDialog
   and UserPSPDialog): its controls go into a tab page the first time it is
   shown (initDialog then; wasActivated tells), setActive runs each time it
   is shown, killActive when another one is chosen (.false keeps it), apply
   on the sheet's OK. propSheet is the sheet.                              */
::attribute propSheet
::method wasActivated
  expose built
  return var("BUILT")
::method setActive unguarded            -- (to override)
  return 0
::method killActive unguarded           -- (to override) .false: stay on this page
  return .true
::method apply unguarded                -- (to override)
  return 0
::method hostIn                        -- (inside) the page in a container (a TabPage), not its own window
  expose form
  use strict arg container
  container~Font = form~Font
  container~Text = form~Text
  old = form
  form = container
  old~Dispose
::method buildPage                     -- (inside) its controls, the first time it is shown
  expose built defined deferred
  if var("BUILT") then return
  built = .true
  self~defineDialog
  self~framesToBack
  defined = .true
  do d over deferred; self~sendWith(d[1], d[2]); end
  self~initDialog
  self~applyData

/* Group boxes and frames go behind the other controls once they are all
   made (a control made later would otherwise be behind an opaque GroupBox);
   in reverse order, so that a frame made first, the outer one, is the last. */
::method frame private
  expose frames
  use arg c
  if \var("FRAMES") then frames = .array~new
  frames~append(c)
::method framesToBack private
  expose frames
  if \var("FRAMES") then return
  self~groupRadios
  do i = frames~items to 1 by -1
    frames[i]~SendToBack
  end

/* Radio buttons within a group box's rectangle go into the group box: in
   Windows Forms the radio buttons of one container are one group (Win32
   groups them by WS_GROUP), and the group box's are its own. */
::method groupRadios private
  expose frames
  boxes = .array~new
  do f over frames
    if .net~isInstance(f, "System.Windows.Forms.GroupBox") then boxes~append(f)
  end
  if boxes~items = 0 then return
  do c over self~form~Controls~makeArray
    if \.net~isInstance(c, "System.Windows.Forms.RadioButton") then iterate
    do b over boxes
      if b~Bounds~Contains(c~Bounds) then do
        self~form~Controls~Remove(c)
        c~Location = .net~System~Drawing~Point~new(c~Left - b~Left, c~Top - b~Top)
        b~Controls~Add(c)
        leave
      end
    end
  end

/* execute([show [, icon]]): defineDialog, initDialog, then the dialog until
   it ends: 1 (OK) or 2 (Cancel); leaving runs last. Unguarded, so that the
   event methods, called while it waits, can run. */
::method execute unguarded
  expose form ending defined deferred
  if \var("FORM") then raise syntax 98.900 array("NetDialog: create (or createCenter) first")
  self~defineDialog
  self~framesToBack
  defined = .true
  do d over deferred; self~sendWith(d[1], d[2]); end
  self~initDialog
  self~applyData
  if .NetDialog~auto then do            -- unattended: autoRun soon, and a watchdog
    runner = .NetDialogAutoRun~new(self)
    t = .net~System~Windows~Forms~Timer~new
    t~Interval = 1200
    h = .net~handler(runner, "TICK")
    t~Tick += h
    t~Start
    w = .net~System~Windows~Forms~Timer~new
    w~Interval = 30000
    w~Tick += .net~handler(runner, "WATCHDOG")
    w~Start
    runner~timers = .array~of(t, w)
    say "(auto) showing" form~Text
  end
  r = form~ShowDialog
  self~snapshot                        -- the data attributes keep their values
  if var("RUNNER") then do
    do t over runner~timers; t~Stop; end
    if runner~failed \== .false then do
      form~Dispose
      raise syntax 98.900 array("NetDialog (auto):" runner~failed)
    end
  end
  self~leaving
  form~Dispose
  return (r~string == "OK")~?(1, 2)
::method defineDialog                  -- (to override)
::method initDialog                    -- (to override)
::method leaving                       -- (to override)
::method validate                      -- (to override) .false keeps the dialog open on OK
  return .true
::method ok unguarded
  if self~validate then self~endDialog(1)
  return 0
::method cancel unguarded
  self~endDialog(2)
  return 0
::method autoRun unguarded             -- unattended (.NetDialog~auto): what the user would do
  self~ok
::method endDialog unguarded           -- ends the dialog: 1 OK, else Cancel
  expose form ending
  use arg code = 1
  ending = .true
  form~DialogResult = (code = 1)~?("OK", "Cancel")
::method "NETDIALOG.CLOSING" unguarded  -- the window's [x] (or Alt+F4): the dialog's cancel
  expose ending
  use arg sender, e
  if ending then return
  ending = .true
  self~cancel

/* data attributes, as ooDialog's: self~name gives the control's value,
   self~name = v sets it (before execute, when the control is created) */
::method applyData private              -- the data attributes set so far, into their controls
  expose data pending controls
  do attr over pending~allIndexes
    c = controls[NetDialogKey(data[attr])]
    if c \== .nil then call NetDialogSetValue c, pending[attr]
  end
::method snapshot private
  expose data pending controls closed
  do attr over data~allIndexes
    c = controls[NetDialogKey(data[attr])]
    if c \== .nil then pending[attr] = NetDialogValue(c)
  end
  closed = .true
::method dataAttribute private
  expose data
  use arg name, id
  data[name~upper] = id
::method unknown
  expose data pending controls closed defined
  use arg name, args
  set = name~right(1) == "="
  attr = set~?(name~left(name~length - 1), name)
  id = data[attr]
  if id == .nil, \defined then do      -- in INIT (an RcDialog's way): a control still to be made
    if set then do
      pending[attr] = args[1]
      return
    end
    if pending~hasIndex(attr) then return pending[attr]
  end
  if id == .nil then raise syntax 97.1 array(self, name)
  c = controls[NetDialogKey(id)]
  if set then do                       -- remembered too: applied again after initDialog (as ooDialog's setData),
    pending[attr] = args[1]            -- when a list has its items
    if c \== .nil then call NetDialogSetValue c, args[1]
    return
  end
  if c == .nil | var("CLOSED") then return pending[attr]
  return NetDialogValue(c)

/* (inside) a control in place: x, y, cx, cy in dialog units */
::method place private
  expose last pending data
  use arg id, ctl, x, y, cx, cy
  D = .net~System~Drawing
  ctl~Location = D~Point~new(self~px(x), self~py(y))
  ctl~Size = D~Size~new(self~px(cx), self~py(cy))
  self~form~Controls~Add(ctl)
  self~register(id, ctl)
  last = .NetDialogLast~new(id, ctl)
  do attr over data~allIndexes         -- a data attribute's value set before
    if data[attr]~string~upper == id~string~upper & pending~hasIndex(attr) then call NetDialogSetValue ctl, pending[attr]
  end
  return ctl
::method register private
  expose controls
  use arg id, ctl
  if id \== "" & id \== -1 then do
    controls[NetDialogKey(id)] = ctl
    ctl~Name = id~string                 -- (its id, for UI Automation and measure-dialogs.rex)
  end

/* ------------------------------------------------------------------- menus */
/* ooDialog's menu bar and popup menus, as a .NET MenuStrip: insertPopup,
   insertItem, insertSeparator (before the item `before`, by id; at the end
   when it is omitted or not there), connectCommandEvent(id, method, dialog),
   enable / disable / check / uncheck (by id), attachTo(dialog). Items with
   the ids IDOK and IDCANCEL end the dialog with its ok and cancel, as
   ooDialog's WM_COMMAND does. A menu of a .rc: rc2oodnet.rex -cls makes it a
   subclass of NetMenuBar.                                                  */
::class NetMenuBar public
::attribute strip get                  -- the MenuStrip
::method init                          -- (ooDialog's arguments are not needed)
  expose strip popups connected
  strip = .net~System~Windows~Forms~MenuStrip~new
  popups = .array~new
  connected = .directory~new
::method getPopup                      -- the NetPopupMenu inserted with that id
  expose popups
  use strict arg id
  do p over popups
    if p~id \== .nil, NetMenuKey(p~id) == NetMenuKey(id) then return p
  end
  return .nil
::method insertPopup
  expose strip popups
  use arg before = .nil, id = .nil, popup, text
  if id \== .nil then popup~id = id
  popup~item~Text = text
  call NetMenuInsert strip~Items, popup~item, self~find(before)
  popups~append(popup)
  return 0
::method find                          -- the ToolStripItem with that id, or .nil
  expose popups
  use arg id
  if id == .nil then return .nil
  do p over popups
    i = p~find(id)
    if i \== .nil then return i
  end
  return .nil
::method item                          -- the same, or an error
  use strict arg id
  i = self~find(id)
  if i == .nil then raise syntax 93.900 array("this menu has no item" id)
  return i
::method connectCommandEvent
  expose connected
  use strict arg id, methodName, dialog
  self~item(id)~Click += .net~handler(dialog, methodName)
  connected[NetMenuKey(id)] = .true
  return 0
::method enable;  self~item(arg(1))~Enabled = .true;  return 0
::method disable; self~item(arg(1))~Enabled = .false; return 0
::method isEnabled; return self~item(arg(1))~Enabled
::method check;   self~item(arg(1))~Checked = .true;  return 0
::method uncheck; self~item(arg(1))~Checked = .false; return 0
::method isChecked; return self~item(arg(1))~Checked
::method attachTo                      -- attachTo(dialog [, pos]): on top of the dialog
  expose strip connected
  use arg dialog
  if \connected~hasIndex("IDOK"), self~find("IDOK") \== .nil then self~connectCommandEvent("IDOK", "OK", dialog)
  if \connected~hasIndex("IDCANCEL"), self~find("IDCANCEL") \== .nil then self~connectCommandEvent("IDCANCEL", "CANCEL", dialog)
  dialog~attachMenu(strip)
  return 0

::class NetPopupMenu public
::attribute item get                   -- the ToolStripMenuItem that holds the items
::attribute id                         -- its id, if it has one
::method init
  expose item ids
  use arg id = .nil
  self~id = (id == "")~?(.nil, id)
  item = .net~System~Windows~Forms~ToolStripMenuItem~new
  ids = .directory~new
/* as a context menu (ooDialog's): assignTo(dialog [, autoConnect]): with
   autoConnect each item runs the dialog's method named as its text without
   "&", spaces and dots ("&Add Employee..." runs addEmployee);
   connectContextMenu(method, hwnd): a right click on that window calls the
   dialog's method with (hwnd, x, y), screen coordinates (-1, -1 from the
   keyboard); show(point): the menu there; enable / disable (an id, or an
   Array of them) */
::method assignTo
  expose dialog item
  use arg dialog, autoConnect = .false
  if autoConnect then do i over item~DropDownItems~makeArray
    if .net~isInstance(i, "System.Windows.Forms.ToolStripSeparator") then iterate
    name = i~Text~changeStr("&", "")~changeStr(" ", "")~changeStr(".", "")
    i~Click += .net~handler(dialog, name)
  end
  return 0
::method connectContextMenu
  expose dialog
  use strict arg methodName, hwnd
  c = .net~System~Windows~Forms~Control~FromHandle(hwnd)
  relay = .NetDialogContextRelay~new(dialog, methodName, hwnd)
  c~MouseUp += .net~handler(relay, "MOUSEUP")
  c~KeyUp += .net~handler(relay, "KEYUP")
  return 0
::method show
  expose strip
  use arg pos
  if \var("STRIP") then do            -- its items move to a ContextMenuStrip, once
    strip = .net~System~Windows~Forms~ContextMenuStrip~new
    do i over item~DropDownItems~makeArray; strip~Items~Add(i); end
  end
  strip~Show(.net~System~Drawing~Point~new(pos~x, pos~y))
  return 0
::method enable
  use strict arg ids
  if \ids~isA(.array) then ids = .array~of(ids)
  do i over ids; self~find(i)~Enabled = .true; end
  return 0
::method disable
  use strict arg ids
  if \ids~isA(.array) then ids = .array~of(ids)
  do i over ids; self~find(i)~Enabled = .false; end
  return 0
::method insertItem                    -- insertItem(before, id, text [, state]): state GRAYED, DISABLED, CHECKED
  expose item ids
  use arg before = .nil, id, text, state = ""
  i = .net~System~Windows~Forms~ToolStripMenuItem~new(text)
  state = state~upper
  if state~wordPos("GRAYED") > 0 | state~wordPos("DISABLED") > 0 then i~Enabled = .false
  if state~wordPos("CHECKED") > 0 then i~Checked = .true
  call NetMenuInsert item~DropDownItems, i, self~find(before)
  ids[NetMenuKey(id)] = i
  return 0
::method insertSeparator               -- insertSeparator(before, id)
  expose item ids
  use arg before = .nil, id = .nil
  i = .net~System~Windows~Forms~ToolStripSeparator~new
  call NetMenuInsert item~DropDownItems, i, self~find(before)
  if id \== .nil then ids[NetMenuKey(id)] = i
  return 0
::method insertPopup                   -- a submenu: insertPopup(before, id, popup, text)
  expose item ids subs
  use arg before = .nil, id = .nil, popup, text
  if \var("SUBS") then subs = .array~new
  popup~item~Text = text
  call NetMenuInsert item~DropDownItems, popup~item, self~find(before)
  if id \== .nil then ids[NetMenuKey(id)] = popup~item
  subs~append(popup)
  return 0
::method find
  expose item ids subs
  use arg id
  if id == .nil then return .nil
  i = ids[NetMenuKey(id)]
  if i \== .nil then return i
  if var("SUBS") then do p over subs
    i = p~find(id)
    if i \== .nil then return i
  end
  return .nil

::routine NetMenuInsert                -- (inside) before a ToolStripItem, or at the end
  use arg items, new, before
  if before == .nil then items~Add(new)
  else items~Insert(items~IndexOf(before), new)
::routine NetMenuKey                   -- (inside) an id as a key: 1 is IDOK, 2 IDCANCEL, as dialogs' ids
  use arg id
  id = id~string~upper
  if id == 1 then return "IDOK"
  if id == 2 then return "IDCANCEL"
  return id

/* ----------------------------------------------------------- property sheet */
/* ooDialog's PropertySheetDialog: .NetPropertySheet~new(pages [, options
   [, caption]]), each page a NetDialog (its controls on a tab); startPage,
   pages, setCurSel(, index), getResult ("CLOSEDOK", "CLOSEDCANCEL");
   options: NOAPPLYNOW (no Apply button). OK asks the page shown to
   killActive, then every page shown to apply. */
::class NetPropertySheet subclass NetDialog public
::attribute pages get
::attribute startPage
::method init
  expose pages options outcome cur      -- (not RESULT: a message instruction sets it)
  use arg pages, options = "", caption = ""
  self~init:super
  self~startPage = 1
  outcome = "CLOSEDCANCEL"; cur = 0
  cx = 0; cy = 0
  do p over pages
    p~propSheet = self
    cx = max(cx, p~sizeX); cy = max(cy, p~sizeY)
  end
  first = pages[1]
  self~createCenter(cx + 14, cy + 42, caption, , , first~fontName, first~fontSize)
::method defineDialog
  expose pages options tabs
  F = .net~System~Windows~Forms
  tabs = F~TabControl~new
  self~place("PROPSHEET.TABS", tabs, 7, 7, self~sizeX - 14, self~sizeY - 35)
  do p over pages
    t = F~TabPage~new
    t~UseVisualStyleBackColor = .true
    p~hostIn(t)
    tabs~TabPages~Add(t)
  end
  apply = options~upper~wordPos("NOAPPLYNOW") = 0
  x = self~sizeX - 7 - 50
  if apply then do
    self~createPushButton("IDAPPLY", x, self~sizeY - 21, 50, 14, , "&Apply", "APPLYALL")
    x -= 55
  end
  self~createPushButton(IDCANCEL, x, self~sizeY - 21, 50, 14, , "Cancel")
  self~createPushButton(IDOK, x - 55, self~sizeY - 21, 50, 14, "DEFAULT", "OK")
  tabs~Selecting += .net~handler(self, "PROPSHEET.SELECTING")
  tabs~Selected += .net~handler(self, "PROPSHEET.SELECTED")
::method initDialog
  expose tabs cur
  start = max(1, min(self~startPage, self~pages~items))
  tabs~SelectedIndex = start - 1
  if cur \= start then self~activate(start)   -- (no Selected event before the window exists)
::method activate private
  expose cur
  use arg i
  cur = i
  p = self~pages[i]
  p~buildPage
  p~setActive(self)
::method "PROPSHEET.SELECTING" unguarded
  expose cur
  use arg tabs, e
  if cur = 0 then return
  p = self~pages[cur]
  if p~wasActivated, p~killActive(self) == .false then e~Cancel = .true
::method "PROPSHEET.SELECTED" unguarded
  use arg tabs, e
  if e~TabPageIndex >= 0 then self~activate(e~TabPageIndex + 1)
::method setCurSel unguarded           -- setCurSel(hPage, index): the page shown (from 1)
  expose tabs
  use arg hPage, index
  tabs~SelectedIndex = index - 1
  return 0
::method curSel
  expose cur
  return cur
::method applyAll unguarded
  do p over self~pages
    if p~wasActivated then p~apply(self)
  end
  return 0
::method ok unguarded
  expose cur outcome
  if cur > 0, self~pages[cur]~killActive(self) == .false then return 0
  self~applyAll
  outcome = "CLOSEDOK"
  self~endDialog(1)
  return 0
::method cancel unguarded
  expose outcome
  outcome = "CLOSEDCANCEL"
  self~endDialog(2)
  return 0
::method getResult
  expose outcome
  return outcome

::class NetDialogUpDownRelay           -- (inside) DELTAPOS with ooDialog's arguments
::method init
  expose dialog methodName last
  use arg dialog, methodName
  last = .nil
::method scroll                        -- a scroll bar: its up arrow is SmallDecrement
  expose dialog methodName
  use arg bar, e
  select case e~Type~string
    when "SmallDecrement" then delta = 1
    when "SmallIncrement" then delta = -1
    otherwise return
  end
  pos = bar~Value                      -- (still the old one: the bar moves after its handlers)
  dialog~send(methodName, pos, delta)
  e~NewValue = max(bar~Minimum, min(bar~Maximum, pos + delta))   -- as an up-down's: up adds one
::method changed                       -- a NumericUpDown: the change
  expose dialog methodName last
  use arg box, e
  v = box~Value
  if last == .nil then delta = 1; else delta = v - last
  last = v
  dialog~send(methodName, v, delta)

::class NetDialogScroller              -- (inside) scrollInControl's text, moving
::attribute running
::method init
  expose ctl text font y step color x timer paint
  use arg ctl, text, font, y, step, sleep, color
  x = ctl~ClientSize~Width
  paint = .net~handler(self, "PAINT")
  ctl~Paint += paint
  timer = .net~System~Windows~Forms~Timer~new
  timer~Interval = max(1, sleep)
  timer~Tick += .net~handler(self, "TICK")
  self~running = .true
  timer~Start
::method tick
  expose ctl text font step x
  if ctl~IsDisposed then do; self~stop; return; end
  x -= step
  if x < -.net~System~Windows~Forms~TextRenderer~MeasureText(text, font)~Width then do; self~stop; return; end
  ctl~Invalidate
::method paint
  expose text font y color x
  use arg sender, e
  .net~System~Windows~Forms~TextRenderer~DrawText(e~Graphics, text, font, .net~System~Drawing~Point~new(x, y), color)
::method stop
  expose ctl timer paint
  timer~Stop
  if \ctl~IsDisposed then do
    ctl~Paint -= paint
    ctl~Invalidate
  end
  self~running = .false

::class NetDialogContextRelay          -- (inside) connectContextMenu: (hwnd, x, y) as ooDialog's
::method init
  expose dialog methodName hwnd
  use arg dialog, methodName, hwnd
::method mouseUp
  expose dialog methodName hwnd
  use arg sender, e
  if e~Button~string \== "Right" then return
  p = sender~PointToScreen(e~Location)
  dialog~send(methodName, hwnd, p~X, p~Y)
::method keyUp                         -- the context menu key, or Shift+F10
  expose dialog methodName hwnd
  use arg sender, e
  k = e~KeyCode~string
  if k == "Apps" | (k == "F10" & e~Shift) then dialog~send(methodName, hwnd, -1, -1)

/* a point, as ooDialog's .Point (x, y attributes) */
::class NetPoint public
::attribute x
::attribute y
::method init
  expose x y
  use arg x = 0, y = 0
::method copy
  expose x y
  return .NetPoint~new(x, y)

::class NetDialogNoSelect              -- (inside) a read-only edit control shows its text unselected
::method deselect
  use arg box
  box~SelectionLength = 0

::class NetDialogLast                  -- (inside) the control placed last, for AUTOBUDDY
::attribute id
::attribute ctl
::method init
  expose id ctl
  use arg id, ctl

::class NetDialogAutoRun               -- (inside) unattended: autoRun, once; its errors end the dialog
::attribute timers
::attribute failed                     -- .false, or what went wrong
::method init
  expose dialog failed
  use arg dialog
  failed = .false
::method tick
  expose dialog failed
  self~timers[1]~Stop
  say "(auto) running" dialog~form~Text
  signal on syntax
  dialog~autoRun
  return
syntax:
  c = condition("O")
  failed = "autoRun: Error" c~code":" c~message
  .error~say(failed)
  if c~traceback \== .nil then do line over c~traceback; .error~say(line); end
  dialog~endDialog(2)
::method watchdog                      -- still open after 30 s: something waits for a user
  expose dialog failed
  self~timers[2]~Stop
  failed = "the dialog was still open after 30 seconds"
  .error~say(failed)
  dialog~endDialog(2)

::routine NetDialogKey                 -- (inside) a control's id as a key: Windows' numbers for the standard buttons as their names
  use arg id
  id = id~string~upper
  if id~dataType("W") then select case id + 0
    when 1 then return "IDOK"
    when 2 then return "IDCANCEL"
    when 9 then return "IDHELP"
    otherwise nop
  end
  return id

/* (inside) a dialog's font as Windows makes it: its height a whole number
   of pixels, -MulDiv(points, dpi, 72) (10 points at 96 dpi: 13 pixels, where
   .NET would draw 13.33, a size larger); "MS Shell Dlg 2" and "MS Shell
   Dlg" are names Windows maps (to Tahoma and Microsoft Sans Serif), which
   GDI+ does not know; "System" is a bitmap font GDI+ cannot use: the nearest
   TrueType one, bold, about as wide (its base units, 8 x 16, are its own) */
::routine NetDialogFont
  use arg name, size, dpi = 96, style = "Regular"
  D = .net~System~Drawing
  px = (size * dpi + 36) % 72          -- (MulDiv rounds)
  select case name~upper
    when "MS SHELL DLG 2" then face = "Tahoma"
    when "MS SHELL DLG" then face = "Microsoft Sans Serif"
    when "SYSTEM" then do
      face = "Microsoft Sans Serif"
      px = (12 * dpi + 48) % 96
      if style == "Regular" then style = "Bold"
    end
    otherwise face = name
  end
  return D~Font~new(face, .net~single(px), style, "Pixel")

::routine NetDialogTrace               -- (inside) unattended: where it is
  if .NetDialog~auto then say "(auto)" arg(1)

::routine NetDialogThrow               -- (inside) once, before the first window
  signal on syntax
  .net~System~Windows~Forms~Application~SetUnhandledExceptionMode("ThrowException")
syntax:
  return

::routine NetDialogValue               -- a control's value: a check's 1/0, else its text
  use arg c
  if .net~isInstance(c, "System.Windows.Forms.CheckBox") | .net~isInstance(c, "System.Windows.Forms.RadioButton") then return c~Checked
  if .net~isInstance(c, "System.Windows.Forms.NumericUpDown") | .net~isInstance(c, "System.Windows.Forms.ScrollBar") then return c~Value
  if .net~isInstance(c, "System.Windows.Forms.ListBox") then return (c~SelectedItem == .nil)~?("", c~SelectedItem)
  return c~Text
::routine NetDialogSetValue
  use arg c, v
  if .net~isInstance(c, "System.Windows.Forms.CheckBox") | .net~isInstance(c, "System.Windows.Forms.RadioButton") then c~Checked = (v = 1)
  else if .net~isInstance(c, "System.Windows.Forms.NumericUpDown") | .net~isInstance(c, "System.Windows.Forms.ScrollBar") then c~Value = v
  else if .net~isInstance(c, "System.Windows.Forms.ListBox") then c~SelectedItem = v
  else if .net~isInstance(c, "System.Windows.Forms.ComboBox"), c~DropDownStyle~string == "DropDownList" then c~SelectedItem = v
  else c~Text = v

/* ------------------------------------------------------- public routines */
/* ooDialog's names, arguments and results. Unattended (.NetDialog~auto):
   nothing is shown; the routine says what it would ask and answers its default. */

::routine NetDialogAuto                -- (inside) unattended? say so
  if \.NetDialog~auto then return .false
  say "(auto)" arg(1)
  return .true

::routine infoDialog public            -- infoDialog(text)
  use strict arg text
  if NetDialogAuto("infoDialog:" text) then return 0
  .net~System~Windows~Forms~MessageBox~Show(text, "Information", "OK", "Information")
  return 0

::routine errorDialog public           -- errorDialog(text)
  use strict arg text
  if NetDialogAuto("errorDialog:" text) then return 0
  .net~System~Windows~Forms~MessageBox~Show(text, "Error", "OK", "Error")
  return 0

::routine askDialog public             -- askDialog(question [, "N"]): 1 yes, 0 no ("N": No the default)
  use arg question, default = "Y"
  if NetDialogAuto("askDialog:" question) then return default~upper \== "N"
  r = .net~System~Windows~Forms~MessageBox~Show(question, "Question", "YesNo", "Question", -
        (default~upper == "N")~?("Button2", "Button1"))
  return r~string == "Yes"

/* messageDialog(text [, hwnd [, title [, button [, icon [, misc]]]]]): ooDialog's
   button sets (OK, OKCANCEL, YESNO, YESNOCANCEL, RETRYCANCEL, ABORTRETRYIGNORE,
   CANCELTRYCONTINUE), icons (INFORMATION, QUESTION, WARNING, ERROR...) and
   DEFBUTTON2 / DEFBUTTON3, in any of the last three arguments, as ooDialog
   takes them; the answer as ooDialog's IDOK (1), IDCANCEL (2), IDABORT (3),
   IDRETRY (4), IDIGNORE (5), IDYES (6), IDNO (7), IDTRYAGAIN (10), IDCONTINUE (11) */
::routine messageDialog public
  use arg text, hwnd, title = "ooDialog Message", w1 = "", w2 = "", w3 = ""
  buttons = .stringTable~new
  buttons~OK = "OK"; buttons~OKCANCEL = "OKCancel"; buttons~YESNO = "YesNo"; buttons~YESNOCANCEL = "YesNoCancel"
  buttons~RETRYCANCEL = "RetryCancel"; buttons~ABORTRETRYIGNORE = "AbortRetryIgnore"; buttons~CANCELTRYCONTINUE = "CancelTryContinue"
  icons = .stringTable~new
  icons~INFORMATION = "Information"; icons~ASTERISK = "Asterisk"; icons~EXCLAMATION = "Exclamation"
  icons~WARNING = "Warning"; icons~ERROR = "Error"; icons~HAND = "Hand"; icons~STOP = "Stop"; icons~QUESTION = "Question"
  b = "OK"; i = "None"; d = "Button1"
  do w over (w1 w2 w3)~upper~makeArray(" ")
    select
      when buttons~hasIndex(w) then b = buttons[w]
      when icons~hasIndex(w) then i = icons[w]
      when w == "DEFBUTTON2" then d = "Button2"
      when w == "DEFBUTTON3" then d = "Button3"
      otherwise nop
    end
  end
  if NetDialogAuto("messageDialog:" text) then do     -- unattended: OK, else Cancel where there is one
    if b == "OK" then return 1
    if b~pos("Cancel") > 0 then return 2
    if b == "YesNo" then return 7
    return 3                                         -- (AbortRetryIgnore: Abort)
  end
  r = .net~System~Windows~Forms~MessageBox~Show(text, title, b, i, d)
  codes = .stringTable~new
  codes~OK = 1; codes~CANCEL = 2; codes~ABORT = 3; codes~RETRY = 4; codes~IGNORE = 5; codes~YES = 6; codes~NO = 7
  codes~TRYAGAIN = 10; codes~CONTINUE = 11
  c = codes[r~string~upper]
  return (c \== .nil)~?(c, 2)

/* fileNameDialog([file [, hwnd [, filter [, load [, title [, defExtension [, multi [, sep]]]]]]]]):
   the file chosen (several, with multi: the folder then the names, by sep), or 0.
   filter: ooDialog's ("Text Files (*.txt)'0'x*.txt'0'x...") or .NET's ("Text|*.txt|...") */
::routine fileNameDialog public
  use arg file = "", hwnd, filter = .nil, load = 1, title = "", defExt = "", multi = .false, sep = " "
  if filter == .nil then filter = "All Files (*.*)" || "0"x || "*.*"
  if NetDialogAuto("fileNameDialog:" title) then return 0
  F = .net~System~Windows~Forms
  dlg = (load = 1 | load~upper == "LOAD")~?(F~OpenFileDialog~new, F~SaveFileDialog~new)
  dlg~Filter = filter~strip("T", "0"x)~changeStr("0"x, "|")
  if title \== "" then dlg~Title = title
  if defExt \== "" then dlg~DefaultExt = defExt
  if file \== "" then do
    if .net~System~IO~Directory~Exists(file) then dlg~InitialDirectory = file
    else dlg~FileName = file
  end
  if multi = 1, .net~isInstance(dlg, "System.Windows.Forms.OpenFileDialog") then dlg~Multiselect = .true
  if dlg~ShowDialog~string \== "OK" then return 0
  if multi = 1, .net~isInstance(dlg, "System.Windows.Forms.OpenFileDialog") then do
    names = dlg~FileNames
    r = .net~System~IO~Path~GetDirectoryName(names[1])
    do n over names; r = r || sep || .net~System~IO~Path~GetFileName(n); end
    return r
  end
  return dlg~FileName

/* browseForFolder([title [, start]]): the folder chosen, or .nil */
::routine browseForFolder public
  use arg title = "", start = ""
  if NetDialogAuto("browseForFolder:" title) then return .nil
  dlg = .net~System~Windows~Forms~FolderBrowserDialog~new
  if title \== "" then dlg~Description = title
  if start \== "" then dlg~SelectedPath = start
  if dlg~ShowDialog~string \== "OK" then return .nil
  return dlg~SelectedPath

/* inputBox(message, title [, default [, size]]): the text, or "" if cancelled */
::routine inputBox public
  use arg message, title = "", default = "", size = 100
  if NetDialogAuto("inputBox:" message) then return default
  return NetDialogAsk(message, title, default, size, "TEXT")
::routine passwordBox public           -- the same, the text hidden
  use arg message, title = "", default = "", size = 100
  if NetDialogAuto("passwordBox:" message) then return default
  return NetDialogAsk(message, title, default, size, "PASSWORD")
::routine integerBox public            -- the same, a whole number (or "")
  use arg message, title = "", default = "", size = 100
  if NetDialogAuto("integerBox:" message) then return default
  return NetDialogAsk(message, title, default, size, "INTEGER")

/* listChoice(message, title, items [, cx [, cy [, preselect]]]): the item chosen, or .nil */
::routine listChoice public
  use arg message, title, items, cx = 150, cy = 80, preselect = ""
  if NetDialogAuto("listChoice:" message) then return items[1]
  r = NetDialogChoose(message, title, items, .false, cx, cy, preselect)
  if r == .nil then return .nil
  return items[r]
/* multiListChoice(message, title, items [, cx [, cy [, preselect]]]): an Array of
   the items chosen, or .nil (cancelled, or none chosen) */
::routine multiListChoice public
  use arg message, title, items, cx = 150, cy = 80, preselect = ""
  if NetDialogAuto("multiListChoice:" message) then return .nil
  r = NetDialogChoose(message, title, items, .true, cx, cy, preselect)
  if r == .nil | r == "" then return .nil
  chosen = .array~new
  do i over r~makeArray(" "); chosen~append(items[i]); end
  return chosen

/* checkList(message, title, labels [, checks [, cx [, max]]]): an Array of 1 / 0,
   one for each label, or .nil if cancelled; checks: an Array, .true for those
   checked at first; max: check boxes in a column */
::routine checkList public
  use arg message, title, labels, checks = .nil, cx = 0, max = 0
  if checks == .nil then checks = .array~new
  if NetDialogAuto("checkList:" message) then return .nil
  dlg = .NetDialogBoxes~new(message, title, labels, checks, max, "CHECK")
  if dlg~execute \= 1 then return .nil
  return dlg~answer

/* multiInputBox(message, title, labels, defaults [, width]): an Array of the texts, or .nil */
::routine multiInputBox public
  use arg message, title, labels, defaults = .nil, width = 100
  if defaults == .nil then defaults = .array~new
  if NetDialogAuto("multiInputBox:" message) then return .nil
  dlg = .NetDialogMultiInput~new(message, title, labels, defaults, width)
  if dlg~execute \= 1 then return .nil
  return dlg~answer

/* singleSelection(message, title, labels [, default [, dlg [, max]]]): the number of
   the choice (from 1), or .nil; max: radio buttons in a column */
::routine singleSelection public
  use arg message, title, labels, default = 1, dlg, max = 0
  if NetDialogAuto("singleSelection:" message) then return default
  checks = .array~new
  checks[default] = .true
  dlg = .NetDialogBoxes~new(message, title, labels, checks, max, "RADIO")
  if dlg~execute \= 1 then return .nil
  return dlg~answer

/* timedMessage(message, title, duration [, earlyReply]): a message that goes away after duration ms */
::routine timedMessage public
  use arg message, title, duration, earlyReply = .false
  if NetDialogAuto("timedMessage:" message) then return 0
  dlg = .NetDialogTimed~new(message, title, duration)
  dlg~execute
  return 0

::routine NetDialogAsk                 -- (inside) inputBox and kin
  use arg message, title, default, size, kind
  dlg = .NetDialogInput~new(message, title, default, size, kind)
  if dlg~execute \= 1 then return ""
  return dlg~answer

::routine NetDialogChoose              -- (inside) listChoice and kin
  use arg message, title, items, multi, cx, cy, preselect
  dlg = .NetDialogList~new(message, title, items, multi, cx, cy, preselect)
  if dlg~execute \= 1 then return .nil
  return dlg~answer

::class NetDialogInput subclass NetDialog   -- (inside) inputBox, passwordBox, integerBox
::attribute answer
::method init
  expose message default kind w
  use arg message, title, default, size, kind
  self~init:super
  w = max(size, 120)
  self~createCenter(w + 20, 62, title)
::method defineDialog
  expose message default kind w
  self~createStatic("msg", 10, 8, w, 10, , message)
  self~createEdit("box", 10, 22, w, 12, (kind == "PASSWORD")~?("PASSWORD", ""))
  self~createPushButton("IDOK", w - 95, 42, 50, 14, "DEFAULT", "OK")
  self~createPushButton("IDCANCEL", w - 40, 42, 50, 14, , "Cancel")
  self~newEdit("box")~Text = default
::method validate
  expose kind
  text = self~newEdit("box")~Text~strip
  if kind == "INTEGER" & \text~dataType("W") then do
    call errorDialog "A whole number is needed."
    return .false
  end
  self~answer = text
  return .true

::class NetDialogList subclass NetDialog    -- (inside) listChoice, multiListChoice
::attribute answer
::method init
  expose message items multi cx cy preselect
  use arg message, title, items, multi, cx, cy, preselect
  self~init:super
  self~createCenter(cx + 20, cy + 50, title)
::method defineDialog
  expose message items multi cx cy preselect
  self~createStatic("msg", 10, 6, cx, 10, , message)
  self~createListBox("list", 10, 18, cx, cy, multi~?("MULTI", ""))
  self~createPushButton("IDOK", cx - 95, cy + 26, 50, 14, "DEFAULT", "OK")
  self~createPushButton("IDCANCEL", cx - 40, cy + 26, 50, 14, , "Cancel")
  list = self~newListBox("list")
  do i over items; list~Items~Add(i); end
  if preselect \== "" then list~SelectedItem = preselect
  else if items~items > 0 then list~SelectedIndex = 0
::method validate
  expose multi
  list = self~newListBox("list")
  if \multi then do
    if list~SelectedIndex < 0 then return .false
    self~answer = list~SelectedIndex + 1
    return .true
  end
  r = ""
  do i over list~SelectedIndices; r = r (i + 1); end
  self~answer = r~strip
  return .true

::class NetDialogBoxes subclass NetDialog   -- (inside) checkList, singleSelection
::attribute answer
::method init
  expose message labels checks max kind rows
  use arg message, title, labels, checks, max, kind
  self~init:super
  n = labels~items
  rows = (max > 0)~?(min(max, n), n)
  cols = (n + rows - 1) % rows
  self~createCenter(max(170, 10 + 120 * cols), 44 + 13 * rows, title)
::method defineDialog
  expose message labels checks max kind rows
  self~createStatic("msg", 10, 6, 300, 10, , message)
  do i = 1 to labels~items
    col = (i - 1) % rows; row = (i - 1) // rows
    if kind == "CHECK" then self~createCheckBox("b"i, 14 + 120 * col, 20 + 13 * row, 115, 12, , labels[i])
    else self~createRadioButton("b"i, 14 + 120 * col, 20 + 13 * row, 115, 12, , labels[i])
    if checks[i] == .true then self~control("b"i)~Checked = .true
  end
  w = self~sizeX
  y = 24 + 13 * rows
  self~createPushButton("IDOK", w - 115, y, 50, 14, "DEFAULT", "OK")
  self~createPushButton("IDCANCEL", w - 60, y, 50, 14, , "Cancel")
::method validate
  expose labels kind
  r = .array~new
  do i = 1 to labels~items
    c = self~control("b"i)~Checked
    if kind == "RADIO" & c then do
      self~answer = i
      return .true
    end
    r[i] = c~?(1, 0)
  end
  if kind == "RADIO" then return .false
  self~answer = r
  return .true

::class NetDialogMultiInput subclass NetDialog   -- (inside) multiInputBox
::attribute answer
::method init
  expose message labels defaults width
  use arg message, title, labels, defaults, width
  self~init:super
  self~createCenter(width + 80, 44 + 16 * labels~items, title)
::method defineDialog
  expose message labels defaults width
  self~createStatic("msg", 10, 6, width + 60, 10, , message)
  do i = 1 to labels~items
    self~createStatic("l"i, 10, 22 + 16 * (i - 1), 55, 12, , labels[i]~changeStr("&", ""))
    self~createEdit("e"i, 68, 20 + 16 * (i - 1), width, 12)
    if defaults~hasIndex(i) then self~control("e"i)~Text = defaults[i]
  end
  y = 24 + 16 * labels~items
  self~createPushButton("IDOK", width - 45, y, 50, 14, "DEFAULT", "OK")
  self~createPushButton("IDCANCEL", width + 10, y, 50, 14, , "Cancel")
::method validate
  expose labels
  r = .array~new
  do i = 1 to labels~items; r[i] = self~control("e"i)~Text; end
  self~answer = r
  return .true

::class NetDialogTimed subclass NetDialog   -- (inside) timedMessage
::method init
  expose message duration
  use arg message, title, duration
  self~init:super
  self~createCenter(200, 40, title)
::method defineDialog
  expose message duration
  self~createStatic("msg", 10, 14, 180, 20, "CENTER", message)
  self~startTimer(duration, "OK")
