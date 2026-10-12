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
 *  This example shows how to embedd a drop-down combo box in a list-view, to
 *  allow the user to edit the items and subitems in the list-view by picking
 *  one of the combo box's items, or typing a text.
 *
 *  To activate the editing, the user clicks once on an item or subitem, then
 *  clicks one more time to activate the editing.  The combo box takes the
 *  place of the item or subitem in the list-view.
 *
 *  When the user is in the editing mode, hitting enter, escape, or clicking the
 *  mouse any where else on the scren, ends the editing.  If enter is hit, the
 *  changes are accepted, otherwise, the changes are abandoned.
 *
 *  The key to how this works is creating an invisible combo box, which is
 *  then made a child of the list-view.  When editing mode is entered, the
 *  combo box is positioned over the item, and made visible.  When editing is
 *  over, the combo box is made invisible again.
 *
 * (.NET version of ooDialog's controls\ListView\subitem.editing\dropDownComboBox.rex,
 * on Windows Forms through oodnet.cls, as editControl.rex: the ComboBox
 * (DropDown) goes into the ListView's Controls (ooDialog: setParent); its
 * events still come to us, so no isGrandChild: its KeyDown gives Enter and
 * Escape, its LostFocus the end of the editing. The ListView's MouseClick
 * and HitTest say which item and subitem were clicked, their Bounds where
 * they are (a ComboBox's height is its font's: the list drops down below);
 * the editing ends on the mouse wheel (ooDialog: BEGINSCROLL).)
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

::method defineDialog
    expose cbVisible

    cbVisible = .false

    self~createComboBox(IDC_CB, 10, 20, 40, 12, 'PARTIAL')
    self~newComboBox(IDC_CB)~Visible = .false                -- (ooDialog: the style HIDDEN)
    self~createListView(IDC_LISTVIEW, 10, 20, 305, 145, "REPORT SHOWSELALWAYS")
    self~createPushButton(IDOK, 280, 175, 35, 15, "DEFAULT", "Close")

::method initDialog
    expose list cb

    list = self~newListView(IDC_LISTVIEW)
    cb   = self~newComboBox(IDC_CB)

    cb~Items~Add('One')                                     -- ooDialog: cb~add('One')
    cb~Items~Add('Two')
    cb~Items~Add('Three')

    self~form~Controls~Remove(cb)                           -- ooDialog: cb~setParent(list)
    list~Controls~Add(cb)

    list~MouseClick += .net~handler(self, "ONCLICK")        -- ooDialog: connectListViewEvent(IDC_LISTVIEW, "CLICK", onClick)
    list~MouseWheel += .net~handler(self, "ONBEGINSCROLL")
    cb~KeyDown += .net~handler(self, "ONCOMBOKEY")          -- ooDialog: cb~getEditControl~isGrandchild
    cb~LostFocus += .net~handler(self, "ONCOMBOLOSTFOCUS")

    self~setUpListView(list)

/** onClick()
 *
 *  This is the event handler for a click on the list-view.  We track the clicks
 *  and when we see that the user has clicked twice in a row on the same item or
 *  subitem we enter editing mode: the combo box is placed over it and made
 *  visible.
 */
::method onClick unguarded
    expose cb cbVisible lastIdx lastCol
    use arg lv, e

    hit = lv~HitTest(e~Location)
    if hit~Item == .nil | hit~SubItem == .nil then return 0
    itemIndex = hit~Item~Index
    columnIndex = hit~Item~SubItems~IndexOf(hit~SubItem)

    if var("LASTIDX"), lastIdx == itemIndex & lastCol == columnIndex then do
        if columnIndex > 0 then r = hit~SubItem~Bounds      -- ooDialog: getSubitemRect(itemIndex, columnIndex, 'LABEL')
        else r = hit~Item~GetBounds("Label")                -- ooDialog: getItemRect(itemIndex, 'LABEL')
        cb~Location = r~Location
        cb~Width = r~Width
        cb~Visible = .true
        cb~BringToFront
        cbVisible = .true
        cb~Focus                                            -- ooDialog: cb~assignFocus
    end

    lastIdx = itemIndex; lastCol = columnIndex
    return 0

::method onBeginScroll unguarded
    expose cbVisible
    if cbVisible then self~hideComboBox
    return 0

/** onComboKey(), onComboLostFocus()
 *
 *  (.NET version) The combo box's events: Enter accepts the text (if not
 *  empty), Escape abandons it, and the lost focus ends the editing too
 *  (ooDialog: the grandchild events 'enter', 'escape', 'killfocus').
 */
::method onComboKey unguarded
    expose list lastIdx lastCol
    use arg cbCtrl, e

    key = e~KeyCode~string
    if key == 'Enter' then do
        text = cbCtrl~Text
        if text == .nil then text = ''
        text = text~strip                                                     -- ooDialog: editCtrl~getText~strip
        if text \== '' then list~Items[lastIdx]~SubItems[lastCol]~Text = text   -- ooDialog: list~setItemText(lastIdx, lastCol, text)
        self~hideComboBox
        e~SuppressKeyPress = .true
    end
    else if key == 'Escape' then do
        self~hideComboBox
        e~SuppressKeyPress = .true
    end
    return 0

::method onComboLostFocus unguarded
    expose cbVisible
    if cbVisible then self~hideComboBox(.false)

::method hideComboBox private unguarded
    expose cb cbVisible list
    use strict arg assignFocus = .true

    cbVisible = .false
    cb~Visible = .false
    cb~SelectedIndex = -1                                   -- ooDialog: cb~selectIndex
    cb~Text = ''
    if assignFocus then list~Focus

::method setUpListView private
    use strict arg list

    list~FullRowSelect = .true              -- ooDialog: addExtendedStyle("FULLROWSELECT GRIDLINES CHECKBOXES HEADERDRAGDROP")
    list~GridLines = .true
    list~CheckBoxes = .true
    list~AllowColumnReorder = .true

    list~Columns~Add("Row (List-view item)", self~px(75))    -- ooDialog: insertColumn(0, ..., 75): dialog units
    list~Columns~Add("Column 2 (subitem 1)", self~px(70))
    list~Columns~Add("Column 3 (subitem 2)", self~px(70))

    list~BeginUpdate
    do i = 1 to 200
        list~Items~Add(.net~System~Windows~Forms~ListViewItem~new(.array~of("Row" i, "Row / Col ("i", 2)", "Row / Col ("i", 3)")))
    end
    list~EndUpdate

::method autoRun                       -- (.NET version) unattended: two clicks on row 3's column 2, "Two" picked, Enter; row 5's item, Escape; Close
    expose list cb
    F = .net~System~Windows~Forms
    r = list~Items[2]~SubItems[1]~Bounds
    click = F~MouseEventArgs~new("Left", 1, r~X + 5, r~Y + 3, 0)
    self~onClick(list, click)
    self~onClick(list, click)
    say "(auto) editing:" cb~Visible "at" cb~Left","cb~Top
    cb~SelectedIndex = 1
    self~onComboKey(cb, F~KeyEventArgs~new("Enter"))
    say "(auto) now:" list~Items[2]~SubItems[1]~Text "- editing:" cb~Visible
    r = list~Items[4]~GetBounds("Label")
    click = F~MouseEventArgs~new("Left", 1, r~X + 5, r~Y + 3, 0)
    self~onClick(list, click)
    self~onClick(list, click)
    say "(auto) the item: editing" cb~Visible "at" cb~Left","cb~Top
    cb~SelectedIndex = 2
    self~onComboKey(cb, F~KeyEventArgs~new("Escape"))
    say "(auto) after Escape:" list~Items[4]~Text
    self~ok
