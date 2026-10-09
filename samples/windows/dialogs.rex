/* dialogs.rex: message boxes and the common file dialog.
   MessageBox.Show takes its buttons and icon as enum names and returns the
   button chosen (a DialogResult, compared with its name). The file dialog
   needs a single-threaded apartment, which the bridge gives every Rexx
   thread on Windows. "rexx dialogs.rex auto" shows nothing.              */

forms = .net~System~Windows~Forms
say "This thread's apartment:" .net~System~Threading~Thread~CurrentThread~GetApartmentState
if arg(1)~strip~caselessEquals("auto") then do
  say "auto: no dialogs shown"
  exit 0
end

answer = forms~MessageBox~Show("Do you like Rexx?", "dialogs.rex", "YesNoCancel", "Question")
select
  when answer = "Yes" then say "Of course."
  when answer = "No"  then say "Give it time."
  otherwise                say "Cancelled ("answer")."
end

d = forms~OpenFileDialog~new
d~Title = "Choose a Rexx program"
d~Filter = "Rexx programs (*.rex;*.cls)|*.rex;*.cls|All files (*.*)|*.*"
d~InitialDirectory = directory()
if d~ShowDialog = "OK" then do
  file = d~FileName
  info = .net~System~IO~FileInfo~new(file)
  say "You chose" info~Name "("info~Length "bytes," .net~System~IO~File~ReadAllLines(file)~items "lines)."
  forms~MessageBox~Show(info~Name "has" info~Length "bytes.", "dialogs.rex", "OK", "Information")
end
else say "No file chosen."

::requires "net.cls"
