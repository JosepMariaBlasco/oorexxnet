/* rc2oodnet.rex: an ooDialog resource script's dialog as oodnet.cls code.

       rexx rc2oodnet.rex file.rc [dialogId] [file.h]
       rexx rc2oodnet.rex -cls file.rc [out.cls]

   Writes, for the dialog dialogId (the first one if not given) of file.rc,
   the self~create(...) line for INIT and the DEFINEDIALOG method that
   builds the same dialog with NetDialog (oodnet.cls): the same coordinates,
   the same ids, and data attributes named as ooDialog names them from the
   controls' texts. Symbolic ids are kept as names; a .h file, if given,
   lets a numeric dialog id be written by its name. What it does not know
   (a control class oodnet.cls has no create* for, a style it does not map)
   is written as a comment, to do by hand.

   With -cls, every dialog of file.rc becomes a public class of a package
   (out.cls, else file.rc's name with "rc.cls" for ".rc"): class
   <file>_<dialogId> (employe5.rc's 101: Employe5_101), a NetDialog that
   creates itself in INIT and builds its controls in DEFINEDIALOG. A
   program that subclasses ooDialog's RcDialog with that .rc subclasses it
   instead, and keeps the rest of its code.                                  */

w = argWords(arg(1))                    -- (a name with spaces in double quotes)
a1 = w[1]; a2 = w[2]; a3 = w[3]; a4 = w[4]
toCls = a1~caselessEquals("-cls")
if toCls then do; rcFile = a2; outFile = a3; end
else do; rcFile = a1; dialogId = a2; hFile = a3; end
if rcFile == "" then do
  say "usage: rexx rc2oodnet.rex file.rc [dialogId] [file.h]"
  say "       rexx rc2oodnet.rex -cls file.rc [out.cls]"
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

/* the dialogs' and menus' header lines */
dialogs = .array~new; menus = .array~new
do i = 1 to lines~items
  w2 = lines[i]~word(2)~upper
  if w2 == "DIALOG" | w2 == "DIALOGEX" then dialogs~append(i)
  if w2 == "MENU" | w2 == "MENUEX" then menus~append(i)
end

if \toCls then do
  found = 0
  do i over dialogs
    if dialogId == "" | lines[i]~word(1)~caselessEquals(dialogId) then do; found = i; leave; end
  end
  if found = 0 then do
    say "no dialog" dialogId "in" rcFile
    exit 1
  end
  out = dialog(lines, found)
  say "-- in INIT (the .rc's" lines[found]~word(1) "DIALOG):"
  do l over out~makeArray("0a"x); say l; end
  exit 0
end

/* -cls: a package */
if dialogs~items = 0 then do
  say "no dialog in" rcFile
  exit 1
end
name = filespec("name", rcFile)
base = name~left(name~lastPos(".") - 1)
if outFile == "" then outFile = filespec("location", rcFile) || base"rc.cls"
o = .stream~new(outFile)
o~open("write replace")
r = .stream~new(rcFile)~~open("read")            -- the .rc's leading comment (its licence) first
do while r~lines > 0
  l = r~linein
  if l~strip~left(2) \== "/*" | l~strip~right(2) \== "*/" then leave
  o~lineout(l)
end
r~close
o~lineout("/*" name "as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).")
o~lineout("   A program that subclasses ooDialog's RcDialog with" name "subclasses")
o~lineout("   these instead. */")
o~lineout("")
o~lineout('::requires "oodnet.cls"')
do i over dialogs
  cls = base~left(1)~upper || base~substr(2)"_"lines[i]~word(1)
  body = dialog(lines, i)~makeArray("0a"x)
  o~lineout("")
  o~lineout("::class" quote(cls) "subclass NetDialog public")
  o~lineout("::method init")
  o~lineout("  forward class (super) continue")
  o~lineout(body[1])
  o~lineout("")
  do j = 3 to body~items; o~lineout(body[j]); end
end
do i over menus                        -- a menu: a NetMenuBar that builds itself
  cls = base~left(1)~upper || base~substr(2)"_"lines[i]~word(1)
  o~lineout("")
  o~lineout("::class" quote(cls) "subclass NetMenuBar public   -- the .rc's" lines[i]~word(1) "MENU")
  o~lineout("::method init")
  o~lineout("  forward class (super) continue")
  do l over menu(lines, i); o~lineout(l); end
end
o~close
say "wrote" outFile":" dialogs~items "dialog" || (dialogs~items = 1)~?("", "s") || -
    (menus~items > 0)~?("," menus~items "menu" || (menus~items = 1)~?("", "s"), "")
exit 0

/* the dialog whose header is lines[found]: its create line, "", then its
   defineDialog method, as lines joined by "0a"x */
dialog: procedure
  use arg lines, found
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
  args = x~strip"," y~strip"," cx~strip"," cy~strip"," quote(caption)"," quote(styles)
  if font \== "" then args = args", ," quote(font)"," fontSize
  out~append("  self~create("args")")
  out~append("")
  out~append("::method defineDialog                  -- the .rc's controls")
  i += 1
  do while i <= lines~items
    l = lines[i]; u = l~word(1)~upper
    if u == "}" | u == "END" then leave
    if l \== "" then out~append("  "control(l))
    i += 1
  end
  return out~makeString("L", "0a"x)

/* the menu whose header is lines[found]: NetPopupMenu / NetMenuBar calls,
   each popup built, then inserted at the end of its parent (as the .rc's
   order) */
menu: procedure
  use arg lines, found
  out = .array~new; stack = .array~new; n = 0
  i = found + 1
  do while i <= lines~items             -- to the menu's opening { (or BEGIN)
    u = lines[i]~word(1)~upper; i += 1
    if u == "{" | u == "BEGIN" then leave
  end
  do while i <= lines~items
    l = lines[i]; u = l~word(1)~upper; i += 1
    select
      when l == "" | u == "{" | u == "BEGIN" then nop
      when u == "POPUP" then do          -- POPUP "text" [, id ...] (MENUEX: with an id)
        n += 1
        a = splitArgs(l~subWord(2))
        pid = (a[2] \== "")~?(rexxId(a[2]), "")
        out~append("  p"n "= .NetPopupMenu~new(" || pid || ")")
        stack~append(.array~of("p"n, a[1], pid))
      end
      when u == "}" | u == "END" then do
        if stack~items = 0 then leave   -- the menu's end
        top = stack[stack~last]
        stack~delete(stack~last)
        if stack~items = 0 then parent = "self"     -- (~? would evaluate both)
        else parent = stack[stack~items][1]
        out~append("  "parent"~insertPopup(," top[3]"," top[1]"," top[2]")")
      end
      when u == "MENUITEM" & stack~items = 0 then out~append("  -- (by hand: an item on the bar)" l)
      when u == "MENUITEM" then do
        target = stack[stack~items][1]
        if l~word(2)~upper == "SEPARATOR" then out~append("  "target"~insertSeparator")
        else if l~upper~pos("MFT_SEPARATOR") > 0 then   -- MENUEX: MENUITEM "", id, MFT_SEPARATOR
          out~append("  "target"~insertSeparator(," rexxId(splitArgs(l~subWord(2))[2])")")
        else do
          a = splitArgs(l~subWord(2))
          state = ""
          do k = 3 to a~items
            f = a[k]~upper
            if wordPos(f, "GRAYED INACTIVE") > 0 | f~pos("MFS_GRAYED") > 0 | f~pos("MFS_DISABLED") > 0 then state = state "GRAYED"
            if f == "CHECKED" | f~pos("MFS_CHECKED") > 0 then state = state "CHECKED"
          end
          out~append("  "target"~insertItem(," rexxId(a[2])"," a[1] || (state == "")~?("", "," quote(state~strip))")")
        end
      end
      otherwise out~append("  -- (by hand)" l)
    end
  end
  return out

/* one control statement as a create* call; NOT WS_VISIBLE and WS_DISABLED,
   which any control may have, as the styles HIDDEN and DISABLED */
control: procedure
  use arg l
  r = control1(l)
  if \r~abbrev("self~create") | r~pos(', "') = 0 then return r
  parse var r head '(' a1 ',' a2 ',' a3 ',' a4 ',' a5 ', "' st '"' tail
  w = styleWords(l~subWord(2))
  add = ""
  if l~upper~space(1)~pos("NOT WS_VISIBLE") > 0, wordPos("HIDDEN", st) = 0 then add = add "HIDDEN"
  if wordPos("WS_DISABLED", w) > 0, wordPos("DISABLED", st) = 0 then add = add "DISABLED"
  if add == "" then return r
  return head"(" || a1"," || a2"," || a3"," || a4"," || a5', "' || (st add)~space || '"' || tail

control1: procedure
  use arg l
  kw = l~word(1)~upper
  rest = l~subWord(2)
  args = splitArgs(rest)
  if l~upper~pos("BS_OWNERDRAW") > 0, wordPos(kw, "PUSHBUTTON DEFPUSHBUTTON AUTO3STATE AUTOCHECKBOX CHECKBOX AUTORADIOBUTTON RADIOBUTTON") > 0 then
    return call("createPushButton", args[2], args, "OWNERDRAW", args[1])   -- a surface to draw on
  select
    when wordPos(kw, "LTEXT RTEXT CTEXT") > 0 then do
      style = (kw == "RTEXT")~?("RIGHT", (kw == "CTEXT")~?("CENTER", ""))
      if args~hasIndex(7) then do w over staticStyles(args[7])~makeArray(" ")   -- (its own styles: SS_SUNKEN...)
        if wordPos(w, style) = 0 then style = (style w)~strip
      end
      return call("createStatic", args[2], args, style, args[1])
    end
    when kw == "EDITTEXT" then return call("createEdit", args[1], shift(args, -1), editStyles(args[6]), , dataName("", args[1]))
    when kw == "PUSHBUTTON" | kw == "DEFPUSHBUTTON" then
      return call("createPushButton", args[2], args, (kw == "DEFPUSHBUTTON")~?("DEFAULT", ""), args[1])
    when kw == "AUTORADIOBUTTON" | kw == "RADIOBUTTON" then do
      style = ""
      if args~hasIndex(7), wordPos("WS_GROUP", styleWords(args[7])) > 0 then style = "GROUP"   -- (a new group starts)
      return call("createRadioButton", args[2], args, style, args[1], dataName(args[1], args[2]))
    end
    when kw == "AUTOCHECKBOX" | kw == "CHECKBOX" | kw == "AUTO3STATE" then
      return call("createCheckBox", args[2], args, "", args[1], dataName(args[1], args[2]))
    when kw == "GROUPBOX" then return call("createGroupBox", args[2], args, "", args[1])
    when kw == "SCROLLBAR" then
      return call("createScrollBar", args[1], shift(args, -1), (args[6]~upper~pos("SBS_VERT") > 0)~?("VERTICAL", ""))
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
        when wordPos(cls, "SCROLLBAR WC_SCROLLBAR") > 0 then return call("createScrollBar", id, geo, (st~pos("SBS_VERT") > 0)~?("VERTICAL", ""))
        when wordPos(cls, "STATIC WC_STATIC") > 0 then return call("createStatic", id, geo, staticStyles(st), text)
        when wordPos(cls, "BUTTON WC_BUTTON") > 0 then do
          select
            when st~pos("BS_OWNERDRAW") > 0 then return call("createPushButton", id, geo, "OWNERDRAW", text)
            when st~pos("BS_AUTORADIOBUTTON") > 0 | st~pos("BS_RADIOBUTTON") > 0 then return call("createRadioButton", id, geo, "", text, dataName(text, id))
            when st~pos("BS_AUTOCHECKBOX") > 0 | st~pos("BS_CHECKBOX") > 0 | st~pos("BS_AUTO3STATE") > 0 then return call("createCheckBox", id, geo, "", text, dataName(text, id))
            when st~pos("BS_GROUPBOX") > 0 then return call("createGroupBox", id, geo, "", text)
            when st~pos("BS_DEFPUSHBUTTON") > 0 then return call("createPushButton", id, geo, "DEFAULT", text)
            otherwise return call("createPushButton", id, geo, "", text)
          end
        end
        when wordPos(cls, "TOOLBARCLASSNAME TOOLBARWINDOW32") > 0 then do
          s = ""
          if st~space(1)~pos("NOT WS_VISIBLE") > 0 then s = "HIDDEN"   -- (made hidden, shown once set up)
          return call("createToolBar", id, geo, s)
        end
        when wordPos(cls, "UPDOWN_CLASS MSCTLS_UPDOWN32") > 0 then do
          s = ""
          if st~pos("UDS_AUTOBUDDY") > 0 then s = s "AUTOBUDDY"
          if st~pos("UDS_SETBUDDYINT") > 0 then s = s "SETBUDDYINT"
          if st~pos("UDS_WRAP") > 0 then s = s "WRAP"
          if st~pos("UDS_ALIGNRIGHT") > 0 then s = s "ALIGNRIGHT"
          if st~pos("UDS_ALIGNLEFT") > 0 then s = s "ALIGNLEFT"
          return call("createUpDown", id, geo, s~strip)
        end
        when wordPos(cls, "MONTHCAL_CLASS SYSMONTHCAL32") > 0 then return call("createMonthCalendar", id, geo, "")
        when wordPos(cls, "DATETIMEPICK_CLASS SYSDATETIMEPICK32") > 0 then return call("createDateTimePicker", id, geo, "")
        when wordPos(cls, "PROGRESS_CLASS MSCTLS_PROGRESS32") > 0 then return call("createProgressBar", id, geo, progressStyles(st))
        when wordPos(cls, "TRACKBAR_CLASS MSCTLS_TRACKBAR32") > 0 then return call("createTrackBar", id, geo, trackBarStyles(st))
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
  if text \== .nil then s = s"," text   -- (createEdit, createListBox, createComboBox have no text: the attribute is 7th)
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
  -- a name that is one of the dialog's methods is not used (ooDialog's rule;
  -- these are those of its methods a control's text is likely to be)
  reserved = "FONTNAME FONTSIZE TITLE HWND OK CANCEL HELP EXECUTE VALIDATE LEAVING" -
             "SHOW HIDE MOVE RESIZE UPDATE CENTER DRAW SIZE INIT DATA FINISHED"
  if wordPos(n~upper, reserved) > 0 then n = ""
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
  if st~space(1)~pos("NOT WS_BORDER") > 0 then r = r "NOBORDER"
  return r~strip

listStyles: procedure
  use arg st
  st = st~upper; r = ""
  if st~pos("LBS_STANDARD") > 0 | st~pos("LBS_SORT") > 0 then r = r "SORT"
  if st~pos("LBS_MULTIPLESEL") > 0 | st~pos("LBS_EXTENDEDSEL") > 0 then r = r "MULTI"
  if st~pos("LBS_USETABSTOPS") > 0 then r = r "USETAB"
  if st~pos("LBS_MULTICOLUMN") > 0 then r = r "COLUMNS"
  if st~pos("LBS_NOINTEGRALHEIGHT") > 0 then r = r "PARTIAL"
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
  w = styleWords(st); r = ""
  if wordPos("SS_CENTER", w) > 0 then r = r "CENTER"        -- (whole words: not SS_CENTERIMAGE)
  if wordPos("SS_RIGHT", w) > 0 then r = r "RIGHT"
  if wordPos("SS_CENTERIMAGE", w) > 0 then r = r "CENTERIMAGE"   -- (centred down)
  if w~pos("FRAME") > 0 then r = r "FRAME"
  if wordPos("WS_BORDER", w) > 0 then r = r "BORDER"
  if wordPos("SS_SUNKEN", w) > 0 then r = r "SUNKEN"
  if w~pos("ELLIPSIS") > 0 then r = r "ELLIPSIS"    -- (SS_ENDELLIPSIS, SS_WORDELLIPSIS, SS_PATHELLIPSIS)
  return r~strip

/* the styles a .rc gives, as words, uppercase, without those it takes away
   (NOT WS_BORDER) */
styleWords: procedure
  use arg st
  w = st~upper~changeStr("|", " ")~changeStr("(", " ")~changeStr(")", " ")~space
  r = ""
  do i = 1 to w~words
    if w~word(i) == "NOT" then do; i += 1; iterate; end
    r = r w~word(i)
  end
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

progressStyles: procedure
  use arg st
  w = styleWords(st); r = ""
  if wordPos("PBS_VERTICAL", w) > 0 then r = r "VERTICAL"
  if wordPos("PBS_SMOOTH", w) > 0 then r = r "SMOOTH"
  if wordPos("PBS_MARQUEE", w) > 0 then r = r "MARQUEE"
  return r~strip

trackBarStyles: procedure
  use arg st
  w = styleWords(st); r = ""
  if wordPos("TBS_VERT", w) > 0 then r = r "VERTICAL"
  if wordPos("TBS_TOP", w) > 0 then r = r "TOP"          -- (TBS_LEFT is the same bit)
  if wordPos("TBS_LEFT", w) > 0 then r = r "LEFT"
  if wordPos("TBS_BOTH", w) > 0 then r = r "BOTH"
  if wordPos("TBS_NOTICKS", w) > 0 then r = r "NOTICKS"
  if wordPos("TBS_ENABLESELRANGE", w) > 0 then r = r "ENABLESELRANGE"
  return r~strip

treeViewStyles: procedure
  use arg st
  st = st~upper; r = ""
  if st~pos("TVS_HASLINES") > 0 then r = r "HASLINES"
  if st~pos("TVS_HASBUTTONS") > 0 then r = r "HASBUTTONS"
  if st~pos("TVS_LINESATROOT") > 0 then r = r "LINESATROOT"
  return r~strip

/* The words of the command line, a word in double quotes kept whole (a path
   with spaces); missing ones are "" */
argWords: procedure
  use arg line
  w = .array~new
  do while line~strip \== ""
    line = line~strip("L")
    if line~left(1) == '"' then parse var line '"' word '"' line
    else parse var line word line
    w~append(word)
  end
  do i = w~items + 1 to 4; w[i] = ""; end
  return w
