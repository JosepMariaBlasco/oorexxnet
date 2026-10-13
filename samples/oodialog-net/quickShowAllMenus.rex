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
 *   Name: quickShowAllMenus.rex
 *   Type: Example ooRexx program
 *
 *   Description:  The main purpose of this example is to demonstrate how you
 *                 can quickly put together an ooRexx script that does real
 *                 work once you have a created a package of useful functions.
 *
 *                 This program uses the windowsSystem.frm package to print out
 *                 a menu outline of every open window that has a menu.
 *
 *   The below table lists the external functions and classes used in this
 *   program and shows where to go to examine the source code for them.
 *
 *   External function            Source
 *   ---------------------------------------------------
 *   MenuDetailer                 windowsSystem.frm
 *
 * (.NET version, through UI Automation: see windowsSystem.frm. The top-level
 * windows are the root element's children, listed first; a window has a menu
 * when it has a MenuBar element (findMenuBar). The MenuDetailer opens each
 * menu to read it: every window with a menu comes to the foreground in turn,
 * and its menus open and close. The MenuDetailer is made for the first window with
 * a menu (the original made it for the desktop window). Unattended
 * (argument "auto"): Notepad is started first, so that one window at least
 * has a menu, and closed at the end.)
 */

  .NetDialog~auto = arg(1)~strip~caselessEquals("auto")  -- (.NET version) unattended
  if .NetDialog~auto then do
    call startProgram getPathToSystemExe("notepad.exe")
    np = findNotepadWindow()
  end

  -- The desktop window is UI Automation's root element.
  A = .net~System~Windows~Automation
  deskTop = A~AutomationElement~RootElement               -- ooDialog: mgr = .WindowsManager~new, mgr~desktopWindow

  -- The MenuDetailer, made for the first window that has a menu.
  menuLister = .nil

  -- Keep track of how many windows we found, and how many have a menu.
  windowCount = 0
  menuCount  = 0

  -- Enumerate all the desktop child windows, printing a menu outline for each
  -- window that has a menu.
  --
  -- Note this:  many up-to-date Windows applications no longer use true menus.
  -- Instead they use a number of new Windows controls that give the appearance
  -- of menus.  UI Automation shows most of them as menus too.
  --
  -- (.NET version) The windows are listed first, then looked at: opening a
  -- window's menus brings it to the foreground, which changes the order of the
  -- windows; walking them with the TreeWalker as the original did, with
  -- firstChild and next, would visit some of them again and again.
  windows = deskTop~FindAll(A~TreeScope~Children, A~Condition~TrueCondition)   -- ooDialog: deskTop~firstChild, child~next
  do child over windows
    windowCount += 1
    if findMenuBar(child) <> .nil then do                 -- ooDialog: child~menu
      menuCount += 1

      if menuLister == .nil then menuLister = .MenuDetailer~new(child)
      else menuLister~setWindow(child)
      menuLister~print
      say; say
    end
  end

  say 'Found' windowCount 'windows, of which' menuCount 'had menus.'

  if .NetDialog~auto, np \== .nil then windowPattern(np)~Close   -- (.NET version)

::requires 'windowsSystem.frm'
