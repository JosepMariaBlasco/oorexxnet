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
 *   Name: displayAnyMenu.rex
 *   Type: Example ooRexx program
 *
 *   Description:  Displays the menu hierarchy for a window that the user picks.
 *
 *                 The user is prompted for the title of an open, top-level,
 *                 window.  This program then parses the details of the menubar
 *                 for that window and displays them graphically.
 *
 *                 The example uses a mixture of ooDialog and winsystm.
 *
 *                 In addition, the example uses some of the public functions
 *                 provided by the windowsSystem.frm package. That framweowork
 *                 is an example of how to extract common function into a
 *                 package and share that function with any number of ooRexx
 *                 programs.
 *
 *   The table below lists the external functions and classes used in this
 *   program and shows where to go to examine the source code for them.
 *
 *   External function            Source
 *   ---------------------------------------------------
 *   RcDialog                     ooDialog
 *   errorDialog()                ooDialog
 *   askDialog()                  ooDialog
 *   infoDialog()                 ooDialog
 *   MenuDetailer                 windowsSystem.frm
 *   findTheWindow()              windowsSystem.frm
 *
 * (.NET version, through oodnet.cls and UI Automation: see windowsSystem.frm.
 * The prompt is WinSystemDlgs_IDD_USER_PROMPT, from winSystemDlgsrc.cls; the
 * MenuDetailer reads the window's menus by opening them, as a user would.
 * Unattended (argument "auto"): Notepad is started, its title typed into the
 * prompt, its menu shown, and it is closed at the end.)
 */

.NetDialog~auto = arg(1)~strip~caselessEquals("auto")    -- (.NET version) unattended
if .NetDialog~auto then call startProgram getPathToSystemExe("notepad.exe")

-- Prompt the user for a window title
dlg = .UserPrompt~new                                    -- ooDialog: .UserPrompt~new(sd"winSystemDlgs.rc", IDD_USER_PROMPT)
if dlg~initCode <> 0 then do
  msg = "Error initializing the UserPrompt dialog." || '0d0a0d0a'x || -
        "The dislplayAnyMenu example will have to quit."
  j = errorDialog(msg)
  return 99
end

-- A return of 2 means the user canceled, and we will just quit.
if dlg~execute("SHOWTOP") == 2 then return 2

-- The UserPrompt dialog validates the data, i.e. it enforces that either a
-- window is found, or that the user cancels.  Here, we ask the dialog for the
-- window (an AutomationElement) that the user picked, create a MenuDetailer
-- object using that window, and then display the menu.
topWnd = dlg~getUserPick
md = .MenuDetailer~new(topWnd)
md~display

if .NetDialog~auto then windowPattern(topWnd)~Close     -- (.NET version)

-- Return 0 for okay
return 0

::requires 'windowsSystem.frm'

/** class UserPrompt
 * Our user prompt dialog subclasses WinSystemDlgs_IDD_USER_PROMPT, the
 * .rc's dialog.  We just over-ride the ok method to take care of validating
 * the user input.  We also add a method, getUserPick(), which is used to
 * return the window the user selected.
 */
::class 'UserPrompt' subclass WinSystemDlgs_IDD_USER_PROMPT

/** ok()
 * The over-ride of the ok() method is basically simple.  It verifies that the
 * user entered something in the edit control and then attempts to find the
 * window.  If the window can not be found, the user is asked whether to try
 * again.
 */
::method ok
  expose wnd edit

  -- Get the edit control (a .NET TextBox) and then the text the user entered.
  if \ var("EDIT") then edit = self~newEdit(IDC_EDIT_NAME)
  title = edit~Text~strip                                -- ooDialog: edit~getText~strip

  -- Check that the user entered something.
  if title~length == 0 then do
    msg = "You must enter the title of a window whose menu" || '0d0a'x || -
          "you want displayed." || '0d0a0d0a'x || -
          "Would you rather cancel?"
    if askDialog(msg) then return self~cancel
    else return
  end

  -- Warn the user that finding the window may take a little bit of time.
  msg = "It may take a second or two find the window" || '0d0a'x || -
        "you picked.  Be patient." || '0d0a0d0a'x || -
        "This dialog will be disabled during the search."
  j = infoDialog(msg)

  -- Disable the dialog so that an impatient user can not fiddle with it.
  self~disable
  edit~Enabled = .false                                  -- ooDialog: edit~disable
  self~disableItem(IDOK)
  self~disableItem(IDCANCEL)

  -- The big step, find the window with the title entered by the user.
  wnd = findTheWindow(title)

  -- Re-enable the dialog.
  self~enable
  edit~Enabled = .true
  self~enableItem(IDOK)
  self~enableItem(IDCANCEL)

  -- If we don't have a window, give the user a chance to try again, or to
  -- cancel.  If the user does not want to try again, we end the dialog by
  -- invoking our cancel() method.
  if wnd == .nil then do
    msg = "Failed to find the window with title:" || '0d0a'x || -
          " " title || '0d0a0d0a'x || -
          "The window title has to match exactly." || '0d0a0d0a'x || -
          "Try again?"
    if askDialog(msg) then return
    else return self~cancel
  end

  -- Okay, we have a window.  We end the dialog by invoking the superclass
  -- ok() method.
  return self~ok:super

::method cancel
  expose wnd
  wnd = .nil
  return self~cancel:super

::method getUserPick
  expose wnd
  return wnd

::method autoRun                       -- (.NET version) unattended: Notepad's title typed, then OK
  edit = self~newEdit(IDC_EDIT_NAME)
  edit~Text = "Untitled - Notepad"
  say "(auto) title:" edit~Text
  self~ok
