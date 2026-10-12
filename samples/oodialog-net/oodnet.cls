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
::method defaultFont class             -- defaultFont([name, size]): the font of dialogs whose create names none
  expose defaultFont                   -- (ooDialog's .application~defaultFont: MS Shell Dlg 2, 8, unless set)
  use arg name, size
  if arg() > 0 then defaultFont = .array~of(name, size)
  if \var("DEFAULTFONT") then defaultFont = .array~of("MS Shell Dlg 2", 8)
  return defaultFont
::method defaultIcon class             -- defaultIcon([file]): the icon (an .ico file) of the dialogs made from now on
  expose defaultIcon                   -- (ooDialog's .application~defaultIcon; .nil: Windows Forms' own)
  if arg() > 0 then defaultIcon = .net~System~Drawing~Icon~new(arg(1))
  if \var("DEFAULTICON") then defaultIcon = .nil
  return defaultIcon
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
::method isDialogActive unguarded      -- its window still there
  if self~isA(.ControlDialog) then return self~controlDialogActive
  return \self~form~IsDisposed
::attribute initCode                   -- as ooDialog's (0: fine)

::attribute ownerDialog                -- ooDialog's: a dialog that owns this one (set before it shows): this one
                                       -- stays above it, hides when it is minimized, closes with it (Form.Owner)
::attribute exArgs                     -- ooDialog's extra arguments to new: a TabOwnerDlgInfo or a ControlDlgInfo, if given
::method init
  expose controls data pending ending deferred defined ownerDialog dataStem connectButtons
  ownerDialog = .nil
  self~exArgs = .nil
  dataStem = .nil; connectButtons = .false
  do i = 1 to arg()                    -- (wherever ooDialog's new takes it)
    if arg(i, "E") then do
      if arg(i)~isA(.TabOwnerDlgInfo) | arg(i)~isA(.ControlDlgInfo) then self~exArgs = arg(i)~copy
      if arg(i)~isA(.NetDialog), self~isA(.ControlDialog) then ownerDialog = arg(i)   -- (a UserControlDialog's parent)
      if arg(i)~isA(.Stem) then dataStem = arg(i)   -- ooDialog's dlgData.: the controls' values by id
      if arg(i)~isA(.String), arg(i)~upper~wordPos("CONNECTBUTTONS") > 0 then connectButtons = .true
    end
  end
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
  expose form bx by sizeX sizeY fontName fontSize uiThread
  use arg x, y, cx, cy, title = "", style = "", dlgClass, fontName = (self~dlgFont[1]), fontSize = (self~dlgFont[2])
  sizeX = cx; sizeY = cy
  F = .net~System~Windows~Forms
  D = .net~System~Drawing
  F~Application~EnableVisualStyles
  if .NetDialog~auto then call NetDialogThrow   -- unattended: an error in an event ends the run, no dialog about it
  form = F~Form~new
  uiThread = .net~System~Environment~CurrentManagedThreadId   -- (the dialog's thread: other threads' calls go there)
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
  if style~wordPos("NOMENU") > 0 then form~ControlBox = .false   -- (no system menu: no [x] either)
  if style~wordPos("CENTER") > 0 then form~StartPosition = "CenterScreen"
  else do
    form~StartPosition = "Manual"
    form~Location = D~Point~new(self~px(x), self~py(y))
  end
  if .NetDialog~defaultIcon \== .nil then form~Icon = .NetDialog~defaultIcon
  form~FormClosing += .net~handler(self, "NETDIALOG.CLOSING")
  return .true                         -- (as ooDialog's: .true, made)

/* createCenter(cx, cy [, title [, style [, dlgClass [, fontName [, fontSize]]]]]) */
::method createCenter
  use arg cx, cy, title = "", style = "", dlgClass, fontName = (.NetDialog~defaultFont[1]), fontSize = (.NetDialog~defaultFont[2])
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
::method px unguarded                  -- dialog units to pixels, across
  expose bx
  if \var("BX") then return trunc(arg(1) * self~factorX + 0.5)   -- (before create: the font it will have)
  return trunc(arg(1) * bx / 4 + 0.5)
::method py unguarded                  -- and down
  expose by
  if \var("BY") then return trunc(arg(1) * self~factorY + 0.5)
  return trunc(arg(1) * by / 8 + 0.5)

/* the controls, as ooDialog's create* methods (x, y, cx, cy in dialog units) */
::method createStatic
  use arg id, x, y, cx, cy, style = "", text = ""
  if arg(4, "O") | arg(5, "O") then do  -- (no size: the text's, as ooDialog's)
    size = self~getTextSizeDu(text)
    if arg(4, "O") then cx = size~width
    if arg(5, "O") then cy = size~height
  end
  c = self~place(id, .net~System~Windows~Forms~Label~new, x, y, cx, cy)
  c~Text = text
  style = style~upper
  down = (style~wordPos("CENTERIMAGE") > 0)~?("Middle", "Top")   -- (SS_CENTERIMAGE: one line, centred down)
  across = "Left"
  if style~wordPos("RIGHT") > 0 then across = "Right"
  if style~wordPos("CENTER") > 0 then across = "Center"
  c~TextAlign = down || across
  if style~wordPos("BORDER") > 0 | style~pos("FRAME") > 0 then c~BorderStyle = "FixedSingle"   -- (GRAYFRAME, BLACKFRAME...)
  if style~pos("FRAME") > 0 then self~frame(c)                 -- a frame: behind what it frames
  if style~wordPos("SUNKEN") > 0 then c~BorderStyle = "Fixed3D"
  if style~wordPos("ELLIPSIS") > 0 then c~AutoEllipsis = .true
  colors = .net~System~Drawing~Color          -- (not C: Rexx's names know no case, c is the control)
  if style~wordPos("WHITERECT") > 0 then c~BackColor = colors~White
  if style~wordPos("BLACKRECT") > 0 then c~BackColor = colors~Black
  if style~wordPos("GRAYRECT") > 0 then c~BackColor = .net~System~Drawing~SystemColors~ControlDark
  if style~wordPos("WHITEFRAME") > 0 then do   -- (a white line round it)
    c~BorderStyle = "None"
    c~Paint += .net~handler(.NetDialogFrameLine~new(colors~White), "PAINT")
  end
  self~common(c, style)
  return 0
::method createStaticText
  forward message "CREATESTATIC"
::method createBlackFrame               -- createBlackFrame(id, x, y, cx, cy [, style]): a frame (a bordered Label)
  use arg id, x, y, cx, cy, style = ""
  return self~createStatic(id, x, y, cx, cy, style "BLACKFRAME", "")
/* createStaticImage(id, x, y, cx, cy [, style]): a PictureBox (its Image:
   ooDialog's setImage); SIZEIMAGE stretches the image, CENTERIMAGE centres it */
::method createStaticImage
  use arg id, x, y, cx, cy, style = ""
  c = self~place(id, .net~System~Windows~Forms~PictureBox~new, x, y, cx, cy)
  st = style~upper
  if st~wordPos("SIZEIMAGE") > 0 then c~SizeMode = "StretchImage"
  else if st~wordPos("CENTERIMAGE") > 0 then c~SizeMode = "CenterImage"
  self~common(c, style)
  return 0
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
  if style~wordPos("UPPER") > 0 | style~wordPos("UPPERCASE") > 0 then c~CharacterCasing = "Upper"
  if style~wordPos("LOWER") > 0 | style~wordPos("LOWERCASE") > 0 then c~CharacterCasing = "Lower"
  if style~wordPos("NUMBER") > 0 then c~KeyPress += .net~handler(.NetDialogDigitsOnly~new, "KEYPRESS")   -- (ES_NUMBER: digits only)
  if style~wordPos("NOBORDER") > 0 then c~BorderStyle = "None"
  if style~wordPos("RIGHT") > 0 then c~TextAlign = "Right"
  if style~wordPos("CENTER") > 0 then c~TextAlign = "Center"
  self~common(c, style)
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
  c~FlatStyle = "System"               -- drawn by Windows, as ooDialog's: a text too wide for Windows Forms' margins
                                       -- stays one line ("ArcCos"); an image or colours need FlatStyle "Standard"
  style = style~upper
  if .net~isInstance(self~form, "System.Windows.Forms.Form") then do   -- (not on a property sheet's page)
    if style~wordPos("DEFAULT") > 0 | id~string~upper == "IDOK" then self~form~AcceptButton = c
    if id~string~upper == "IDCANCEL" then self~form~CancelButton = c
  end
  if style~wordPos("DISABLED") > 0 then c~Enabled = .false
  if style~wordPos("HIDDEN") > 0 then c~Visible = .false
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
  self~common(c, style)
  if arg(8, "E") then self~dataAttribute(attributeName, id)
  return 0
::method createRadioButton
  expose radios
  use arg id, x, y, cx, cy, style = "", label = "", attributeName
  c = self~place(id, .net~System~Windows~Forms~RadioButton~new, x, y, cx, cy)
  c~Text = label
  self~common(c, style)
  if \var("RADIOS") then radios = .array~new
  radios~append(.array~of(c, style~upper~wordPos("GROUP") > 0))   -- (GROUP: WS_GROUP, a new group starts)
  if arg(8, "E") then self~dataAttribute(attributeName, id)
  return 0
::method createGroupBox
  use arg id, x, y, cx, cy, style = "", text = ""
  c = self~place(id, .net~System~Windows~Forms~GroupBox~new, x, y, cx, cy)
  c~Text = text
  self~common(c, style)
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
  self~common(c, style)
  if arg(7, "E") then self~dataAttribute(attributeName, id)
  return 0
::method createComboBox
  use arg id, x, y, cx, cy, style = "", attributeName
  c = self~place(id, .net~System~Windows~Forms~ComboBox~new, x, y, cx, cy)
  style = style~upper
  select
    when style~wordPos("LIST") > 0 then c~DropDownStyle = "DropDownList"
    when style~wordPos("SIMPLE") > 0 then do
      c~DropDownStyle = "Simple"
      c~Height = self~py(cy)              -- (its list shown: the .rc's height)
    end
    otherwise c~DropDownStyle = "DropDown"
  end
  if style~wordPos("SORT") > 0 then c~Sorted = .true
  self~common(c, style)
  if arg(7, "E") then self~dataAttribute(attributeName, id)
  return 0
/* An up-down control with AUTOBUDDY and SETBUDDYINT joins the edit control
   before it (a number): Windows Forms has both in one, a NumericUpDown, which
   takes the edit's place and both ids. */
::method createUpDown
  expose last
  use arg id, x, y, cx, cy, style = "", attributeName
  F = .net~System~Windows~Forms
  buddyInt = style~upper~wordPos("SETBUDDYINT") > 0 | style~upper~wordPos("BUDDYINT") > 0   -- (the .rc's, createUpDown's)
  if style~upper~wordPos("AUTOBUDDY") > 0, buddyInt, var("LAST"), .net~isInstance(last~ctl, "System.Windows.Forms.TextBox") then do
    old = last~ctl
    c = F~NumericUpDown~new
    c~Location = old~Location
    c~Size = old~Size
    c~TextAlign = old~TextAlign
    c~ThousandsSeparator = style~upper~wordPos("NOTHOUSANDS") = 0   -- as Windows' up-down shows its buddy's number
    if style~upper~wordPos("ALIGNLEFT") > 0 then c~UpDownAlign = "Left"
    self~form~Controls~Remove(old)
    self~form~Controls~Add(c)
    self~register(last~id, c)
    self~register(id, c)
    if arg(7, "E") then self~dataAttribute(attributeName, id)
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
/* a tool bar: a .NET ToolStrip where the .rc puts it (its items: ToolStripButton...,
   ooDialog's TbButton; ~Items~Add / Insert, ~Items~Count: addButtons, buttonCount) */
::method createToolBar
  use arg id, x, y, cx, cy, style = ""
  F = .net~System~Windows~Forms
  c = self~place(id, F~ToolStrip~new, x, y, cx, cy)
  c~Dock = "None"
  c~GripStyle = "Hidden"
  if style~upper~wordPos("HIDDEN") > 0 then c~Visible = .false
  return 0
::method createScrollBar                -- VERTICAL, else horizontal (ooDialog: setRange, setPosition; here ~Minimum, ~Maximum, ~Value)
  use arg id, x, y, cx, cy, style = ""
  F = .net~System~Windows~Forms
  bar = (style~upper~wordPos("VERTICAL") > 0)~?(F~VScrollBar~new, F~HScrollBar~new)
  c = self~place(id, bar, x, y, cx, cy)
  c~LargeChange = 1
  self~common(c, style)
  return 0
::method createMonthCalendar
  use arg id, x, y, cx, cy, style = ""
  c = self~place(id, .net~System~Windows~Forms~MonthCalendar~new, x, y, cx, cy)
  c~MaxSelectionCount = 1
  self~common(c, style)
  return 0
::method createDateTimePicker
  use arg id, x, y, cx, cy, style = ""
  c = self~place(id, .net~System~Windows~Forms~DateTimePicker~new, x, y, cx, cy)
  self~common(c, style)
  return 0
::method createProgressBar               -- VERTICAL (PBS_VERTICAL, which .NET's ProgressBar has not: added to its window's style), SMOOTH, MARQUEE
  use arg id, x, y, cx, cy, style = ""
  st = style~upper
  if st~wordPos("VERTICAL") > 0 then do
    .NetStyledProgressBar~prepare
    bar = .NetStyledProgressBar~new(4)   -- PBS_VERTICAL
  end
  else bar = .net~System~Windows~Forms~ProgressBar~new
  c = self~place(id, bar, x, y, cx, cy)
  if st~wordPos("SMOOTH") > 0 then c~Style = "Continuous"
  if st~wordPos("MARQUEE") > 0 then c~Style = "Marquee"
  self~common(c, style)
  return 0
/* createTrackBar: VERTICAL; the ticks TOP (or LEFT), BOTH, NOTICKS (else
   bottom, or right); ENABLESELRANGE (TBS_ENABLESELRANGE, which .NET's
   TrackBar has not: added to its window's style; TBM_SETSELSTART and
   TBM_SETSELEND through sendWinIntMsg then show a selection) */
::method createTrackBar
  use arg id, x, y, cx, cy, style = ""
  st = style~upper
  if st~wordPos("ENABLESELRANGE") > 0 then do
    .NetStyledTrackBar~prepare
    bar = .NetStyledTrackBar~new(32)     -- TBS_ENABLESELRANGE
  end
  else bar = .net~System~Windows~Forms~TrackBar~new
  bar~AutoSize = .false                  -- (the .rc's size)
  bar~Maximum = 100                      -- (Windows' track bar: 0 to 100, a page a fifth of it; .NET's: 0 to 10, 5)
  bar~LargeChange = 20
  c = self~place(id, bar, x, y, cx, cy)
  if st~wordPos("VERTICAL") > 0 then c~Orientation = "Vertical"
  select
    when st~wordPos("NOTICKS") > 0 then c~TickStyle = "None"
    when st~wordPos("BOTH") > 0 then c~TickStyle = "Both"
    when st~wordPos("TOP") > 0 | st~wordPos("LEFT") > 0 then c~TickStyle = "TopLeft"
    otherwise nop
  end
  self~common(c, style)
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
  c~AutoArrange = style~wordPos("AUTOARRANGE") > 0   -- (Windows': only with LVS_AUTOARRANGE; .NET's: on unless told)
  if style~wordPos("EDITLABELS") > 0 then c~LabelEdit = .true
  self~common(c, style)
  return 0
::method createTreeView
  use arg id, x, y, cx, cy, style = ""
  c = self~place(id, .net~System~Windows~Forms~TreeView~new, x, y, cx, cy)
  style = style~upper
  c~ShowLines = style~wordPos("LINES") > 0 | style~wordPos("HASLINES") > 0
  c~ShowPlusMinus = style~wordPos("BUTTONS") > 0 | style~wordPos("HASBUTTONS") > 0
  c~ShowRootLines = style~wordPos("ATROOT") > 0 | style~wordPos("LINESATROOT") > 0
  self~common(c, style)
  return 0
::method createTab                     -- FIXED (tabs of one width), BUTTONS, MULTILINE, BOTTOM
  use arg id, x, y, cx, cy, style = ""
  c = self~place(id, .net~System~Windows~Forms~TabControl~new, x, y, cx, cy)
  st = style~upper
  if st~wordPos("FIXED") > 0 then c~SizeMode = "Fixed"
  if st~wordPos("BUTTONS") > 0 then c~Appearance = "Buttons"
  if st~wordPos("MULTILINE") > 0 then c~Multiline = .true
  if st~wordPos("BOTTOM") > 0 then c~Alignment = "Bottom"
  self~common(c, style)
  return 0
::method common private                -- (inside) styles any control may have: HIDDEN, DISABLED
  use arg c, style = ""
  style = style~upper
  if style~wordPos("HIDDEN") > 0 then c~Visible = .false
  if style~wordPos("DISABLED") > 0 then c~Enabled = .false

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
::method newToolBar;      forward message "CONTROL"

/* events: ooDialog's names; the method gets .NET's (sender, e) */
::method connectButtonEvent
  use arg id, event = "CLICKED", methodName
  if arg(3, "O") then methodName = id
  select case event~upper
    when "DBLCLK" then e = "DoubleClick"
    when "GOTFOCUS" then e = "GotFocus"
    when "LOSTFOCUS" then e = "LostFocus"
    when "HOTITEM" then return self~connectHot(id, methodName)
    otherwise e = "Click"
  end
  return self~connectEvent(id, e, methodName)
::method connectHot private             -- HOTITEM: methodName(id, entering) as the mouse comes onto the button (.true) and leaves it
  expose defined deferred
  use strict arg id, methodName
  if \defined then do
    deferred~append(.array~of("CONNECTHOT", .array~of(id, methodName)))
    return 0
  end
  relay = .NetDialogHotRelay~new(self, id, methodName)
  c = self~control(id)
  c~MouseEnter += .net~handler(relay, "ENTER")
  c~MouseLeave += .net~handler(relay, "LEAVE")
  return 0
/* connectListViewEvent(id, event [, method]): CLICK (.NET's MouseClick),
   DBLCLK (DoubleClick), ACTIVATE (ItemActivate: a double click, or Enter),
   COLUMNCLICK, SELECTCHANGED (ItemSelectionChanged), CHECKBOXCHANGED
   (ItemChecked), BEGINEDIT / ENDEDIT (BeforeLabelEdit / AfterLabelEdit:
   the list view's labels made editable), BEGINDRAG (ItemDrag; with
   ooDialog's DefListDragHandler: an item of an icon view dragged to where
   it is let go, Escape puts it back); the method gets .NET's (sender, e) */
::method connectListViewEvent
  expose defined deferred
  use arg id, event, methodName
  if arg(3, "O") then methodName = "on" || event   -- (ooDialog's default: onColumnClick...)
  if event~upper == "BEGINDRAG", methodName~caselessEquals("DefListDragHandler") then do
    if \defined then do
      deferred~append(.array~of("CONNECTLISTVIEWEVENT", .array~of(id, event, methodName)))
      return 0
    end
    .NetListDrag~new(self~control(id))
    return 0
  end
  if wordPos(event~upper, "BEGINEDIT ENDEDIT") > 0 then do
    if \defined then do
      deferred~append(.array~of("CONNECTLISTVIEWEVENT", .array~of(id, event, methodName)))
      return 0
    end
    self~control(id)~LabelEdit = .true
  end
  select case event~upper
    when "CLICK" then e = "MouseClick"
    when "DBLCLK" then e = "DoubleClick"
    when "ACTIVATE" then e = "ItemActivate"
    when "BEGINEDIT" then e = "BeforeLabelEdit"
    when "ENDEDIT" then e = "AfterLabelEdit"
    when "BEGINDRAG" then e = "ItemDrag"
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
::method connectComboBoxEvent            -- SELCHANGE, SELENDOK (.NET's SelectionChangeCommitted), DROPDOWN, CLOSEUP, DBLCLK
  use arg id, event, methodName
  select case event~upper
    when "SELENDOK" then return self~connectEvent(id, "SelectionChangeCommitted", methodName)
    when "DROPDOWN" then return self~connectEvent(id, "DropDown", methodName)
    when "CLOSEUP" then return self~connectEvent(id, "DropDownClosed", methodName)
    otherwise forward message "CONNECTLISTBOXEVENT"
  end
/* connectDateTimePickerEvent(id, event, method): DATETIMECHANGE (.NET's
   ValueChanged), SETFOCUS, KILLFOCUS, DROPDOWN, CLOSEUP; USERSTRING: a .NET
   DateTimePicker cannot be typed in (Win32's CANPARSE): F2 puts an edit
   control over it, and Enter (or leaving it) calls method with ooDialog's
   (dateTime, userString, id, hwnd), dateTime a Rexx .DateTime, the
   control's; the .DateTime it answers is the control's new value; Escape
   leaves it as it is */
::method connectDateTimePickerEvent
  expose defined deferred
  use arg id, event, methodName
  select case event~upper
    when "DATETIMECHANGE" then e = "ValueChanged"
    when "SETFOCUS" then e = "GotFocus"
    when "KILLFOCUS" then e = "LostFocus"
    when "DROPDOWN" then e = "DropDown"
    when "CLOSEUP" then e = "CloseUp"
    when "USERSTRING" then do
      if \defined then do
        deferred~append(.array~of("CONNECTDATETIMEPICKEREVENT", .array~of(id, event, methodName)))
        return 0
      end
      dtp = self~control(id)
      relay = .NetDialogUserString~new(self, dtp, id, methodName)
      dtp~KeyDown += .net~handler(relay, "KEY")
      return 0
    end
    otherwise e = event
  end
  return self~connectEvent(id, e, methodName)
/* connectHelp(method): F1 (.NET's HelpRequested) */
::method connectHelp
  use strict arg methodName
  self~form~HelpRequested += .net~handler(.NetDialogHelpRelay~new(self, methodName), "HELP")
  return 0
/* setControlColor(id, background [, foreground]): ooDialog's colours, an
   index into Windows' default palette (0 black, 1 dark red, 2 dark green, 3
   dark yellow... 13 red... 19 white), or .NET Colors */
::method setControlColor
  use arg id, bg, fg
  c = self~control(id)
  c~BackColor = NetDialogColor(bg)
  if arg(3, "E") then c~ForeColor = NetDialogColor(fg)
  return 0
::method connectStaticEvent             -- CLICKED, DBLCLK (ooDialog wants SS_NOTIFY; a .NET Label has them)
  use arg id, event, methodName
  select case event~upper
    when "CLICKED" then e = "Click"
    when "DBLCLK" then e = "DoubleClick"
    otherwise e = event
  end
  return self~connectEvent(id, e, methodName)
/* connectTabEvent(id, event [, method]): SELCHANGE (.NET's
   SelectedIndexChanged), SELCHANGING (Selecting), KEYDOWN */
::method connectTabEvent
  use arg id, event, methodName
  if arg(3, "O") then methodName = "on" || event
  select case event~upper
    when "SELCHANGE" then e = "SelectedIndexChanged"
    when "SELCHANGING" then e = "Selecting"
    when "KEYDOWN" then e = "KeyDown"
    otherwise e = event
  end
  return self~connectEvent(id, e, methodName)
/* connectTrackBarEvent(id, event [, method]): ENDTRACK (the user lets the
   thumb go: .NET's MouseUp and KeyUp), POSCHANGED / THUMBPOSITION (its
   ValueChanged), THUMBTRACK (Scroll); the method gets .NET's (sender, e) */
::method connectTrackBarEvent
  use arg id, event, methodName
  if arg(3, "O") then methodName = "on" || event
  select case event~upper
    when "ENDTRACK" then do
      self~connectEvent(id, "MouseUp", methodName)
      return self~connectEvent(id, "KeyUp", methodName)
    end
    when "POSCHANGED", "THUMBPOSITION" then e = "ValueChanged"
    when "THUMBTRACK" then e = "Scroll"
    otherwise e = event
  end
  return self~connectEvent(id, e, methodName)
/* connectTreeViewEvent(id, event [, method]): SELCHANGED (.NET's
   AfterSelect), SELCHANGING (BeforeSelect), EXPANDING (BeforeExpand),
   EXPANDED (AfterExpand), BEGINEDIT / ENDEDIT (BeforeLabelEdit /
   AfterLabelEdit), BEGINDRAG (ItemDrag), KEYDOWN; BEGINDRAG with
   ooDialog's DefTreeDragHandler: an item dragged onto another one becomes
   its last child (not onto itself, its parent or one of its children); the
   target is drop highlighted, opens after a second, and the tree scrolls at
   its edges */
::method connectTreeViewEvent
  expose defined deferred
  use arg id, event, methodName
  if arg(3, "O") then methodName = "on" || event
  ev = event~upper
  if ev == "BEGINDRAG", methodName~caselessEquals("DefTreeDragHandler") then do
    if \defined then do
      deferred~append(.array~of("CONNECTTREEVIEWEVENT", .array~of(id, event, methodName)))
      return 0
    end
    .NetTreeDrag~new(self~control(id))
    return 0
  end
  select case ev
    when "SELCHANGED" then e = "AfterSelect"
    when "SELCHANGING" then e = "BeforeSelect"
    when "EXPANDING" then e = "BeforeExpand"
    when "EXPANDED" then e = "AfterExpand"
    when "BEGINEDIT" then e = "BeforeLabelEdit"
    when "ENDEDIT" then e = "AfterLabelEdit"
    when "BEGINDRAG", "BEGINRDRAG" then e = "ItemDrag"
    when "KEYDOWN" then e = "KeyDown"
    otherwise e = event
  end
  return self~connectEvent(id, e, methodName)
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
::method scrollInControl unguarded
  expose scroller
  if self~offThread then return self~onThread("SCROLLINCONTROL", arg(1, "A"))
  use arg id, text, fontName = "MS Shell Dlg 2", fontSize = 8, fontStyle = "", displaceY = 0, step = 4, sleep = 10, color = 0
  if var("SCROLLER") then scroller~stop
  if arg(2, "O") then return 0         -- (only the id: the scrolling stopped, as ooDialog's)
  st = ""
  do w over fontStyle~upper~makeArray(" ")
    if wordPos(w, "BOLD ITALIC UNDERLINE STRIKEOUT") > 0 then st = st w~left(1) || w~substr(2)~lower
  end
  if st == "" then st = "Regular"
  font = NetDialogFont(fontName, fontSize, self~form~DeviceDpi, st~strip~changeStr(" ", ", "))
  color = NetDialogColor(color)
  scroller = .NetDialogScroller~new(self~control(id), text, font, displaceY, step, sleep, color)
  return 0
::method scrolling unguarded
  expose scroller
  return var("SCROLLER") & scroller~running

/* -------------------------------------------------------- other threads */
/* ooDialog's dialog methods may be called from any Rexx thread (a method
   started with start, as ooDialog's programs do: an animation, a game's
   loop). A window belongs to the thread that made it: those below that
   touch it, called from another thread, run on the dialog's thread
   (.NetEventThread~runLater, the bridge's) and give their result back;
   those that only change what it shows return at once, as ooDialog's. */
::method offThread private unguarded   -- (inside) on another thread than the dialog's (then waits for its window)
  expose form uiThread
  if \var("FORM") | \var("UITHREAD") then return .false
  if .net~System~Environment~CurrentManagedThreadId == uiThread then return .false
  do while \form~IsHandleCreated & \form~IsDisposed   -- (a thread started in initDialog: the window comes soon)
    call SysSleep 0.02
  end
  return \form~IsDisposed
::method onThreadLater private unguarded   -- (inside) the same, not waited for (what only changes the window:
  use arg name, args                        -- a thread holding the object's lock does not wait for its handlers)
  .NetEventThread~eventThreadFor(self~form)~runLater(self, name, "A", args)
  return 0
::method onThread private unguarded    -- (inside) the message run on the dialog's thread, its result
  use arg name, args
  m = .NetEventThread~eventThreadFor(self~form)~runLater(self, name, "A", args)
  r = m~result
  if m~hasError then do
    c = m~errorCondition
    raise syntax 98.900 array("on the dialog's thread:" c~errortext":" c~message)
  end
  if m~hasResult then return r
  return 0

/* ----------------------------------------------- controls, by their ids */
::method enableControl unguarded       -- enableControl(id), disableControl(id), showControl(id), hideControl(id)
  if self~offThread then return self~onThreadLater("ENABLECONTROL", arg(1, "A"))
  self~control(arg(1))~Enabled = .true
  return 0
::method disableControl unguarded
  if self~offThread then return self~onThreadLater("DISABLECONTROL", arg(1, "A"))
  self~control(arg(1))~Enabled = .false
  return 0
::method showControl unguarded
  if self~offThread then return self~onThreadLater("SHOWCONTROL", arg(1, "A"))
  self~control(arg(1))~Visible = .true
  return 0
::method hideControl unguarded
  if self~offThread then return self~onThreadLater("HIDECONTROL", arg(1, "A"))
  self~control(arg(1))~Visible = .false
  return 0
::method setControlText unguarded      -- setControlText(id, text), getControlText(id)
  if self~offThread then return self~onThreadLater("SETCONTROLTEXT", arg(1, "A"))
  use strict arg id, text
  self~control(id)~Text = text
  return 0
::method getControlText unguarded
  if self~offThread then return self~onThread("GETCONTROLTEXT", arg(1, "A"))
  use strict arg id
  return self~control(id)~Text
/* resizeControl(id, size | cx, cy [, opts]), moveControl(id, point | x, y [, opts]): in pixels */
::method resizeControl unguarded
  if self~offThread then return self~onThread("RESIZECONTROL", arg(1, "A"))
  use arg id, a, b, opts = ""
  if a~isA(.String) then size = .net~System~Drawing~Size~new(a, b)
  else do; size = .net~System~Drawing~Size~new(a~width, a~height); if arg(3, "E") then opts = b; end
  self~control(id)~Size = size
  return 0
::method moveControl unguarded
  if self~offThread then return self~onThread("MOVECONTROL", arg(1, "A"))
  use arg id, a, b, opts = ""
  if a~isA(.String) then pt = .net~System~Drawing~Point~new(a, b)
  else do; pt = .net~System~Drawing~Point~new(a~x, a~y); if arg(3, "E") then opts = b; end
  self~control(id)~Location = pt
  return 0
::method getControlHandle unguarded    -- (here the control itself: what takes a handle below takes it)
  use strict arg id
  return self~control(id)
::method getWindowRect unguarded       -- getWindowRect(control | form): "left top right bottom", on the screen, in pixels
  if self~offThread then return self~onThread("GETWINDOWRECT", arg(1, "A"))
  use strict arg w
  if \w~isA(.NetObject) then w = self~form
  if .net~isInstance(w, "System.Windows.Forms.Form") then r = w~Bounds
  else do
    p = w~Parent~PointToScreen(w~Location)
    r = .net~System~Drawing~Rectangle~new(p, w~Size)
  end
  return r~Left r~Top r~Right r~Bottom
::method clearRect unguarded           -- clearRect(control, left, top, right, bottom): painted with its background
  if self~offThread then return self~onThreadLater("CLEARRECT", arg(1, "A"))
  use arg w, l, t, r, b
  g = w~CreateGraphics
  br = .net~System~Drawing~SolidBrush~new(w~BackColor)
  g~FillRectangle(br, l, t, r - l, b - t)
  br~Dispose; g~Dispose
  return 0
/* setControlSysColor(id, background [, foreground]): Windows' system colours by number (15: a button's face) */
::method setControlSysColor unguarded
  if self~offThread then return self~onThreadLater("SETCONTROLSYSCOLOR", arg(1, "A"))
  use arg id, bk, fg
  c = self~control(id)
  c~BackColor = NetDialogSysColor(bk)
  if arg(3, "E") then c~ForeColor = NetDialogSysColor(fg)
  c~Invalidate
  return 0
::method factorX unguarded             -- pixels in a dialog unit across (and down: factorY), as ooDialog's
  expose bx
  if \var("BX") then return NetDialogBaseUnits(self~dlgFont[1], self~dlgFont[2])[1] / 4
  return bx / 4
::method factorY unguarded
  expose by
  if \var("BY") then return NetDialogBaseUnits(self~dlgFont[1], self~dlgFont[2])[2] / 8
  return by / 8
::method setDlgFont                    -- setDlgFont(name, size): the font create will give the dialog
  expose dlgFont
  use strict arg name, size = 8
  dlgFont = .array~of(name, size)
  return 0
::method dlgFont private unguarded
  expose dlgFont
  if var("DLGFONT") then return dlgFont
  return .NetDialog~defaultFont
/* show, hide (showFast, hideFast: the same): the dialog's window (a modal
   one is made transparent: hidden, Windows Forms would end its ShowDialog);
   a control dialog's panel */
::method show unguarded
  if self~offThread then return self~onThread("SHOW", arg(1, "A"))
  if self~isA(.ControlDialog) then return self~controlDialogShow   -- (a mixin's methods come after the superclasses')
  f = self~form
  if f~Modal then f~Opacity = 1
  else f~Visible = .true
  return 0
::method hide unguarded
  if self~offThread then return self~onThread("HIDE", arg(1, "A"))
  if self~isA(.ControlDialog) then return self~controlDialogHide
  f = self~form
  if f~Modal then f~Opacity = 0
  else f~Visible = .false
  return 0
::method showFast unguarded
  forward message "SHOW"
::method hideFast unguarded
  forward message "HIDE"
::method enable unguarded              -- enable, disable: the dialog's window (all its controls with it)
  if self~offThread then return self~onThreadLater("ENABLE", arg(1, "A"))
  self~form~Enabled = .true
  return 0
::method disable unguarded
  if self~offThread then return self~onThreadLater("DISABLE", arg(1, "A"))
  self~form~Enabled = .false
  return 0
::method toTheTop unguarded            -- the dialog in front, active
  if self~offThread then return self~onThread("TOTHETOP", arg(1, "A"))
  f = self~form
  f~TopMost = .true; f~TopMost = .false
  f~Activate
  return 0
::method get unguarded                 -- the dialog's window (ooDialog's handle)
  return self~form~Handle
::method getRealPos unguarded          -- the window's position and size, in pixels (a NetPoint, a NetSize)
  return .NetPoint~new(self~form~Left, self~form~Top)
::method getRealSize unguarded
  return .NetSize~new(self~form~Width, self~form~Height)
::method backgroundBitmap              -- backgroundBitmap(file [, opts]): drawn at the top left, its own size
  use arg file, opts = ""
  self~form~BackgroundImage = .net~System~Drawing~Image~FromFile(file)
  self~form~BackgroundImageLayout = "None"
  return 0
::method setDataAttribute unguarded    -- (ooDialog copies an attribute and its control; here they are one)
  return 0
::method getDataAttribute unguarded
  return 0
/* comboAddDirectory(id, pattern [, attributes]): the files the pattern
   names (their names), added to the combo box; comboDrop(id): all removed */
::method comboAddDirectory unguarded
  if self~offThread then return self~onThread("COMBOADDDIRECTORY", arg(1, "A"))
  use arg id, pattern, attributes = ""
  dir = filespec("drive", pattern) || filespec("path", pattern)
  if dir == "" then dir = "."
  cb = self~control(id)
  do f over .net~System~IO~Directory~GetFiles(dir, filespec("name", pattern))
    cb~Items~Add(filespec("name", f))
  end
  return 0
::method comboDrop unguarded
  if self~offThread then return self~onThread("COMBODROP", arg(1, "A"))
  self~control(arg(1))~Items~Clear
  return 0
/* createPushButtonGroup(x, y, cx, cy, "text id method ...", bottom, opts): ooDialog's (its code) */
::method createPushButtonGroup
  use arg x, y, cx, cy, inp, bottom, opts = ""
  parse var inp bt bid bfnk newinp
  if arg(6, "O") then bottom = 0
  if arg(3, "O") then cx = 40
  else if cx = 0 then cx = 40
  if arg(4, "O") then cy = 12
  else if cy = 0 then cy = 12
  opts = opts~translate
  do while bt \= ""
    if bt~pos("'") > 0 then parse var inp "'"bt"'" bid bfnk newinp
    else if bt~pos('"') > 0 then parse var inp '"'bt'"' bid bfnk newinp
    if bfnk = 0 then bfnk = ""
    if bfnk == "" then self~createPushButton(bid, x, y, cx, cy, opts, bt)
    else self~createPushButton(bid, x, y, cx, cy, opts, bt, bfnk)
    n = opts~wordpos("DEFAULT")
    if n \= 0 then opts = opts~delword(n, 1)
    if bottom = 0 then y = y + trunc(cy * 1.5); else x = x + trunc(cx * 1.25)
    inp = newinp
    parse var inp bt bid bfnk newinp
  end
  return 0
::method createWhiteFrame               -- the static frames and rectangles: white, black, gray
  use arg id, x, y, cx, cy, style = ""
  return self~createStatic(id, x, y, cx, cy, style "WHITEFRAME", "")
::method createGrayFrame
  use arg id, x, y, cx, cy, style = ""
  return self~createStatic(id, x, y, cx, cy, style "GRAYFRAME", "")
::method createWhiteRect
  use arg id, x, y, cx, cy, style = ""
  return self~createStatic(id, x, y, cx, cy, style "WHITERECT", "")
::method createBlackRect
  use arg id, x, y, cx, cy, style = ""
  return self~createStatic(id, x, y, cx, cy, style "BLACKRECT", "")
::method createGrayRect
  use arg id, x, y, cx, cy, style = ""
  return self~createStatic(id, x, y, cx, cy, style "GRAYRECT", "")

/* write(x, y, text [, fontName [, fontSize [, fontStyle [, fg [, bk]]]]]):
   text on the dialog's face, at once (as ooDialog's: what next paints the
   dialog wipes it out), on its background colour (fontStyle TRANSPARENT:
   none); fg, bk: ooDialog's colour numbers; writeToButton(id, ...),
   writeToControl: on a control's face (with a device context: on what it
   draws) */
::method write unguarded
  if self~offThread then return self~onThreadLater("WRITE", arg(1, "A"))
  use arg x, y, text, fontName = "System", fontSize = 10, fontStyle = "", fg = (-1), bk = (-1)
  return NetDialogWriteOn(self~form, x, y, text, fontName, fontSize, fontStyle, fg, bk)
::method writeToControl unguarded
  expose dcs
  if self~offThread then return self~onThreadLater("WRITETOCONTROL", arg(1, "A"))
  use arg id, x, y, text, fontName = "System", fontSize = 10, fontStyle = "", fg = (-1), bk = (-1)
  dc = .nil
  if var("DCS") then dc = dcs[NetDialogKey(id)]
  if dc \== .nil then return NetDialogWriteOn(self~control(id), x, y, text, fontName, fontSize, fontStyle, fg, bk, dc)
  return NetDialogWriteOn(self~control(id), x, y, text, fontName, fontSize, fontStyle, fg, bk)
::method writeToButton unguarded
  forward message "WRITETOCONTROL"
::method scrollInButton unguarded
  forward message "SCROLLINCONTROL"

/* -------------------------------------------------- device contexts */
/* ooDialog's drawing on a control through its device context (GDI's):
   getButtonDC(id) gives it; createPen(width, style, color),
   createBrush(color), createFontEx: the objects; objectToDC(dc, obj),
   fontToDC(dc, font): selected (answering the one there before);
   rectangle, drawLine, drawPixel, drawArc, drawPie, drawAngleArc,
   fillDrawing, writeDirect; transparentText, opaqueText, setArcDirection;
   freeButtonDC, deleteObject. Here the device context draws on a bitmap
   that the control shows (its Paint), drawn again when the control is:
   ooDialog's drawing goes away when the control repaints itself. Colours
   are ooDialog's numbers; coordinates pixels. */
::method getButtonDC unguarded
  expose dcs
  use strict arg id
  if \var("DCS") then dcs = .directory~new
  key = NetDialogKey(id)
  if dcs~hasIndex(key) then return dcs[key]
  c = self~control(id)
  if .net~isInstance(c, "System.Windows.Forms.ButtonBase") then c~FlatStyle = "Standard"   -- (System: no Paint)
  dc = .NetDC~new(c)
  dcs[key] = dc
  c~Paint += .net~handler(dc, "PAINT")
  return dc
::method getControlDC unguarded
  forward message "GETBUTTONDC"
::method freeButtonDC unguarded        -- (the drawing stays: the control shows it)
  return 0
::method freeControlDC unguarded
  return 0
::method createPen unguarded           -- createPen([width [, style [, color]]]): style SOLID DASH DOT DASHDOT DASHDOTDOT NULL
  use arg width = 1, style = "SOLID", color = 0
  D = .net~System~Drawing
  style = style~strip~upper
  if style == "NULL" then return D~Pen~new(D~Color~Transparent, .net~single(1))
  pen = D~Pen~new(NetDialogColor(color), .net~single(max(width, 1)))
  select case style
    when "DASH" then pen~DashStyle = "Dash"
    when "DOT" then pen~DashStyle = "Dot"
    when "DASHDOT" then pen~DashStyle = "DashDot"
    when "DASHDOTDOT" then pen~DashStyle = "DashDotDot"
    otherwise nop
  end
  if width > 1 then do                 -- (GDI's wide pens: round ends and joins)
    pen~StartCap = "Round"; pen~EndCap = "Round"; pen~LineJoin = "Round"
  end
  return pen
::method createBrush unguarded         -- createBrush([color]): a solid brush (no color: a hollow one)
  if arg(1, "O") then return .net~System~Drawing~SolidBrush~new(.net~System~Drawing~Color~Transparent)
  return .net~System~Drawing~SolidBrush~new(NetDialogColor(arg(1)))
::method objectToDC unguarded          -- a pen or a brush (or a font) into the device context: the one before
  use strict arg dc, obj
  return dc~select(obj)
::method fontToDC unguarded
  use strict arg dc, font
  return dc~select(font)
::method deleteObject unguarded
  use strict arg obj
  if obj~isA(.NetObject) then obj~Dispose
  return 0
::method transparentText unguarded
  arg(1)~transparent = .true
  return 0
::method opaqueText unguarded
  arg(1)~transparent = .false
  return 0
::method setArcDirection unguarded     -- setArcDirection(dc, CLOCKWISE | COUNTERCLOCKWISE): drawArc's and drawPie's
  use strict arg dc, direction
  dc~clockwise = direction~strip~upper == "CLOCKWISE"
  return 0
::method rectangle unguarded           -- rectangle(dc, left, top, right, bottom [, "FILL"]): the pen's outline (FILL: the brush inside)
  use arg dc, l, t, r, b, fill = ""
  return dc~rectangle(l, t, r, b, fill~upper == "FILL")
::method drawLine unguarded            -- drawLine(dc, [x, y,] toX, toY): from x, y (or the last line's end)
  use arg dc, x, y, toX, toY
  if arg(2, "O") then x = dc~curX
  if arg(3, "O") then y = dc~curY
  return dc~line(x, y, toX, toY)
::method drawPixel unguarded           -- drawPixel(dc, x, y, color)
  use arg dc, x, y, color
  return dc~pixel(x, y, color)
::method drawArc unguarded             -- drawArc(dc, left, top, right, bottom [, startX, startY, endX, endY]): an ellipse's line
  use arg dc, l, t, r, b, sx, sy, ex, ey
  if arg() < 6 then return dc~ellipse(l, t, r, b)
  return dc~arc(l, t, r, b, sx, sy, ex, ey, .false)
::method drawPie unguarded             -- drawPie(dc, left, top, right, bottom, startX, startY, endX, endY): filled with the brush
  use arg dc, l, t, r, b, sx, sy, ex, ey
  return dc~arc(l, t, r, b, sx, sy, ex, ey, .true)
::method drawAngleArc unguarded        -- drawAngleArc(dc, xStart, yStart, x, y, radius, startAngle, sweepAngle): GDI's AngleArc
  use arg dc, xs, ys, x, y, radius, angle, sweep
  return dc~angleArc(xs, ys, x, y, radius, angle, sweep)
::method fillDrawing unguarded         -- fillDrawing(dc, x, y, color): filled with the brush from x, y to a line of color
  use arg dc, x, y, color
  return dc~flood(x, y, color)
::method writeDirect unguarded         -- writeDirect(dc, x, y, text): in the device context's font
  use arg dc, x, y, text
  return dc~text(x, y, text)

/* ---------------------------------------------------------- bitmap buttons */
/* ooDialog's bitmap buttons: an owner-drawn button (here a Panel) whose face
   is a bitmap, one for each state (normal, focused, selected: pressed,
   disabled), drawn at a displacement (setBitmapPosition) or stretched
   (STRETCH), in a frame (FRAME). A bitmap is a file's name, or with INMEMORY
   what loadBitmap gave (here a .NET Image); 0 or "": none.
   createBitmapButton(id, x, y, cx, cy, opts, text, method, normal [, focused
   [, selected [, disabled]]]); installBitmapButton(id, method, normal ...,
   opts): an owner-drawn button of a .rc; changeBitmapButton(id, normal ...,
   opts): its bitmaps changed, and drawn again. */
::method loadBitmap unguarded          -- loadBitmap(file [, opts]): the bitmap (a .NET Image)
  use arg file, opts = ""
  return .net~System~Drawing~Image~FromFile(file)
::method removeBitmap unguarded
  use arg image
  if image~isA(.NetObject) then image~Dispose
  return 0
::method createBitmapButton
  use arg id, x, y, cx = 0, cy = 0, opts = "", text = "", msgToRaise = "", bmp = 0, focus = "", sel = "", disabl = ""
  self~createPushButton(id, x, y, cx, cy, opts~translate "OWNER", text)
  return self~installBitmapButton(id, msgToRaise~space(0), bmp, focus, sel, disabl, opts)
::method installBitmapButton unguarded
  expose painters
  if self~offThread then return self~onThread("INSTALLBITMAPBUTTON", arg(1, "A"))
  use arg id, msgToRaise = "", bmp = 0, focus = "", sel = "", disabl = "", opts = ""
  if \var("PAINTERS") then painters = .directory~new
  c = self~control(id)
  p = .NetBitmapPainter~new(c)
  painters[NetDialogKey(id)] = p
  p~set(self~bitmapOf(bmp), self~bitmapOf(focus), self~bitmapOf(sel), self~bitmapOf(disabl), opts)
  if .net~isInstance(c, "System.Windows.Forms.ButtonBase") then c~FlatStyle = "Standard"   -- (System: no Paint)
  call NetDialogDoubleBuffered c
  c~Paint += .net~handler(p, "PAINT")
  c~MouseDown += .net~handler(p, "DOWN")
  c~MouseUp += .net~handler(p, "UP")
  if msgToRaise \== "" then self~connectButtonEvent(id, "CLICKED", msgToRaise)
  c~Invalidate
  return 0
::method changeBitmapButton unguarded
  if self~offThread then return self~onThreadLater("CHANGEBITMAPBUTTON", arg(1, "A"))
  use arg id, bmp = 0, focus = "", sel = "", disabl = "", opts = ""
  p = self~painterOf(id)
  p~set(self~bitmapOf(bmp), self~bitmapOf(focus), self~bitmapOf(sel), self~bitmapOf(disabl), opts)
  p~control~Invalidate
  return 0
::method setBitmapPosition unguarded   -- setBitmapPosition(id, point | x, y): where the bitmap is drawn, in pixels
  if self~offThread then return self~onThreadLater("SETBITMAPPOSITION", arg(1, "A"))
  use arg id, a, b
  p = self~painterOf(id)
  if a~isA(.String) then do; p~dx = a; p~dy = b; end
  else do; p~dx = a~x; p~dy = a~y; end
  p~control~Invalidate
  return 0
::method displaceBitmap unguarded
  forward message "SETBITMAPPOSITION"
::method getBitmapPosition unguarded   -- getBitmapPosition(id, point): point~x, point~y set
  use arg id, pt
  p = self~painterOf(id)
  pt~x = p~dx; pt~y = p~dy
  return 0
::method getBitmapSizeX unguarded
  img = self~painterOf(arg(1))~normal
  if img == .nil then return 0
  return img~Width
::method getBitmapSizeY unguarded
  img = self~painterOf(arg(1))~normal
  if img == .nil then return 0
  return img~Height
/* scrollBitmapFromTo(id, fromX, fromY, toX, toY, stepX, stepY [, delay [, displace]]):
   the bitmap moved step by step from one place to the other, drawn each
   time, delay ms apart; displace: it stays there (else back where it was) */
::method scrollBitmapFromTo unguarded
  if self~offThread then return self~onThread("SCROLLBITMAPFROMTO", arg(1, "A"))
  use arg id, fromX, fromY, toX, toY, stepX = 0, stepY = 0, delay = 0, displace = .true
  if stepX = 0 & stepY = 0 then return 1
  p = self~painterOf(id)
  oldX = p~dx; oldY = p~dy
  x = fromX; y = fromY
  do forever
    p~dx = x; p~dy = y
    p~control~Refresh
    if delay > 0 then call msSleep delay
    if \self~isDialogActive then return 0
    doneX = (stepX = 0) | (stepX > 0 & x >= toX) | (stepX < 0 & x <= toX)
    doneY = (stepY = 0) | (stepY > 0 & y >= toY) | (stepY < 0 & y <= toY)
    if doneX & doneY then leave
    if \doneX then do
      x += stepX
      if stepX > 0 then x = min(x, toX); else x = max(x, toX)
    end
    if \doneY then do
      y += stepY
      if stepY > 0 then y = min(y, toY); else y = max(y, toY)
    end
  end
  if \displace then do; p~dx = oldX; p~dy = oldY; p~control~Invalidate; end
  return 0
::method painterOf private unguarded
  expose painters
  use arg id
  if var("PAINTERS") then p = painters[NetDialogKey(id)]
  else p = .nil
  if p == .nil then do
    self~installBitmapButton(id)
    p = painters[NetDialogKey(id)]
  end
  return p
::method bitmapOf private unguarded    -- (inside) a bitmap argument: a file's name, an Image, 0 / "": none
  expose bitmapFiles
  use arg b
  if b == .nil then return .nil
  if b~isA(.NetObject) then return b
  if b == "" | b == 0 then return .nil
  if \var("BITMAPFILES") then bitmapFiles = .directory~new
  if \bitmapFiles~hasIndex(b) then bitmapFiles[b] = .net~System~Drawing~Image~FromFile(b)
  return bitmapFiles[b]

/* wantKeys(control [, keys]): Enter and Escape (or the keys named, as
   .NET's Keys) go to the control's KeyDown, not to the dialog: Windows
   Forms would otherwise give Enter to the default button (AcceptButton) and
   Escape to Cancel before the control sees them (ooDialog's isGrandChild
   and wantReturn get them to the control) */
::method wantKeys
  use arg ctl, keys = "Enter Escape"
  ctl~PreviewKeyDown += .net~handler(.NetDialogInputKeys~new(keys), "PREVIEW")
  return 0

/* sizing, as ooDialog's: connectResize(method): each change of the dialog's
   size calls method with ooDialog's (sizingType, sizeInfo): SIZE_RESTORED,
   SIZE_MINIMIZED or SIZE_MAXIMIZED, and the client area's width + 65536 *
   its height, in pixels (WM_SIZE's); connectSizeMoveEnded(method): once the
   user lets go (.NET's ResizeEnd); connectResizing(method): while the user
   drags an edge, before the size changes (WM_SIZING, which .NET has not: a
   NativeWindow on the form sees it), method gets (rect, edge), rect a NetRect
   of the window on the screen (left top right bottom) and edge LEFT, RIGHT,
   TOP, TOPLEFT, TOPRIGHT, BOTTOM, BOTTOMLEFT or BOTTOMRIGHT: when it answers
   .true, the window takes rect's coordinates as it changed them */
::constant SIZE_RESTORED 0
::constant SIZE_MINIMIZED 1
::constant SIZE_MAXIMIZED 2
::constant SIZE_MAXSHOW 3
::constant SIZE_MAXHIDE 4
::method connectResize
  use arg methodName = "onResize"
  self~form~Resize += .net~handler(.NetDialogResizeRelay~new(self, methodName), "RESIZE")
  return .true
::method connectSizeMoveEnded
  use arg methodName = "onSizeMoveEnded"
  self~form~ResizeEnd += .net~handler(.NetDialogSizeEndRelay~new(self, methodName), "ENDED")
  return .true
::method connectResizing
  use arg methodName = "onResizing"
  .NetDialogSizingHook~prepare
  hook = .NetDialogSizingHook~new(self, methodName)
  f = self~form
  if f~IsHandleCreated then hook~AssignHandle(.net~as(f~Handle, "System.IntPtr"))
  else f~HandleCreated += .net~handler(hook, "CREATED")
  return .true
::method pixelCX                       -- the dialog's window, in pixels
  return self~form~Width
::method pixelCY
  return self~form~Height
::method redrawClient                  -- the dialog and its controls drawn again
  use arg erase = .true
  self~form~Refresh
  return 0
::method update
  self~form~Refresh
  return 0
::method redraw                        -- (ooDialog's: the dialog drawn again)
  forward message "REDRAWCLIENT"
::method controlDialogs                -- (inside) the control dialogs started in this one, in that order
  expose controlDialogs
  if \var("CONTROLDIALOGS") then controlDialogs = .array~new
  return controlDialogs

/* connectKeyPress(method, keys [, filter]): those keys, anywhere in the
   dialog, call method with ooDialog's (key, shift, control, alt, info);
   keys: Windows' virtual key codes (ooDialog's .VK~F3...), or .NET's Keys
   names ("F3"), a list or a range ("112-114"); filter: NONE (no Shift,
   Control or Alt down), SHIFT, CONTROL, ALT, AND (all those named), the
   default any */
::method connectKeyPress
  use arg methodName, keys, filter = ""
  f = self~form
  if .net~isInstance(f, "System.Windows.Forms.Form") then f~KeyPreview = .true
  f~KeyDown += .net~handler(.NetDialogKeyPress~new(self, methodName, keys, filter), "KEYDOWN")
  return 0
::method getTextSizeDu                 -- a text's size in this dialog's font, in dialog units (a NetSize)
  use strict arg text
  s = .net~System~Windows~Forms~TextRenderer~MeasureText(text, self~form~Font)
  bx = self~px(4000) / 1000; by = self~py(8000) / 1000
  return .NetSize~new((s~Width * 4 + bx - 1) % bx, (s~Height * 8 + by - 1) % by)
::method pixel2dlgUnit                 -- a NetRect's or NetPoint's pixels to dialog units (its x / left, y / top, right, bottom)
  use strict arg r
  if r~isA(.NetSize) then do
    r~width = r~width * 4 % (self~px(4000) / 1000); r~height = r~height * 8 % (self~py(8000) / 1000)
    return 0
  end
  if r~isA(.NetPoint) then do
    r~x = r~x * 4 % (self~px(4000) / 1000); r~y = r~y * 8 % (self~py(8000) / 1000)
    return 0
  end
  bx = self~px(4000) / 1000; by = self~py(8000) / 1000
  r~left = r~left * 4 % bx; r~right = r~right * 4 % bx
  r~top = r~top * 8 % by;   r~bottom = r~bottom * 8 % by
  return 0

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
::method getControlData unguarded      -- a control's value: an edit's text, a check's 1 / 0, a list's selected item
  if self~offThread then return self~onThread("GETCONTROLDATA", arg(1, "A"))
  use strict arg id
  return NetDialogValue(self~control(id))
::method setControlData unguarded
  if self~offThread then return self~onThread("SETCONTROLDATA", arg(1, "A"))
  use strict arg id, value
  call NetDialogSetValue self~control(id), value
  return 0
/* setDataStem(stem.), getDataStem(stem.): ooDialog's: the controls' values
   from and into a stem, its tails the controls' ids (IDC_EDIT, 101...) */
::method setDataStem unguarded
  expose controls
  if self~offThread then return self~onThread("SETDATASTEM", arg(1, "A"))
  use strict arg stem
  do k over stem~allIndexes
    c = controls[NetDialogKey(k)]
    if c \== .nil then call NetDialogSetValue c, stem[k]
  end
  return 0
::method getDataStem unguarded
  expose controls data
  if self~offThread then return self~onThread("GETDATASTEM", arg(1, "A"))
  use strict arg stem
  do attr over data~allIndexes         -- every control with a value
    k = NetDialogKey(data[attr])
    c = controls[k]
    if c \== .nil then stem[k] = NetDialogValue(c)
  end
  return 0
::method stemIn private                 -- (inside) a dlgData. given to new: into the controls; CONNECTBUTTONS
  expose dataStem connectButtons controls
  if dataStem \== .nil then self~setDataStem(dataStem)
  if \connectButtons then return
  do k over controls~allIndexes         -- each push button to the method its text names (ooDialog's)
    if wordPos(k, "IDOK IDCANCEL IDHELP") > 0 then iterate
    c = controls[k]
    if \.net~isInstance(c, "System.Windows.Forms.Button") then iterate
    m = NetMenuMethodName(c~Text)
    if m \== "", self~hasMethod(m) then c~Click += .net~handler(.NetDialogButtonRelay~new(self, m), "CLICK")
  end
::method stemOut private                -- (inside) after OK: the controls' values into the dlgData. given
  expose dataStem
  if dataStem \== .nil then self~getDataStem(dataStem)
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
::method createFontEx                  -- createFontEx(name, size [, additional]): a .NET Font (weight >= 600: bold); additional
  expose form                          -- a Directory (WEIGHT, ITALIC...) or words: BOLD ITALIC UNDERLINE STRIKEOUT
  use arg name, size = 8, additional = .nil
  style = "Regular"
  if additional~isA(.string) then do
    w = additional~upper
    st = ""
    do k over .array~of("Bold", "Italic", "Underline", "Strikeout")
      if w~wordPos(k~upper) > 0 then st = st k
    end
    if st \== "" then style = st~strip
  end
  else if additional \== .nil then do
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
::method wizBack unguarded              -- (to override) a wizard's Back: 0 on, -1 stay, or the page number to go to
  return 0
::method wizNext unguarded              -- (to override) a wizard's Next: the same
  return 0
::method wizFinish unguarded            -- (to override) a wizard's Finish: 0 ends it
  return 0
::method queryFromSibling unguarded     -- (to override) a sibling's querySiblings(arg1, arg2): 0 lets the others answer
  return 0
::method pageCreate unguarded           -- (to override) once, before its controls are made
  return .true
::method headerTitle                    -- a wizard's interior page: the header's title and subtitle ("": an exterior page)
  expose headerTitle
  if \var("HEADERTITLE") then return ""
  return headerTitle
::method "HEADERTITLE="
  expose headerTitle
  use strict arg headerTitle
::method headerSubtitle
  expose headerSubtitle
  if \var("HEADERSUBTITLE") then return ""
  return headerSubtitle
::method "HEADERSUBTITLE="
  expose headerSubtitle
  use strict arg headerSubtitle
::method dlgHandle                      -- (ooDialog's: the window's handle)
  return self~hwnd
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
  self~pageCreate
  self~defineDialog
  self~framesToBack
  defined = .true
  do d over deferred; self~sendWith(d[1], d[2]); end
  self~initDialog
  self~applyData
  if self~isA(.ResizingAdmin) then self~raSetup   -- (a page: its controls follow the tab page's size)

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
  self~groupRadios
  if \var("FRAMES") then return
  do i = frames~items to 1 by -1
    frames[i]~SendToBack
  end

/* Radio buttons within a group box's rectangle go into the group box (the
   smallest, when boxes nest): in Windows Forms the radio buttons of one
   container are one group (Win32 groups them by WS_GROUP), and the group
   box's are its own. Where a container has radio buttons of more than one
   group (a radio button made with GROUP starts one), each group goes into a
   transparent Panel of its own. */
::method groupRadios private
  expose frames radios
  if \var("RADIOS") then return
  D = .net~System~Drawing
  boxes = .array~new
  if var("FRAMES") then do f over frames
    if .net~isInstance(f, "System.Windows.Forms.GroupBox") then boxes~append(f)
  end
  runs = .array~new                    -- for each container (0: the form, else a box's index): its groups of radio buttons
  do r over radios
    c = r[1]
    k = 0; area = 0
    do i = 1 to boxes~items
      b = boxes[i]
      if b~Bounds~Contains(c~Bounds), (k = 0 | b~Width * b~Height < area) then do
        k = i
        area = b~Width * b~Height
      end
    end
    if k > 0 then do
      b = boxes[k]
      self~form~Controls~Remove(c)
      c~Location = D~Point~new(c~Left - b~Left, c~Top - b~Top)
      b~Controls~Add(c)
    end
    if \runs~hasIndex(k + 1) then runs[k + 1] = .array~of(.array~new)
    groups = runs[k + 1]
    if r[2], groups[groups~last]~items > 0 then groups~append(.array~new)
    groups[groups~last]~append(c)
  end
  do k = 1 to runs~last
    if \runs~hasIndex(k) then iterate
    groups = runs[k]
    if groups~items < 2 then iterate
    if k = 1 then container = self~form
    else container = boxes[k - 1]
    do g over groups
      if g~items = 0 then iterate
      u = g[1]~Bounds
      do c over g; u = D~Rectangle~Union(u, c~Bounds); end
      p = .net~System~Windows~Forms~Panel~new
      p~BackColor = D~Color~Transparent
      p~Bounds = u
      container~Controls~Add(p)
      do c over g
        container~Controls~Remove(c)
        c~Location = D~Point~new(c~Left - u~X, c~Top - u~Y)
        p~Controls~Add(c)
      end
      p~BringToFront
    end
  end

/* execute([show [, icon]]): defineDialog, initDialog, then the dialog until
   it ends: 1 (OK) or 2 (Cancel); leaving runs last. Unguarded, so that the
   event methods, called while it waits, can run. */
::method execute unguarded
  expose form ending defined deferred
  if self~isA(.ControlDialog) then return self~controlDialogExecute   -- (a mixin's methods come after the superclasses')
  self~prepare
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
  if self~ownerDialog \== .nil then r = form~ShowDialog(self~ownerDialog~form)
  else r = form~ShowDialog
  self~snapshot                        -- the data attributes keep their values
  if r~string == "OK" then self~stemOut
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
/* popup([show]): the dialog shown without waiting for it (ooDialog's
   popup; a modeless form): the events of this thread's windows run it, as
   while a modal dialog or msSleep waits. ok / cancel / endDialog close it;
   leaving runs when it closes. */
::method popup unguarded
  expose form modeless
  self~prepare
  modeless = .true
  form~FormClosed += .net~handler(self, "NETDIALOG.CLOSED")
  if self~ownerDialog \== .nil then form~Owner = self~ownerDialog~form
  form~Show
  return 0
::method isModeless private
  expose modeless
  return var("MODELESS")
::method "NETDIALOG.CLOSED" unguarded
  expose asyncResult
  use arg sender, e
  asyncResult = (sender~DialogResult~string == "OK")~?(1, 2)
  self~snapshot
  self~leaving
/* executeAsync([sleep [, show]]): ooDialog's: the dialog runs while the
   program goes on (there on a thread of its own; here a modeless form, as
   popup, whose events run while this thread waits: endAsyncExecution,
   msSleep); endAsyncExecution: waits until it has ended, its result (1 OK,
   2 Cancel) */
::method executeAsync unguarded
  self~popup
  return 0
::method endAsyncExecution unguarded
  expose asyncResult
  do while \var("ASYNCRESULT")
    call msSleep 50
  end
  return asyncResult
::method prepare private               -- (inside) defineDialog, initDialog, the data
  expose form defined deferred
  if \var("FORM") then raise syntax 98.900 array("NetDialog: create (or createCenter) first")
  self~defineDialog
  self~framesToBack
  defined = .true
  do d over deferred; self~sendWith(d[1], d[2]); end
  if self~isA(.TabOwnerDialog) then self~tabOwnerSetup
  self~initDialog
  self~applyData
  self~stemIn
  if self~isA(.ResizingAdmin) then self~raSetup
::method setWindowTitle                -- setWindowTitle(hwnd, text): a window of this program's title
  use strict arg hwnd, text
  .net~System~Windows~Forms~Control~FromHandle(hwnd)~Text = text
  return 0
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
  expose form ending closing
  if self~offThread then return self~onThread("ENDDIALOG", arg(1, "A"))   -- (ok, cancel from another thread)
  use arg code = 1
  ending = .true
  form~DialogResult = (code = 1)~?("OK", "Cancel")
  if self~isModeless, \var("CLOSING") then form~Close   -- (a modeless form: DialogResult does not close it)
::method "NETDIALOG.CLOSING" unguarded  -- the window's [x] (or Alt+F4): the dialog's cancel
  expose ending closing
  use arg sender, e
  if ending then return
  if e~CloseReason~string \== "UserClosing" then do   -- its owner closing, Windows ending: no say in it
    ending = .true
    return
  end
  closing = .true                      -- (endDialog: no Close of its own)
  self~cancel
  drop closing
  if \ending then e~Cancel = .true     -- a cancel that did not end the dialog (overridden): it stays, as in ooDialog

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
::method unknown unguarded
  expose data pending controls closed defined
  if self~offThread then return self~onThread("UNKNOWN", arg(1, "A"))
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
   connectAllCommandEvents([method [, dialog]]), enable / disable / check /
   uncheck / checkRadio (by id), attachTo(dialog). Items with the ids IDOK
   and IDCANCEL end the dialog with its ok and cancel, as ooDialog's
   WM_COMMAND does. A command's method gets ooDialog's (id, 0), the id as
   the menu was given it. A menu of a .rc: rc2oodnet.rex -cls makes it a
   subclass of NetMenuBar. ooDialog's UserMenuBar builds itself with
   addPopup, addItem, addSeparator and complete: the same here.

   ooDialog's constructors take an autoConnect and an attachTo argument; here
   the program says it after the menu is built: menuBar~attachTo(dialog),
   then menuBar~connectAllCommandEvents (each item to the dialog's method
   named as its text: "Insert Text ..." runs insertText).                  */
::class NetMenuBar public
::attribute strip get                  -- the MenuStrip
::method init                          -- (ooDialog's arguments are not needed)
  expose strip popups connected attached queued
  attached = .nil
  strip = .net~System~Windows~Forms~MenuStrip~new
  popups = .array~new
  connected = .directory~new
  queued = .array~new                  -- addItem's methods, connected when it is attached
::method getPopup                      -- getPopup(id [, byPosition]): the NetPopupMenu inserted with that id, or at that position (from 1)
  expose popups
  use strict arg id, byPosition = .false
  if byPosition then do
    if \popups~hasIndex(id) then return .nil
    return popups[id]
  end
  do p over popups
    if p~id \== .nil, NetMenuKey(p~id) == NetMenuKey(id) then return p
  end
  return .nil
/* ooDialog's UserMenuBar: addPopup(id, text [, opts [, helpID]]),
   addItem(id, text [, opts [, method]]), addSeparator(id [, opts]),
   complete; opts: DEFAULT (bold), GRAYED, DISABLED, CHECKED, RADIO (a check
   mark here: .NET's menu items have no bullet), END (ignored: the popups
   end where the next one starts) */
::method addPopup
  expose current
  use arg id, text, opts = "", helpID
  current = .NetPopupMenu~new(id)
  self~insertPopup(, id, current, text)
  call NetMenuState current~item, opts
  return .true
::method addItem
  expose current queued
  use arg id, text, opts = "", methodName
  if \var("CURRENT") then raise syntax 93.900 array("NetMenuBar: addItem before addPopup")
  current~insertItem(, id, text, opts)
  if arg(4, "E") then queued~append(.array~of(id, methodName))
  return .true
::method addSeparator
  expose current
  use arg id, opts = ""
  if \var("CURRENT") then raise syntax 93.900 array("NetMenuBar: addSeparator before addPopup")
  current~insertSeparator(, id)
  return .true
::method complete                      -- (nothing to do: the menu is ready as it is built)
  return .true
::method insertPopup
  expose strip popups
  use arg before = .nil, id = .nil, popup, text
  if id \== .nil then popup~id = id
  popup~item~Text = text
  call NetMenuInsert strip~Items, popup~item, self~find(before)
  popups~append(popup)
  return 0
::method find                          -- the ToolStripItem with that id (a popup's too), or .nil
  expose popups
  use arg id
  if id == .nil then return .nil
  do p over popups
    if p~id \== .nil, NetMenuKey(p~id) == NetMenuKey(id) then return p~item
    i = p~find(id)
    if i \== .nil then return i
  end
  return .nil
::method item                          -- the same, or an error
  use strict arg id
  i = self~find(id)
  if i == .nil then raise syntax 93.900 array("this menu has no item" id)
  return i
::method connectCommandEvent           -- connectCommandEvent(id, method [, dialog]): the dialog attached to, if omitted
  expose connected attached
  use strict arg id, methodName, dialog = (attached)
  self~item(id)~Click += .net~handler(.NetMenuCommandRelay~new(dialog, methodName, id), "CLICK")
  connected[NetMenuKey(id)] = .true
  return 0
/* connectAllCommandEvents([method [, dialog]]): every command item (not a
   submenu or a separator, nor IDOK, IDCANCEL, IDHELP, which go to ok, cancel
   and help) to method, or each to the method named as its text without
   spaces, "&", "+", ":" and a closing "..." (ooDialog's names) */
::method connectAllCommandEvents
  expose popups connected attached
  use arg methodName = .nil, dialog = (attached)
  if dialog == .nil then raise syntax 93.900 array("NetMenuBar: connectAllCommandEvents needs a dialog (or attachTo first)")
  do p over popups
    p~connectAllCommandEvents(methodName, dialog, connected)
  end
  return .true
::method checkRadio                    -- checkRadio(first, last, id): the items from first to last unchecked, id checked
  use strict arg first, last, id
  call NetMenuCheckRadio self~item(first), self~item(last), self~item(id)
  return .true
::method enable;  self~item(arg(1))~Enabled = .true;  return 0
::method disable; self~item(arg(1))~Enabled = .false; return 0
::method isEnabled; return self~item(arg(1))~Enabled
::method check;   self~item(arg(1))~Checked = .true;  return 0
::method uncheck; self~item(arg(1))~Checked = .false; return 0
::method isChecked; return self~item(arg(1))~Checked
::method attachTo                      -- attachTo(dialog [, pos]): on top of the dialog
  expose strip connected attached queued
  use arg dialog
  attached = dialog
  if \connected~hasIndex("IDOK"), self~find("IDOK") \== .nil then self~connectCommandEvent("IDOK", "OK", dialog)
  if \connected~hasIndex("IDCANCEL"), self~find("IDCANCEL") \== .nil then self~connectCommandEvent("IDCANCEL", "CANCEL", dialog)
  do q over queued; self~connectCommandEvent(q[1], q[2], dialog); end
  queued~empty
  dialog~attachMenu(strip)
  return .true

::class NetPopupMenu public
::attribute item get                   -- the ToolStripMenuItem that holds the items
::attribute id                         -- its id, if it has one
::method init
  expose item ids dialog
  use arg id = .nil
  dialog = .nil
  self~id = (id == "")~?(.nil, id)
  item = .net~System~Windows~Forms~ToolStripMenuItem~new
  ids = .directory~new
/* as a context menu (ooDialog's): assignTo(dialog [, autoConnect [,
   method]]): with autoConnect each item runs the dialog's method named as
   its text (ooDialog's names: "&Add Employee..." runs addEmployee), or
   method; connectContextMenu(method, hwnd [, dialog]): a right click on that
   window calls the dialog's method with (hwnd, x, y), screen coordinates
   (-1, -1 from the keyboard); show(point [, dialog]): the menu there;
   connectAllCommandEvents([method [, dialog]]); enable / disable (an id, or
   an Array of them) */
::method assignTo
  expose dialog
  use arg dialog, autoConnect = .false, methodName = .nil
  if autoConnect then self~connectAllCommandEvents(methodName, dialog)
  return .true
::method connectAllCommandEvents       -- (a menu bar's third argument: its items connected one by one)
  expose dialog ids subs
  use arg methodName = .nil, dlg = .nil, skip = (.directory~new)
  if dlg == .nil then dlg = dialog
  if dlg == .nil then raise syntax 93.900 array("NetPopupMenu: connectAllCommandEvents needs a dialog")
  if dialog == .nil then dialog = dlg
  do key over ids~allIndexes
    i = ids[key]
    if .net~isInstance(i, "System.Windows.Forms.ToolStripSeparator") then iterate
    if i~HasDropDownItems | wordPos(key, "IDOK IDCANCEL IDHELP 9") > 0 | skip~hasIndex(key) then iterate
    name = methodName
    if name == .nil then name = NetMenuMethodName(i~Text)
    i~Click += .net~handler(.NetMenuCommandRelay~new(dlg, name, key), "CLICK")
  end
  if var("SUBS") then do p over subs; p~connectAllCommandEvents(methodName, dlg, skip); end
  return .true
::method checkRadio                    -- checkRadio(first, last, id), as a menu bar's
  use strict arg first, last, id
  call NetMenuCheckRadio self~find(first), self~find(last), self~find(id)
  return .true
::method connectContextMenu
  expose dialog
  use strict arg methodName, hwnd, dlg = .nil
  if dlg == .nil then dlg = dialog
  c = .net~System~Windows~Forms~Control~FromHandle(hwnd)
  relay = .NetDialogContextRelay~new(dlg, methodName, hwnd)
  c~MouseUp += .net~handler(relay, "MOUSEUP")
  c~KeyUp += .net~handler(relay, "KEYUP")
  return .true
::method show
  expose strip dialog item
  use arg pos, dlg = .nil
  if dlg \== .nil then dialog = dlg
  if \var("STRIP") then do            -- its items move to a ContextMenuStrip, once
    strip = .net~System~Windows~Forms~ContextMenuStrip~new
    do i over item~DropDownItems~makeArray; strip~Items~Add(i); end
  end
  strip~Show(.net~System~Drawing~Point~new(pos~x, pos~y))
  return 0
::method contextStrip                  -- the ContextMenuStrip show makes (.nil before it is shown)
  expose strip
  if var("STRIP") then return strip
  return .nil
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
::method insertItem                    -- insertItem(before, id, text [, state]): state GRAYED, DISABLED, CHECKED, DEFAULT
  expose item ids
  use arg before = .nil, id, text, state = ""
  i = .net~System~Windows~Forms~ToolStripMenuItem~new(text)
  call NetMenuState i, state
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
::routine NetMenuState                 -- (inside) an item's state words: GRAYED, DISABLED, CHECKED, DEFAULT
  use arg i, state
  state = state~upper
  if state~wordPos("GRAYED") > 0 | state~wordPos("DISABLED") > 0 then i~Enabled = .false
  if state~wordPos("CHECKED") > 0 then i~Checked = .true
  if state~wordPos("DEFAULT") > 0 then i~Font = .net~System~Drawing~Font~new(i~Font, "Bold")   -- (Windows' default item: bold)
/* (inside) ooDialog's method name for a menu item: its text without spaces,
   tabs, "&", "+" and ":", and cut where a closing "..." starts
   (strdup_2methodName in oodCommon.cpp) */
::routine NetMenuMethodName
  use arg text
  name = text~changeStr(" ", "")~changeStr("09"x, "")~changeStr("&", "")~changeStr("+", "")~changeStr(":", "")
  if name~length >= 3, name~substr(name~length - 2, 1) == "." then name = name~left(name~length - 3)
  return name
::routine NetMenuCheckRadio            -- (inside) checkRadio: the items of first's menu from first to last
  use arg first, last, chosen
  items = first~Owner~Items
  a = items~IndexOf(first); b = items~IndexOf(last)
  do k = min(a, b) to max(a, b)
    it = items[k]
    if .net~isInstance(it, "System.Windows.Forms.ToolStripMenuItem") then it~Checked = it~Equals(chosen)
  end


/* (inside) a bitmap button's face: its bitmaps, drawn on the control's Paint
   as ooDialog's drawBitmapButton draws them */
::class NetBitmapPainter
::attribute control
::attribute normal
::attribute dx unguarded
::attribute dy unguarded
::method init
  expose control dx dy pressed normal focused selected disabled stretch frame
  use arg control
  dx = 0; dy = 0; pressed = .false
  normal = .nil; focused = .nil; selected = .nil; disabled = .nil; stretch = .false; frame = .false
::method set unguarded
  expose normal focused selected disabled stretch frame
  use arg normal, focused, selected, disabled, opts
  o = opts~upper
  stretch = o~wordPos("STRETCH") > 0
  frame = o~wordPos("FRAME") > 0
::method down unguarded
  expose pressed control
  pressed = .true; control~Invalidate
::method up unguarded
  expose pressed control
  pressed = .false; control~Invalidate
::method paint unguarded
  expose control dx dy pressed normal focused selected disabled stretch frame
  use arg sender, e
  D = .net~System~Drawing
  g = e~Graphics
  g~Clear(control~BackColor)
  w = control~ClientSize~Width; h = control~ClientSize~Height
  img = normal
  sel = pressed & control~Enabled
  if \control~Enabled then do; if disabled \== .nil then img = disabled; end
  else if sel then do; if selected \== .nil then img = selected; end
  else if control~Focused then do; if focused \== .nil then img = focused; end
  x = dx; y = dy
  if sel & frame then do; x += 3; y += 3; end          -- (a 3D effect)
  if img \== .nil then do
    sx = 0; sy = 0
    right = w + x; bottom = h + y                       -- (the button's rectangle, displaced)
    if x < 0 then do; sx = -x; x = 0; end
    if y < 0 then do; sy = -y; y = 0; end
    if stretch then do; dw = right - x; dh = bottom - y; end
    else do; dw = img~Width - sx; dh = img~Height - sy; end
    if dw > 0, dh > 0 then do
      src = D~Rectangle~new(sx, sy, img~Width - sx, img~Height - sy)
      if \stretch then src = D~Rectangle~new(sx, sy, dw, dh)
      g~DrawImage(img, D~Rectangle~new(x, y, dw, dh), src, D~GraphicsUnit~Pixel)
    end
  end
  if frame then do
    g~DrawRectangle(D~Pens~Black, 0, 0, w - 1, h - 1)
    grey = D~Pen~new(D~Color~FromArgb(120, 120, 120), .net~single(2))
    if sel then do
      g~DrawLine(grey, 2, 2, w - 2, 2); g~DrawLine(grey, 2, h - 2, 2, 1)
    end
    else do
      white = D~Pen~new(D~Color~FromArgb(240, 240, 240), .net~single(2))
      g~DrawLine(white, 2, 2, w - 2, 2); g~DrawLine(white, 2, h - 2, 2, 1)
      g~DrawLine(grey, w - 2, 2, w - 2, h - 2); g~DrawLine(grey, 2, h - 2, w - 2, h - 2)
      white~Dispose
    end
    grey~Dispose
  end


/* (inside) ooDialog's device context: a bitmap with the control's face,
   drawn on (GDI's current pen, brush, font, text mode, position, arc
   direction), shown by the control's Paint */
::class NetDC
::attribute graphics get
::attribute bitmap get
::attribute transparent
::attribute clockwise
::attribute curX
::attribute curY
::method init
  expose control bmp graphics pen brush font transparent clockwise curX curY brushes
  use arg control
  D = .net~System~Drawing
  w = max(control~Width, 1); h = max(control~Height, 1)
  bmp = D~Bitmap~new(w, h)
  control~DrawToBitmap(bmp, D~Rectangle~new(0, 0, w, h))   -- (what the control shows now)
  graphics = D~Graphics~FromImage(bmp)
  siblings = control~Parent~Controls      -- (and the controls made after it over it: Windows paints them on it,
  i = siblings~GetChildIndex(control)     -- Windows Forms puts them behind it)
  do k = i + 1 to siblings~Count - 1     -- (in the order they were made: the last on top)
    c = siblings[k]
    if \c~Visible | \c~Bounds~IntersectsWith(control~Bounds) then iterate
    tmp = D~Bitmap~new(c~Width, c~Height)
    c~DrawToBitmap(tmp, D~Rectangle~new(0, 0, c~Width, c~Height))
    graphics~DrawImageUnscaled(tmp, c~Left - control~Left, c~Top - control~Top)
    tmp~Dispose
  end
  pen = D~Pen~new(D~Color~Black, .net~single(1))
  brush = D~SolidBrush~new(D~Color~White)
  font = control~Font
  transparent = .false; clockwise = .false; curX = 0; curY = 0
  brushes = .directory~new
::method paint unguarded
  expose bmp
  use arg sender, e
  e~Graphics~DrawImageUnscaled(bmp, 0, 0)
::method select
  expose pen brush font
  use arg obj
  if .net~isInstance(obj, "System.Drawing.Pen") then do; old = pen; pen = obj; return old; end
  if .net~isInstance(obj, "System.Drawing.Brush") then do; old = brush; brush = obj; return old; end
  if .net~isInstance(obj, "System.Drawing.Font") then do; old = font; font = obj; return old; end
  return .nil
::method shown private                  -- (the control shows the bitmap again)
  expose control
  control~Invalidate
  return 0
::method rectangle
  expose graphics pen brush
  use arg l, t, r, b, fill
  l = trunc(l); t = trunc(t); r = trunc(r); b = trunc(b)   -- (GDI's coordinates: whole pixels)
  x = min(l, r); y = min(t, b); w = abs(r - l); h = abs(b - t)
  if fill then graphics~FillRectangle(brush, x, y, w, h)
  if w > 1, h > 1 then graphics~DrawRectangle(pen, x, y, w - 1, h - 1)
  return self~shown
::method line
  expose graphics pen curX curY
  use arg x, y, toX, toY
  x = trunc(x); y = trunc(y); toX = trunc(toX); toY = trunc(toY)
  graphics~DrawLine(pen, x, y, toX, toY)
  curX = toX; curY = toY
  return self~shown
::method pixel
  expose graphics brushes
  use arg x, y, color
  x = trunc(x); y = trunc(y)
  if \brushes~hasIndex(color) then brushes[color] = .net~System~Drawing~SolidBrush~new(NetDialogColor(color))
  graphics~FillRectangle(brushes[color], x, y, 1, 1)
  return self~shown
::method ellipse
  expose graphics pen
  use arg l, t, r, b
  l = trunc(l); t = trunc(t); r = trunc(r); b = trunc(b)
  graphics~DrawEllipse(pen, min(l, r), min(t, b), abs(r - l), abs(b - t))
  return self~shown
::method arc                           -- an arc, or a pie, from the start radial to the end one (GDI's direction)
  expose graphics pen brush clockwise
  use arg l, t, r, b, sx, sy, ex, ey, pie
  l = trunc(l); t = trunc(t); r = trunc(r); b = trunc(b)
  x = min(l, r); y = min(t, b); w = abs(r - l); h = abs(b - t)
  if w = 0 | h = 0 then return 0
  M = .net~System~Math
  cx = x + w / 2; cy = y + h / 2
  a1 = M~Atan2(sy - cy, sx - cx) * 180 / M~PI          -- (.NET's degrees: clockwise on the screen)
  a2 = M~Atan2(ey - cy, ex - cx) * 180 / M~PI
  if clockwise then sweep = NetDialogMod360(a2 - a1)
  else sweep = -NetDialogMod360(a1 - a2)               -- (GDI's default: counterclockwise on the screen)
  if sweep = 0 then sweep = clockwise~?(360, -360)
  rect = .net~System~Drawing~RectangleF~new(.net~single(x), .net~single(y), .net~single(w), .net~single(h))
  if pie then do
    graphics~FillPie(brush, .net~single(x), .net~single(y), .net~single(w), .net~single(h), .net~single(a1), .net~single(sweep))
    graphics~DrawPie(pen, rect, .net~single(a1), .net~single(sweep))
  end
  else graphics~DrawArc(pen, rect, .net~single(a1), .net~single(sweep))
  return self~shown
::method angleArc                      -- GDI's AngleArc: a line from xs, ys to the arc's start, the arc (degrees counterclockwise)
  expose graphics pen curX curY
  use arg xs, ys, x, y, radius, angle, sweep
  M = .net~System~Math
  a = angle * M~PI / 180; e = (angle + sweep) * M~PI / 180
  sx = x + radius * M~Cos(a); sy = y - radius * M~Sin(a)
  graphics~DrawLine(pen, .net~single(xs), .net~single(ys), .net~single(sx), .net~single(sy))
  rect = .net~System~Drawing~RectangleF~new(.net~single(x - radius), .net~single(y - radius), .net~single(2 * radius), .net~single(2 * radius))
  graphics~DrawArc(pen, rect, .net~single(-angle), .net~single(-sweep))
  curX = trunc(x + radius * M~Cos(e)); curY = trunc(y - radius * M~Sin(e))
  self~shown
  return 0
::method text
  expose graphics font transparent
  use arg x, y, text
  x = trunc(x); y = trunc(y)
  D = .net~System~Drawing
  back = transparent~?(D~Color~Transparent, D~Color~White)
  .net~System~Windows~Forms~TextRenderer~DrawText(graphics, text, font, D~Point~new(x, y), D~Color~Black, back, -
    .net~System~Windows~Forms~TextFormatFlags~NoPadding)
  return self~shown
::method flood                         -- GDI's FloodFill (FLOODFILLBORDER): from x, y up to a line of the color
  expose bmp graphics brush
  use arg x, y, color
  D = .net~System~Drawing
  w = bmp~Width; h = bmp~Height
  x = trunc(x); y = trunc(y)
  if x < 0 | y < 0 | x >= w | y >= h then return 1
  rect = D~Rectangle~new(0, 0, w, h)
  data = bmp~LockBits(rect, "ReadOnly", "Format32bppArgb")
  ints = .net~System~Array~CreateInstance(.net~type("int"), w * h)
  .net~System~Runtime~InteropServices~Marshal~Copy(data~Scan0, ints, 0, w * h)
  bmp~UnlockBits(data)
  px = ints~makeArray                  -- (the pixels, a Rexx Array: one row after the other)
  border = NetDialogColor(color)~ToArgb
  if px[y * w + x + 1] = border then return 1
  done = .set~new
  todo = .queue~of(x y)
  do while todo~items > 0              -- (a span at a time, as scanline fills go)
    parse value todo~pull with sx sy
    row = sy * w
    if px[row + sx + 1] = border | done~hasIndex(sx sy) then iterate
    l = sx
    do while l > 0
      if px[row + l] = border then leave    -- (the pixel left of l)
      l -= 1
    end
    r = sx
    do while r < w - 1
      if px[row + r + 2] = border then leave   -- (the pixel right of r)
      r += 1
    end
    graphics~FillRectangle(brush, l, sy, r - l + 1, 1)
    do i = l to r
      done~put(i sy)
      if sy > 0 then if px[row - w + i + 1] \= border, \done~hasIndex(i (sy - 1)) then todo~queue(i (sy - 1))
      if sy < h - 1 then if px[row + w + i + 1] \= border, \done~hasIndex(i (sy + 1)) then todo~queue(i (sy + 1))
    end
  end
  return self~shown

::class NetDialogFrameLine             -- (inside) a static frame's line, in its colour
::method init
  expose color
  use arg color
::method paint
  expose color
  use arg sender, e
  .net~System~Windows~Forms~ControlPaint~DrawBorder(e~Graphics, sender~ClientRectangle, color, "Solid")

::class NetDialogButtonRelay           -- (inside) CONNECTBUTTONS: a button's Click, the dialog's method, no arguments
::method init
  expose dialog methodName
  use arg dialog, methodName
::method click
  expose dialog methodName
  dialog~send(methodName)

::class NetMenuCommandRelay            -- (inside) a menu item's Click: the dialog's method with ooDialog's (id, 0)
::method init
  expose dialog methodName id
  use arg dialog, methodName, id
::method click
  expose dialog methodName id
  dialog~send(methodName, id, 0)

/* ----------------------------------------------------------- property sheet */
/* ooDialog's PropertySheetDialog: .NetPropertySheet~new(pages [, options
   [, caption]]), each page a NetDialog (its controls on a tab); startPage,
   pages, setCurSel(, index), getResult ("CLOSEDOK", "CLOSEDCANCEL");
   options: NOAPPLYNOW (no Apply button). OK asks the page shown to
   killActive, then every page shown to apply. */
::class NetPropertySheet subclass NetDialog public
::constant IDC_TAB_IN_PROPSHEET "PROPSHEET.TABS"   -- the tab control's id (ResizingAdmin's sizing names it)
::attribute pages get
::attribute startPage
::attribute header                     -- a wizard's header bitmap (a .NET Image), on its interior pages
::attribute watermark                  -- a wizard's watermark (a .NET Image), on its exterior pages (no headerTitle)
::method init
  expose pages options outcome cur wizard extH intH
  use arg pages, options = "", caption = ""
  self~init:super
  self~startPage = 1
  self~header = .nil; self~watermark = .nil
  outcome = "CLOSEDCANCEL"; cur = 0
  op = options~upper
  wizard = op~wordPos("WIZARD97") > 0 | op~wordPos("WIZARD") > 0 | op~wordPos("AERO") > 0 | op~wordPos("WIZARDLITE") > 0
  cx = 0; cy = 0; extH = 0; intH = 0
  do p over pages
    p~propSheet = self
    cx = max(cx, p~sizeX); cy = max(cy, p~sizeY)
    if p~headerTitle == "" then extH = max(extH, p~sizeY)
    else intH = max(intH, p~sizeY)
  end
  first = pages[1]
  if wizard then do                    -- exterior pages fill the area; interior ones go under a header
    contentH = max(extH, intH + 50)
    self~createCenter(cx, contentH + 31, caption, , , first~fontName, first~fontSize)
  end
  else self~createCenter(cx + 14, cy + 42, caption, , , first~fontName, first~fontSize)
::method isWizard
  expose wizard
  return wizard
::method defineDialog
  expose pages options tabs wizard
  if wizard then do; self~defineWizard; return; end
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
/* a wizard (Wizard97): the page shown over the area above a line, the
   buttons under it (Back, Next or Finish, Cancel); an interior page (one
   with a headerTitle) under a white header with its title, subtitle and the
   header bitmap, 7 dialog units in; an exterior page on white, the
   watermark on its left */
::method defineWizard private
  expose pages panels headerBox titleLabel subtitleLabel headerPicture
  F = .net~System~Windows~Forms
  D = .net~System~Drawing
  contentH = self~sizeY - 31
  w = self~px(self~sizeX)
  headerBox = F~Panel~new
  headerBox~BackColor = D~Color~White
  headerBox~Bounds = D~Rectangle~new(0, 0, w, self~py(36))
  self~form~Controls~Add(headerBox)
  titleLabel = F~Label~new
  titleLabel~Font = D~Font~new(self~form~Font, "Bold")
  titleLabel~Bounds = D~Rectangle~new(self~px(15), self~py(8), w - self~px(15) - 60, self~py(10))
  subtitleLabel = F~Label~new
  subtitleLabel~Bounds = D~Rectangle~new(self~px(22), self~py(18), w - self~px(22) - 60, self~py(18))
  headerPicture = F~PictureBox~new
  headerPicture~SizeMode = "CenterImage"
  headerPicture~Bounds = D~Rectangle~new(w - 56, (self~py(36) - 49) % 2, 49, 49)
  line = F~Label~new
  line~BorderStyle = "Fixed3D"
  line~Bounds = D~Rectangle~new(0, self~py(36) - 2, w, 2)
  do c over .array~of(titleLabel, subtitleLabel, headerPicture, line); headerBox~Controls~Add(c); end
  panels = .array~new
  do i = 1 to pages~items
    p = pages[i]
    panel = F~Panel~new
    panel~Visible = .false
    if p~headerTitle == "" then do       -- exterior
      panel~Bounds = D~Rectangle~new(0, 0, w, self~py(contentH))
      panel~BackColor = D~Color~White
    end
    else panel~Bounds = D~Rectangle~new(0, self~py(36) + self~py(7), w, self~py(p~sizeY))
    p~hostIn(panel)
    self~form~Controls~Add(panel)
    panels[i] = panel
  end
  sep = F~Label~new
  sep~BorderStyle = "Fixed3D"
  sep~Bounds = D~Rectangle~new(0, self~py(contentH), w, 2)
  self~form~Controls~Add(sep)
  y = contentH + 9
  x = self~sizeX - 7 - 50
  self~createPushButton(IDCANCEL, x, y, 50, 14, , "Cancel")
  x -= 57
  self~createPushButton("PROPSHEET.NEXT", x, y, 50, 14, "DEFAULT", "&Next >", "WIZARDNEXT")
  self~createPushButton("PROPSHEET.FINISH", x, y, 50, 14, "HIDDEN", "Finish", "WIZARDFINISH")
  self~createPushButton("PROPSHEET.BACK", x - 50, y, 50, 14, , "< &Back", "WIZARDBACK")
  self~form~AcceptButton = self~control("PROPSHEET.NEXT")
::method initDialog
  expose tabs cur wizard
  start = max(1, min(self~startPage, self~pages~items))
  if wizard then do
    self~setWizButtons("NEXT")
    self~activate(start)
    return
  end
  tabs~SelectedIndex = start - 1
  if cur \= start then self~activate(start)   -- (no Selected event before the window exists)
::method activate private
  expose cur wizard panels headerBox titleLabel subtitleLabel headerPicture
  use arg i
  if wizard then do
    if cur > 0 then panels[cur]~Visible = .false
    p = self~pages[i]
    if p~headerTitle == "" then do
      headerBox~Visible = .false
      if self~watermark \== .nil then do
        panels[i]~BackgroundImage = self~watermark
        panels[i]~BackgroundImageLayout = "None"
      end
    end
    else do
      titleLabel~Text = p~headerTitle
      subtitleLabel~Text = p~headerSubtitle
      if self~header \== .nil then headerPicture~Image = self~header
      headerBox~Visible = .true
      headerBox~BringToFront
    end
    panels[i]~Visible = .true
    panels[i]~BringToFront
  end
  cur = i
  p = self~pages[i]
  p~buildPage
  p~setActive(self)
/* a wizard's buttons: setWizButtons(words): BACK, NEXT, FINISH,
   DISABLEDFINISH; pressButton(BACK | NEXT | FINISH | CANCEL); a page's
   wizBack / wizNext answer 0 (on), -1 (stay) or the page number to go to,
   its wizFinish 0 (end) or else (stay) */
::method setWizButtons unguarded
  use strict arg opts
  opts = opts~upper
  self~control("PROPSHEET.BACK")~Enabled = opts~wordPos("BACK") > 0
  finishing = opts~wordPos("FINISH") > 0 | opts~wordPos("DISABLEDFINISH") > 0
  next = self~control("PROPSHEET.NEXT"); finish = self~control("PROPSHEET.FINISH")
  next~Visible = \finishing
  next~Enabled = opts~wordPos("NEXT") > 0
  finish~Visible = finishing
  finish~Enabled = opts~wordPos("FINISH") > 0
  self~form~AcceptButton = finishing~?(finish, next)
  return .true
::method pressButton unguarded
  use strict arg button
  select case button~upper
    when "BACK" then self~wizardBack
    when "NEXT" then self~wizardNext
    when "FINISH" then self~wizardFinish
    when "CANCEL" then self~cancel
    when "OK" then self~ok
    otherwise nop
  end
  return .true
::method wizardBack unguarded
  expose cur
  if \self~control("PROPSHEET.BACK")~Enabled then return 0
  r = self~pages[cur]~wizBack(self)
  self~wizardGo(r, cur - 1)
  return 0
::method wizardNext unguarded
  expose cur
  if \self~control("PROPSHEET.NEXT")~Enabled then return 0
  r = self~pages[cur]~wizNext(self)
  self~wizardGo(r, cur + 1)
  return 0
::method wizardGo private
  expose cur
  use arg r, default
  if r = -1 then return                -- (the page stays)
  if self~pages[cur]~killActive(self) == .false then return
  to = default
  if datatype(r, "W"), r > 0 then to = r
  if to < 1 | to > self~pages~items then return
  self~activate(to)
::method wizardFinish unguarded
  expose cur outcome
  r = self~pages[cur]~wizFinish(self)
  if r \= 0 then return 0
  self~applyAll
  outcome = "CLOSEDOK"
  self~endDialog(1)
  return 0
/* querySiblings(arg1, arg2): each page made so far gets
   queryFromSibling(arg1, arg2, propSheet), until one answers other than 0 */
::method querySiblings unguarded
  use arg arg1, arg2
  do p over self~pages
    if \p~wasActivated then iterate
    r = p~queryFromSibling(arg1, arg2, self)
    if r \= 0 then return r
  end
  return 0
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
  expose tabs wizard
  use arg hPage, index
  if wizard then self~activate(index)
  else tabs~SelectedIndex = index - 1
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
  expose cur outcome wizard
  if wizard then return self~wizardNext   -- (Enter: the default button)
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

/* --------------------------------------------------------- control dialogs */
/* ooDialog's ControlDialog: a dialog inside another one (its ownerDialog),
   a page of a tab control's display area, say. A NetDialog that inherits
   ControlDialog (ooDialog's RcControlDialog, ResControlDialog and
   UserControlDialog: "subclass ... inherit ControlDialog") shows its
   controls in a Panel of its owner, once execute is sent (its owner shown,
   or about to be): defineDialog, initDialog, as any dialog, at the place
   create gave it, in the owner's coordinates; show, hide, setWindowPos (to
   a NetRect: left, top, width, height), hwnd, isDialogActive,
   endExecution(ok) (leaving runs). It cannot end by itself: its owner ends.
   The panel is its form; self~form~Parent the owner's. */
::class ControlDialog public mixinclass Object
::method controlDialogExecute unguarded   -- (NetDialog's execute: no show or icon, it is inside its owner)
  expose started
  if var("STARTED") then return 0
  owner = self~ownerDialog
  if owner == .nil then raise syntax 98.900 array("ControlDialog: ownerDialog first")
  panel = .net~System~Windows~Forms~Panel~new
  x = self~form~Location~X; y = self~form~Location~Y   -- (where create put it)
  self~hostIn(panel)
  panel~Bounds = .net~System~Drawing~Rectangle~new(x, y, self~px(self~sizeX), self~py(self~sizeY))
  owner~form~Controls~Add(panel)
  panel~BringToFront
  started = .true
  owner~controlDialogs~append(self)    -- (for its ResizingAdmin's pagedTab)
  self~buildPage
  return 0
::method controlDialogActive unguarded    -- (NetDialog's isDialogActive)
  expose started
  if \var("STARTED") then return .false
  return \self~form~IsDisposed
::method controlDialogShow unguarded    -- (NetDialog's show and hide, for a control dialog: its panel)
  self~form~Visible = .true
  self~form~BringToFront
  return 0
::method controlDialogHide unguarded
  self~form~Visible = .false
  return 0
::method setWindowPos unguarded        -- setWindowPos(hwndAfter, rect [, flags]): rect's left, top, right (the width), bottom (the height)
  use arg after, r, flags = ""
  self~form~Bounds = .net~System~Drawing~Rectangle~new(r~left, r~top, r~right, r~bottom)
  if flags~upper~wordPos("HIDEWINDOW") > 0 then self~form~Visible = .false
  else do
    self~form~Visible = .true
    self~form~BringToFront             -- (above the tab control: hwndAfter's place)
  end
  return 0
::method endExecution unguarded
  expose ended
  use arg ok = .false
  if var("ENDED") then return 0
  ended = .true
  self~leaving
  return 0
::method pageTitle                     -- its tab's text, from its ControlDlgInfo (a managed page)
  if self~exArgs~isA(.ControlDlgInfo) then return self~exArgs~title
  return self~title
::method isManaged
  if \self~exArgs~isA(.ControlDlgInfo) then return .false
  return self~exArgs~managed == .true
::method tabPageSetActive unguarded    -- (to override) 0: the page may show; or the number of another page to show instead
  use arg owner, tab
  return 0
::method tabPageKillActive unguarded   -- (to override) .false: stay on this page
  use arg owner, tab
  return .true

/* ooDialog's TabOwnerDialog: a dialog whose tab controls show control
   dialogs as their pages, a ManagedTab for each, given to new in a
   TabOwnerDlgInfo. Each page (a ControlDialog with a ControlDlgInfo: its
   title is the tab's text) is made the first time its tab is chosen, and
   placed over the tab control's display area; the page that goes is asked
   tabPageKillActive(owner, tab) and the one that comes tabPageSetActive(owner,
   tab) (the owner's tabOwnerKillActive / tabOwnerSetActive(page, tab) instead,
   when the ManagedTab's options say KILLACTIVE / SETACTIVE); with SELCHANGE
   the owner's tabOwnerSelChange(page, pageNumber) follows a change.     */
::class TabOwnerDialog public mixinclass Object
::method tabOwnerSetup                 -- (inside) once the controls exist, before initDialog
  expose managed
  managed = .array~new
  info = self~exArgs
  if \info~isA(.TabOwnerDlgInfo) then raise syntax 98.900 array("TabOwnerDialog: new needs a TabOwnerDlgInfo")
  do mt over info~tabs
    managed~append(.NetManagedTab~new(self, self~control(mt~tabID), mt))
  end
::method getTabPage                    -- getTabPage(tabID, index): the page dialog (index from 1)
  expose managed
  use strict arg tabID, index
  do m over managed
    if NetDialogKey(m~tabID) == NetDialogKey(tabID) then return m~pages[index]
  end
  return .nil
::method tabOwnerOk unguarded
  expose managed
  do m over managed; do p over m~pages; p~endExecution(.true); end; end
  return 0
::method tabOwnerCancel unguarded
  expose managed
  do m over managed; do p over m~pages; p~endExecution(.false); end; end
  return 0
::method tabOwnerKillActive unguarded  -- (to override)
  use arg pageDlg, tab
  return .true
::method tabOwnerSetActive unguarded   -- (to override)
  use arg pageDlg, tab
  return 0
::method tabOwnerSelChange unguarded   -- (to override)
  use arg pageDlg, pageNumber
  return 0
::method tabOwnerSelChanging unguarded -- (to override)
  use arg pageDlg, pageNumber
  return 0

::class TabOwnerDlgInfo public          -- new(managedTab | Array of them); add(managedTab)
::attribute tabs get
::method init
  expose tabs
  use arg mts = .nil
  tabs = .array~new
  if mts~isA(.array) then do m over mts; tabs~append(m); end
  else if mts \== .nil then tabs~append(mts)
::method add
  expose tabs
  use strict arg mt
  tabs~append(mt)
  return 0
::method copy
  expose tabs
  c = .TabOwnerDlgInfo~new(tabs~copy)
  return c

::class ManagedTab public               -- new(tabID, pages [, opts]): opts SELCHANGE SELCHANGING SETACTIVE KILLACTIVE
::attribute tabID get
::attribute pages get
::attribute opts get
::attribute startPage
::method init
  expose tabID pages opts
  use strict arg tabID, pages, opts = "", startPage = 1
  opts = opts~upper
  self~startPage = startPage

::class ControlDlgInfo public           -- new([owner [, managed [, title [, size]]]]): a control dialog's extra arguments
::attribute owner
::attribute managed
::attribute title
::attribute size
::method init
  use arg owner = .nil, managed = .false, title = "", size = .nil
  self~owner = owner; self~managed = managed; self~title = title; self~size = size
::method copy
  return .ControlDlgInfo~new(self~owner, self~managed, self~title, self~size)

::class NetManagedTab                   -- (inside) a TabOwnerDialog's managed tab control
::attribute tabID get
::attribute pages get
::method init
  expose owner tc mt pages showing tabID
  use strict arg owner, tc, mt
  tabID = mt~tabID
  pages = mt~pages
  do p over pages
    tc~TabPages~Add(p~pageTitle)
    p~ownerDialog = owner
  end
  showing = 0
  tc~SelectedIndexChanged += .net~handler(self, "SELCHANGE")
  tc~Selecting += .net~handler(self, "SELECTING")
  tc~SizeChanged += .net~handler(self, "PLACE")
  start = max(1, min(mt~startPage, pages~items))
  self~bring(start)
  showing = start
  if start > 1 then tc~SelectedIndex = start - 1
::method bring private                  -- page i made, if it is not yet, and placed over the display area
  expose owner tc pages
  use arg i
  p = pages[i]
  p~execute
  self~placePage(p)
::method placePage private
  expose tc
  use arg p
  r = tc~DisplayRectangle
  p~form~Bounds = .net~System~Drawing~Rectangle~new(tc~Left + r~X, tc~Top + r~Y, r~Width, r~Height)
::method place                          -- the tab control's size changed: the page follows
  expose pages showing
  if showing > 0 then self~placePage(pages[showing])
::method selecting
  expose owner tc mt pages showing
  use arg sender, e
  if showing = 0 then return
  p = pages[showing]
  if mt~opts~wordPos("KILLACTIVE") > 0 then ok = owner~tabOwnerKillActive(p, tc)
  else ok = p~tabPageKillActive(owner, tc)
  if ok == .false then e~Cancel = .true
  else if mt~opts~wordPos("SELCHANGING") > 0 then owner~tabOwnerSelChanging(p, showing)
::method selChange
  expose owner tc mt pages showing
  use arg sender, e
  cur = tc~SelectedIndex + 1
  if cur < 1 | cur = showing then return
  new = pages[cur]
  self~bring(cur)
  if mt~opts~wordPos("SETACTIVE") > 0 then other = owner~tabOwnerSetActive(new, tc)
  else other = new~tabPageSetActive(owner, tc)
  if \datatype(other, "W") then other = 0
  if other \= 0, other \= cur then do  -- another page instead
    tc~SelectedIndex = other - 1
    return
  end
  if showing > 0 then pages[showing]~hide
  new~show
  showing = cur
  if mt~opts~wordPos("SELCHANGE") > 0 then owner~tabOwnerSelChange(new, cur)
::method showing                        -- (inside) the page number shown
  expose showing
  return showing

/* ooDialog's UserPSPDialog: a property sheet's page laid out in code, its
   size given later by setSize(size) (dialog units, in the default font):
   new([dlgData [, hFile [, options [, title]]]]) */
::class UserPSPDialog subclass NetDialog public
::attribute pageTitle
::method init
  use arg dlgData, hFile, options = "", title = ""
  self~init:super
  self~pageTitle = title
::method setSize
  use strict arg size
  self~create(0, 0, size~width, size~height, self~pageTitle)
  return 0

/* ooDialog's .Size (width, height) */
::class NetSize public
::attribute width
::attribute height
::method init
  expose width height
  use arg width = 0, height = 0

/* ooDialog's TimedMessage class: new(message, title, duration
   [, earlyReply]), execute */
::class TimedMessage public
::method init
  expose message title duration earlyReply pos
  use arg message, title, duration, earlyReply = .false, pos = .nil
::method execute
  expose message title duration earlyReply pos
  return timedMessage(message, title, duration, earlyReply, pos)

/* ----------------------------------------------------------------- resizing */
/* ooDialog's ResizingAdmin: a NetDialog that inherits it can be sized by the
   user, and its controls follow as its defineSizing says, with ooDialog's
   methods and meaning (oodResizableDialog.cpp's arithmetic). Each edge of a
   control is pinned to an edge of the dialog, or of a control named before
   it (its pinToID): STATIONARY keeps its distance to that edge, PROPORTIONAL
   moves as that window's size changes, MYLEFT (a right edge) and MYTOP (a
   bottom one) keep the control's own width and height. Every edge is
   PROPORTIONAL to the dialog unless defineSizing says otherwise (the
   defaults, defaultLeft... or defaultSizing, are copied to a control when
   it is first named, and to the ones never named). The dialog cannot be
   made smaller than it starts (minSize, noMinSize; maxSize). ooDialog adds
   WS_THICKFRAME: a sizing border. wantSizeEnded([method]): method (default
   onSizeEnded) once the user lets go. Controls inside others (a ListView's
   edit control, radio buttons in a group box) move with their parent.     */
::class ResizingAdmin public mixinclass Object
::constant IDC_DEFAULT_PINTO_WINDOW 0   -- a pin's pinTo: the dialog (as omitting it)
::method defineSizing                  -- (to override) the pins: defaultLeft..., controlLeft..., controlSizing...
  return 0
::method raState private
  expose defEdges order edges minSize maxSize sizeEnded pagedTabs
  if \var("ORDER") then do
    pagedTabs = .array~new             -- the tab controls' keys whose display area the control dialogs fill
    defEdges = .directory~new
    do side over .array~of("LEFT", "TOP", "RIGHT", "BOTTOM")
      defEdges[side] = .array~of("PROPORTIONAL", side, .nil)
    end
    order = .array~new                 -- the controls' keys, in the order they were named
    edges = .directory~new             -- key -> Directory of LEFT TOP RIGHT BOTTOM -> (how, edge, pinTo)
    minSize = "INITIAL"; maxSize = .nil; sizeEnded = .nil
  end
::method raPin private      -- (how, edge, pinTo) checked, for side
  expose order
  use strict arg side, how, edge, pinTo, ctrlKey = .nil
  how = how~upper; edge = edge~upper
  ok = wordPos(how, "STATIONARY PROPORTIONAL") > 0 | (how == "MYLEFT" & side == "RIGHT") | (how == "MYTOP" & side == "BOTTOM")
  if \ok then raise syntax 93.900 array("ResizingAdmin: the" side~lower "edge cannot be pinned" how)
  if wordPos(edge, "LEFT TOP RIGHT BOTTOM XCENTER YCENTER") = 0 then raise syntax 93.900 array("ResizingAdmin: no edge" edge)
  if pinTo == 0 then pinTo = .nil      -- (IDC_DEFAULT_PINTO_WINDOW: the dialog)
  if pinTo \== .nil then do            -- a control named before this one (ooDialog's rule)
    k = NetDialogKey(pinTo)
    p = order~index(k)
    bad = p == .nil                    -- (Rexx's | evaluates both sides)
    if \bad, ctrlKey \== .nil then do
      q = order~index(ctrlKey)
      if q \== .nil then bad = p > q
    end
    if bad then raise syntax 93.900 array("ResizingAdmin: pinToID" pinTo "is not a control named before" ctrlKey)
    pinTo = k
  end
  return .array~of(how, edge, pinTo)
::method raEntry private    -- a control's edges, made from the defaults the first time
  expose defEdges order edges
  use strict arg id
  self~raState
  k = NetDialogKey(id)
  if \edges~hasIndex(k) then do
    e = .directory~new
    do side over defEdges~allIndexes; e[side] = defEdges[side]; end
    edges[k] = e
    order~append(k)
  end
  return edges[k]
::method defaultSide private
  expose defEdges
  use arg side, how, edge, pinTo = .nil
  self~raState
  defEdges[side] = self~raPin(side, how, edge, pinTo)
  return 0
::method defaultLeft;   use arg how, edge, pinTo = .nil; return self~defaultSide("LEFT", how, edge, pinTo)
::method defaultTop;    use arg how, edge, pinTo = .nil; return self~defaultSide("TOP", how, edge, pinTo)
::method defaultRight;  use arg how, edge, pinTo = .nil; return self~defaultSide("RIGHT", how, edge, pinTo)
::method defaultBottom; use arg how, edge, pinTo = .nil; return self~defaultSide("BOTTOM", how, edge, pinTo)
::method defaultSizing                 -- defaultSizing([left [, top [, right [, bottom]]]]): Arrays (how, edge [, pinTo])
  sides = .array~of("LEFT", "TOP", "RIGHT", "BOTTOM")
  do i = 1 to 4
    if arg(i, "E") then self~defaultSide(sides[i], arg(i)[1], arg(i)[2], arg(i)[3])
  end
  return 0
::method controlSide private
  use arg side, id, how, edge, pinTo = .nil
  e = self~raEntry(id)
  e[side] = self~raPin(side, how, edge, pinTo, NetDialogKey(id))
  return 0
::method controlLeft;   use arg id, how, edge, pinTo = .nil; return self~controlSide("LEFT", id, how, edge, pinTo)
::method controlTop;    use arg id, how, edge, pinTo = .nil; return self~controlSide("TOP", id, how, edge, pinTo)
::method controlRight;  use arg id, how, edge, pinTo = .nil; return self~controlSide("RIGHT", id, how, edge, pinTo)
::method controlBottom; use arg id, how, edge, pinTo = .nil; return self~controlSide("BOTTOM", id, how, edge, pinTo)
::method controlSizing                 -- controlSizing(id [, left [, top [, right [, bottom]]]])
  use arg id
  self~raEntry(id)
  sides = .array~of("LEFT", "TOP", "RIGHT", "BOTTOM")
  do i = 1 to 4
    if arg(i + 1, "E") then self~controlSide(sides[i], id, arg(i + 1)[1], arg(i + 1)[2], arg(i + 1)[3])
  end
  return 0
::method useDefaultSizing              -- the control's edges back to the defaults
  expose defEdges edges
  use strict arg id
  e = self~raEntry(id)
  do side over defEdges~allIndexes; e[side] = defEdges[side]; end
  return 0
::method minSize                       -- in pixels, the dialog's whole window (.nil: none)
  expose minSize
  self~raState
  if minSize == "INITIAL" then return .nil
  return minSize
::method "MINSIZE="                    -- anything with width and height (ooDialog's .Size), or a .NET Size
  expose minSize
  use strict arg size
  self~raState
  minSize = .net~System~Drawing~Size~new(size~width, size~height)
::method noMinSize
  expose minSize
  self~raState
  minSize = .nil
  return 0
::method maxSize
  expose maxSize
  self~raState
  return maxSize
::method "MAXSIZE="
  expose maxSize
  use strict arg size
  self~raState
  maxSize = .net~System~Drawing~Size~new(size~width, size~height)
::method noMaxSize
  expose maxSize
  self~raState
  maxSize = .nil
  return 0
/* pagedTab(tabID, dlgIDs): ooDialog's, for control dialogs used as a tab
   control's pages: as the dialog is resized, they are sized to the tab
   control's display area. (Here: the control dialogs started in this dialog;
   dlgIDs, ooDialog's dlgID attributes, are not looked at.) */
::method pagedTab
  expose pagedTabs
  use strict arg tabID, dlgIDs = .nil
  self~raState
  pagedTabs~append(NetDialogKey(tabID))
  return 0
::method wantSizeEnded
  expose sizeEnded
  use arg methodName = "onSizeEnded"
  self~raState
  sizeEnded = methodName
  return 0
::method raSetup private    -- (inside) once the controls exist and initDialog has run
  expose order edges defEdges rects menuH minSize maxSize sizeEnded
  self~raState
  self~defineSizing
  f = self~form
  page = \.net~isInstance(f, "System.Windows.Forms.Form")   -- (a property sheet's page: its tab page)
  if \page then do
    cs = f~ClientSize
    f~FormBorderStyle = "Sizable"       -- (ooDialog: WS_THICKFRAME)
    f~ClientSize = cs                   -- (the client area kept)
  end
  menuH = 0
  if \page then if f~MainMenuStrip \== .nil then menuH = f~MainMenuStrip~Height
  rects = .directory~new                -- key -> .array(control, original l t r b, current l t r b)
  i = 0
  do c over f~Controls~makeArray        -- every control of the dialog itself, in the dialog's order
    if c~Dock~string \== "None" then iterate   -- (a menu bar)
    k = NetDialogKey(c~Name)
    if k == "" | rects~hasIndex(k) then do; i += 1; k = "RESIZINGADMIN."i; end
    if \edges~hasIndex(k) then do      -- not named in defineSizing: the defaults
      e = .directory~new
      do side over defEdges~allIndexes; e[side] = defEdges[side]; end
      edges[k] = e
      order~append(k)
    end
    b = c~Bounds
    o = .array~of(b~Left, b~Top, b~Right, b~Bottom)
    rects[k] = .array~of(c, o, o~copy)
  end
  if page then do                       -- (the page as it was designed: the tab page's size comes later)
    rects["RESIZINGADMIN.DIALOG"] = .array~of(.nil, .array~of(0, 0, self~px(self~sizeX), self~py(self~sizeY)), .nil)
    f~Resize += .net~handler(self, "RARESIZE")
    if f~ClientSize~Width > 0, f~ClientSize~Height > 0 then self~raResize(f, .nil)
    return
  end
  rects["RESIZINGADMIN.DIALOG"] = .array~of(.nil, .array~of(0, menuH, f~ClientSize~Width, f~ClientSize~Height), .nil)
  if minSize == "INITIAL" then f~MinimumSize = f~Size
  else if minSize \== .nil then f~MinimumSize = minSize
  if maxSize \== .nil then f~MaximumSize = maxSize
  f~Resize += .net~handler(self, "RARESIZE")
  if sizeEnded \== .nil then f~ResizeEnd += .net~handler(self, sizeEnded)
::method raResize unguarded
  expose order edges rects menuH pagedTabs
  use arg f, e
  if .net~isInstance(f, "System.Windows.Forms.Form") then if f~WindowState~string == "Minimized" then return
  if f~ClientSize~Width = 0 | f~ClientSize~Height = 0 then return
  dlg = rects["RESIZINGADMIN.DIALOG"]
  dlg[3] = .array~of(0, menuH, f~ClientSize~Width, f~ClientSize~Height)
  f~SuspendLayout
  do k over order
    r = rects[k]
    if r == .nil then iterate          -- (named, but not a control of the dialog itself)
    pins = edges[k]; o = r[2]; cur = r[3]
    cur[1] = ResizingAdminEdge(1, pins["LEFT"], o, cur, rects)
    cur[2] = ResizingAdminEdge(2, pins["TOP"], o, cur, rects)
    cur[3] = ResizingAdminEdge(3, pins["RIGHT"], o, cur, rects)
    cur[4] = ResizingAdminEdge(4, pins["BOTTOM"], o, cur, rects)
    r[1]~Bounds = .net~System~Drawing~Rectangle~new(cur[1], cur[2], cur[3] - cur[1], cur[4] - cur[2])
  end
  do k over pagedTabs                  -- the pages over the tab controls' display areas
    if \rects~hasIndex(k) then iterate
    tc = rects[k][1]; dr = tc~DisplayRectangle
    area = .net~System~Drawing~Rectangle~new(tc~Left + dr~X, tc~Top + dr~Y, dr~Width, dr~Height)
    do d over self~controlDialogs; d~form~Bounds = area; end
  end
  f~ResumeLayout
  return 0

/* (inside) one edge's new coordinate: side 1 left, 2 top, 3 right, 4 bottom;
   pin (how, edge, pinTo); o and cur the control's original and current
   rectangles (left top right bottom) */
::routine ResizingAdminEdge
  use arg side, pin, o, cur, rects
  how = pin[1]
  if how == "MYLEFT" then return cur[1] + (o[3] - o[1])
  if how == "MYTOP" then return cur[2] + (o[4] - o[2])
  key = pin[3]                         -- (the dialog, or a control: the dialog if it is not one of the dialog's own)
  if key == .nil then key = "RESIZINGADMIN.DIALOG"
  else if \rects~hasIndex(key) then key = "RESIZINGADMIN.DIALOG"
  t = rects[key]
  tOld = t[2]; tNow = t[3]
  if how == "STATIONARY" then
    return o[side] - ResizingAdminCoord(pin[2], tOld) + ResizingAdminCoord(pin[2], tNow)
  -- PROPORTIONAL: the pinned-to window's size across (left, right) or down (top, bottom)
  if side // 2 = 1 then do; oldSize = tOld[3] - tOld[1]; newSize = tNow[3] - tNow[1]; end
  else do; oldSize = tOld[4] - tOld[2]; newSize = tNow[4] - tNow[2]; end
  if oldSize = 0 then return o[side]
  return tNow[side] + trunc((o[side] - tOld[side]) * newSize / oldSize)
::routine ResizingAdminCoord
  use arg edge, r
  select case edge
    when "LEFT" then return r[1]
    when "TOP" then return r[2]
    when "RIGHT" then return r[3]
    when "BOTTOM" then return r[4]
    when "XCENTER" then return (r[1] + r[3]) % 2
    otherwise return (r[2] + r[4]) % 2
  end

/* --------------------------------------------------------- dialog areas */
/* ooDialog's DlgArea: an area of a dialog, in dialog units, to place
   controls in: new(left, top, width, height [, margin]); x([offset]) and
   y([offset]) inside the margin, an offset of whole numbers (negative: from
   the right or bottom) or a percentage ("70%"); w([pc]) and h([pc]), the
   width and height inside the margin, or a percentage of them, or "R": what
   is left after the last x or y (wr, hr); l t r b, the edges inside the
   margin. The same arithmetic as ooDialog's (written anew here). */
::class DlgArea public
::attribute t
::attribute l
::attribute b
::attribute r
::attribute top
::attribute left
::attribute width
::attribute height
::attribute margin
::method init
  expose lastX lastY
  use arg left, top, width, height, margin
  self~top = DlgAreaNum(top, 10)
  self~left = DlgAreaNum(left, 10)
  self~width = DlgAreaNum(width, 100)
  self~height = DlgAreaNum(height, 100)
  if datatype(margin, "N") then self~margin = trunc(margin)
  else self~margin = max(min(self~height % 7, 5), 1)
  self~t = self~top + self~margin
  self~l = self~left + self~margin
  self~b = self~top + self~height - self~margin
  self~r = self~left + self~width - self~margin
  lastX = 0; lastY = 0
::method x
  expose lastX
  use arg offset = ""
  lastX = "0" || offset
  return DlgAreaPos(offset, self~left, self~width, self~margin, self~w)
::method y
  expose lastY
  use arg offset = ""
  lastY = "0" || offset
  return DlgAreaPos(offset, self~top, self~height, self~margin, self~h)
::method w
  use arg pc = ""
  if pc~upper == "R" then return self~wr
  w = self~width - 2 * self~margin
  if pc~pos("%") > 0 then return trunc(w * pc~changeStr("%", "") / 100)
  return w
::method h
  use arg pc = ""
  if pc~upper == "R" then return self~hr
  h = self~height - 2 * self~margin
  if pc~pos("%") > 0 then return trunc(h * pc~changeStr("%", "") / 100)
  return trunc(h)
::method wr                            -- the width left, after the last x
  expose lastX
  if lastX~pos("%") = 0 then return self~left + self~width - self~margin - lastX
  return self~w(100 - lastX~changeStr("%", "") || "%")
::method hr                            -- the height left, after the last y
  expose lastY
  if lastY~pos("%") = 0 then return self~top + self~height - self~margin - lastY
  return self~h(100 - lastY~changeStr("%", "") || "%")
::method cx;    return self~w(arg(1))
::method cy;    return self~h(arg(1))
::method sizeX; return self~width
::method sizeY; return self~height

::routine DlgAreaNum                   -- (inside) a whole number, or the default
  use arg n, default
  if datatype(n, "N") then return trunc(n)
  return default
::routine DlgAreaPos                   -- (inside) x or y: offset from the edge, within the margin
  use arg offset, start, size, margin, inner
  if offset~pos("%") > 0 then do
    pc = offset~changeStr("%", "")
    if \datatype(pc, "N") then return start + margin
    if pc < 0 then pc = 100 + pc       -- (from the right or bottom)
    return trunc(start + margin + inner * pc / 100)
  end
  if \datatype(offset, "N") then return start + margin
  if offset >= 0 then return trunc(start + margin + offset)
  return trunc(start + size - margin + offset)

/* ooDialog's DlgAreaU: the whole dialog as a DlgArea, new(dialog [, margin
   [, noResize [, noMove]]]), which also resizes the dialog's controls:
   resize(dialog, sizeInfo), from connectResize's method, scales each
   control's original position and size as the dialog's client area has
   grown (noResizePut(id), noMovePut(id): controls whose size, or position,
   stays). ooDialog reads defineDialog's source to know the controls'
   original rectangles; here they are the controls' own, as they were made.
   correctionFactor is 1 here (ooDialog's 1.05 makes up for the rounding of
   its sizes in dialog units: this is in pixels); updateOnResize: .false
   leaves the redrawing to the program (redrawClient). */
::class DlgAreaU subclass DlgArea public
::attribute noResize
::attribute noMove
::attribute correctionFactor
::attribute lastError
::attribute updateOnResize
::method init
  expose dlg original
  use arg dlg, margin = 5, noResize = .nil, noMove = .nil
  if \datatype(margin, "N") then margin = 5
  self~init:super(0, 0, dlg~sizeX, dlg~sizeY, margin)
  self~noResize = .set~new
  self~noMove = .set~new
  if noResize~isA(.collection) then do id over noResize; self~noResizePut(id); end
  if noMove~isA(.collection) then do id over noMove; self~noMovePut(id); end
  self~correctionFactor = 1
  self~lastError = .nil
  self~updateOnResize = .true
  original = .nil
::method noResizePut
  use strict arg id
  self~noResize~put(NetDialogKey(id))
  return 0
::method noMovePut
  use strict arg id
  self~noMove~put(NetDialogKey(id))
  return 0
::method resize
  expose original origW origH
  use arg dialog, sizeInfo
  f = dialog~form
  if original == .nil then do          -- the controls as defineDialog made them
    original = .array~new
    do c over f~Controls~makeArray
      if c~Dock~string \== "None" then iterate   -- (a menu bar)
      original~append(.array~of(c, c~Bounds, NetDialogKey(c~Name)))
    end
    origW = dialog~px(self~width); origH = dialog~py(self~height)
  end
  w = sizeInfo // 65536; h = sizeInfo % 65536
  if w = 0 | h = 0 then return 0       -- (minimized)
  fx = w / origW * self~correctionFactor
  fy = h / origH * self~correctionFactor
  f~SuspendLayout
  do o over original
    c = o[1]; b = o[2]
    x = b~X; y = b~Y; cw = b~Width; ch = b~Height
    if \self~noResize~hasIndex(o[3]) then do; cw = trunc(cw * fx); ch = trunc(ch * fy); end
    if \self~noMove~hasIndex(o[3]) then do; x = trunc(x * fx); y = trunc(y * fy); end
    c~Bounds = .net~System~Drawing~Rectangle~new(x, y, cw, ch)
  end
  f~ResumeLayout
  if self~updateOnResize then dialog~update
  return 0

/* ooDialog's .Rect: left, top, right, bottom */
::class NetRect public
::attribute left
::attribute top
::attribute right
::attribute bottom
::method init
  expose left top right bottom
  use arg left = 0, top = 0, right = 0, bottom = 0

::class NetDialogResizeRelay           -- (inside) connectResize: (sizingType, sizeInfo)
::method init
  expose dialog methodName
  use arg dialog, methodName
::method resize
  expose dialog methodName
  use arg f, e
  select case f~WindowState~string
    when "Minimized" then type = 1
    when "Maximized" then type = 2
    otherwise type = 0
  end
  cs = f~ClientSize
  dialog~send(methodName, type, cs~Width + 65536 * cs~Height)

::class NetDialogSizeEndRelay          -- (inside) connectSizeMoveEnded
::method init
  expose dialog methodName
  use arg dialog, methodName
::method ended
  expose dialog methodName
  dialog~send(methodName)

/* (inside) connectResizing: a NativeWindow on the dialog's form, whose
   WndProc sees WM_SIZING (wParam the edge, lParam the window's RECT) */
::class NetDialogSizingHook subclass NetObject
::method prepare class                 -- (once, the first time it is needed: not when the package loads)
  expose extended
  if var("EXTENDED") then return
  .net~extend(self, "System.Windows.Forms.NativeWindow")
  extended = .true
::method init
  expose dialog methodName
  use strict arg dialog, methodName
  self~init:super
::method created                       -- the form's HandleCreated
  use arg f, e
  self~AssignHandle(.net~as(f~Handle, "System.IntPtr"))
::method WndProc
  expose dialog methodName
  use arg ref
  msg = ref~Value
  if msg~Msg = 532 then do             -- WM_SIZING (0x214)
    edges = "LEFT RIGHT TOP TOPLEFT TOPRIGHT BOTTOM BOTTOMLEFT BOTTOMRIGHT"
    k = msg~WParam
    if k >= 1, k <= 8 then do
      M = .net~System~Runtime~InteropServices~Marshal
      p = .net~as(msg~LParam, "System.IntPtr")
      r = .NetRect~new(M~ReadInt32(p, 0), M~ReadInt32(p, 4), M~ReadInt32(p, 8), M~ReadInt32(p, 12))
      if dialog~send(methodName, r, edges~word(k)) == .true then do
        M~WriteInt32(p, 0, .net~int32(r~left));  M~WriteInt32(p, 4, .net~int32(r~top))
        M~WriteInt32(p, 8, .net~int32(r~right)); M~WriteInt32(p, 12, .net~int32(r~bottom))
      end
    end
  end
  r = .net~ref(msg)
  self~base.WndProc(r)
  ref~Value = r~value

/* (inside) .NET controls with a window style their class has not
   (PBS_VERTICAL, TBS_ENABLESELRANGE): CreateParams overridden */
::class NetStyledProgressBar subclass NetObject
::method prepare class                 -- (once, the first time it is needed)
  expose extended
  if var("EXTENDED") then return
  .net~extend(self, "System.Windows.Forms.ProgressBar")
  extended = .true
::method init
  expose extra
  use strict arg extra
  self~init:super
::method CreateParams
  expose extra
  cp = self~CreateParams:super
  cp~Style = NetBitOr(cp~Style, extra)
  return cp
::class NetStyledTrackBar subclass NetObject
::method prepare class
  expose extended
  if var("EXTENDED") then return
  .net~extend(self, "System.Windows.Forms.TrackBar")
  extended = .true
::method init
  expose extra
  use strict arg extra
  self~init:super
::method CreateParams
  expose extra
  cp = self~CreateParams:super
  cp~Style = NetBitOr(cp~Style, extra)
  return cp
::routine NetBitOr                     -- (inside) a | b, for whole numbers (b's bits added where a has not got them)
  use arg a, b
  r = a; bit = 1; n = b
  do while n > 0
    if n // 2 = 1, (a % bit) // 2 = 0 then r += bit
    n = n % 2; bit *= 2
  end
  return r

/* (inside) ooDialog's DefListDragHandler on a .NET ListView: in an icon
   view, the item follows the pointer; Escape puts it back */
::class NetListDrag
::method init
  expose lv item origin dx dy
  use arg lv
  item = .nil
  lv~AllowDrop = .true
  lv~ItemDrag += .net~handler(self, "ITEMDRAG")
  lv~DragOver += .net~handler(self, "DRAGOVER")
  lv~DragDrop += .net~handler(self, "DRAGDROP")
::method itemDrag
  expose lv item origin dx dy
  use arg sender, e
  if wordPos(lv~View~string, "LargeIcon SmallIcon") = 0 then return   -- (items have places in the icon views only)
  item = e~Item
  origin = item~Position
  p = lv~PointToClient(.net~System~Windows~Forms~Control~MousePosition)
  dx = p~X - origin~X; dy = p~Y - origin~Y
  r = lv~DoDragDrop("ListViewItem", "Move")
  if r~string == "None" then item~Position = origin   -- (given up: back where it was)
  item = .nil
::method dragOver
  expose lv item dx dy
  use arg sender, e
  if item == .nil then do; e~Effect = "None"; return; end
  e~Effect = "Move"
  p = lv~PointToClient(.net~System~Drawing~Point~new(e~X, e~Y))
  item~Position = .net~System~Drawing~Point~new(max(0, p~X - dx), max(0, p~Y - dy))
::method dragDrop
  use arg sender, e

/* (inside) ooDialog's DefTreeDragHandler on a .NET TreeView */
::class NetTreeDrag
::method init
  expose tree dragged hover since
  use arg tree
  dragged = .nil; hover = .nil; since = 0
  tree~AllowDrop = .true
  tree~ItemDrag += .net~handler(self, "ITEMDRAG")
  tree~DragOver += .net~handler(self, "DRAGOVER")
  tree~DragDrop += .net~handler(self, "DRAGDROP")
  tree~DragLeave += .net~handler(self, "DRAGLEAVE")
::method itemDrag
  expose tree dragged
  use arg sender, e
  dragged = e~Item
  tree~SelectedNode = dragged
  tree~DoDragDrop("TreeNode", "Move")
  self~highlight(.nil)
  dragged = .nil
::method canDrop                       -- not on itself, its parent, or one of its children
  expose dragged
  use arg target
  if target == .nil | dragged == .nil then return .false
  if target~Equals(dragged) then return .false
  if dragged~Parent \== .nil then if target~Equals(dragged~Parent) then return .false
  p = target~Parent
  do while p \== .nil
    if p~Equals(dragged) then return .false
    p = p~Parent
  end
  return .true
::method dragOver
  expose tree hover since
  use arg sender, e
  p = tree~PointToClient(.net~System~Drawing~Point~new(e~X, e~Y))
  target = tree~GetNodeAt(p)
  if self~canDrop(target) then do
    e~Effect = "Move"
    if hover == .nil then new = .true
    else new = \hover~Equals(target)
    if new then do
      self~highlight(target)
      hover = target
      since = .net~System~Environment~TickCount
    end
    else if .net~System~Environment~TickCount - since > 1000, target~Nodes~Count > 0, \target~IsExpanded then target~Expand   -- (after a second)
  end
  else do
    e~Effect = "None"
    self~highlight(.nil)
    hover = .nil
  end
  h = tree~ItemHeight                  -- the tree scrolls when the pointer is at its edges
  if p~Y < h then do
    top = tree~TopNode
    if top \== .nil then if top~PrevVisibleNode \== .nil then top~PrevVisibleNode~EnsureVisible
  end
  else if p~Y > tree~ClientSize~Height - h then do
    n = tree~GetNodeAt(.net~System~Drawing~Point~new(1, tree~ClientSize~Height - 1))
    if n \== .nil then if n~NextVisibleNode \== .nil then n~NextVisibleNode~EnsureVisible
  end
::method dragDrop
  expose tree dragged
  use arg sender, e
  target = tree~GetNodeAt(tree~PointToClient(.net~System~Drawing~Point~new(e~X, e~Y)))
  self~highlight(.nil)
  if \self~canDrop(target) then return
  self~move(dragged, target)
::method move                          -- the item, with its children, as the target's last child
  expose tree
  use arg item, target
  item~Remove
  target~Nodes~Add(item)
  tree~SelectedNode = item
  item~EnsureVisible
::method dragLeave
  use arg sender, e
  self~highlight(.nil)
::method highlight private             -- TVM_SELECTITEM, TVGN_DROPHILITE: the drop target shown
  expose tree
  use arg node
  h = 0
  if node \== .nil then h = node~Handle
  call sendWinIntMsg tree, 4363, 8, h  -- (0x110B)

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

::class NetDialogHotRelay              -- (inside) HOTITEM: (id, entering) as ooDialog's
::method init
  expose dialog id methodName
  use arg dialog, id, methodName
::method enter
  expose dialog id methodName
  dialog~sendWith(methodName, .array~of(id, .true))
::method leave
  expose dialog id methodName
  dialog~sendWith(methodName, .array~of(id, .false))

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
::method incr                          -- incr([dx [, dy]]): moved (by 1, 1 if not given)
  expose x y
  use arg dx = 1, dy = (dx)
  x += dx; y += dy
  return self

::class NetDialogUserString            -- (inside) a DateTimePicker's USERSTRING
::method init
  expose dialog dtp id methodName box
  use arg dialog, dtp, id, methodName
  box = .nil
::method key                           -- F2 on the picker: the edit control over it
  expose dialog dtp box
  use arg sender, e
  if e~KeyCode~string \== "F2" then return
  e~Handled = .true
  if box == .nil then do
    box = .net~System~Windows~Forms~TextBox~new
    box~Font = dtp~Font
    box~AutoSize = .false
    dtp~Parent~Controls~Add(box)
    dialog~wantKeys(box)
    box~KeyDown += .net~handler(self, "BOXKEY")
    box~LostFocus += .net~handler(self, "BOXLEFT")
  end
  box~Bounds = dtp~Bounds
  box~Text = ""
  box~Visible = .true
  box~BringToFront
  box~Focus
::method boxKey
  use arg sender, e
  k = e~KeyCode~string
  if k == "Enter" then do; e~SuppressKeyPress = .true; self~done(.true); end
  else if k == "Escape" then do; e~SuppressKeyPress = .true; self~done(.false); end
::method boxLeft
  expose box
  use arg sender, e
  if box~Visible then self~done(.true)
::method done private
  expose dialog dtp id methodName box
  use arg accept
  text = box~Text~strip
  box~Visible = .false
  dtp~Focus
  if \accept | text == "" then return
  v = dtp~Value
  dt = .DateTime~new(v~Year, v~Month, v~Day, v~Hour, v~Minute, v~Second)
  r = dialog~send(methodName, dt, text, id, dtp~Handle)
  if \r~isA(.DateTime) then return
  if r~isoDate == dt~isoDate then return    -- (the same: the picker does nothing, as Windows')
  dtp~Value = .net~System~DateTime~new(r~year, r~month, r~day, r~hours, r~minutes, r~seconds)

::class NetDialogHelpRelay             -- (inside) connectHelp
::method init
  expose dialog methodName
  use arg dialog, methodName
::method help
  expose dialog methodName
  use arg sender, e
  e~Handled = .true
  dialog~send(methodName)

::class NetDialogKeyPress              -- (inside) connectKeyPress
::method init
  expose dialog methodName keys filter
  use arg dialog, methodName, keys, filter
  keys = keys~changeStr(",", " ")~space
  filter = filter~upper
::method keyDown
  expose dialog methodName keys filter
  use arg sender, e
  code = e~KeyValue; name = e~KeyCode~string
  hit = .false
  do k over keys~makeArray(" ")
    if k~pos("-") > 1 then do
      parse var k a "-" b
      if datatype(a, "W"), datatype(b, "W"), code >= a, code <= b then hit = .true
    end
    else if datatype(k, "W") then do; if k = code then hit = .true; end
    else if k~caselessEquals(name) then hit = .true
  end
  if \hit then return
  sh = e~Shift; ct = e~Control; al = e~Alt
  if filter \== "" then do
    if filter~wordPos("NONE") > 0 then do; if sh | ct | al then return; end
    else if filter~wordPos("AND") > 0 then do
      if filter~wordPos("SHIFT") > 0, \sh then return
      if filter~wordPos("CONTROL") > 0, \ct then return
      if filter~wordPos("ALT") > 0, \al then return
    end
    else do
      want = (filter~wordPos("SHIFT") > 0 & sh) | (filter~wordPos("CONTROL") > 0 & ct) | (filter~wordPos("ALT") > 0 & al)
      if \want then return
    end
  end
  e~Handled = .true
  dialog~send(methodName, code, sh, ct, al, "")

::class NetDialogInputKeys             -- (inside) wantKeys
::method init
  expose keys
  use arg keys
::method preview
  expose keys
  use arg ctl, e
  if wordPos(e~KeyCode~string, keys) > 0 then e~IsInputKey = .true

::class NetDialogDigitsOnly            -- (inside) an edit control's NUMBER style: only digits typed
::method keyPress
  use arg box, e
  c = e~KeyChar
  if c~c2d < 32 then return            -- (Backspace, Ctrl+C...)
  if \c~dataType("W") then e~Handled = .true

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
  if style~pos(",") > 0 then           -- (several: "Bold, Italic", .NET's flags, parsed by .NET)
    style = .net~System~Enum~Parse(D~FontStyle~Regular~GetType, style)
  return D~Font~new(face, .net~single(px), style, "Pixel")

/* (inside) a colour: a .NET Color, or ooDialog's index into Windows'
   default palette (PALETTEINDEX: its 20 colours) */
::routine NetDialogColor public       -- (public: a program's own drawing may want ooDialog's colours)
  use arg c
  if .net~isInstance(c, "System.Drawing.Color") then return c
  rgb = "0 0 0,128 0 0,0 128 0,128 128 0,0 0 128,128 0 128,0 128 128,192 192 192,192 220 192,166 202 240," || -
        "255 251 240,160 160 164,128 128 128,255 0 0,0 255 0,255 255 0,0 0 255,255 0 255,0 255 255,255 255 255"
  if \c~dataType("W") | c < 0 | c > 19 then c = 0
  parse value rgb~makeArray(",")[c + 1] with r g b
  return .net~System~Drawing~Color~FromArgb(r, g, b)

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
  else if .net~isInstance(c, "System.Windows.Forms.NumericUpDown") then do
    if v~dataType("N") then do         -- (a buddy holds any number: the range widened to take it)
      if v > c~Maximum then c~Maximum = v
      if v < c~Minimum then c~Minimum = v
    end
    c~Value = v
  end
  else if .net~isInstance(c, "System.Windows.Forms.ScrollBar") then c~Value = v
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
  if filter == .nil | filter == "" then filter = "All Files (*.*)" || "0"x || "*.*"
  save = load~upper == "SAVE" | load == 0       -- (as ooDialog's: anything else, "" too, opens)
  multi = multi == 1 | multi~upper == "MULTI"
  if sep == "" then sep = " "
  if NetDialogAuto("fileNameDialog:" title) then return 0
  F = .net~System~Windows~Forms
  dlg = save~?(F~SaveFileDialog~new, F~OpenFileDialog~new)
  dlg~Filter = filter~strip("T", "0"x)~changeStr("0"x, "|")
  if title \== "" then dlg~Title = title
  if defExt \== "" then dlg~DefaultExt = defExt
  if file \== "" then do
    if .net~System~IO~Directory~Exists(file) then dlg~InitialDirectory = file
    else dlg~FileName = file
  end
  if multi, \save then dlg~Multiselect = .true
  if dlg~ShowDialog~string \== "OK" then return 0
  if multi, \save, dlg~FileNames~Length > 1 then do   -- (one file: its name alone, as ooDialog's)
    names = dlg~FileNames
    r = .net~System~IO~Path~GetDirectoryName(names[1])   -- (a .NET array is a Rexx Array: from 1)
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
  if dlg~execute \= 1 then return ""      -- (cancelled: "", as ooDialog's)
  return dlg~answer

/* ooDialog's ProgressDialog: new([caption [, message [, min [, max [,
   step]]]]]), its attributes (msgText, msgHeight, noMsg, noStatus,
   marqueeMode, marqueePause, canCancel, incrStep, rangeMin, rangeMax,
   initialStatusText, width, absoluteWidth), begin, increase([n]),
   updateStatus(text), updateStatusText(text), complete, endNow,
   setInterruptible(worker): a Cancel button that interrupts the worker
   (an Alerter: its isCanceled turns .true). ooDialog runs it on a thread of
   its own; here it is modeless on this one (popup): increase, the status and
   complete let this thread's events run (Application.DoEvents), so that it
   paints and its Cancel button works while the program does its work. */
::class ProgressDialog subclass NetDialog public
::attribute absoluteWidth
::attribute canCancel
::attribute captionText
::attribute incrStep
::attribute initialStatusText
::attribute marqueeMode
::attribute marqueePause
::attribute msgHeight
::attribute msgText
::attribute noMsg
::attribute noStatus
::attribute rangeMax
::attribute rangeMin
::attribute width
::method init
  expose worker
  use strict arg capt = "Application Processing ...", msg = "Background processing is taking place.  Please be patient.", -
                 min = 0, max = 100, incr = 1
  self~init:super
  self~captionText = capt; self~msgText = msg
  self~rangeMin = min; self~rangeMax = max; self~incrStep = incr
  self~msgHeight = 1; self~noMsg = .false; self~noStatus = .false
  self~initialStatusText = "Status: "; self~absoluteWidth = .false; self~width = 91
  self~marqueePause = 100; self~marqueeMode = .false; self~canCancel = .false
  worker = .nil
::method begin
  expose cx cy
  self~createCenter(10, 10, self~captionText)       -- (the font first: the sizes are in its dialog units)
  self~calcSizes
  self~form~ClientSize = .net~System~Drawing~Size~new(self~px(cx), self~py(cy))
  self~popup
  self~pump
  return 0
::method calcSizes private
  expose cx cy lineHeight
  pad = 7
  if self~noMsg, self~noStatus then t = "Background processing is taking place.  Please be patient."
  else if \self~noMsg, self~msgHeight < 2 then t = self~msgText
  else t = "Background processing is taking place.  Please be patient."
  s = .net~System~Windows~Forms~TextRenderer~MeasureText(t, self~form~Font)
  bx = self~px(4000) / 1000; by = self~py(8000) / 1000
  lineHeight = (s~Height * 8 + by - 1) % by
  cy = pad
  if \self~noMsg then cy += lineHeight * self~msgHeight
  if \self~noStatus then cy += pad + lineHeight
  if cy > pad then cy += pad
  cy += lineHeight + pad
  if self~canCancel then cy += pad + 14
  if self~absoluteWidth then cx = self~width
  else cx = max((s~Width * 4 + bx - 1) % bx + 2 * pad, 91)
::method defineDialog
  expose cx cy lineHeight
  pad = 7
  w = cx - 2 * pad
  y = pad
  if \self~noMsg then do
    h = lineHeight * self~msgHeight
    self~createStaticText(IDC_ST_MSG, pad, y, w, h, , self~msgText)
    y += h + pad
  end
  if \self~noStatus then do
    self~createStaticText(IDC_ST_STATUS, pad, y, w, lineHeight, , "")
    y += lineHeight + pad
  end
  self~createProgressBar(IDC_PB_MAIN, pad, y, w, lineHeight, self~marqueeMode~?("SMOOTH MARQUEE", "SMOOTH"))
  y += lineHeight + pad
  if self~canCancel then self~createPushButton(IDCANCEL, cx - pad - 35, y, 35, 14, , "Cancel")
::method initDialog
  expose pb statusBar
  pb = self~newProgressBar(IDC_PB_MAIN)
  if self~marqueeMode then pb~MarqueeAnimationSpeed = self~marqueePause
  else do
    pb~Minimum = self~rangeMin; pb~Maximum = self~rangeMax; pb~Step = self~incrStep
    pb~PerformStep
  end
  if \self~noStatus then do
    statusBar = self~newStatic(IDC_ST_STATUS)
    statusBar~Text = self~initialStatusText
  end
::method increase unguarded
  expose pb
  use strict arg incr = (self~incrStep)
  if self~marqueeMode | \var("PB") then return
  pb~Increment(incr)
  self~pump
::method updateStatus unguarded
  use strict arg text
  self~doStatus("Status:" text)
::method updateStatusText unguarded
  use strict arg text
  self~doStatus(text)
::method doStatus unguarded private
  expose statusBar
  use strict arg text
  if self~noStatus | \var("STATUSBAR") then return
  statusBar~Text = text
  self~pump
::method complete unguarded
  expose pb
  if \var("PB") then return
  if self~marqueeMode then pb~Style = "Continuous"   -- (the marquee stops)
  else pb~Value = self~rangeMax
  self~pump
::method endNow unguarded
  self~endDialog(1)
  return 0
::method setInterruptible unguarded
  expose worker
  use strict arg worker
  self~canCancel = .true
::method ok unguarded                  -- (Enter does nothing)
::method cancel unguarded              -- Cancel, or the window's [x]: the worker is interrupted, the program ends the dialog
  expose worker
  if worker \== .nil then do
    if worker~interruptible then worker~interrupt
    return 0
  end
  if self~canCancel then return self~cancel:super
  return 0
::method pump private
  .net~System~Windows~Forms~Application~DoEvents

/* ooDialog's Alerter: a worker a ProgressDialog's Cancel interrupts */
::class Alerter public
::attribute isCanceled get
::method init
  expose isCanceled
  isCanceled = .false
::method interruptible unguarded
  return .true
::method interrupt unguarded
  expose isCanceled
  isCanceled = .true

/* ooDialog's SingleSelection class: new(message, title, entries. [, preSel [, len [, max]]]),
   execute: the number chosen, or "" (cancelled; unattended too) */
::class SingleSelection public
::method init
  expose message title labels preSel max
  use arg message, title, entries, preSel = 1, len = 0, max = 0
  labels = .array~new
  do i = 1 while entries~hasIndex(i)
    labels~append(entries[i])
  end
::method execute
  expose message title labels preSel max
  if NetDialogAuto("SingleSelection:" message) then return ""
  return singleSelection(message, title, labels, preSel, , max)
::method focusControl                  -- focusControl(id): (the preselected button has the focus already)
  return 0

/* ooDialog's other standard dialog classes, on the routines above: new as
   ooDialog's (a stem's entries from 1; CheckList's checks and MultiInputBox's
   values at 101, 102...), execute as ooDialog's. Unattended, CheckList and
   MultiInputBox answer 1 (OK) with what they were given. */
::class InputBox public                -- new(message, title [, default [, size]]): execute, the text ("": cancelled)
::method init
  expose message title default size
  use arg message, title = "", default = "", size = 100
::method kind                          -- (inside) NetDialogInput's kind
  return "TEXT"
::method execute
  expose message title default size
  if NetDialogAuto(self~class~id":" message) then return default
  return NetDialogAsk(message, title, default, size, self~kind)
::class PasswordBox public subclass InputBox
::method kind
  return "PASSWORD"
::class IntegerBox public subclass InputBox
::method kind
  return "INTEGER"

::class ListChoice public              -- new(message, title, entries. [, lenX [, lenY [, preSel]]]): the entry chosen ("": cancelled)
::method init
  expose message title items cx cy preSel
  use arg message, title, entries, cx = 150, cy = 80, preSel = ""
  if cx == "" then cx = 150
  if cy == "" then cy = 80
  items = NetDialogStemArray(entries, 1)
::method execute
  expose message title items cx cy preSel
  r = listChoice(message, title, items, cx, cy, preSel)
  if r == .nil then return ""
  return r
::class MultiListChoice public         -- the same: the numbers of the entries chosen ("1 3 4"; "": cancelled, or none)
::method init
  expose message title items cx cy preSel
  use arg message, title, entries, cx = 150, cy = 80, preSel = ""
  if cx == "" then cx = 150
  if cy == "" then cy = 80
  items = NetDialogStemArray(entries, 1)
::method execute
  expose message title items cx cy preSel
  if NetDialogAuto("MultiListChoice:" message) then return ""
  r = NetDialogChoose(message, title, items, .true, cx, cy, preSel)
  if r == .nil then return ""
  return r

::class CheckList public               -- new(message, title, labels., checks. [, len [, max]]): 1 (checks. set) or 2
::method init
  expose message title labels checks max
  use arg message, title, labels, checks, len = 0, max = 0
::method execute
  expose message title labels checks max
  items = NetDialogStemArray(labels, 1)
  states = .array~new
  do i = 1 to items~items
    states[i] = checks[100 + i] == 1
  end
  if NetDialogAuto("CheckList:" message) then return 1
  dlg = .NetDialogBoxes~new(message, title, items, states, max, "CHECK")
  if dlg~execute \= 1 then return 2
  answer = dlg~answer
  do i = 1 to items~items
    checks[100 + i] = answer[i]
  end
  return 1

/* MultiInputBox: new(message, title, labels., values. [, len]); after OK, each
   value is an attribute named from its label, its letters and digits
   ("Street and City: ": StreetandCity), as ooDialog's */
::class MultiInputBox public
::method init
  expose message title labels values width answers
  use arg message, title, labels, values, width = 100
  if width == "" then width = 100
  answers = .directory~new
  items = NetDialogStemArray(labels, 1)
  do i = 1 to items~items
    if values~hasIndex(100 + i) then answers[NetDialogLabelName(items[i])] = values[100 + i]
    else answers[NetDialogLabelName(items[i])] = ""
  end
::method execute
  expose message title labels values width answers
  items = NetDialogStemArray(labels, 1)
  defaults = .array~new
  do i = 1 to items~items
    if values~hasIndex(100 + i) then defaults[i] = values[100 + i]
    else defaults[i] = ""
  end
  if NetDialogAuto("MultiInputBox:" message) then return 1
  dlg = .NetDialogMultiInput~new(message, title, items, defaults, width)
  if dlg~execute \= 1 then return 2
  answer = dlg~answer
  do i = 1 to items~items
    answers[NetDialogLabelName(items[i])] = answer[i]
  end
  return 1
::method unknown                       -- the values, by their names
  expose answers
  use arg name
  if answers~hasIndex(name) then return answers[name]
  raise syntax 97.1 array(self, name)


::routine NetDialogSoundFile           -- (inside) a sound's file: as named, or in a directory of SOUNDPATH (ooDialog's), or Windows' Media
  use arg file
  if SysFileExists(file) then return file
  dirs = value("SOUNDPATH", , "ENVIRONMENT")
  win = value("WINDIR", , "ENVIRONMENT")
  dirs = dirs";"win"\Media"
  do d over dirs~makeArray(";")
    if d \== "", SysFileExists(d"\"file) then return d"\"file
  end
  return file
::routine NetDialogWriteOn             -- (inside) write, writeToControl: text drawn on a window, at once
  use arg w, x, y, text, fontName, fontSize, fontStyle, fg, bk, dc = .nil
  st = ""
  do word over fontStyle~upper~makeArray(" ")
    if wordPos(word, "BOLD ITALIC UNDERLINE STRIKEOUT") > 0 then st = st word~left(1) || word~substr(2)~lower
  end
  if st == "" then st = "Regular"
  font = NetDialogFont(fontName, fontSize, w~DeviceDpi, st~strip~changeStr(" ", ", "))
  D = .net~System~Drawing
  fore = D~Color~Black; back = D~Color~White         -- (a window's device context: black on white, opaque)
  if fg \= -1 then fore = NetDialogColor(fg)
  if bk \= -1 then back = NetDialogColor(bk)
  if fontStyle~upper~wordPos("TRANSPARENT") > 0 then back = D~Color~Transparent
  pt = D~Point~new(trunc(x), trunc(y))
  flags = .net~System~Windows~Forms~TextFormatFlags~NoPadding
  if dc \== .nil then do
    .net~System~Windows~Forms~TextRenderer~DrawText(dc~graphics, text, font, pt, fore, back, flags)
    w~Invalidate
  end
  else do
    g = w~CreateGraphics
    .net~System~Windows~Forms~TextRenderer~DrawText(g, text, font, pt, fore, back, flags)
    g~Dispose
  end
  return 0
::routine NetDialogDoubleBuffered       -- (inside) a control drawn off screen first (its protected DoubleBuffered, by reflection)
  use arg c
  R = .net~System~Reflection
  flags = .net~System~Enum~Parse(R~BindingFlags~Instance~GetType, "Instance, NonPublic")
  c~GetType~GetProperty("DoubleBuffered", flags)~SetValue(c, .net~bool(.true))
  return 0
::routine NetDialogSysColor            -- (inside) Windows' system colour number n (GetSysColor's), as .NET's
  use arg n
  names = .array~of("ScrollBar", "Desktop", "ActiveCaption", "InactiveCaption", "Menu", "Window", "WindowFrame", -
    "MenuText", "WindowText", "ActiveCaptionText", "ActiveBorder", "InactiveBorder", "AppWorkspace", "Highlight", -
    "HighlightText", "Control", "ControlDark", "GrayText", "ControlText", "InactiveCaptionText", "ControlLightLight", -
    "ControlDarkDark", "ControlLight", "InfoText", "Info", "Control", "HotTrack", "GradientActiveCaption", -
    "GradientInactiveCaption", "MenuHighlight", "MenuBar")
  if \n~dataType("W") | n < 0 | n >= names~items then n = 15
  return .net~System~Drawing~Color~FromKnownColor(.net~System~Enum~Parse(.net~System~Drawing~KnownColor~Control~GetType, names[n + 1]))
::routine NetDialogBaseUnits           -- (inside) a font's dialog base units (x, y), on the screen
  use arg fontName, fontSize
  F = .net~System~Windows~Forms
  D = .net~System~Drawing
  g = D~Graphics~FromHwnd(.net~as(0, "System.IntPtr"))
  dpi = trunc(g~DpiY)
  g~Dispose
  if fontName~caselessEquals("System") then return .array~of((8 * dpi + 48) % 96, (16 * dpi + 48) % 96)
  font = NetDialogFont(fontName, fontSize, dpi)
  flags = F~TextFormatFlags~NoPadding
  big = D~Size~new(32000, 32000)
  ext = F~TextRenderer~MeasureText("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz", font, big, flags)~Width
  return .array~of((ext % 26 + 1) % 2, F~TextRenderer~MeasureText("A", font, big, flags)~Height)
::routine NetDialogMod360              -- (inside) an angle in 0 <= a < 360
  use arg a
  return a - 360 * (a / 360)~floor
::routine NetDialogStemArray            -- (inside) a stem's entries from first on, as an Array
  use arg stem, first
  a = .array~new
  do i = first while stem~hasIndex(i)
    a~append(stem[i])
  end
  return a
::routine NetDialogLabelName            -- (inside) a label's letters and digits, upper case (an attribute's name)
  use arg label
  name = ""
  do i = 1 to label~length
    c = label~subchar(i)
    if c~datatype("A") then name ||= c
  end
  return name~upper

/* timedMessage(message, title, duration [, earlyReply [, pos]]): a message
   that goes away after duration ms; pos: its top left on the screen */
::routine timedMessage public
  use arg message, title, duration, earlyReply = .false, pos = .nil
  if duration >= 0, NetDialogAuto("timedMessage:" message) then return 0
  dlg = .NetDialogTimed~new(message, title, duration, pos)
  if duration < 0 then do              -- until the program cancels it: the dialog, shown, at once
    dlg~popup
    return dlg
  end
  if earlyReply == .true then do       -- back at once; it goes away by itself
    dlg~popup
    return 0
  end
  dlg~execute
  return 0

/* sendWinIntMsg(control, msg, wParam, lParam): a Windows message sent to a
   control (ooDialog's control~sendWinIntMsg), its result. A NativeWindow
   on the control's handle passes it to the control's own window procedure
   (Windows Forms', then Windows'): .NET has no SendMessage of its own. */
::routine sendWinIntMsg public
  use strict arg ctl, msg, wParam, lParam
  F = .net~System~Windows~Forms
  h = .net~as(ctl~Handle, "System.IntPtr")
  nw = F~NativeWindow~new
  nw~AssignHandle(h)
  r = .net~ref(F~Message~Create(h, .net~int32(msg), .net~as(wParam, "System.IntPtr"), .net~as(lParam, "System.IntPtr")))
  signal on syntax
  nw~DefWndProc(r)
  nw~ReleaseHandle
  return r~value~Result
syntax:
  nw~ReleaseHandle
  raise propagate

/* findWindow(title): the handle of this program's window of that title, or
   0 (.NET has no Win32 FindWindow: its own forms, Application.OpenForms) */
::routine findWindow public
  use strict arg title
  do f over .net~System~Windows~Forms~Application~OpenForms~makeArray
    if f~Text == title then return f~Handle
  end
  return 0

/* play(file [, "YES" | "LOOP"]): a .wav, to its end, or in the background
   ("YES"), or over and over ("LOOP") until another play; .NET's SoundPlayer */
::routine play public                  -- play(file [, how]): a .wav file; how YES: not waited for, LOOP: again and again
  use arg file, how = ""
  if NetDialogAuto("play:" file how) then return 0
  if arg() = 0 | file == "" then return 0     -- (ooDialog's play(): stops one playing; here none plays long)
  file = NetDialogSoundFile(file)
  p = .net~System~Media~SoundPlayer~new(file)
  select
    when how~upper == "YES" then p~Play
    when how~upper == "LOOP" then p~PlayLooping
    otherwise p~PlaySync
  end
  return 0

/* msSleep(ms): waits, this thread's windows alive meanwhile (a modeless
   dialog, a timedMessage that replied early) */
::routine msSleep public
  use strict arg ms
  F = .net~System~Windows~Forms
  sw = .net~System~Diagnostics~Stopwatch~StartNew
  do while sw~ElapsedMilliseconds < ms
    F~Application~DoEvents
    call SysSleep 0.02
  end
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
  if multi, preselect \== "" then do i over preselect~makeArray(" ")   -- (multiListChoice: the items' numbers)
    list~SetSelected(i - 1, .true)
  end
  else if preselect \== "" then list~SelectedItem = preselect
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
  use arg message, title, duration, pos = .nil
  self~init:super
  self~createCenter(200, 40, title)
  if pos \== .nil then do              -- (its top left there, on the screen)
    self~form~StartPosition = "Manual"
    self~form~Location = .net~System~Drawing~Point~new(pos~x, pos~y)
  end
::method defineDialog
  expose message duration timer
  self~createStatic("msg", 10, 14, 180, 20, "CENTER", message)
  if duration > 0 then timer = self~startTimer(duration, "OK")   -- (-1: until cancelled)
::method leaving
  expose timer
  if var("TIMER") then timer~Stop      -- (it would tick on, after the window)
