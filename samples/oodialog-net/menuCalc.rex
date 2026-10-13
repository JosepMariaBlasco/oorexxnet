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
 *   Name: menuCalc.rex
 *   Type: Example ooRexx program
 *
 *   Description:  Displays the menu hierarchy of the Windows Calculator
 *                 application.  The menu hierachy for both the Calculator's
 *                 standard view and its scientific view are printed to the
 *                 console.
 *
 *                 This is a very simple program so that it is easeier to see
 *                 the details.
 *
 *                 The example uses a mixture of ooDialog and winsystm.
 *
 *                 In addition, the example uses some of the public functions
 *                 provided by the windowsSystem.frm package. That framweowork
 *                 is an example of how to extract common function into a
 *                 package and share that function with any number of ooRexx
 *                 programs.
 *
 *   The below table lists the external functions and classes used in this
 *   program and shows where to go to examine the source code for them.
 *
 *   External function            Source
 *   ---------------------------------------------------
 *   getPathToSystemExe()         windowsSystem.frm
 *   errorDialog()                ooDialog
 *   findTheWindow()              windowsSystem.frm
 *   MenuDetailer                 windowsSystem.frm
 *
 * (.NET version, through UI Automation: see windowsSystem.frm. The
 * MenuDetailer reads the Calculator's menu by opening its menus, as a user
 * would. Today's Calculator has no menu: it says so, and its views are
 * switched in its navigation pane (calcSetView()). Whether the Calculator
 * is in its standard view is told by its keys (calcView()): UI Automation
 * does not tell whether a classic menu's radio item is checked. Unattended
 * (argument "auto"): the same, its dialogs showing nothing.)
 */

.NetDialog~auto = arg(1)~strip~caselessEquals("auto")    -- (.NET version) unattended

-- Get the complete path to the calculator application to be sure we start the
-- the program we want.
calcExe = getPathToSystemExe("calc.exe")

-- If we could not get the complete path, just quit.
if calcExe == .nil then do
  msg = "Faild to locate a definitive path to the Windows" || '0d0a'x || -
        "Calculator application.  This sample can not execute."
  return errorDialog(msg)
end

-- This will start the calculator application as a separate process.
call startProgram calcExe                                -- ooDialog: "start" calcExe

-- Get the calculator window, quit if that fails.
calcWnd = getCalcWindow()
if calcWnd == .nil then return 99

-- First, display the menu for the 'Standard' view.  The calculator application
-- may already be in the standard view.  But, if it is not, we will first switch
-- to that view.
--
-- The way we switch to Standard view is to simulator clicking on the View menu,
-- and then clicking the Standard menu item: calcSetView() does that.

if \ inStandardView(calcWnd) then do
  call calcSetView calcWnd, "Standard"                   -- ooDialog: calcWnd~ProcessMenuCommand("&View","S&tandard")
  calcWnd = getCalcWindow()
  if calcWnd == .nil then return 99
end

-- To print the menu, we instantiate a MenuDetailer object using the Calculator
-- window.  Then we tell the menu detailer object to 'print.'  Printing sends
-- the output to the console.

say; say "Printing the Calculator's Standard View menu"
menuDetail = .MenuDetailer~new(calcWnd)
menuDetail~print

-- Switch to the Scientific view and print that menu.  Switching to Scientific
-- view is done as above, we simulate clicking on the Scientific menu item.
--
-- We find the window again after switching views (the original's Calculator
-- made a new window for each view), and we need a new MenuDetailer object.

call calcSetView calcWnd, "Scientific"                   -- ooDialog: calcWnd~ProcessMenuCommand("&View","&Scientific")
calcWnd = getCalcWindow()
if calcWnd == .nil then return 99

say; say; say "Printing the Calculator's" calcView(calcWnd) "View menu"
menuDetail = .MenuDetailer~new(calcWnd)
menuDetail~print

-- Now close the Calculator, as its Close button would.
windowPattern(calcWnd)~Close                             -- ooDialog: calcWnd~SendSysCommand("Close")

return 0

::requires 'windowsSystem.frm'

/** getCalcWindow()
 * A simple helper routine.  We need to find and re-find the calculator window
 * several times.  Each time we need to check for .nil and notify the user if
 * there is an error.
 *
 * The same steps, repeated more than once, is a good signal to put the code
 * into its own routine (or own method when using objects.)
 */
::routine getCalcWindow

  calcWnd = findCalcWindow()                             -- ooDialog: findTheWindow("Calculator")
  if calcWnd == .nil then do
    msg = "Could not find the Calculator application window." || '0d0a0d0a'x || -
          "This sample with have to abort."
    j = errorDialog(msg)
  end
return calcWnd

/** inStandardView()
 * Another simple helper routine.
 *
 * This tests if the calculator is in standard view.  The original saw whether
 * the menu item for the standard view was checked; UI Automation does not
 * tell that of a classic menu's radio item, so calcView() looks at the keys
 * the Calculator shows.
 */
::routine inStandardView
  use strict arg calc

return calcView(calc) == "Standard"
