/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 2011-2014 Rexx Language Association. All rights reserved.    */
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
/* ooDialog User Guide - Exercise08

   Support - DragMgr					 	 v01-00  26Jun13
   ---------------------
   A singleton component that manages direct manipulation.

   Notes: A 'source' view is a dialog that's "picked up" by pressing and holding
          button 1 (usually the left button) of the mouse.
          A 'target' view is a dialog that's dropped onto by releasing
          button 1 over the target dialog.

   Interface DragMgr {
     setTarget
     setSource
     removeDlg
     list         lists tables of source & target dialogs.
     dmPickup 	  captures mouse - i.e. sets the mouse capture to the window
           	  of this mouse instance.
     moving	  If over a target (as supered by a dlg instance):
                  - check if this is a valid target AND is topmost window
		  - If over a valid drop area send dmQueryDrop(sourceDlg,mousePos)
		    to target.
		  - If response is .true then show dropOKCursor
		    else show noDropCursor (system-provided).
     dmDrop	  - If cursor is no-drop then no-op.
		    Else send dmDrop(sourceDlg) to drop target.
     }

  Changes:
    v01-00 06Jun13: First version.
           18Jun13: Changed 'drop' method name to 'dmDrop'.
           26Jun13: Change 'queryTables' method name to 'list' (to conform with
                    other Managers).


   (.NET version, on Windows Forms through oodnet.cls. ooDialog's DragMgr
   drags by hand with .Mouse: on the left button, dragDetect, capture and a
   cursor; on each move, the window under the pointer (windowFromPoint,
   mapWindowPoints, childWindowFromPoint) checked against the targets; on the
   button's release, the drop. Windows Forms has drag and drop of its own,
   which does the capture and the tracking: here dmPickup arms a drag,
   moving starts it (DoDragDrop) once the pointer has gone further than the
   system's drag size, as dragDetect, a target's DragOver says whether it
   takes the drop (the target's model class's dmQueryDrop, as the
   original), GiveFeedback sets the cursors (the source's own, and Windows'
   NO), and a target's DragDrop drops it (its dmDrop, with the source's
   model). A target takes drops anywhere in its drop area, over its controls
   too, as the original. The tables and the method names are the
   original's; drop(sourceDlg, targetDlg) and sources are for unattended
   runs.)
  = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = */

::REQUIRES oodnet.cls                         -- ooDialog: ::REQUIRES ooDialog.cls
::REQUIRES "Order\OrderModelsData.rex"

/*//////////////////////////////////////////////////////////////////////////////
  ============================================================================*/
::CLASS DragMgr PUBLIC

  ::ATTRIBUTE targetDialogs PRIVATE  -- dlg - hwnd, dropArea
  ::ATTRIBUTE sourceDialogs PRIVATE  -- dlg - mouse, dropOkCursor, pickupArea
  ::ATTRIBUTE dragInProgress
  --::ATTRIBUTE draggingSourceDlg PRIVATE


  /*----------------------------------------------------------------------------
    init - initialises the Drag Manager
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD init
    expose icons dragging cursorIsNoDrop noDropCursor
    .local~my.DragMgr = self
    --say "DragMgr-init-01: .local~my.DragMgr =" .local~my.DragMgr
    self~dragInProgress = .false
    self~targetDialogs = .Table~new	-- Index = dlg id
    					-- Item = an Array: hwnd, dropArea,
    self~sourceDialogs = .Table~new	-- Index = dlg id,
    					-- Item = an Array: mouse, cursor, pickupArea
    noDropCursor = .net~System~Windows~Forms~Cursors~No   -- ooDialog: .Mouse~loadCursor("NO")

    cursorIsNoDrop = .false
    dragging       = .false

    return self


  /*----------------------------------------------------------------------------
    setTarget - Adds a target view component to the Targets table
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD setTarget PUBLIC
    --expose targetDialogs
    use strict arg dlg, hwnd, dropArea
    items = .Array~new
    items[1] = hwnd;  items[2] = dropArea
    self~targetDialogs[dlg] = items
    -- (.NET version) the dialog, and every control in it, take drops
    relay = .DragMgrTarget~new(self, dlg)
    self~allowDrop(dlg~form, relay)


  /*----------------------------------------------------------------------------
    setSource - Adds a source view component to the Targets table
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD setSource PUBLIC
    --expose sourceDialogs dropOkCursor
    --use strict arg dlg, mouse, cursorFile, pickupArea, control
    use strict arg sourceWin, mouse, cursorFile, pickupArea, srcDlg	-- ***
    -- cursorFile is relative path and filename e.g. "bmp\customer.cur".
    --say "DragManager-setSource-01: sourceWin, Area =" sourceWin||"," pickupArea

    dropOkCursor = loadCursorFromFile(cursorFile)   -- ooDialog: .Mouse~loadCursorFromFile(cursorFile)
    if dropOkCursor == 0 then do
      say "DragManager-setSource-02:" .HRSdm~badOkCursor
      dropOkCursor = .net~System~Windows~Forms~Cursors~Default
    end

    items    = .Array~new
    items[1] = mouse;  items[2] = dropOkCursor;
    items[3] = pickupArea;  items[4] = srcDlg
    self~sourceDialogs[sourceWin] = items


  /*----------------------------------------------------------------------------
    RemoveDlg - Removes a dialog from the Targets table when the dialog closes.
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD removeDlg PUBLIC
    use strict arg dlg
    -- Check in SourceDlgs:
    self~sourceDialogs~remove(dlg)
    self~targetDialogs~remove(dlg)


  /*----------------------------------------------------------------------------
    dmPickup - Handles drag initiation when the user "picks up" a dialog.
               (.NET version: arms the drag; moving starts it.)
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD dmPickup PUBLIC
    expose armed armedAt dragging
    use strict arg sourceWin, keyState, mousePos
    arrItems = self~sourceDialogs[sourceWin]  	-- mouse,srcCursor,pickupArea,sourceDlg
    armed = .false
    if arrItems == .nil then return .false
    if keyState \== 'lButton' | \ mousePos~inRect(arrItems[3]) then return .false
    armed = .true; armedAt = mousePos~copy		-- ooDialog: if mouse~dragDetect(mousePos) then ...
    return


  /*----------------------------------------------------------------------------
    moving - Handles mouse movements.
             (.NET version: once the pointer has gone further than the drag
             size with the button down, Windows Forms' drag and drop starts;
             it tracks the targets itself: dragOver.)
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD moving PUBLIC
    expose armed armedAt dragging dropOkCursor dragSource dragSourceDlg queried
    use arg sourceWin, sourceDlg, keyState, mousePos
    if \var("ARMED") then return
    if \armed | dragging then return
    if keyState \== 'lButton' then do; armed = .false; return; end
    size = .net~System~Windows~Forms~SystemInformation~DragSize
    if abs(mousePos~x - armedAt~x) <= size~Width % 2, abs(mousePos~y - armedAt~y) <= size~Height % 2 then return
    arrItems = self~sourceDialogs[sourceWin]
    armed = .false
    dragging = .true; self~dragInProgress = .true
    dropOkCursor = arrItems[2]
    dragSourceDlg = arrItems[4]
    queried = .table~new                    -- target dialog -> its dmQueryDrop answer
    window = arrItems[1]~window             -- the dialog's form or the control
    feedback = .net~handler(.DragMgrSource~new(self), "GIVEFEEDBACK")
    window~GiveFeedback += feedback
    signal on syntax name done
    window~DoDragDrop("ooRexx/.NET User Guide view", "Copy")   -- (until the drop, or Escape)
done:
    window~GiveFeedback -= feedback
    dragging = .false; self~dragInProgress = .false
    return


  /*----------------------------------------------------------------------------
    dmDrop - Handles things when the user lets the button go on the source.
             (.NET version: a drag in progress ends with the target's
             DragDrop: dragDrop; here the button was let go before a drag.)
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD dmDrop PUBLIC
    expose armed
    use strict arg sourceDlg, keyState, mousePos
    armed = .false
    return


  /*----------------------------------------------------------------------------
    (.NET version) Windows Forms' drag and drop: a target's DragOver and
    DragDrop, the source's GiveFeedback.
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD dragOver PUBLIC UNGUARDED
    expose dragging
    use strict arg targetDlg, e
    e~Effect = "None"
    if \var("DRAGGING") then return
    if \dragging then return
    if self~acceptsDrop(targetDlg, .net~System~Drawing~Point~new(e~X, e~Y)) then e~Effect = "Copy"

  ::METHOD dragDrop PUBLIC UNGUARDED
    expose dragging dragSourceDlg
    use strict arg targetDlg, e
    if \var("DRAGGING") then return
    if \dragging then return
    if \self~acceptsDrop(targetDlg, .net~System~Drawing~Point~new(e~X, e~Y)) then return
    self~drop(dragSourceDlg, targetDlg)

  ::METHOD giveFeedback PUBLIC UNGUARDED
    expose dropOkCursor noDropCursor
    use strict arg e
    e~UseDefaultCursors = .false
    if e~Effect~string == "None" then .net~System~Windows~Forms~Cursor~Current = noDropCursor
    else .net~System~Windows~Forms~Cursor~Current = dropOkCursor

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    acceptsDrop - (.NET version) the original's checks: the point (on the
                  screen) in the target's drop area, the target not the
                  source, and the target's model class taking a drop of the
                  source's (dmQueryDrop, asked once per drag).            */
  ::METHOD acceptsDrop PRIVATE UNGUARDED
    expose dragSourceDlg queried
    use strict arg targetDlg, screenPt
    if targetDlg = dragSourceDlg then return .false
    items = self~targetDialogs[targetDlg]
    if items == .nil then return .false
    p = targetDlg~form~PointToClient(screenPt)
    if \.NetPoint~new(p~X, p~Y)~inRect(items[2]) then return .false
    if \queried~hasIndex(targetDlg) then queried[targetDlg] = self~queryDrop(dragSourceDlg, targetDlg)
    return queried[targetDlg]

  ::METHOD queryDrop PRIVATE UNGUARDED   -- (the original's, from moving)
    use strict arg sourceDlg, targetDlg
    objectMgr = .local~my.ObjectMgr
    sourceClassName = objectMgr~modelClassFromView(sourceDlg)
    targetClassName = objectMgr~modelClassFromView(targetDlg)
    interpret "r = ."||targetClassName||"~dmQueryDrop("||sourceClassName||")"
    return r == .true

  /*- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    drop - (.NET version) the drop itself, the original's (from dmDrop): the
           target's dmDrop with the source's model. Also for unattended runs,
           which cannot drag a real mouse.                                */
  ::METHOD drop PUBLIC UNGUARDED
    use strict arg sourceDlg, targetDlg
    objectMgr = .local~my.ObjectMgr
    sourceModelId = objectMgr~modelIdFromView(sourceDlg)
    return targetDlg~dmDrop(sourceModelId, sourceDlg)

  ::METHOD sources PUBLIC                -- (.NET version, for unattended runs) the source dialogs
    s = .array~new
    do i over self~sourceDialogs
      s~append(self~sourceDialogs[i][4])
    end
    return s

  ::METHOD allowDrop PRIVATE             -- (.NET version) a control and its children take drops
    use strict arg control, relay
    control~AllowDrop = .true
    control~DragOver += .net~handler(relay, "DRAGOVER")
    control~DragDrop += .net~handler(relay, "DRAGDROP")
    do c over control~Controls
      self~allowDrop(c, relay)
    end


  /*----------------------------------------------------------------------------
    list - A debug mehod that lists source and target dialogs on the console.
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
  ::METHOD list PUBLIC		-- Debug method
    say; say "======================================="
    say "DragManager Tables"
    say "-------------------------------------"
    say "Sources:"
    --say "asking dlg =" dlg
    do i over self~SourceDialogs
      say "i =" i
      items = self~SourceDialogs[i]
      say "mouse  = " items[1]
      say "cursor = " items[2]
      say "area   = " items[3]
      say "dialog = " items[4]
    end
    say "-------------------------------------"
    say "Targets:"
    arr = self~targetDialogs[dlg]
    do i over self~targetDialogs
      say "i =" i
      items = self~TargetDialogs[i]
      say "hwnd     = " items[1]
      say "dropArea = " items[2]
    end
    say "======================================="; say

/*============================================================================*/


/* (.NET version) ooDialog's .Mouse~loadCursorFromFile: a .NET Cursor, or 0 */
::ROUTINE loadCursorFromFile
  use strict arg file
  signal on syntax
  return .net~System~Windows~Forms~Cursor~new(file)
syntax:
  return 0

/*==============================================================================
  (.NET version) the relays of Windows Forms' drag and drop events
  ----------------------------------------------------------------------------*/
::CLASS DragMgrTarget                    -- a target's DragOver and DragDrop, for its dialog
::METHOD init
  expose mgr dlg
  use strict arg mgr, dlg
::METHOD dragOver UNGUARDED
  expose mgr dlg
  use arg sender, e
  mgr~dragOver(dlg, e)
::METHOD dragDrop UNGUARDED
  expose mgr dlg
  use arg sender, e
  mgr~dragDrop(dlg, e)

::CLASS DragMgrSource                    -- the source's GiveFeedback
::METHOD init
  expose mgr
  use strict arg mgr
::METHOD giveFeedback UNGUARDED
  expose mgr
  use arg sender, e
  mgr~giveFeedback(e)
/*============================================================================*/

/*==============================================================================
  Human-Readable Strings (HRSdm)				  v00-01 23Jan12
  --------
   The HRSdm class provides constant character strings for user-visible messages.
  = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = */

::CLASS HRSdm PRIVATE		-- Human-Readable Strings
  ::CONSTANT badNoDropCursor  "Error loading NoDrop Cursor, sys error code:"
  ::CONSTANT badOkCursor  "Error loading DropOK Cursor, sys error code:"
