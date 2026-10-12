/* measure-dialogs.rex: ooDialog's dialogs and their oodnet.cls ports, measured
   side by side, in pixels.

       rexx measure-dialogs.rex [build-dir]          (Windows)

   For each dialog of the list below (a .rc of ooDialog's samples, which
   come with ooRexx for Windows), it opens the original with ooDialog's
   RcDialog, and the same .rc made a NetDialog by rc2oodnet.rex, and writes
   to measure-dialogs.log (in the current directory) every control's
   rectangle in client coordinates, its class, id and text, and the size of
   its text in its font: GDI's (GetTextExtentPoint32, as Win32 controls draw)
   for the original, TextRenderer's for the port. Also each dialog's window
   and client size, and its dialog base units as each side computes them.
   The original's controls are found through UI Automation (from .NET), so
   that the controls without an id (-1) are there too.

   Nothing to click: each dialog closes by itself. build-dir: the bridge's
   build, as for check-samples.rex. The dialogs, with their fonts:

       rc\calculator.rc            DIALOG_1           MS Shell Dlg 10
       rc\oodStandardDialogs.rc    IDD_STDRTNS        MS Shell Dlg 8
       controls\upDown.rc          IDD_UP_DOWN        MS Shell Dlg 2 8
       tutorial\employe8.rc        100                System 8
       tutorial\employe7.rc        IDD_EMPLOYEES7     Tahoma 10
       tutorial\employe7.rc        IDD_EMPLOYEE_LIST  Courier New 12
       examples\resources\osfDialogs.rc   IDD_SIMPLE_OSF_DIALOGS  (radio buttons in a group box)
       examples\resources\addManyRows.rc  IDD_SORT_PARAMS         (group boxes in a group box,
                                     two groups of radio buttons in one, an up-down)

   Each side of each dialog runs in a process of its own (the original's in
   measure-dialogs-ood.rex, the port's as measure-dialogs.rex -net), killed
   if it has not ended after 30 s; ooDialog and oodnet.cls, which have public
   routines of the same names, are never loaded together.                    */

parse source . . me
here = filespec("location", me)
w = argWords(arg(1))
select
  when w[1] == "-net" then exit measureNet(w[2], w[3], w[4])
  otherwise nop
end

if \.rexxInfo~platform~upper~abbrev("WIN") then do
  say "Windows only (ooDialog)"
  exit 2
end
out = w[1]
if out == "" then out = env("REXXNET_BUILD")
if out == "" then out = env("USERPROFILE")"\build\rexxnet"
if \.file~new(out"\Rexx.Net.dll")~exists then do
  say "no Rexx.Net.dll in" out "(build the bridge first)"
  exit 2
end
call env "REXX_PATH", out
call env "PATH", out";"env("PATH")
.context~package~loadPackage("net.cls")  -- (after REXX_PATH): the children are run through .NET's Process

ood = oodSamples()
if ood == "" then do
  say "ooDialog's samples not found next to" .rexxInfo~executable
  exit 2
end
log = directory()"\measure-dialogs.log"
call SysFileDelete log
call logLine log, "measure-dialogs.rex" date("S") time() "-" .rexxInfo~version "-" .rexxInfo~platform
call logLine log, "ooDialog's samples:" ood
dialogs = .array~of("rc\calculator.rc DIALOG_1", "rc\oodStandardDialogs.rc IDD_STDRTNS",  -
  "controls\upDown.rc IDD_UP_DOWN", "tutorial\employe8.rc 100",                          -
  "tutorial\employe7.rc IDD_EMPLOYEES7", "tutorial\employe7.rc IDD_EMPLOYEE_LIST",              -
  "examples\resources\osfDialogs.rc IDD_SIMPLE_OSF_DIALOGS", "examples\resources\addManyRows.rc IDD_SORT_PARAMS")
tmp = here"measure-dialogs-tmp.cls"     -- next to oodnet.cls, which it requires
fails = 0
do d over dialogs
  parse var d rel id
  rcFile = ood || rel
  call logLine log, ""
  call logLine log, "== dialog" rel id
  if \SysFileExists(rcFile) then do
    call logLine log, "error: no" rcFile
    fails += 1
    iterate
  end
  h = includeFile(rcFile)
  oodId = id
  if firstDialog(rcFile)~caselessEquals(id) then oodId = ""   -- (ooDialog: the first dialog, its id perhaps a #define of the .rc)
  call SysFileDelete tmp
  address system 'rexx "'here'rc2oodnet.rex" -cls "'rcFile'" "'tmp'"'
  cls = classFor(tmp, id)
  if cls == "" then do
    call logLine log, "error: rc2oodnet.rex made no class for" id
    fails += 1
    iterate
  end
  if child('"'here'measure-dialogs-ood.rex" "'rcFile'" "'oodId'" "'h'" "'tmp'" "'cls'" "'log'"', log) \= 0 then fails += 1
  if child('"'me'" -net "'tmp'" "'cls'" "'log'"', log) \= 0 then fails += 1
end
call SysFileDelete tmp
say "wrote" log "("fails "failed)"
exit fails > 0

/* ------------------------------------------------------------------ port */
/* The class rc2oodnet.rex made of that dialog, run unattended: its autoRun,
   once the window shows, measures and cancels */
::routine measureNet
  use arg clsFile, clsName, log
  .context~package~loadPackage("net.cls")
  p = .context~package~loadPackage(clsFile)
  p~findClass("NetDialog")~auto = .true
  cls = p~findClass(clsName)~subclass("MeasuredNetDialog")
  sup = .MeasureNetMixin~methods(.MeasureNetMixin)   -- its methods, defined on the subclass itself: inherit
  do while sup~available                                     -- would put them after the superclasses (NetDialog's autoRun)
    cls~define(sup~index, sup~item)
    sup~next
  end
  .local~measureLog = log              -- (for the methods below)
  .local~measureFailed = 0
  dlg = cls~new
  signal on syntax name broken
  say "(net) execute"
  dlg~execute
  say "(net) ended"
  return .measureFailed
broken:
  c = condition("O")
  call logLine log, "error (net):" c~code c~errortext c~message
  return 1

::class MeasureNetMixin mixinclass Object        -- (its methods are copied)
::method autoRun unguarded
  logFile = .measureLog
  signal on syntax name broken
  say "(net) measuring"
  F = .net~System~Windows~Forms
  D = .net~System~Drawing
  form = self~form
  o = form~PointToScreen(D~Point~new(0, 0))
  b = form~Bounds
  call logLine logFile, "net window" b~Width b~Height "client" form~ClientSize~Width form~ClientSize~Height -
    "client-at" o~X - b~X o~Y - b~Y
  ext = F~TextRenderer~MeasureText("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz", form~Font, -
    D~Size~new(32000, 32000), F~TextFormatFlags~NoPadding)
  call logLine logFile, "net base-units" self~px(4000) / 1000 self~py(8000) / 1000 -
    "(TextRenderer: a..zA..Z" ext~Width"; font" form~Font~Name form~Font~SizeInPoints"pt" form~Font~Height"px," -
    "dpi" form~DeviceDpi")"
  self~walk(form~Controls, o)
  self~endDialog(2)
  return
broken:
  c = condition("O")
  call logLine logFile, "error (net):" c~code c~errortext c~message
  .local~measureFailed = 1
  self~endDialog(2)
::method walk private                  -- the controls, those in a group box, a panel or a tab too
  use arg controls, o
  logFile = .measureLog
  F = .net~System~Windows~Forms
  D = .net~System~Drawing
  do c over controls~makeArray
    p = c~Parent~PointToScreen(c~Location)
    t = c~Text
    sz = F~TextRenderer~MeasureText(t, c~Font, D~Size~new(32000, 32000), F~TextFormatFlags~NoPadding)
    if t == "" then sz = D~Size~new(0, 0)
    call logLine logFile, "net ctl" c~GetType~Name quoteId(c~Name) p~X - o~X p~Y - o~Y c~Width c~Height -
      "text" sz~Width sz~Height quoteText(t)
    if .net~isInstance(c, "System.Windows.Forms.GroupBox") | .net~isInstance(c, "System.Windows.Forms.Panel") | -
       .net~isInstance(c, "System.Windows.Forms.TabControl") | .net~isInstance(c, "System.Windows.Forms.TabPage") then
      self~walk(c~Controls, o)
  end

/* --------------------------------------------------------------- helpers */
::routine child                        -- rexx with these arguments, killed after 30 s
  use arg args, log
  psi = .net~System~Diagnostics~ProcessStartInfo~new("rexx", args)
  psi~UseShellExecute = .false
  p = .net~System~Diagnostics~Process~Start(psi)
  if \p~WaitForExit(30000) then do
    call logLine log, "error: still running after 30 s; killed"
    p~Kill(.true)
    return 124
  end
  return p~ExitCode

::routine logLine
  use arg file, line
  say line
  s = .stream~new(file)
  s~open("write append")
  s~lineOut(line)
  s~close

::routine quoteId
  use arg id
  if id == "" then return "-"
  return id

::routine quoteText                    -- a text in one line, quoted
  use arg t
  return '"'t~changeStr("0d0a"x, "\n")~changeStr("0a"x, "\n")~changeStr("09"x, "\t")'"'

/* The words of the command line, a word in double quotes kept whole (a path
   with spaces); missing ones are "" */
::routine argWords
  use arg line
  w = .array~new
  do while line~strip \== ""
    line = line~strip("L")
    if line~left(1) == '"' then parse var line '"' word '"' line
    else parse var line word line
    w~append(word)
  end
  do i = w~items + 1 to 6; w[i] = ""; end
  return w

::routine env                          -- an environment variable: its value, or set it
  use arg name, value
  if arg(2, "o") then return value(name, , "ENVIRONMENT")
  call value name, value, "ENVIRONMENT"
  return value

::routine oodSamples                   -- ooDialog's samples: in the portable build, bin\..\samples; installed, next to rexx.exe
  bin = filespec("location", .rexxInfo~executable)
  do d over .array~of(bin"samples\oodialog\", bin"..\samples\oodialog\")
    if SysFileExists(d"rc\calculator.rc") then return .file~new(d)~absolutePath"\"
  end
  return ""

::routine includeFile                  -- the .rc's #include "x.h", if that file is there (ooDialog: its symbols)
  use arg rc
  s = .stream~new(rc)~~open("read")
  do while s~lines > 0
    l = s~lineIn~strip
    if l~caselessAbbrev("#include"), l~pos('"') > 0 then do
      parse var l '"' name '"'
      f = filespec("location", rc) || name
      if SysFileExists(f) then do; s~close; return f; end
    end
  end
  s~close
  return ""

::routine firstDialog                  -- the id of the .rc's first DIALOG (or DIALOGEX)
  use arg rc
  s = .stream~new(rc)~~open("read")
  do while s~lines > 0
    parse value s~lineIn with id kind .
    if kind~caselessEquals("DIALOG") | kind~caselessEquals("DIALOGEX") then do; s~close; return id; end
  end
  s~close
  return ""

::routine classFor                     -- the class rc2oodnet.rex made of dialog id: <File>_<id>
  use arg file, id
  if \SysFileExists(file) then return ""
  s = .stream~new(file)~~open("read")
  do while s~lines > 0
    l = s~lineIn
    if l~caselessAbbrev('::class "'), l~caselessPos('_'id'" ') > 0 then do
      parse var l '"' name '"'
      s~close
      return name
    end
  end
  s~close
  return ""
