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
 *   Name: displayWindowTree.rex
 *   Type: Example ooRexx program
 *
 *   Description:  Allows the user to pick an open top-level window and then
 *                 displays the window hiearchy for that window.  The program
 *                 uses both ooDialog and winsystm classes.
 *
 *                 This example uses some of the public functions provided by
 *                 the windowsSystem.frm package. That framework contains
 *                 functions shared with other example programs shipped with
 *                 ooRexx that use winsystm.cls.
 *
 *   External function            Source
 *   ---------------------------------------------------
 *   errorDialog()                ooDialog
 *   getWindowTree()              windowsSystem.frm
 *   showWindowTree()             windowsSystem.frm
 *
 * (.NET version, through oodnet.cls and UI Automation: see windowsSystem.frm.
 * The top-level windows are the children of UI Automation's root element
 * (the original's desktop window's children), except this program's own: UI
 * Automation should not be asked about a program's windows from the thread
 * that runs them. The dialog is WinSystemDlgs_IDD_WINDOW_LIST, from
 * winSystemDlgsrc.cls; its list view a .NET ListView. Unattended (argument
 * "auto"): the first window's hierarchy is shown, then Quit.)
 */

.NetDialog~auto = arg(1)~strip~caselessEquals("auto")    -- (.NET version) unattended

-- Create and show our dialog.  The logic of the program is contained within
-- the WindowListDlg class.
dlg = .WindowListDlg~new                                 -- ooDialog: .WindowListDlg~new(sd"winSystemDlgs.rc", IDD_WINDOW_List)
if dlg~initCode == 0 then do
  dlg~execute("SHOWTOP")
  return 0
end
else do
  msg = "Failed to instantiate the .WindowListDlg object." || '0d0a0d0a'x || -
        "Aborting on error."
  j = errorDialog(msg)
  return 99
end


::requires "windowsSystem.frm"

::class 'WindowListDlg' public subclass WinSystemDlgs_IDD_WINDOW_LIST

/** initdialog()
 * Initialize the state of our dialog controls.
 */
::method initDialog
  expose listView windows inError

  inError = .false
  windows = .array~new

  -- The list view is a .NET ListView, in its Details view (the .rc's REPORT).
  listView = self~newListView(IDC_LV_WINDOWS)
  if listView == .nil then return self~putInErrorState("NOLISTVIEW")

  listView~FullRowSelect = .true                         -- ooDialog: addExtendedStyle("FULLROWSELECT LABELTIP")
  listView~ShowItemToolTips = .true

  -- One column, as wide as the list view, less a vertical scroll bar.
  width = listView~ClientSize~Width - .net~System~Windows~Forms~SystemInformation~VerticalScrollBarWidth
  listView~Columns~Add("Window Title", width)

  self~connectButtonEvent(IDC_PB_SHOW, "CLICKED", onShow)
  self~connectButtonEvent(IDC_PB_QUIT, "CLICKED", onQuit)
  self~connectButtonEvent(IDC_PB_REFRESH, "CLICKED", onRefresh)

  self~onRefresh

/** onRefresh()
 * This method contains the logic to populate the list view control with the
 * titles of the current top-level windows.  The method is connected to the
 * Refresh button, so it is invoked when the user pushes that button.
 *
 * However, it can also be invoked internally to populate the list view.  This
 * is done when the dialog is initialized, from the initDialog() method.  And
 * it is also invokde if a window has closed, in the onShow() method.
 */
::method onRefresh
  expose listView windows inError

  windows~empty
  listView~Items~Clear                                   -- ooDialog: listView~deleteAll

  -- The top-level windows: the root element's children, those with a title
  -- that are on the screen, and not this program's.
  A = .net~System~Windows~Automation
  AE = A~AutomationElement
  me = .net~int32(.net~System~Environment~ProcessId)
  notMine = A~NotCondition~new(A~PropertyCondition~new(AE~ProcessIdProperty, me))
  do child over AE~RootElement~FindAll(A~TreeScope~Children, notMine)   -- ooDialog: deskTop~firstChild, child~next
    if child~Current~Name~strip \== "", \child~Current~IsOffscreen then windows~append(child)
  end

  if windows~isEmpty then return self~putInErrorState("NOWINDOWS")

  do wnd over windows
    listView~Items~Add(wnd~Current~Name)                 -- ooDialog: listView~addRow( , ,  wnd~title)
  end

  listView~Items[0]~Selected = .true                     -- ooDialog: listView~select(0)

/** onShow()
 * The user pushed the 'Show' button.  In the unlikely event that we are in an
 * error state we will quit.  Otherwise, we will display the window hiearchy of
 * the window the user selected.
 */
::method onShow
  expose listView inError windows

  if inError then return self~cancel
  if listView~SelectedIndices~Count == 0 then return 0

  wnd = windows[listView~SelectedIndices[0] + 1]

  -- A window that has closed since the list was made: UI Automation raises an
  -- ElementNotAvailableException when it is asked about it (the original
  -- checked for an "Illegal Handle" state).
  signal on syntax name closed
  tree = getWindowTree(wnd)
  signal off syntax
  success = showWindowTree(tree)
  return 0
closed:
  return self~badHandle

/** onQuit()
 * The user pushed the 'Quit' button.  This is easy, just quit the dialog.
 */
::method onQuit
  return self~cancel

/** badHandle()
 * This private method is invoked when the user picks a window that has been
 * closed since the list view was originally populated.  We tell the user the
 * problem and refresh the list view.
 */
::method badHandle private
  expose listView

  title = listView~SelectedItems[0]~Text
  msg = "The window you selected appears to have been closed." || '0d0a0d0a'x || -
        "Window title:" title || '0d0a0d0a'x || -
        "The window list is being refreshed.  Select a new window."
  j = infoDialog(msg)

  self~onRefresh
  return 0

/** putInErrorState()
 * This private method is used when some un-recoverable error is detected.
 *
 * It displays an error message to the user based on the reason for the error,
 * sets the error state flag, and tries to disable the Show push button.
 */
::method putInErrorState private
  expose inError
  use strict arg reason

  inError = .true

  select
    when reason == "NOWINDOWS" then do
      msg = "For some reason no top-level windows were located." || '0d0a'x || -
            "This is not correct, the sample program is not"     || '0d0a'x || -
            "executing correctly."
    end
    when reason == "NOLISTVIEW" then do
      msg = "An internal error is preventing this sample program" || '0d0a'x || -
            "from executing correctly.  The ListControl object" || '0d0a'x || -
            "could not be obtained."
    end
    otherwise do
      msg = "The sample program is not executing correctly," || '0d0a'x || -
            "some unknown error."
    end
  end

  msg = msg || '0d0a0d0a'x || "Please just quit."
  j = errorDialog(msg)

  pb = self~newPushButton(IDC_PB_SHOW)
  if pb <> .nil then pb~Enabled = .false                 -- ooDialog: pb~disable
  return 0

::method autoRun                       -- (.NET version) unattended: the windows, the first one shown, Quit
  expose listView windows
  say "(auto)" listView~Items~Count "top-level windows:"
  do i = 0 to listView~Items~Count - 1
    say "  " listView~Items[i]~Text
  end
  self~onShow
  self~onQuit
