/* measure-dialogs-ood.rex: the original's side of measure-dialogs.rex (which
   runs it): one dialog of a .rc, opened with ooDialog's RcDialog, measured
   once it shows, then cancelled.

       rexx measure-dialogs-ood.rex "file.rc" "dialogId" "file.h" "port.cls" "class" "log"

   dialogId "": the .rc's first dialog; file.h "": none. port.cls and class:
   the dialog as rc2oodnet.rex made it, whose create* lines give the ids of
   the controls to measure. Each goes to the log as a line
       ood ctl Type id x y w h text tw th "text"
   (client coordinates; tw th: its text's size in its font, through GDI);
   then, if .NET's UI Automation can be reached (net.cls), every child window,
   those without an id too, as
       ood uia Class automationId x y w h text tw th "text"                 */

w = argWords(arg(1))
rcFile = w[1]; id = w[2]; hFile = w[3]; portFile = w[4]; portClass = w[5]; log = w[6]
a = .array~of(rcFile)
if id \== "" then a[2] = id
if hFile \== "" then a[4] = hFile
say "(ood) the dialog"
dlg = .MeasuredRcDialog~sendWith("NEW", a)
dlg~logFile = log
dlg~failed = 0
dlg~ids = portIds(portFile, portClass)
if dlg~initCode \= 0 then do
  call logLine log, "error: ooDialog could not load the dialog (initCode" dlg~initCode")"
  exit 1
end
say "(ood) execute"
dlg~execute("SHOWTOP")
say "(ood) ended"
exit dlg~failed

::requires "ooDialog.cls"

::class MeasuredRcDialog subclass RcDialog
::attribute logFile
::attribute failed
::attribute ids                        -- .array of .array(type, id)
::method initDialog
  say "(ood) initDialog"
  self~start("MEASURE")
  return 0
::method measure unguarded
  expose logFile ids
  signal on syntax name broken
  call SysSleep 1.5                    -- shown
  say "(ood) measuring"
  numeric digits 20
  o = .Point~new(0, 0)
  self~client2screen(o)                -- the client area's top left, on the screen
  wr = self~windowRect
  cr = self~clientRect
  call logLine logFile, "ood window" wr~right - wr~left wr~bottom - wr~top "client" cr~right - cr~left cr~bottom - cr~top -
    "client-at" o~x - wr~left o~y - wr~top
  ext = self~getTextSizePx("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
  a = self~getTextSizePx("A")
  call logLine logFile, "ood base-units" (ext~width % 26 + 1) % 2 a~height "(GDI: a..zA..Z" ext~width"," "A" a~width"x"a~height")" -
    "factors" self~factorX self~factorY
  do t over ids                        -- the controls with an id, through ooDialog
    h = self~getControlHandle(t[2])
    if h == 0 then do
      call logLine logFile, "ood missing" t[1] t[2]
      iterate
    end
    call logLine logFile, "ood ctl" t[1] t[2] self~describe(h, o)
  end
  self~uia(o)
  say "(ood) measured"
  self~cancel
  return
broken:
  c = condition("O")
  call logLine logFile, "error (ood):" c~code c~errortext c~message
  self~failed = 1
  self~cancel

::method describe unguarded             -- a child window: x y w h text tw th "text"
  use arg h, o
  win = .Window~new(h)
  r = win~windowRect
  t = win~getText
  if t~length > 0 then sz = win~getTextSizePx(t)
  else sz = .Size~new(0, 0)
  return r~left - o~x r~top - o~y r~right - r~left r~bottom - r~top "text" sz~width sz~height quoteText(t)

::method uia unguarded                  -- every child window, through .NET's UI Automation
  expose logFile
  use arg o
  signal on syntax name broken
  say "(ood) UI Automation"
  .context~package~loadPackage("net.cls")
  .net~load("UIAutomationClient")
  .net~load("UIAutomationTypes")
  uia = "System.Windows.Automation."
  root = .net~type(uia"AutomationElement")~FromHandle(.net~System~IntPtr~new(.net~int64(self~hwnd~substr(3)~x2d)))
  kids = root~FindAll(.net~type(uia"TreeScope")~Descendants, .net~type(uia"Condition")~TrueCondition)
  do i = 0 to kids~Count - 1
    info = kids~Item(i)~Current
    hw = info~NativeWindowHandle
    if hw = 0 then iterate             -- (parts without a window of their own: a title bar)
    aid = info~AutomationId
    if aid == "" then aid = "-"
    call logLine logFile, "ood uia" info~ClassName aid self~describe("0x" || hw~d2x(16), o)
  end
  return
broken:
  c = condition("O")
  call logLine logFile, "error (ood, UI Automation):" c~code c~errortext c~message

/* The controls of the port's class: its create* lines, (type, id) */
::routine portIds
  use arg file, cls
  ids = .array~new
  s = .stream~new(file)~~open("read")
  inside = .false
  do while s~lines > 0
    l = s~lineIn~strip
    if l~caselessAbbrev("::class") then inside = l~caselessPos('"'cls'"') > 0
    else if inside, l~caselessAbbrev("self~create"), \l~caselessAbbrev("self~create(") then do
      parse var l "self~create" type "(" id "," .
      id = id~strip
      if id \== "-1" & id \== "" then ids~append(.array~of(type, id))
    end
  end
  s~close
  return ids

::routine logLine
  use arg file, line
  say line
  s = .stream~new(file)
  s~open("write append")
  s~lineOut(line)
  s~close

::routine quoteText                    -- a text in one line, quoted
  use arg t
  return '"'t~changeStr("0d0a"x, "\n")~changeStr("0a"x, "\n")~changeStr("09"x, "\t")'"'

::routine argWords                     -- (as measure-dialogs.rex's)
  use arg line
  w = .array~new
  do while line~strip \== ""
    line = line~strip("L")
    if line~left(1) == '"' then parse var line '"' word '"' line
    else parse var line word line
    w~append(word)
  end
  do i = w~items + 1 to 8; w[i] = ""; end
  return w
