/* forms-progress.rex: a window updated from another Rexx thread.
   A window's controls belong to the thread that made them, its event
   thread: other threads must ask it to touch them. A worker thread does a
   job in steps and reports with .NetEventThread~runLaterLatest(bar,
   "VALUE=", "I", n): the message goes to the event thread of its target
   (the progress bar's window), and a newer report replaces one still
   queued, so a busy window never falls behind. At the end the worker
   sends runLater messages and uses their GUIMessages: one asks the window
   for its title (result waits for the answer), one fails on purpose
   (its error stays in the GUIMessage). The Start button starts the job;
   "rexx forms-progress.rex auto" starts it and closes by itself.          */

forms = .net~System~Windows~Forms
drawing = .net~System~Drawing
forms~Application~EnableVisualStyles

form = forms~Form~new
form~Text = "Progress from another thread"
form~ClientSize = drawing~Size~new(360, 120)
form~StartPosition = "CenterScreen"
form~FormBorderStyle = "FixedDialog"
form~MaximizeBox = .false

bar = forms~ProgressBar~new
bar~Location = drawing~Point~new(12, 14)
bar~Width = 336
bar~Maximum = 100

label = forms~Label~new
label~Text = "Press Start."
label~Location = drawing~Point~new(12, 50)
label~AutoSize = .true

button = forms~Button~new
button~Text = "Start"
button~Location = drawing~Point~new(264, 82)
button~Width = 84

form~Controls~Add(bar)
form~Controls~Add(label)
form~Controls~Add(button)

auto = arg(1)~strip~caselessEquals("auto")
job = .Job~new(form, bar, label, button, auto)
button~Click += .net~handler(job, "CLICK")            -- runs on this thread, the window's
if auto then form~Shown += .net~handler(job, "CLICK")  -- (unattended: start at once)
forms~Application~Run(form)
say "Window closed; reports sent:" job~sent", shown:" job~shown
exit

::requires "net.cls"

::class Job
::attribute sent get
::attribute shown get
::method init
  expose form bar label button auto sent shown
  use arg form, bar, label, button, auto
  sent = 0; shown = 0
::method click unguarded                               -- on the window's thread
  expose button label
  button~Enabled = .false
  label~Text = "Working..."
  self~work                                            -- returns at once: the job runs on another thread
::method work unguarded
  expose form bar label button auto sent
  reply                                                -- the rest on a new Rexx thread
  do i = 1 to 100
    call SysSleep 0.02                                 -- a step of the job
    .NetEventThread~runLaterLatest(bar, "VALUE=", "I", i)   -- to the bar's window thread
    .NetEventThread~runLaterLatest(self, "COUNT")      -- (counts the reports shown)
    sent += 1
  end
  title = .NetEventThread~runLater(form, "TEXT")       -- a GUIMessage: ask the window
  say "The window's title, read on its thread:" title~result
  bad = .NetEventThread~runLater(bar, "VALUE=", "I", 1000)   -- beyond Maximum: .NET refuses
  x = bad~result
  say "Setting 1000: hasError" bad~hasError"," bad~errorCondition~message~left(60)"..."
  done = .NetEventThread~runLater(label, "TEXT=", "I", "Done:" sent "reports sent.")
  .NetEventThread~runLater(button, "ENABLED=", "I", .true)
  if auto then do
    call SysSleep 0.5
    .NetEventThread~runLater(form, "CLOSE")
  end
::method count unguarded                               -- on the window's thread
  expose shown
  shown += 1
