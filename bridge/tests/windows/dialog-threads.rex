/* dialog-threads.rex: a manual check, on Windows, of a common dialog shown
   from Rexx threads: the main one, then one made by START, then one made by
   START while the main thread runs a form's message loop (CLR.CLS's 12-savefile
   does that). Each step says where it is: a step that never ends shows where
   it hangs.

       cd <the bridge's build>  &&  rexx <this file>

   Cancel each dialog (or save: nothing is written). */
say "1. main thread:" apartment()
call show "main thread"

say "2. a thread made by START"
m = .Step~new~start("dialog", "started thread")
say "   ... its result:" m~result

say "3. a thread made by START, from a click, while the main thread runs Application.Run"
form = .net~type("System.Windows.Forms.Form")~new
form~Text = "dialog-threads: click the button"
button = .net~type("System.Windows.Forms.Button")~new
button~Text = "Open the dialog"
button~AutoSize = .true
form~Controls~Add(button)
button~Click += .net~handler(.Click~new(form), "INVOKE")
say "   (click the button, cancel the dialog; the form closes by itself)"
.net~type("System.Windows.Forms.Application")~Run(form)
say "done"
exit

apartment: return .net~System~Threading~Thread~CurrentThread~GetApartmentState~string

show:
  use arg where
  d = .net~type("System.Windows.Forms.SaveFileDialog")~new
  d~FileName = "dialog-threads.txt"
  say "   ShowDialog on the" where "..."
  r = d~ShowDialog
  say "   ... returned" r
  return r

::requires "net.cls"

::class Step
::method dialog
  use arg where
  say "   " where":" .net~System~Threading~Thread~CurrentThread~GetApartmentState~string
  d = .net~type("System.Windows.Forms.SaveFileDialog")~new
  say "   ShowDialog on the" where "..."
  r = d~ShowDialog
  say "   ... returned" r
  return r

::class Click
::method init
  expose form
  use arg form
::method invoke
  expose form
  say "   click: on the main thread, starting a thread"
  .Closer~new~start("run", form)

::class Closer
::method run
  use arg form
  r = .Step~new~dialog("thread started from the click")
  say "   closing the form"
  form~Close
  return
