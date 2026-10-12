/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 1995, 2004 IBM Corporation. All rights reserved.             */
/* Copyright (c) 2005-2014 Rexx Language Association. All rights reserved.    */
/*                                                                            */
/* This program and the accompanying materials are made available under       */
/* the terms of the Common Public License v1.0 which accompanies this         */
/* distribution. A copy is also available at the following address:           */
/* https://www.oorexx.org/license.html                                        */
/*                                                                            */
/* Redistribution and use in source and binary forms, with or                 */
/* without modification, are permitted provided that the following            */
/* conditions are met:                                                        */
/*                                                                            */
/* Redistributions of source code must retain the above copyright             */
/* notice, this list of conditions and the following disclaimer.              */
/* Redistributions in binary form must reproduce the above copyright          */
/* notice, this list of conditions and the following disclaimer in            */
/* the documentation and/or other materials provided with the distribution.   */
/*                                                                            */
/* Neither the name of Rexx Language Association nor the names                */
/* of its contributors may be used to endorse or promote products             */
/* derived from this software without specific prior written permission.      */
/*                                                                            */
/* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS        */
/* "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT          */
/* LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS          */
/* FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT   */
/* OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,      */
/* SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED   */
/* TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,        */
/* OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY     */
/* OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING    */
/* NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS         */
/* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.               */
/*                                                                            */
/*----------------------------------------------------------------------------*/

/**
 *   Name: usewmgr.rex
 *   Type: Example ooRexx program
 *
 *   Description:  Demonstrates the use of the WindowsManager, the WindowObject,
 *                 and the WindowsClipboard classes.  Has some examples of
 *                 ooDialog usage.
 *
 *                 This example uses some of the public functions provided by
 *                 the windowsSystem.frm package. That framework contains
 *                 functions shared with other example programs shipped with
 *                 ooRexx that use winsystm.cls.
 *
 *   Note:         Because of language dependencies this example will not run
 *                 correctly on all language versions of Windows.  It assumes
 *                 the window titles are in English.  To run on a different
 *                 language version, change the window titles for the Calculator
 *                 and Notepad applications to the correct title for
 *                 the specific language version of Windows.
 *
 * (.NET version, through UI Automation, .NET's Clipboard and oodnet.cls: see
 * windowsSystem.frm. The WindowsManager's foreground window is the window
 * of UI Automation's FocusedElement; the WindowsClipboard is .NET's
 * Clipboard. The Calculator is driven by the framework's calc* routines
 * (the classic Calculator's menu, or today's navigation pane; its keys);
 * its hexadecimal mode is in its Programmer view (in Windows XP's it was in
 * the Scientific one). Notepad is minimized, maximized, restored and resized
 * through its WindowPattern and TransformPattern. What UI Automation cannot
 * do, as a user cannot, the program says instead of doing: change the
 * Calculator's title; disable, enable or hide Notepad's windows.
 * Unattended (argument "auto"): the message boxes show nothing, their text
 * is printed.)
 */

.NetDialog~auto = arg(1)~strip~caselessEquals("auto")    -- (.NET version) unattended

-- First, give the user a clue as to what is happening.
msg = "This ooRexx example program demonstrates controlling a"     || .endOfLine           || -
      "Windows application using .NET's UI Automation."            || .endOfLine~copies(2) || -
      "Information will be displayed using message boxes like"     || .endOfLine           || -
      "this one.  Push the ok button in them to continue the"      || .endOfLine           || -
      "demonstration."                                             || .endOfLine~copies(2) || -
      "You will see the Calculator and Notepad programs appear"    || .endOfLine           || -
      "on your screen, one at a time.  There are some short"       || .endOfLine           || -
      "pauses between actions.  Be patient during them."           || .endOfLine~copies(2) || -
      "On the other hand, if the pauses are too short for you,"    || .endOfLine           || -
      "you can increase the pauses by editing the code.  This"     || .endOfLine           || -
      "will provide a good excuse to explore the code, which"      || .endOfLine           || -
      "is an excellent way to learn.  Simply search for 'call"     || .endOfLine           || -
      "pause' in the code and increase the amount for any"         || .endOfLine           || -
      "pause that is is too short."                                || .endOfLine~copies(2) || -
      "In particular watch the Calculator program to see the"      || .endOfLine           || -
      "changes as it is remotely controlled.  The applications"    || .endOfLine           || -
      "will be closed automatically"
j = infoDialog(msg)

-- A simple demonstration of UI Automation.  Display the title and coordinates
-- of the current foreground window: the window of the element that has the
-- keyboard focus.
focused = .net~System~Windows~Automation~AutomationElement~FocusedElement   -- ooDialog: winMgr~ForegroundWindow
if focused \= .nil then do
  fg = topLevelOf(focused)
  msg = "Current foreground window" || '0d0a0d0a'x || -
        "  Window title:   " fg~Current~Name || '0d0a'x || -
        "  Window location:" coordinates(fg)
  j = infoDialog(msg)
end
else do
  msg = "UI Automation failed to find the foreground window."
  j = errorDialog(msg)
end

-- A more involved demonstration using the Windows Calculator application.  The
-- real work is done in the workWithCalc() routine.
calcPrg = getPathToSystemExe("calc.exe")
if calcPrg \== .nil then do
  ret = workWithCalc(calcPrg)
end
else do
  msg = "Faild to locate a definitive path to the Windows" || '0d0a'x || -
        "Calculator application.  Going to skip this part" || '0d0a'x || -
        "of the demonstration."
  j = errorDialog(msg)
end

-- An example similar to the Windows Calculator, but using Windows Notepad.
notepad = getPathToSystemExe("notepad.exe")
if notepad \== .nil then do
  ret = workWithNotepad(notepad)
end
else do
  msg = "Faild to locate a definitive path to the Windows" || '0d0a'x || -
        "Notepad application.  Going to skip this part of" || '0d0a'x || -
        "the demonstration."
  j = errorDialog(msg)
end

return 0

/* windowsSystem.frm contains public helper routines and also requires
 * oodnet.cls (the message dialogs) and net.cls (.NET).
 */
::requires "windowsSystem.frm"

::routine workWithCalc
  use strict arg calcPrg

  -- Start the Calculator program.
  call startProgram calcPrg                              -- ooDialog: "start" calcPrg

  -- Find the Calculator Window, if we don't find it, then end this portion of
  -- the demonstration.
  calc = findTheWindow("Calculator")
  if calc == .nil then return windowFailure("Calculator")

  -- Make the calculator the top-most window.
  call focusOn calc                                      -- ooDialog: calc~ToForeground
  call pause 2

  -- Switch to the scientific view.
  call calcSetView calc, "Scientific"                    -- ooDialog: calc~ProcessMenuCommand("&View","&Scientific")
  call pause 2

  /* The original's Calculator made a new window when its view changed: it
   * found it again after each change.  We do too: it does no harm.
   */
  calc = findTheWindow("Calculator")
  if calc == .nil then return windowFailure("Calculator")
  call focusOn calc

  /* Each button of the Calculator is pushed through UI Automation, by
   * calcKey(), with its label: see windowsSystem.frm.
   */

  /* The clipboard: .NET's Clipboard */
  cb = .net~System~Windows~Forms~Clipboard                -- ooDialog: cb = .WindowsClipboard~new

  /* Switch between Scientific and Standard view */
  call calcSetView calc, "Standard"                      -- ooDialog: calc~ProcessMenuCommand("&View","S&tandard")
  call pause 2
  calc = findTheWindow("Calculator")
  if calc == .nil then return windowFailure("Calculator")
  call calcSetView calc, "Scientific"
  call pause 2
  calc = findTheWindow("Calculator")
  if calc == .nil then return windowFailure("Calculator")

  -- The original changed the Calculator's title here: "Calculator - Open
  -- Object Rexx is in charge!".  UI Automation cannot: a user cannot either.
  say "(UI Automation does not change another program's title.)"

  -- Do a few calculations and retrieve the results via the clipboard
  call keys calc, "7 + 5 ="                              -- ooDialog: calc~sendCommand(seven) ...

  msg = "Calculator says: 7+5="copied(calc, cb)
  j = infoDialog(msg)
  call pause 2

  call keys calc, "/ 1 . 5 ="

  msg = "Calculator says: 7+5/1.5="copied(calc, cb)
  j = infoDialog(msg)

  call keys calc, "* 3 ="

  msg = "Calculator says: 7+5/1.5*3="copied(calc, cb)
  j = infoDialog(msg)
  call pause 2

  -- Switch to hexadecimal mode: in the Programmer view, which starts again
  -- from 0: the answer, still on the clipboard, is pasted there first.
  call calcSetView calc, "Programmer"
  call calcPaste calc
  call calcKey calc, "Hex"                               -- ooDialog: calc~pushButton("Hex")
  msg = "Calculator says: 7+5/1.5*3="copied(calc, cb) " (HEX)"
  j = infoDialog(msg)
  call pause 2

  -- Switch back to decimal mode, and to the Scientific view.
  call calcKey calc, "Dec"
  call calcSetView calc, "Scientific"

  -- Copy a number to the clipboard and from there to the calculator to
  -- demonstrate another way to enter numbers.
  call clip cb, "SETTEXT", "123456789"                    -- ooDialog: cb~copy("123456789")
  call calcPaste calc                                    -- ooDialog: calc~processMenuCommand("&Edit", "&Paste")
  call pause 2
  say "Pasted, the Calculator shows" calcDisplay(calc)

  -- Push the "Grads" radio button (the original clicked it with the mouse).
  call calcKey calc, "Grads"
  call pause 2

  -- Close the Calculator application, as its Close button would.
  windowPattern(calc)~Close                              -- ooDialog: calc~sendSysCommand("Close")

return 0

/* (.NET version) The Calculator's keys, by their labels, separated by blanks */
::routine keys
  use strict arg calc, labels
  do key over labels~makeArray(" ")
    call calcKey calc, key
  end
  return

/* (.NET version) The Calculator's answer copied to the clipboard, then read
   from it: the clipboard is emptied, the Calculator's Copy chosen, and we
   wait until the data is available (the original waited in a busy loop).
   The clipboard is one for every program: one that has it open makes
   .NET's Clipboard fail for a moment (ExternalException), so each use is
   tried again a few times (clip). */
::routine copied
  use strict arg calc, cb
  call clip cb, "CLEAR"                                  -- ooDialog: cb~empty
  call calcCopy calc                                     -- ooDialog: calc~processMenuCommand("&Edit", "&Copy")
  do 40 while \clip(cb, "CONTAINSTEXT")                  -- ooDialog: do while cb~IsDataAvailable = 0
    call SysSleep .05
  end
  return clip(cb, "GETTEXT")                             -- ooDialog: cb~Paste

/* (.NET version) A message to the Clipboard, tried again while another
   program has the clipboard open */
::routine clip
  use strict arg cb, message, ...
  args = .context~args~section(3)
  do 9
    try = clipTry(cb, message, args)
    if try[1] then return try[2]
    call SysSleep .1
  end
  return clipTry(cb, message, args, .true)[2]           -- (the last time: its error, if any)

::routine clipTry
  use strict arg cb, message, args, last = .false
  if \last then signal on syntax
  cb~sendWith(message, args)
  if symbol("RESULT") == "VAR" then return .array~of(.true, result)
  return .array~of(.true, "")
syntax:
  return .array~of(.false)

::routine workWithNotepad
  use strict arg notePrg

  -- Start the Notepad program.
  call startProgram notePrg                              -- ooDialog: "start" notePrg

  np = findTheWindow("Untitled - Notepad")
  if np == .nil then return windowFailure("Notepad")

  -- Move Notepad to foreground.
  call focusOn np                                        -- ooDialog: np~toForeground

  -- The text area: the edit window, the first (and perhaps only) child window
  -- of the classic Notepad.
  npe = findTextArea(np)                                 -- ooDialog: np~firstChild
  if npe == .nil then return windowFailure("Notepad")

  -- sendText() types text into a window: SendKeys, once the window has the
  -- focus.
  call sendText npe, "Hello,"

  -- The sendKey() function types a key, by its virtual key name.
  call sendKey npe, "RETURN"

  -- SendKeys waits until the keys are processed: the pauses mimic a user.
  j = sendTextWithPause(npe, "This is a sample that mainly demonstrates the use")
  j = sendKeyWithPause(npe, "RETURN")
  j = sendTextWithPause(npe, "of .NET's UI Automation.")
  j = sendKeyWithPause(npe, "RETURN")
  j = sendKeyWithPause(npe, "RETURN")
  j = sendTextWithPause(npe, "It also introduces its patterns, and .NET's")
  j = sendKeyWithPause(npe, "RETURN")
  j = sendTextWithPause(npe, "Clipboard class.")
  j = sendKeyWithPause(npe, "RETURN")
  j = sendKeyWithPause(npe, "RETURN")
  call sendText npe, "In 1 second intervals I'm going to minimize, maximize, restore,"
  j = sendKeyWithPause(npe, "RETURN")
  call sendText npe, "and resize Notepad."
  j = sendKeyWithPause(npe, "RETURN")
  call pause 3

  -- A window's WindowPattern: its visual state, as its title bar's buttons.
  wp = windowPattern(np)
  wp~SetWindowVisualState("Minimized")                   -- ooDialog: np~minimize
  call pause 1
  wp~SetWindowVisualState("Maximized")                   -- ooDialog: np~maximize
  call pause 1
  wp~SetWindowVisualState("Normal")                      -- ooDialog: np~restore
  call pause 1

  -- Change the size of the Notepad window.
  j = resizeWindow(np, 650, 280)                         -- ooDialog: np~resize(650, 280)

  -- The original disabled Notepad's window here (its menu could not be used),
  -- then its edit window, then hid the edit window, enabling and showing them
  -- again.  UI Automation does what a user can do: it cannot.
  j = sendKeyWithPause(npe, "RETURN")
  j = sendTextWithPause(npe, "(The original disabled and hid Notepad's windows here:")
  j = sendKeyWithPause(npe, "RETURN")
  j = sendTextWithPause(npe, "UI Automation acts as a user, who cannot.)")
  call pause 2
  j = sendKeyWithPause(npe, "RETURN")
  j = sendKeyWithPause(npe, "RETURN")
  call sendText npe, "The show is over. Good bye in 3 seconds!"

  -- The Save dialog's button that discards the text (UI Automation names it
  -- without its '&'; findDescendent ignores case: Windows 11 says "Don't save").
  if isVistaOrLater() then buttonName = "Don't Save"
  else buttonName = "No"

  call pause 2

  -- Close Notepad as its Close button would.
  wp~Close                                               -- ooDialog: np~sendSysCommand("Close")

  -- Wait for the dialog that asks whether to save the changes: Notepad's
  -- descendant (as UI Automation shows it), whose Don't Save button we push.
  call pause 1
  button = .nil
  signal on syntax name gone                             -- (Notepad closed: it did not ask)
  do 10 while button == .nil
    button = findDescendent(np, buttonName)
    if button == .nil then call SysSleep .3
  end
  signal off syntax
  if button \== .nil then do
    -- Push the Don't Save button, which closes Notepad.
    button~GetCurrentPattern(.net~System~Windows~Automation~InvokePattern~Pattern)~Invoke   -- ooDialog: fg~focusItem(button), button~SendKey("SPACE")
  end
  else do
    msg = 'Could not locate the' buttonName 'button used to ' || '0d0a'x || -
          'discard the text changes.  findDescendent() failed' || '0d0a0d0a'x || -
          'You will have to close the Notepad windows manually.'
    j = errorDialog(msg)
  end

return 0

gone:
  say "Notepad closed without asking whether to save the text (it keeps it itself)."
  return 0

/* (.NET version) A pause between the steps: SysSleep, shorter when nobody
   watches (argument "auto") */
::routine pause
  use strict arg seconds
  if .NetDialog~auto then seconds = seconds / 4
  call SysSleep seconds
  return

/** windowFailure()
 * A simple helper function to put up an error message box.
 */
::routine windowFailure
  use strict arg name

  msg = "Failed to locate the" name "application window." || '0d0a0d0a'x || -
        "Ending the" name "demonstration prematurely."
  j = errorDialog(msg)

return .false
