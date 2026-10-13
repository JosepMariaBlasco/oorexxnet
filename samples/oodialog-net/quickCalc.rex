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
 *   Description:  Demonstrates how to control an application programmatically
 *                 using the winsystm classes.  Does some simple calculations
 *                 using the Windows Calculator application.
 *
 *                 This program is similar to userwmgr.rex but more simple to
 *                 better show what is going on.
 *
 *                 This example uses some of the public functions provided by
 *                 the windowsSystem.frm package.  That framweowork is an
 *                 example of how to extract common function into a package and
 *                 share that function with any number of ooRexx programs.
 *
 *   To really understand how this program works, you will need to examine the
 *   the code for the external functions in windowsSystem.frm.
 *
 *   The table below lists the external functions and classes used in this
 *   program and shows where to go to examine the source code for them.
 *
 *   External function            Source
 *   ---------------------------------------------------
 *   errorDialog()                ooDialog
 *   infoDialog()                 ooDialog
 *   getPathToSystemExec()        windowsSystem.frm
 *   findTheWindow()              windowsSystem.frm
 *
 * (.NET version, through UI Automation: see windowsSystem.frm. The buttons
 * are pushed by calcKey(), with their labels: the classic Calculator's by
 * its control ids, as the original's sendCommand did (but Windows 7's ids:
 * Windows XP's, the original's, differ), today's by its AutomationIds. The
 * answer is what calcDisplay() reads. Unattended (argument "auto"): the
 * answers are printed.)
 */

.NetDialog~auto = arg(1)~strip~caselessEquals("auto")    -- (.NET version) unattended

-- Get the complete path to the calculator executable.  This ensures we start
-- the correct application.
calcExe = getPathToSystemExe("calc.exe")

-- Abort if we have an error.
if calcExe == .nil then do
  msg = "Faild to locate a definitive path to the Windows" || '0d0a'x || -
        "Calculator application.  This sample can not execute."
  return errorDialog(msg)
end

-- Start calculator as a separate process.
call startProgram calcExe                                -- ooDialog: "start" calcExe

-- It takes some finite period of time for an application to start.  This can
-- vary substantially depending on the system load.  findTheWindow() allows for
-- this, but will eventually time out if the window can not be located.
calc = findCalcWindow()                                  -- ooDialog: findTheWindow("Calculator")
if calc == .nil then do
  msg = "Could not find the Calculator application window." || '0d0a0d0a'x || -
        "This example program will have to abort."
  return errorDialog(msg)
end

-- Make the calculator the top-most window.
call focusOn calc                                        -- ooDialog: calc~ToForeground

/* Each button of the Calculator has an AutomationId.  The classic Calculator's
 * are the buttons' resource IDs, which its dialog gets in a command
 * (WM_COMMAND) notification when one is pushed (the original sent those
 * commands itself); today's Calculator names its buttons (num1Button,
 * plusButton...).  calcKey() pushes a button through UI Automation, as a
 * click would: its InvokePattern.  You can verify the AutomationIds by
 * exploring the Calculator with the displayWindowTree.rex example program.
 *
 * The answer field: calcDisplay() reads it (the original read the title of
 * the Calculator's first child window, an Edit).
 */

if calcDisplay(calc) == "" then do
  msg = "Failed to locate the answer field in the Calculator application." || '0d0a0d0a'x || -
        "This example program will have to abort."
  j = errorDialog(msg)

  -- Try to close the calculator application, although we may be hosed and this
  -- won't work.
  windowPattern(calc)~Close
  return 99
end

-- We will calculate 10 * 16.  After each button push we will pause a bit so
-- that the user can see the numbers appear on the calculator.  Then we will get
-- the answer and display a message box showing the whole thing.  This starts
-- our message.
msg = "10 * 16 ="

do key over .array~of("1", "0", "*", "1", "6", "=")       -- ooDialog: calc~sendCommand(one) ...
  call calcKey calc, key
  j = SysSleep(.5)
end

-- Now get the answer.
msg = msg calcDisplay(calc)                              -- ooDialog: answerField~title
j = infoDialog(msg)

-- Push the clear button
call calcKey calc, "C"

-- Do one more calculation.
msg = "(5 + 5) * 16 / (2 + 1) ="

call calcKey calc, "MC"

do key over .array~of("2", "+", "1", "=")
  call calcKey calc, key
  j = SysSleep(.5)
end

call calcKey calc, "MS"

do key over .array~of("5", "+", "5", "=", "*", "1", "6", "=")
  call calcKey calc, key
  j = SysSleep(.5)
end

call calcKey calc, "/"
call calcKey calc, "MR"
call calcKey calc, "="

-- Now get the answer.
msg = msg calcDisplay(calc)
j = infoDialog(msg)

-- Close the calculator, as its Close button would.
windowPattern(calc)~Close                                -- ooDialog: calc~sendSysCommand("Close")

::requires 'windowsSystem.frm'
