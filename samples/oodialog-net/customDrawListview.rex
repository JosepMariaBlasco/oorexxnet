/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 2012-2014 Rexx Language Association. All rights reserved.    */
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
 *  This example shows how to work with a simple ListView control in report
 *  view.
 *
 *  The main points of the example are:
 *
 *  1.) It shows how to use the LvFullRow, LvItem, and LvSubItem objects to add
 *      items to list-views
 *
 *  2.) It shows how to use custom draw with a list-view change the text and
 *      background color of a single list-view item, and / or change the font
 *      for a single item.
 *
 *  Note that in the .rc file, the resource script file, for this example, the
 *  dialog is created *not* visible.  Thus, while the dialog is being
 *  initialized, it is not visible on the screen.  This eliminates flicker while
 *  the items are being inserted into the list-view.  Some people like the users
 *  of their applications to see the list-view being filled, some people dislike
 *  flicker.  So, it is mostly a matter of preference how you create the dialog,
 *  initially visible, or initially invisible.  But, it is good to be aware of
 *  the option.
 *
 * (.NET version of ooDialog's controls\ListView\customDrawListview.rex, on
 * Windows Forms through oodnet.cls; the .rc is customDrawListviewrc.cls,
 * written by rc2oodnet.rex -cls. A .NET ListViewItem has its own colours and
 * font (ForeColor, BackColor, Font), which the ListView draws with: no custom
 * draw is needed for them. onCustomDraw keeps the original's logic, for an
 * item, and runs when the item is added and each time it is checked or
 * unchecked (the ListView's ItemChecked), instead of each time it is drawn.
 * LvItem, LvSubItem and LvFullRow are a ListViewItem and its SubItems; a
 * dialog's controls are filled before it shows, so there is no flicker
 * either.)
 */

    .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended

    dlg = .CustomDrawDlg~new                                -- ooDialog: .CustomDrawDlg~new(sd'rc\customDrawListview.rc', IDD_CUSTOMDRAW)
    if dlg~initCode = 0 then do
        dlg~execute("SHOWTOP")
    end

return 0
-- End of entry point.

::requires "customDrawListviewrc.cls"

/** CustomDrawDlg
 *
 * Our dialog subclass.  (.NET version: no CustomDraw mixin; the items' own
 * colours and font.)
 */
::class 'CustomDrawDlg' subclass CustomDrawListview_IDD_CUSTOMDRAW

/** init()
 *
 * Note that we created the colors and font one time here, rather than create
 * them each time the onCustomDraw() method is invoked.
 *
 * We also create our rows here rather than in initDialog().  The rows are
 * inserted into the list-view in initDialog().
 */
::method init
    expose textRed textBlack textBlue rowGreen rowLiteBlue rowYellow rows checkedFont

    forward class (super) continue

    -- ooDialog: self~customDraw, self~customDrawControl(IDC_LV_CUSTOM, 'ListView', onCustomDraw)

    C = .net~System~Drawing~Color                           -- ooDialog: self~RGB(r, g, b)
    textBlack   = C~FromArgb(  0,   0,   0)
    textRed     = C~FromArgb(247,   7,  59)
    textBlue    = C~FromArgb( 17,   5, 250)
    rowYellow   = C~FromArgb(245, 245, 127)
    rowLiteBlue = C~FromArgb(115, 245, 186)
    rowGreen    = C~FromArgb(188, 237, 102)

    checkedFont = self~createFontEx("Courier New", 10)

    rows = self~createRows

/** initDialog()
 *
 * initDialog is the place to do any initialization that requires the underlying
 * dialog to exist.  Here we add some extended list-view styles and fill the
 * list-view with its items.
 */
::method initDialog
    expose list rows

    list = self~newListView(IDC_LV_CUSTOM)

    list~FullRowSelect = .true                              -- ooDialog: addExtendedStyle("FULLROWSELECT GRIDLINES CHECKBOXES HEADERDRAGDROP")
    list~GridLines = .true
    list~CheckBoxes = .true
    list~AllowColumnReorder = .true

    list~Columns~Add("Line text", self~px(75))              -- ooDialog: InsertColumn(0, "Line text", 75): dialog units
    list~Columns~Add("Line number", self~px(55))
    list~Columns~Add("Numbers", self~px(50))
    list~Columns~Add("Characters", self~px(55))

    list~BeginUpdate                                        -- ooDialog: prepare4nItems
    do r over rows
        list~Items~Add(r)                                   -- ooDialog: addFullRow
        self~onCustomDraw(r)
    end
    list~EndUpdate

    list~ItemChecked += .net~handler(self, "ONITEMCHECKED")


/** onItemChecked()
 *
 * (.NET version) An item checked or unchecked: its colours and font again.
 */
::method onItemChecked unguarded
    use arg lv, e
    self~onCustomDraw(e~Item)


/** onCustomDraw()
 *
 * (.NET version) Sets the item's text colour, background colour and font
 * (ooDialog: the LvCustomDrawSimple object's clrText, clrTextBk and font,
 * and its reply CDRF_NEWFONT, each time the item is drawn).
 *
 * The logic of what we are doing is relatively simple.  We color every other
 * row with a different color, if the user has not checked the row.  All checked
 * rows use a differnt color and font than the unchecked rows.
 */
::method onCustomDraw unguarded
    expose list textRed textBlack textBlue rowGreen rowLiteBlue rowYellow checkedFont
    use arg lvItem

    item = lvItem~Index                                     -- ooDialog: lvcds~item

    if (item // 2) == 0 then do
        if lvItem~Checked then do                           -- ooDialog: list~isChecked(item)
            lvItem~ForeColor = textBlue
            lvItem~BackColor = rowLiteBlue
            lvItem~Font      = checkedFont
        end
        else do
            lvItem~ForeColor = textRed
            lvItem~BackColor = rowYellow
            lvItem~Font      = list~Font
        end
    end
    else do
        if lvItem~Checked then do
            lvItem~ForeColor = textBlue
            lvItem~BackColor = rowLiteBlue
            lvItem~Font      = checkedFont
        end
        else do
            lvItem~ForeColor = textBlack
            lvItem~BackColor = rowGreen
            lvItem~Font      = list~Font
        end
    end

    return .true


/** createRows()
 *
 * Here we create a ListViewItem for every list-view item, with its subitems,
 * one for each column (ooDialog: an LvFullRow of an LvItem and LvSubItems).
 *
 * All the rows are put into an array.  The array is later used to insert all
 * the items into the list-view.
 */
::method createRows private

    rows = .array~new(10)

    do i = 1 to 1000
        j = i - 1
        rows[i] = .net~System~Windows~Forms~ListViewItem~new(.array~of('Line' i, i, random(1, 200), self~randomChars))
    end

    return rows


/** randomChars()
 *
 * Simple method to generate some random string of characters.
 */
::method randomChars private

    len   = random(1, 7)
    chars = ''

    do i = 1 to len
        chars || = random(97, 122)~d2c
    end

    return chars


/** leaving()
 *
 * This method is invoked automatically be the ooDialog framework when the
 * dialog is closed.  It should be used to do any needed clean up.  Here we
 * delete the font we created.
 *
 * Note that the colors we created are just numbers and do not represent any
 * system resource.
 */
::method leaving unguarded
  expose checkedFont
  self~deleteFont(checkedFont)

::method autoRun                       -- (.NET version) unattended: rows 1 and 2 checked, their colours; OK
    expose list
    say "(auto)" list~Items~Count "rows"
    do i = 0 to 1
        list~Items[i]~Checked = .true
    end
    list~Items[0]~Checked = .false
    do i = 0 to 3
        it = list~Items[i]
        say "(auto) row" i + 1":" it~Text "checked" it~Checked", text" it~ForeColor~Name", back" it~BackColor~Name", font" it~Font~Name
    end
    self~ok
