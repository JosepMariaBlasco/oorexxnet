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
 * Name: sysinfo.rex
 * Type: Open Object Rexx Script using ooDialog and OLE
 * Resource: sysinfo.rc
 *
 * Description:
 * Demo application for inspecting some system properties using WMI
 *
 * WMI is the acronym for Windows Management Instrumentation. Full documentation
 * of WMI can be found in the Windows SDK which Microsoft provides free of
 * charge.  You can also locate this documentation on the web.  A google search
 * of:
 *
 *   "MSDN Windows Management Instrumentation"
 *
 * will lead you straight to the documentation

 * (.NET version of ooDialog's sysinfo\sysinfo.rex, on Windows Forms through
 * oodnet.cls: sysinfo.rc's dialog is Sysinfo_SYSINFO_DLG, from
 * sysinforc.cls. WMI is the same COM object, from .net~getObject: the
 * thread that asks it (started with start, as the original's) lists a
 * component's instances, and the list box shows them on the dialog's thread
 * (a window belongs to the thread that made it): showItems and
 * showHourGlass, called from that thread, run there (oodnet.cls's
 * onThreadLater), without waiting, so that ok and cancel, which wait for the
 * thread to finish, cannot wait for each other. The list box gets the
 * instances all at once rather than one by one. The combo box's SELCHANGE
 * is ooDialog's: only the user's choices; .NET's SelectedIndexChanged
 * follows the program's too, so the user's are SELENDOK here (.NET's
 * SelectionChangeCommitted). The hourglass is the list box's UseWaitCursor,
 * and the mouse goes to its middle and back, as the original's .Mouse did
 * (not when unattended).)
 */

  .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended

  sysInfoDlg = .SystemClass~new          -- ooDialog: .SystemClass~new(sd'sysinfo.rc', SYSINFO_DLG)
  if sysInfoDlg~initCode == 0 then do
    sysInfoDlg~execute("SHOWTOP")
  end

return 0


::requires "sysinforc.cls"

::class 'SystemClass' subclass Sysinfo_SYSINFO_DLG

::method initDialog
  expose cb lb componentQueue queueHasData userHasQuit doneProcessing shown

  -- Connect the selection change event of the combo box to a method in this
  -- dialog. (.NET version: SELENDOK, the user's choices only, as ooDialog's SELCHANGE)
  self~connectComboBoxEvent(IDC_CB_COMPONENTS, "SELENDOK", selectionChange)

  -- Fill the combo box with the names of the WMI classes we will display.
  cb = self~newComboBox(IDC_CB_COMPONENTS)
  if cb \= .nil then do
    cb~Items~Add("Win32_BootConfiguration")              -- ooDialog: cb~add(...)
    cb~Items~Add("Win32_ComputerSystem")
    cb~Items~Add("Win32_Environment")
    cb~Items~Add("Win32_OperatingSystem")
    cb~Items~Add("Win32_Printer")
    cb~Items~Add("Win32_Process")
    cb~Items~Add("Win32_Processor")
    cb~Items~Add("Win32_Service")
  end

  lb = self~newListBox(IDC_LB_DATA)
  lb~HorizontalScrollbar = .true                         -- (.NET version) the .rc's WS_HSCROLL
  cb~SelectedItem = "Win32_ComputerSystem"               -- ooDialog: cb~select("Win32_ComputerSystem")

  componentQueue = .queue~new
  queueHasData = .false
  userHasQuit = .false
  doneProcessing = .true
  shown = 0                                              -- (.NET version) lists shown, for autoRun
  self~start("queueProcessor")

  self~addToQueue("Win32_ComputerSystem")


::method queueProcessor unguarded
  expose queueHasData componentQueue lb userHasQuit doneProcessing

  doneProcessing = .false

  do forever
    if userHasQuit then leave

    guard on when queueHasData

    if userHasQuit then leave

    component = componentQueue~pull
    do while component \== .nil
      if userHasQuit then leave

      -- Change the cursor to the hour glass cursor to indicate we are processing
      -- and the user should be patient.
      self~showHourGlass

      WMIObject = .net~getObject("WinMgmts:")           -- ooDialog: .OLEObject~getObject("WinMgmts:")

      if WMIObject \== .nil, component \== "" then do
        if userHasQuit then leave

        items = .array~new                               -- (.NET version) shown all at once, below
        objects = WMIObject~instancesOf(component)

        do instance over objects
          if userHasQuit then leave

          -- Please note: these objects offer a lot more information than is
          -- displayed here. For simplicity's sake only the name and description
          -- (if available) are shown.

          name = instance~name
          desc = instance~description
          if ((name = desc) | (desc = .nil)) then
            items~append(name)
          else
            items~append(name "("desc")")
        end
        self~showItems(items)                            -- ooDialog: lb~deleteAll, then lb~add each

      end
      -- Restore the cursor to its original shape and position.
      self~showHourGlass(.false)

      component = componentQueue~pull
    end
    queueHasData = .false
  end

  doneProcessing = .true

::method selectionChange unguarded
  expose cb lb

  component = cb~SelectedItem                            -- ooDialog: cb~selected
  self~addToQueue(component)

  return 0

::method ok unguarded
  expose userHasQuit queueHasData doneProcessing

  userHasQuit = .true
  queueHasData = .true

  guard on when doneProcessing

  return self~ok:super

::method cancel unguarded
  expose userHasQuit queueHasData doneProcessing

  userHasQuit = .true
  queueHasData = .true

  guard on when doneProcessing

  return self~cancel:super

::method addToQueue private
  expose queueHasData componentQueue
  use strict arg component

  componentQueue~queue(component)
  queueHasData = .true

::method showItems unguarded           -- (.NET version) the list box's items, on the dialog's thread
  expose lb shown
  use strict arg items
  if self~offThread then return self~onThreadLater("SHOWITEMS", arg(1, "A"))
  lb~BeginUpdate
  lb~Items~Clear
  do item over items
    lb~Items~Add(item)
  end
  lb~EndUpdate
  shown += 1

::method showHourGlass unguarded       -- (.NET version: unguarded, on the dialog's thread)
  expose lb oldCursorPosition
  use strict arg show = .true
  if self~offThread then return self~onThreadLater("SHOWHOURGLASS", arg(1, "A"))

  cursor = .net~System~Windows~Forms~Cursor              -- ooDialog: mouse = .Mouse~new(lb)

  if show then do
    -- Save the current cursor position.  Change the list box's cursor shape to
    -- the hour glass and save the old shape.
    oldCursorPosition = cursor~Position                  -- ooDialog: mouse~getCursorPos
    lb~UseWaitCursor = .true                             -- ooDialog: oldCursor = mouse~wait

    -- Set the point object to the midpoint of the list box and position the
    -- cursor at that posiiion
    middle = .net~System~Drawing~Point~new(lb~Width % 2, lb~Height % 2)
    if \.NetDialog~auto then cursor~Position = lb~PointToScreen(middle)   -- ooDialog: mouse~setCursorPos(p)
  end
  else do
    lb~UseWaitCursor = .false                            -- ooDialog: mouse~restoreCursor(oldCursor)
    if \.NetDialog~auto then cursor~Position = oldCursorPosition
  end

::method shown unguarded               -- (.NET version) lists shown so far
  expose shown
  return shown

::method choose unguarded              -- (.NET version, for autoRun) a component chosen, as the user would
  expose cb
  use strict arg component
  if self~offThread then return self~onThread("CHOOSE", arg(1, "A"))
  cb~SelectedItem = component
  self~selectionChange

::method autoRun unguarded             -- (.NET version) unattended: three components, then OK
  self~start("autoSteps")              -- (on a thread of its own: the lists come to the dialog's thread)

::method autoSteps unguarded
  expose lb
  do component over .array~of("", "Win32_OperatingSystem", "Win32_Processor")
    seen = self~shown
    if component \== "" then self~choose(component)
    else seen = 0                                        -- (the first, Win32_ComputerSystem, chosen in initDialog)
    do 400 while self~shown <= seen                      -- (at most 20 s)
      call SysSleep 0.05
    end
    n = lb~Items~Count
    first = ""
    if n > 0 then first = lb~Items[0]
    say "(auto)" self~newComboBox(IDC_CB_COMPONENTS)~SelectedItem":" n "line(s); a first one:" (first \== "")
  end
  self~ok
