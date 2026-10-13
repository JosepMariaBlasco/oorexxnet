/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 2010-2014 Rexx Language Association. All rights reserved.    */
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
 *  A simple List View control.  Demonstrates how to determine which column
 *  within a row the user has clicked on.
 *
 *  Each time the user clicks on the list view control, the row and column
 *  clicked are reported.  This is done using "say" so the program is best
 *  run from a command prompt window.
 *
 *  (.NET version of ooDialog's controls/ListView/columnClickListView.rex, on
 *  Windows Forms through oodnet.cls. The ListView is .NET's: columns with
 *  Columns~Add, rows as ListViewItems; the click comes with its mouse
 *  position, and HitTest gives the row and the column.)
 */

  .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended
  dlg = .SimpleLV~new
  if dlg~initCode = 0 then do
    dlg~create(30, 30, 325, 200, "A Simple List View", "VISIBLE")
    dlg~execute("SHOWTOP")
  end

-- End of entry point.

::requires "oodnet.cls"

::class 'SimpleLV' subclass NetDialog

::method defineDialog
  self~createListView(IDC_LISTVIEW, 10, 20, 305, 145, "REPORT SHOWSELALWAYS")
  self~createPushButton(IDOK, 280, 175, 35, 15, "DEFAULT", "Close")
  self~connectListViewEvent(IDC_LISTVIEW, "CLICK", onClick)

::method initDialog
  -- Get a reference to the list view.
  list = self~newListView(IDC_LISTVIEW)
  -- ooDialog's extended styles: .NET properties
  list~FullRowSelect = .true
  list~GridLines = .true
  list~CheckBoxes = .true
  list~AllowColumnReorder = .true      -- HEADERDRAGDROP
  list~Columns~Add("Row (Column 1)", self~px(75), "Left")
  list~Columns~Add("Column 2", self~px(70), "Left")
  list~Columns~Add("Column 3", self~px(70), "Left")
  list~BeginUpdate                     -- (.NET version) 200 rows, drawn once
  do i = 1 to 200
    item = .net~System~Windows~Forms~ListViewItem~new("Line" i)
    item~SubItems~Add("Line / Col ("i", 2)")
    item~SubItems~Add("Line / Col ("i", 3)")
    list~Items~Add(item)
  end
  list~EndUpdate

::method onClick                       -- .NET: (sender, MouseEventArgs)
  use arg listView, e
  hit = listView~HitTest(e~X, e~Y)
  if hit~Item == .nil then return
  -- Rexx numbering: from 1
  itemIndex = hit~Item~Index + 1
  columnIndex = hit~Item~SubItems~IndexOf(hit~SubItem) + 1
  say 'onClick() row:' itemIndex 'column:' columnIndex 'key state:' .net~System~Windows~Forms~Control~ModifierKeys 'lv:' listView

::method autoRun                       -- (.NET version) unattended: a click on row 3, column 2
  list = self~newListView(IDC_LISTVIEW)
  -- .net~int32: Items and SubItems have an indexer by number and one by key
  -- (a string): a Rexx string would choose the key's
  r = list~Items[2]~SubItems[1]~Bounds
  e = .net~System~Windows~Forms~MouseEventArgs~new("Left", 1, r~X + 2, r~Y + 2, 0)
  self~onClick(list, e)
  self~ok
