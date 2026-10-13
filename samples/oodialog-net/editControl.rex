/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 2013-2014 Rexx Language Association. All rights reserved.    */
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
 *  This example shows how to embedd an edit control in a list-view, to allow
 *  the user to edit the subitems in the list-view.
 *
 *  To activate the editing, the user clicks once on a subitem, then clicks one
 *  more time to activate the editing.  An edit control takes the place of the
 *  subitem in the list-view.
 *
 *  When the user is in the editing mode, hitting enter, escape, or clicking the
 *  mouse any where else on the scren, ends the editing.  If enter is hit, the
 *  changes are accepted, otherwise, the changes are abandoned.
 *
 *  The key to how this works is creating an invisible edit control, which is
 *  then made a child of the list-view.  When editing mode is entered, the edit
 *  control is positioned over the subitem, sized to the size of the subitem,
 *  and made visible.  When editing is over, the edit control is made invisible
 *  again.
 *
 * (.NET version of ooDialog's controls\ListView\subitem.editing\editControl.rex,
 * on Windows Forms through oodnet.cls. The edit control, a TextBox, goes into
 * the ListView's Controls (ooDialog: setParent); a child's events still come
 * to us in .NET, so no isGrandChild: its KeyDown gives Enter and Escape, its
 * LostFocus the end of the editing. The ListView's MouseClick and HitTest
 * say which item and subitem were clicked (ooDialog: the CLICK event's
 * arguments), the subitem's Bounds where it is; a .NET ListView has no scroll
 * event, so the editing ends on the mouse wheel (ooDialog: BEGINSCROLL).)
 */

    .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended

    dlg = .SimpleLV~new
    if dlg~initCode = 0 then do
        dlg~create(30, 30, 325, 200, "In-place Editing List View", "VISIBLE")
        dlg~execute("SHOWTOP")
    end

return 0

::requires "oodnet.cls"

::class 'SimpleLV' subclass NetDialog

/** defineDialog()
 *
 * Standard defineDialog. We create an edit control, list-view, and ok button in
 * the dialog template.  Note the edit control is made invisible.
 *
 * We add a flag to keep track of whether the edit control is visisble or not.
 */
::method defineDialog
  expose editVisible

  editVisible = .false

  self~createListView(IDC_LISTVIEW, 10, 20, 305, 145, "REPORT SHOWSELALWAYS")
  self~createEdit(IDC_EDIT, 10, 10, 40, 11, 'AUTHSCROLLH NOTAB')
  self~newEdit(IDC_EDIT)~Visible = .false                   -- (ooDialog: the style HIDDEN)
  self~createPushButton(IDOK, 280, 175, 35, 15, "DEFAULT", "Close")

/** initDialog()
 *
 *  Here we populate the list-view, make the edit control a child of the
 *  list-view (drawn over it), and connect the events we need to monitor.
 */
::method initDialog
    expose list edit

    list = self~newListView(IDC_LISTVIEW)
    edit = self~newEdit(IDC_EDIT)

    self~form~Controls~Remove(edit)                         -- ooDialog: edit~setParent(list)
    list~Controls~Add(edit)

    list~MouseClick += .net~handler(self, "ONCLICK")        -- ooDialog: connectListViewEvent(IDC_LISTVIEW, "CLICK", onClick)
    list~MouseWheel += .net~handler(self, "ONBEGINSCROLL")
    edit~KeyDown += .net~handler(self, "ONEDITKEY")         -- ooDialog: edit~isGrandChild, onEditGrandChildEvent
    self~wantKeys(edit)                                     -- (Enter and Escape to it, not to the dialog's buttons)
    edit~LostFocus += .net~handler(self, "ONEDITLOSTFOCUS")

    self~setUpListView(list)

/** onClick()
 *
 *  This is the event handler for a click on the list-view.  We track the clicks
 *  and when we see that the user has clicked twice in a row on the same subitem
 *  we enter editing mode.
 *
 *  When we enter editing mode, we size the edit control to the size of the
 *  subitem, position the edit control over it, and make the edit control
 *  visible.
 */
::method onClick unguarded
  expose edit editVisible lastIdx lastCol
  use arg lv, e

  hit = lv~HitTest(e~Location)
  if hit~Item == .nil | hit~SubItem == .nil then return 0
  itemIndex = hit~Item~Index
  columnIndex = hit~Item~SubItems~IndexOf(hit~SubItem)

  if var("LASTIDX"), lastIdx == itemIndex & lastCol == columnIndex then do
    if columnIndex > 0 then do
        edit~Bounds = hit~SubItem~Bounds                    -- ooDialog: getSubitemRect, setWindowPos
        edit~Text = hit~SubItem~Text
        edit~Visible = .true
        edit~BringToFront
        editVisible = .true
        edit~Focus                                          -- ooDialog: edit~assignFocus
    end
  end

  lastIdx = itemIndex; lastCol = columnIndex
  return 0

/** onBeginScroll()
 *
 *  When the user is in the editing mode and then scrolls the list, we
 *  interpret that as canceling the edit.
 */
::method onBeginScroll unguarded
    expose editVisible edit
    if editVisible then self~hideEdit(edit)
    return 0

/** onEditKey(), onEditLostFocus()
 *
 *  (.NET version) The edit control's events: Enter accepts the new text (if
 *  it is not empty), Escape abandons it, and the lost focus ends the editing
 *  too (ooDialog: onEditGrandChildEvent's 'enter', 'escape', 'killfocus').
 */
::method onEditKey unguarded
    expose list lastIdx lastCol
    use arg editCtrl, e

    key = e~KeyCode~string
    if key == 'Enter' then do
        text = editCtrl~Text~strip
        if text \== '' then list~Items[lastIdx]~SubItems[lastCol]~Text = text   -- ooDialog: list~setItemText(lastIdx, lastCol, text)
        self~hideEdit(editCtrl)
        e~SuppressKeyPress = .true          -- (no beep, and no Enter for the dialog's default button)
    end
    else if key == 'Escape' then do
        self~hideEdit(editCtrl)
        e~SuppressKeyPress = .true
    end
    return 0

::method onEditLostFocus unguarded
    expose editVisible
    use arg editCtrl, e
    if editVisible then self~hideEdit(editCtrl, .false)

/** hideEdit()
 *
 *  Makes the edit control invisible, removes its text, and, maybe, assigns the
 *  focus back to the list-view.  This is done each time the editing mode is
 *  ended.
 */
::method hideEdit private unguarded
    expose editVisible list
    use strict arg editCtrl, assignFocus = .true

    editVisible = .false
    if assignFocus then list~Focus
    editCtrl~Text = ""
    editCtrl~Visible = .false

/** setUpListView()
 *
 * Sets up the list view by adding the columns and populating the list with
 * rows.
 */
::method setUpListView private
    use strict arg list

    list~FullRowSelect = .true              -- ooDialog: addExtendedStyle("FULLROWSELECT GRIDLINES CHECKBOXES HEADERDRAGDROP")
    list~GridLines = .true
    list~CheckBoxes = .true
    list~AllowColumnReorder = .true

    list~Columns~Add("Row (List-view item)", self~px(75), "Left")    -- ooDialog: insertColumn(0, ..., 75): dialog units
    list~Columns~Add("Column 2 (subitem 1)", self~px(70), "Left")
    list~Columns~Add("Column 3 (subitem 2)", self~px(70), "Left")

    list~BeginUpdate
    do i = 1 to 200
        list~Items~Add(.net~System~Windows~Forms~ListViewItem~new(.array~of("Row" i, "Row / Col ("i", 2)", "Row / Col ("i", 3)")))
    end
    list~EndUpdate

::method autoRun                       -- (.NET version) unattended: two clicks on row 3's column 2, a new text, Enter; then Escape; Close
    expose list edit
    F = .net~System~Windows~Forms
    r = list~Items[2]~SubItems[1]~Bounds
    click = F~MouseEventArgs~new("Left", 1, r~X + 5, r~Y + 3, 0)
    self~onClick(list, click)
    self~onClick(list, click)
    say "(auto) editing:" edit~Visible "over" edit~Text "at" edit~Left","edit~Top
    edit~Text = "edited"
    self~onEditKey(edit, F~KeyEventArgs~new("Enter"))
    say "(auto) now:" list~Items[2]~SubItems[1]~Text "- editing:" edit~Visible
    self~onClick(list, click)
    edit~Text = "abandoned"
    self~onEditKey(edit, F~KeyEventArgs~new("Escape"))
    say "(auto) after Escape:" list~Items[2]~SubItems[1]~Text
    self~ok
