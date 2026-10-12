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


/**
 * This example program demonstrates one approach to adding drag-and-drop to an
 * ooDialog program using the .Mouse class.
 *
 * (.NET version of ooDialog's mouse\dragNdrop.rex, on Windows Forms through
 * oodnet.cls: dragNdrop.rc's dialog is DragNdrop_IDD_NFL_DLG, from
 * dragNdroprc.cls (rc2oodnet.rex -cls). ooDialog's .Mouse drags by hand: on
 * LBUTTONDOWN, dragDetect, capture and a cursor; on MOUSEMOVE, the cursor for
 * where the pointer is (the other list views mapped into this one's
 * coordinates); on LBUTTONUP, the drop. Windows Forms has drag and drop of
 * its own, which does the capture and the tracking: a list view's ItemDrag
 * starts it (DoDragDrop), DragOver on a list view says whether a row may be
 * dropped there, GiveFeedback sets the cursors (the same two: dragging.cur,
 * and Windows' NO), DragDrop drops it. So the nine handlers of the original
 * (three for each list view) are four here, the list view their sender, and
 * the drop targets need no mapping. The DragItem class is the original's.)
 */

  .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended
  -- ooDialog: .application~setDefaults('O', sd'dragNdrop.h', .false): here the ids are names

  dlg = .DreamTeamDlg~new                                 -- ooDialog: .DreamTeamDlg~new(sd'dragNdrop.rc', IDD_NFL_DLG)

  if dlg~initCode == 0 then do
    dlg~execute("SHOWTOP", IDI_DLG_OOREXX)
  end

::requires "dragNdroprc.cls"

::class 'DreamTeamDlg' subclass DragNdrop_IDD_NFL_DLG

::method init
  expose dropOkCursor noDropCursor cursorIsNoDrop dragging srcDir
  forward class (super) continue

  srcDir = filespec("location", .context~package~name)   -- ooDialog: .application~srcDir

  -- This will load a cursor from a file.  The file has to actually be a cursor
  -- or the method will fail.  The operating system will refuse to load anything
  -- but an actual cursor.  The return is an .Image object.
  -- (.NET version: a .NET Cursor, from the file; an error if it is not one.)
  dropOkCursor = .net~System~Windows~Forms~Cursor~new(srcDir"resources\dragging.cur")   -- ooDialog: .Mouse~loadCursorFromFile(...)

  -- This loads the system's predefined NO cursor.  Again the return is a .Image
  -- object.
  noDropCursor = .net~System~Windows~Forms~Cursors~No    -- ooDialog: .Mouse~loadCursor("NO")

  cursorIsNoDrop = .false
  dragging       = .false

  return 0

::method initDialog
  expose lvNFL lvWest lvEast noDropCursor dragItem

  lvNFL = self~newListView(IDC_LV_NFL)
  self~setUpListView(lvNFL)

  lvWest = self~newListView(IDC_LV_WEST)
  self~setUpListView(lvWest)

  lvEast = self~newListView(IDC_LV_EAST)
  self~setUpListView(lvEast)

  self~setMice

  -- (.NET version: no mapDropTargets; each list view is told when a row is
  -- dragged over it, and dropped on it.)

  dragItem = .nil


::method doDrag private
  expose noDropCursor cursorIsNoDrop dragging
  use arg lv, index

  -- (.NET version: DoDragDrop, after this, captures the mouse and shows the
  -- cursors: ooDialog's mouse~capture, mouse~setCursor(noDropCursor).)
  di = .DragItem~new(lv, index)

  cursorIsNoDrop = .true
  dragging       = .true

  return di


/* (.NET version) ooDialog's nflOnLBdown, westOnLBdown, eastOnLBdown: a row
   dragged (the list view's own drag detection: ItemDrag) is dragged until the
   button is let go (DoDragDrop) */
::method onItemDrag unguarded
  expose dragItem dragging cursorIsNoDrop
  use arg lv, e

  if e~Button~string \== 'Left' then return

  index = e~Item~Index                                    -- ooDialog: lv~hitTestInfo(p)
  lv~Focus                                                -- ooDialog: lv~assignFocus, focus(index), select(index)
  e~Item~Focused = .true
  e~Item~Selected = .true

  dragItem = self~doDrag(lv, index)
  lv~DoDragDrop("DragItem", "Move")                       -- (until the drop, or the drag given up)

  dragging = .false
  cursorIsNoDrop = .false
  dragItem = .nil

/* (.NET version) ooDialog's nflOnMove...: whether the row may be dropped on
   the list view under the pointer (any of the other two) */
::method onDragOver unguarded
  expose dragging dragItem
  use arg target, e

  if dragging, dragItem \== .nil, self~canDrop(dragItem~source, target) then e~Effect = "Move"
  else e~Effect = "None"

::method canDrop private
  use strict arg source, target
  return \source~Equals(target)

/* (.NET version) the cursors, as ooDialog's mouse~setCursor in nflOnMove... */
::method onGiveFeedback unguarded
  expose dropOkCursor noDropCursor cursorIsNoDrop
  use arg source, e

  e~UseDefaultCursors = .false
  if e~Effect~string == "Move" then do
    .net~System~Windows~Forms~Cursor~Current = dropOkCursor
    cursorIsNoDrop = .false
  end
  else do
    .net~System~Windows~Forms~Cursor~Current = noDropCursor
    cursorIsNoDrop = .true
  end

/* (.NET version) ooDialog's nflOnLBup...: the row dropped */
::method onDragDrop unguarded
  expose dragItem
  use arg target, e

  if dragItem == .nil then return

  -- The point is on the screen: map it to the client coordinates of the list
  -- view where the row is being dropped.  Then the drag item can determine
  -- where the insertion point for the row should be in the target list view.
  p = target~PointToClient(.net~System~Drawing~Point~new(e~X, e~Y))   -- ooDialog: lv~mapWindowPoints(dragItem~target~hwnd, p)

  dragItem~target = target
  dragItem~drop(.NetPoint~new(p~X, p~Y))


::method setMice private
  expose lvNFL lvWest lvEast

  -- (.NET version: ooDialog's .Mouse~new(lv) and connectEvent('LBUTTONDOWN' /
  -- 'LBUTTONUP' / 'MOUSEMOVE', ...) for each list view, as .NET's events.)
  do lv over .array~of(lvNFL, lvWest, lvEast)
    lv~AllowDrop = .true
    lv~ItemDrag += .net~handler(self, onItemDrag)
    lv~DragOver += .net~handler(self, onDragOver)
    lv~DragDrop += .net~handler(self, onDragDrop)
    lv~GiveFeedback += .net~handler(self, onGiveFeedback)
  end

::method setUpListView private
  use strict arg lv

  lv~GridLines = .true                                    -- ooDialog: lv~addExtendedStyle("GRIDLINES DOUBLEBUFFER FULLROWSELECT")
  lv~FullRowSelect = .true
  lv~Columns~Add('Player', 105, 'Left')                   -- ooDialog: lv~insertColumnPX(0, 'Player', 105, 'LEFT')
  lv~Columns~Add('Team', 115, 'Center')
  lv~Columns~Add('Position', 65, 'Center')
  lv~Columns~Add('Rating', 65, 'Center')

  if lv~Name == IDC_LV_NFL then do                        -- ooDialog: lv~id == .constDir[IDC_LV_NFL]
    playerRows = self~getPlayers
    do l over playerRows
      lv~Items~Add(.net~System~Windows~Forms~ListViewItem~new(.array~of(l~player, l~team, l~pos, l~rating)))   -- ooDialog: addRow
    end
  end

::method getPlayers private
  expose srcDir

  rows = .Array~new

  fileObj = .stream~new(srcDir"resources\nflPlayers.txt")
  players = fileObj~makeArray

  do line over players
    line = line~strip
    if line~length == 0 | line~abbrev("#") | line~abbrev("/*") then iterate

    parse var line name', 'team', 'p', 'rating .

    r = .Directory~new
    r~player = name
    r~team   = team
    r~pos    = p
    r~rating = rating
    rows~append(r)
  end

  fileObj~close

  return rows

::method autoRun unguarded                               -- (.NET version) unattended: rows dragged by DragItem, as a drop would
  expose lvNFL lvWest lvEast
  say "(auto) NFL players:" lvNFL~Items~Count "- West:" lvWest~Items~Count "- East:" lvEast~Items~Count
  say "(auto) may drop NFL on West:" self~canDrop(lvNFL, lvWest) "- NFL on NFL:" self~canDrop(lvNFL, lvNFL)
  do i = 1 to 3                                          -- the first three to the West, the next two to the East
    di = .DragItem~new(lvNFL, 0); di~target = lvWest; di~drop
  end
  do i = 1 to 2
    di = .DragItem~new(lvNFL, 0); di~target = lvEast; di~drop
  end
  r = lvWest~Items[0]~Bounds                             -- one dropped on the West's first row goes before it
  di = .DragItem~new(lvNFL, 0); di~target = lvWest; di~drop(.NetPoint~new(r~X + 5, r~Y + 2))
  di = .DragItem~new(lvWest, 1); di~target = lvEast; di~drop
  say "(auto) West:" rows(lvWest)
  say "(auto) East:" rows(lvEast)
  say "(auto) NFL:" lvNFL~Items~Count "left, selected:" lvNFL~SelectedItems[0]~Text
  self~ok

/* (.NET version) a list view's players */
::routine rows
  use strict arg lv
  s = ""
  do i = 0 to lv~Items~Count - 1
    s = s || "; " || lv~Items[i]~Text
  end
  return s~substr(3)


/* Class: DragItem - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\

    Drag items are an encapsulation of the data needed to drag and drop one row
    of a list view to another.
\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'DragItem'

::attribute target

::method init
  expose lv index row target
  use arg lv, index

  item = lv~Items[index]                                  -- ooDialog: lv~getItemInfo(index, row [, column])
  row = .Directory~new
  row~player = item~SubItems[0]~Text
  row~team   = item~SubItems[1]~Text
  row~pos    = item~SubItems[2]~Text
  row~rating = item~SubItems[3]~Text

  target = .nil

::method source                                           -- (.NET version) the list view it comes from
  expose lv
  return lv

::method drop
  expose lv index row target
  use strict arg pt = 0

  if target \== .nil then do
    -- Drop the row at the end of the list by default.
    targetIndex = target~Items~Count                      -- ooDialog: target~items

    if pt~isA(.NetPoint) then do
      hit = target~GetItemAt(pt~x, pt~y)                  -- ooDialog: target~hitTestInfo(pt)
      if hit \== .nil then targetIndex = hit~Index
    end

    target~Items~Insert(targetIndex, .net~System~Windows~Forms~ListViewItem~new(.array~of(row~player, row~team, row~pos, row~rating)))   -- ooDialog: addRow(targetIndex, ...)

    lv~Items~RemoveAt(index)                              -- ooDialog: lv~delete(index)

    count = lv~Items~Count
    if count <> 0 then do
      if index == count then lv~Items[index - 1]~Selected = .true   -- ooDialog: lv~select(index - 1)
      else lv~Items[index]~Selected = .true
    end
  end
