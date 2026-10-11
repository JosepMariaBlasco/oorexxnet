/* rc2oodnet.rex: an ooDialog resource script's dialog as oodnet.cls code.

       rexx rc2oodnet.rex file.rc [dialogId] [file.h]

   Writes, for the dialog dialogId (the first one if not given) of file.rc,
   the self~create(...) line for INIT and the DEFINEDIALOG method that
   builds the same dialog with NetDialog (oodnet.cls): the same coordinates,
   the same ids, and data attributes named as ooDialog names them from the
   controls' texts. Symbolic ids are kept as names; a .h file, if given,
   lets a numeric dialog id be written by its name. What it does not know
   (a control class oodnet.cls has no create* for, a style it does not map)
   is written as a comment, to do by hand.                                     */

parse arg rcFile dialogId hFile
if rcFile == "" then do
  say "usage: rexx rc2oodnet.rex file.rc [dialogId] [file.h]"
  exit 2
end
if \SysFileExists(rcFile) then do
  say "no file" rcFile
  exit 2
end

/* the .rc's lines, continuations joined (a line ending in "," or "|", or
   one starting with "|", goes on the next) */
lines = .array~new
s = .stream~new(rcFile)~~open("read")
do while s~lines > 0
  line = s~linein~strip
  if line~left(2) == "//" then iterate
  last = lines~lastItem
  if lines~items > 0, last~right(1) == "," | last~right(1) == "|" | line~left(1) == "|" then
    lines[lines~last] = last line
  else lines~append(line)
end
s~close

/* the dialog: its header line, then its block { ... } (or BEGIN ... END) */
found = 0
do i = 1 to lines~items
  w2 = lines[i]~word(2)~upper
  if w2 == "DIALOG" | w2 == "DIALOGEX" then do
    if dialogId == "" | lines[i]~word(1)~caselessEquals(dialogId) then do; found = i; leave; end
  end
end
if found = 0 then do
  say "no dialog" dialogId "in" rcFile
  exit 1
end
header = lines[found]
parse var header id . rest
parse var rest x "," y "," cx "," cy .
caption = ""; font = ""; fontSize = ""; styles = ""
out = .array~new
i = found + 1
do while i <= lines~items
  l = lines[i]; u = l~word(1)~upper
  if u == "{" | u == "BEGIN" then leave
  select
    when u == "CAPTION" then caption = unquote(l~subWord(2))
    when u == "FONT" then do
      parse var l . size "," f "," .
      fontSize = size~strip; font = unquote(f~strip)
    end
    when u == "STYLE" then styles = dialogStyles(l~subWord(2))
    otherwise nop
  end
  i += 1
end
say "-- in INIT (the .rc's" id "DIALOG):"
args = x~strip"," y~strip"," cx~strip"," cy~strip"," quote(caption)"," quote(styles)
if font \== "" then args = args", ," quote(font)"," fontSize
say "  self~create("args")"
say
say "::method defineDialog                  -- the .rc's controls"
i += 1
do while i <= lines~items
  l = lines[i]; u = l~word(1)~upper
  if u == "}" | u == "END" then leave
  if l \== "" then say "  "control(l)
  i += 1
end
exit 0

/* one control statement as a create* call */
control: procedure
  use arg l
  kw = l~word(1)~upper
  rest = l~subWord(2)
  args = splitArgs(rest)
  select
    when wordPos(kw, "LTEXT RTEXT CTEXT") > 0 then do
      style = (kw == "RTEXT")~?("RIGHT", (kw == "CTEXT")~?("CENTER", ""))
      return call("createStatic", args[2], args, style, args[1])
    end
    when kw == "EDITTEXT" then return call("createEdit", args[1], shift(args, -1), editStyles(args[6]), , dataName("", args[1]))
    when kw == "PUSHBUTTON" | kw == "DEFPUSHBUTTON" then
      return call("createPushButton", args[2], args, (kw == "DEFPUSHBUTTON")~?("DEFAULT", ""), args[1])
    when kw == "AUTORADIOBUTTON" | kw == "RADIOBUTTON" then
      return call("createRadioButton", args[2], args, "", args[1], dataName(args[1], args[2]))
    when kw == "AUTOCHECKBOX" | kw == "CHECKBOX" | kw == "AUTO3STATE" then
      return call("createCheckBox", args[2], args, "", args[1], dataName(args[1], args[2]))
    when kw == "GROUPBOX" then return call("createGroupBox", args[2], args, "", args[1])
    when kw == "LISTBOX" then return call("createListBox", args[1], shift(args, -1), listStyles(args[6]), , dataName("", args[1]))
    when kw == "COMBOBOX" then return call("createComboBox", args[1], shift(args, -1), comboStyles(args[6]), , dataName("", args[1]))
    when kw == "CONTROL" then do
      /* CONTROL "text", id, class, style, x, y, cx, cy */
      text = args[1]; id = args[2]; cls = unquote(args[3])~upper; st = args[4]~upper
      geo = .array~of(text, id, args[5], args[6], args[7], args[8])
      select
        when wordPos(cls, "EDIT WC_EDIT") > 0 then return call("createEdit", id, geo, editStyles(st), , dataName(text, id))
        when wordPos(cls, "COMBOBOX WC_COMBOBOX") > 0 then return call("createComboBox", id, geo, comboStyles(st), , dataName(text, id))
        when wordPos(cls, "LISTBOX WC_LISTBOX") > 0 then return call("createListBox", id, geo, listStyles(st), , dataName(text, id))
        when wordPos(cls, "STATIC WC_STATIC") > 0 then return call("createStatic", id, geo, staticStyles(st), text)
        when wordPos(cls, "BUTTON WC_BUTTON") > 0 then do
          select
            when st~pos("BS_AUTORADIOBUTTON") > 0 | st~pos("BS_RADIOBUTTON") > 0 then return call("createRadioButton", id, geo, "", text, dataName(text, id))
            when st~pos("BS_AUTOCHECKBOX") > 0 | st~pos("BS_CHECKBOX") > 0 | st~pos("BS_AUTO3STATE") > 0 then return call("createCheckBox", id, geo, "", text, dataName(text, id))
            when st~pos("BS_GROUPBOX") > 0 then return call("createGroupBox", id, geo, "", text)
            when st~pos("BS_DEFPUSHBUTTON") > 0 then return call("createPushButton", id, geo, "DEFAULT", text)
            otherwise return call("createPushButton", id, geo, "", text)
          end
        end
        when wordPos(cls, "UPDOWN_CLASS MSCTLS_UPDOWN32") > 0 then do
          s = ""
          if st~pos("UDS_AUTOBUDDY") > 0 then s = s "AUTOBUDDY"
          if st~pos("UDS_SETBUDDYINT") > 0 then s = s "SETBUDDYINT"
          if st~pos("UDS_WRAP") > 0 then s = s "WRAP"
          return call("createUpDown", id, geo, s~strip)
        end
        when wordPos(cls, "MONTHCAL_CLASS SYSMONTHCAL32") > 0 then return call("createMonthCalendar", id, geo, "")
        when wordPos(cls, "DATETIMEPICK_CLASS SYSDATETIMEPICK32") > 0 then return call("createDateTimePicker", id, geo, "")
        when wordPos(cls, "PROGRESS_CLASS MSCTLS_PROGRESS32") > 0 then return call("createProgressBar", id, geo, "")
        when wordPos(cls, "TRACKBAR_CLASS MSCTLS_TRACKBAR32") > 0 then return call("createTrackBar", id, geo, (st~pos("TBS_VERT") > 0)~?("VERTICAL", ""))
        when wordPos(cls, "WC_LISTVIEW SYSLISTVIEW32") > 0 then return call("createListView", id, geo, listViewStyles(st))
        when wordPos(cls, "WC_TREEVIEW SYSTREEVIEW32") > 0 then return call("createTreeView", id, geo, treeViewStyles(st))
        when wordPos(cls, "WC_TABCONTROL SYSTABCONTROL32") > 0 then return call("createTab", id, geo, "")
        otherwise return "-- (by hand)" l
      end
    end
    otherwise return "-- (by hand)" l
  end

/* createX(id, x, y, cx, cy, style [, text [, attribute]]) */
call: procedure
  use arg method, id, geo, style, text = .nil, attr = .nil
  s = method"("rexxId(id)"," geo[3]"," geo[4]"," geo[5]"," geo[6]"," quote(style)
  if text \== .nil then s = s"," text
  else if attr \== .nil then s = s","
  if attr \== .nil then s = s"," quote(attr)
  return "self~"s")"

shift: procedure                       -- (id, x, y, cx, cy, style) as (text, id, x, y, cx, cy, style)
  use arg a
  return .array~of('""', a[1], a[2], a[3], a[4], a[5], a[6])

/* "A, B, C" as an Array, quoted strings kept whole */
splitArgs: procedure
  use arg s
  a = .array~new; cur = ""; inq = .false
  do i = 1 to s~length
    c = s~subStr(i, 1)
    if c == '"' then inq = \inq
    if c == "," & \inq then do; a~append(cur~strip); cur = ""; iterate; end
    cur = cur || c
  end
  if cur~strip \== "" then a~append(cur~strip)
  do i = a~items + 1 to 9; a[i] = ""; end
  return a

/* a control's data attribute name, as ooDialog's autodetection makes it
   from its text (letters and digits, no "&"); else its symbolic id, or
   DATA<id> for a numeric one */
dataName: procedure
  use arg text, id
  t = unquote(text)~changeStr("&", "")
  n = ""
  do i = 1 to t~length
    c = t~subStr(i, 1)
    if c~datatype("A") then n = n || c
  end
  if n == "" | n~left(1)~datatype("W") then do
    if id~datatype("W") then n = "DATA"id
    else n = id
  end
  return n~upper

rexxId: procedure                      -- a number as it is; a symbol (IDOK, IDC_EDIT) as it is
  use arg id
  return id~strip

unquote: procedure
  use arg s
  s = s~strip
  if s~left(1) == '"' & s~right(1) == '"' then return s~subStr(2, s~length - 2)~changeStr('""', '"')
  return s

quote: procedure
  return '"' || arg(1)~changeStr('"', '""') || '"'

dialogStyles: procedure
  use arg st
  st = st~upper; r = ""
  if st~pos("DS_CENTER") > 0 then r = r "CENTER"
  if st~pos("WS_MINIMIZEBOX") > 0 then r = r "MINIMIZEBOX"
  if st~pos("WS_MAXIMIZEBOX") > 0 then r = r "MAXIMIZEBOX"
  if st~pos("WS_THICKFRAME") > 0 then r = r "SIZEBOX"
  return r~strip

editStyles: procedure
  use arg st
  st = st~upper; r = ""
  if st~pos("ES_MULTILINE") > 0 then r = r "MULTILINE"
  if st~pos("ES_READONLY") > 0 then r = r "READONLY"
  if st~pos("ES_PASSWORD") > 0 then r = r "PASSWORD"
  if st~pos("ES_RIGHT") > 0 then r = r "RIGHT"
  if st~pos("ES_CENTER") > 0 then r = r "CENTER"
  if st~pos("ES_NUMBER") > 0 then r = r "NUMBER"
  if st~pos("WS_VSCROLL") > 0 then r = r "VSCROLL"
  if st~pos("WS_HSCROLL") > 0 then r = r "HSCROLL"
  return r~strip

listStyles: procedure
  use arg st
  st = st~upper; r = ""
  if st~pos("LBS_STANDARD") > 0 | st~pos("LBS_SORT") > 0 then r = r "SORT"
  if st~pos("LBS_MULTIPLESEL") > 0 | st~pos("LBS_EXTENDEDSEL") > 0 then r = r "MULTI"
  return r~strip

comboStyles: procedure
  use arg st
  st = st~upper; r = ""
  if st~pos("CBS_DROPDOWNLIST") > 0 then r = r "LIST"
  else if st~pos("CBS_SIMPLE") > 0 then r = r "SIMPLE"
  if st~pos("CBS_SORT") > 0 then r = r "SORT"
  return r~strip

staticStyles: procedure
  use arg st
  st = st~upper; r = ""
  if st~pos("SS_CENTER") > 0 then r = r "CENTER"
  if st~pos("SS_RIGHT") > 0 then r = r "RIGHT"
  if st~pos("FRAME") > 0 then r = r "FRAME"
  if st~pos("WS_BORDER") > 0 then r = r "BORDER"
  return r~strip

listViewStyles: procedure
  use arg st
  st = st~upper; r = ""
  select
    when st~pos("LVS_REPORT") > 0 then r = "REPORT"
    when st~pos("LVS_LIST") > 0 then r = "LIST"
    when st~pos("LVS_SMALLICON") > 0 then r = "SMALLICON"
    otherwise r = "ICON"
  end
  if st~pos("LVS_SHOWSELALWAYS") > 0 then r = r "SHOWSELALWAYS"
  if st~pos("LVS_SINGLESEL") > 0 then r = r "SINGLESEL"
  return r

treeViewStyles: procedure
  use arg st
  st = st~upper; r = ""
  if st~pos("TVS_HASLINES") > 0 then r = r "HASLINES"
  if st~pos("TVS_HASBUTTONS") > 0 then r = r "HASBUTTONS"
  if st~pos("TVS_LINESATROOT") > 0 then r = r "LINESATROOT"
  return r~strip
