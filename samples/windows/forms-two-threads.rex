/* forms-two-threads.rex: two windows, each on a UI thread of its own.
   In .NET each window belongs to the thread that made it, and a program
   may have several such threads. Here two Rexx objects (Counters) each
   start a Rexx thread, make a window on it and run its message loop: two
   event threads. .NetEventThread~current tells an event thread which one
   it is; .NetEventThread~threads lists them all.
   The main thread then sends runLater messages: .NetEventThread~runLater
   sends each to the event thread of its target (a window's control: that
   window's thread), and eventThreadFor(control) gives that event thread,
   whose own runLater sends there any message (here to the Counter, a
   plain Rexx object). Each message returns a GUIMessage: the main thread
   waits for the results, which show on which thread each one ran.
   The windows' buttons count clicks on their own threads, while the main
   thread waits. "rexx forms-two-threads.rex auto" closes them by itself.  */

forms = .net~System~Windows~Forms
forms~Application~EnableVisualStyles
auto = arg(1)~strip~caselessEquals("auto")

left = .Counter~new("Left window", 100)
right = .Counter~new("Right window", 500)
left~start; right~start                               -- each on a new Rexx thread
do until left~ready & right~ready                     -- their windows exist
  call SysSleep 0.05
end

say "Event threads:" .NetEventThread~threads~makeString("L", ", ")
say "Left's thread:" left~threadId", right's:" right~threadId

-- runLater to a control: it runs on that control's window's thread
a = .NetEventThread~runLater(left~label, "TEXT=", "I", "Hello from the main thread")
b = .NetEventThread~runLater(right~label, "TEXT=", "I", "Hello from the main thread")
say "Sent; completed yet?" a~completed b~completed

-- eventThreadFor(control): that window's event thread, to send it any message
leftThread = .NetEventThread~eventThreadFor(left~label)
rightThread = .NetEventThread~eventThreadFor(right~label)
l = leftThread~runLater(left, "WHERE")                -- the Counter, a Rexx object, on the left's thread
r = rightThread~runLater(right, "WHERE")
say "Left's WHERE ran on:" l~result                   -- result waits until it has run
say "Right's WHERE ran on:" r~result
say "Both labels set?" a~completed b~completed

if auto then do
  left~click; right~click; right~click               -- as clicks would (runLater to each window)
  call SysSleep 0.3
  .NetEventThread~runLater(left~form, "CLOSE")
  .NetEventThread~runLater(right~form, "CLOSE")
end
else say "Click the buttons; close both windows to end."
do until left~closed & right~closed
  call SysSleep 0.1
end
say "Clicks: left" left~clicks", right" right~clicks
exit

::requires "net.cls"

/* A window with a label and a button, on a Rexx thread of its own. */
::class Counter
::attribute form
::attribute label
::attribute threadId
::attribute ready
::attribute closed
::attribute clicks
::method init
  expose title x
  use arg title, x
  self~ready = .false; self~closed = .false; self~clicks = 0

::method start unguarded
  expose title x
  reply                                                -- the rest on a new Rexx thread
  forms = .net~System~Windows~Forms
  drawing = .net~System~Drawing
  f = forms~Form~new
  f~Text = title
  f~StartPosition = "Manual"
  f~Location = drawing~Point~new(x, 200)
  f~ClientSize = drawing~Size~new(320, 90)
  l = forms~Label~new
  l~Location = drawing~Point~new(12, 14)
  l~AutoSize = .true
  b = forms~Button~new
  b~Text = "Click me"
  b~Location = drawing~Point~new(12, 50)
  f~Controls~Add(l); f~Controls~Add(b)
  b~Click += .net~handler(self, "CLICKED")            -- runs on this thread
  self~threadId = .NetEventThread~current~id          -- this thread: an event thread now
  l~Text = "I am event thread" self~threadId
  self~form = f; self~label = l
  f~Shown += .net~handler(self, "SHOWN")
  forms~Application~Run(f)                            -- this thread's message loop, until it closes
  self~closed = .true

::method shown unguarded                               -- the window exists: messages can find it
  self~ready = .true

::method clicked unguarded                             -- on this window's thread
  self~clicks += 1
  self~label~Text = "Clicked" self~clicks "time(s) on event thread" .NetEventThread~current~id

::method click unguarded                               -- from any thread: a click, run on the window's
  .NetEventThread~eventThreadFor(self~label)~runLater(self, "CLICKED")

::method where unguarded                               -- run by runLater: which event thread is this?
  return .NetEventThread~current~makeString
