/* forms-hello.rex: a Windows Forms window, built and driven from Rexx.
   A label, a text box and a button; the button's Click event runs a Rexx
   method. Application.Run shows the window and runs its message loop on
   this thread; the Click handler runs on it too, while Run waits.
   "rexx forms-hello.rex auto" fills the box, clicks and closes by itself. */

forms = .net~System~Windows~Forms
drawing = .net~System~Drawing
forms~Application~EnableVisualStyles

form = forms~Form~new
form~Text = "Hello from Rexx"
form~ClientSize = drawing~Size~new(340, 110)
form~StartPosition = "CenterScreen"                -- an enum, by its name
form~FormBorderStyle = "FixedDialog"
form~MaximizeBox = .false

label = forms~Label~new
label~Text = "Type your name and press the button (or Enter)."
label~Location = drawing~Point~new(12, 14)
label~AutoSize = .true

box = forms~TextBox~new
box~Location = drawing~Point~new(12, 44)
box~Width = 220

button = forms~Button~new
button~Text = "Greet"
button~Location = drawing~Point~new(244, 42)
button~Width = 84

form~Controls~Add(label)
form~Controls~Add(box)
form~Controls~Add(button)
form~AcceptButton = button                          -- Enter clicks it

greeter = .Greeter~new(label, box)
button~Click += .net~handler(greeter, "CLICK")

if arg(1)~strip~caselessEquals("auto") then call auto form, box, button
forms~Application~Run(form)
say "Window closed after" greeter~count "greeting(s)."
exit

auto: procedure                                     -- for unattended runs
  use arg form, box, button
  timer = .net~System~Windows~Forms~Timer~new
  timer~Interval = 800
  timer~Tick += .net~handler(.Auto~new(form, box, button, timer), "TICK")
  timer~Start
  return

::requires "net.cls"

::class Greeter
::attribute count get
::method init
  expose label box count
  use arg label, box
  count = 0
::method click                                      -- sender, EventArgs
  expose label box count
  name = box~Text~strip
  if name == "" then name = "stranger"
  count += 1
  label~Text = "Hello," name"! (greeting" count")"
  say label~Text

::class Auto
::method init
  expose form box button timer
  use arg form, box, button, timer
::method tick
  expose form box button timer
  timer~Stop
  box~Text = "Rexx"
  button~PerformClick
  form~Close
