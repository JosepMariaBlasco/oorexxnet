/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 2008-2014 Rexx Language Association. All rights reserved.    */
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
 *   Name: writeWithNotepad.rex
 *   Type: Example ooRexx program
 *
 *   Description:  An example of using the winsystm.cls classes to control the
 *                 Notepad application.  It is a subset of the usewmgr.rex
 *                 example, intended to be simplier and maybe easier to see what
 *                 is happening.
 *
 *                 This example uses some of the public functions provided by
 *                 the windowsSystem.frm package. That framework contains
 *                 functions shared with other example programs shipped with
 *                 ooRexx that use winsystm.cls.
 *
 *   External function            Source
 *   ---------------------------------------------------
 *   getPathToSystemExe()         windowsSystem.frm
 *   errorDialog()                ooDialog
 *   findTheWindow()              windowsSystem.frm
 *   sendTextWithPause()          windowsSystem.frm
 *   sendKeyWithPause()           windowsSystem.frm
 *   isVistaOrLater()             windowsSystem.frm
 *   getWindowTree()              windowsSystem.frm
 *   showWindowTree()             windowsSystem.frm
 *   findDescendent()             windowsSystem.frm
 *
 * (.NET version, through UI Automation: see windowsSystem.frm. Notepad's
 * text area is found among its descendants (findTextArea: the Windows 11
 * Notepad has it deeper than the first child); the text is typed into it
 * (sendTextWithPause: SendKeys); the window is resized with its
 * TransformPattern and closed with its WindowPattern; the Don't Save button
 * is pushed with its InvokePattern. The Save dialog is that button's window:
 * in the classic Notepad a dialog of its own, in the Windows 11 Notepad a
 * part of its window. A Notepad that keeps unsaved text itself (Windows 11's,
 * restoring its last session) closes without asking: the program says so.
 * Unattended (argument "auto"): no pause to read the text, the dialogs show
 * nothing.)
 *
 * The external functions used by this program allow you to read through the
 * code here and get the over-all picture of how the program works.  To
 * understand the finer details, you will need to look at the implementation
 * of the external functions contained in windowsSystem.frm.
 */

.NetDialog~auto = arg(1)~strip~caselessEquals("auto")    -- (.NET version) unattended

-- Get the full path to notepad to be sure we start the right application.
notepadExe = getPathToSystemExe("notepad.exe")

-- Quit if we can't get the path.  Let the user know why we are quitting.
if notepadExe == .nil then do
  msg = "Faild to locate a definitive path to the Windows" || '0d0a'x || -
        "Notepad application.  This sample can not execute."
  return errorDialog(msg)
end

-- This will start notepad as a separate process.
call startProgram notepadExe                             -- ooDialog: "start" notepadExe

-- When Notepad is started without a file name as an argument, its title will be
-- 'Untitled - Notepad'  We try to find that window, quitting if we can not.
-- Note that findTheWindow() tries several times to locate the window, but will
-- eventually time out.  Again, we let the user know why we are quitting if we
-- do.

np = findNotepadWindow()                                 -- ooDialog: findTheWindow("Untitled - Notepad")
if np == .nil then do
  msg = "Could not find the Notepad application window." || '0d0a0d0a'x || -
        "This sample will have to abort."
  return errorDialog(msg)
end

-- Make sure the size of the Notepad window is wide enough for our text.
j = resizeWindow(np, 650, 500)                           -- ooDialog: np~resize(650, 500)

-- Move Notepad to the foreground.
call focusOn np                                          -- ooDialog: np~ToForeground

-- Get the text area: the edit window, the first (and perhaps only) child
-- window of the classic Notepad.
editWnd = findTextArea(np)                               -- ooDialog: np~FirstChild
if editWnd == .nil then do
  msg = "Could not find the text area of Notepad." || '0d0a0d0a'x || -
        "This sample will have to abort."
  windowPattern(np)~Close
  return errorDialog(msg)
end

-- Put some text into Notepad, if the user reads it, she will have a clue as to
-- what is going to happen.
j = SysSleep(.01)
j = sendTextWithPause(editWnd, "Hello,")
j = sendKeyWithPause(editWnd, "RETURN")
j = sendKeyWithPause(editWnd, "RETURN")
j = sendTextWithPause(editWnd, "When the Notepad Save dialog window opens, wait a second or two.  ")
j = sendKeyWithPause(editWnd, "RETURN")
j = sendTextWithPause(editWnd, "Then a dialog window will open that will allow you to explore the")
j = sendKeyWithPause(editWnd, "RETURN")
j = sendTextWithPause(editWnd, "window hierarchy of the Save dialog.  When you close that dialog, ")
j = sendKeyWithPause(editWnd, "RETURN")
j = sendTextWithPause(editWnd, "Notepad will close automatically.  (If things work correctly.)")
j = sendKeyWithPause(editWnd, "RETURN")
j = sendKeyWithPause(editWnd, "RETURN")
j = sendTextWithPause(editWnd, "The show is over. Good bye in several seconds.")
j = sendKeyWithPause(editWnd, "RETURN")

-- (.NET version) What Notepad has now: its text area's TextPattern.
A = .net~System~Windows~Automation
r = .net~ref
if editWnd~TryGetCurrentPattern(A~TextPattern~Pattern, r) then do
  lines = r~value~DocumentRange~GetText(-1)~changeStr('0d0a'x, '0a'x)~changeStr('0d'x, '0a'x)~strip("T", '0a'x)~makeArray('0a'x)
  say "Notepad has" lines~items "lines; the first:" lines[1]
end

-- The Save dialog's button that discards the text: discardButton() finds it by
-- its AutomationId, whatever Windows' language (the original: by its name,
-- "Do&n't Save", "&No" before Vista).
buttonName = "Don't Save"

-- Pause a little bit to allow the user to read the text.
if \.NetDialog~auto then j = SysSleep(5)

-- Close Notepad as its Close button would: its WindowPattern's Close.
windowPattern(np)~Close                                  -- ooDialog: np~SendSysCommand("Close")

/* When Notepad closes, it will put up a dialog asking if we want to save the
 * changes we just wrote to a file.  We will wait a second for the dialog and
 * then use the Don't Save button to discard our text.
 *
 * Initially, functions like getWindowTree() and showWindowTree() or
 * printWindowTree() were very useful in discovering the interface changes in
 * Notepad on Vista: they show UI Automation's view of it here.
 */

-- Wait a second and then look for the button among Notepad's descendants (UI
-- Automation shows the dialog Notepad opens as one of them).  If we encounter
-- errors, inform the user as to what they were.
j = SysSleep(1)
button = .nil
signal on syntax name gone                               -- (Notepad closed: UI Automation's ElementNotAvailableException)
do 10 while button == .nil
  button = discardButton(np)
  if button == .nil then j = SysSleep(.3)
end
signal off syntax
if button \== .nil then do
  fg = windowOf(button)                                  -- ooDialog: fg = winMgr~ForegroundWindow
  j = SysSleep(.1)

  -- Display the window hierarchy of the Save dialog.
  tree = getWindowTree(fg)
  success = showWindowTree(tree)

  -- Push the Don't Save button, which has the effect of closing Notepad
  -- automatically.
  button~GetCurrentPattern(A~InvokePattern~Pattern)~Invoke   -- ooDialog: fg~focusItem(button), button~SendKey("SPACE")
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

::requires "windowsSystem.frm"
