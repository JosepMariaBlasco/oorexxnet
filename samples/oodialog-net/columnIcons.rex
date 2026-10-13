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
 *  This example shows how to add icons to the invidual columns of a list-view
 *  when it is in report view.
 *
 * (.NET version of ooDialog's controls\ListView\columnIcons.rex, on Windows
 * Forms through oodnet.cls: columnIcons.rc's dialog is ColumnIcons_IDD_DIALOG,
 * from columnIconsrc.cls (the original uses the .rc compiled, a ResDialog).
 * A .NET ListView draws no images in its subitems (SUBITEMIMAGES): in the
 * report view it is drawn by us (OwnerDraw: DrawSubItem draws each cell's
 * icon, from its Tag, and its text), its other views as usual. The image
 * lists are .NET ImageLists of the original's bitmap strips (AddStrip). A
 * click on a column sorts by it, ascending, then descending: the ListView's
 * sort with a Rexx IComparer (ColumnSorter) for these few rows (ooDialog: its
 * internal sort). The views are the ListView's View; the extended styles its
 * properties. ooDialog's default drag handler, which moves icons, has no
 * counterpart here.)
 */

    .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended

    dlg = .ListViews~new               -- ooDialog: .ListViews~new(sd"rc\columnIcons.dll", IDD_DIALOG)
    if dlg~initCode == 0 then do
        dlg~execute("SHOWTOP")
    end
    else do
        say 'Dialog failed to initialize, aborting.'
        return 99
    end

    return 0
-- End of entry point.

::requires "columnIconsrc.cls"
::requires "net.cls"                   -- (.NET version) NetObject, for ColumnSorter

::class 'ListViews' subclass ColumnIcons_IDD_DIALOG

::method initDialog
    expose list itemColumns

    list = self~newListView(IDC_LV_VIEWS)
    self~newRadioButton(IDC_RB_ICON)~Checked = .true

    itemColumns = .array~of(-1, -1, -1, -1)

    self~connectEvents
    self~setImageLists
    self~populateList(list)

::method onReport
    expose list
    list~View = "Details"              -- ooDialog: list~setView("REPORT")
    return 0

::method onList
    expose list
    list~View = "List"

::method onIcon
    expose list
    list~View = "LargeIcon"

::method onSmallIcon
    expose list
    list~View = "SmallIcon"

::method onColClick unguarded
    expose itemColumns
    use arg listView, e                -- (.NET version) ooDialog: use arg id, colIndex, listView

    colIndex = e~Column
    -- Adjust for 0-based indexes
    i = colIndex + 1

    if itemColumns[i] == -1 then do
      ascending = .true
      itemColumns[i] = 0
    end
    else if itemColumns[i] == 0 then do
      ascending = .false
      itemColumns[i] = 1
    end
    else do
      ascending = .true
      itemColumns[i] = 0
    end

    listView~ListViewItemSorter = .ColumnSorter~new(colIndex, ascending)   -- (it sorts at once)
    listView~ListViewItemSorter = .nil
    return 0

::method connectEvents private
    expose list
    self~connectButtonEvent(IDC_RB_REPORT, "CLICKED", onReport)
    self~connectButtonEvent(IDC_RB_LIST, "CLICKED", onList)
    self~connectButtonEvent(IDC_RB_ICON, "CLICKED", onIcon)
    self~connectButtonEvent(IDC_RB_SMALL_ICON, "CLICKED", onSmallIcon)
    list~ColumnClick += .net~handler(self, "ONCOLCLICK")  -- ooDialog: connectListViewEvent(IDC_LV_VIEWS, "COLUMNCLICK", onColClick)
    -- (.NET version) the report view drawn by us: each cell, its icon and its text
    list~OwnerDraw = .true
    list~DrawColumnHeader += .net~handler(self, "ONDRAWHEADER")
    list~DrawItem += .net~handler(self, "ONDRAWITEM")
    list~DrawSubItem += .net~handler(self, "ONDRAWSUBITEM")

::method setImageLists private
    expose list small

    -- (.NET version) the original's bitmap strips (ooDialog: .ResourceImage,
    -- .ImageList~create, add)
    D = .net~System~Drawing
    srcDir = filespec("location", .context~package~name)

    small = .net~System~Windows~Forms~ImageList~new
    small~ImageSize = D~Size~new(16, 16)
    small~ColorDepth = "Depth24Bit"
    small~Images~AddStrip(D~Bitmap~new(srcDir"resources\columnIcons_16.bmp"))
    list~SmallImageList = small        -- ooDialog: list~setImageList(imageList, SMALL)

    normal = .net~System~Windows~Forms~ImageList~new
    normal~ImageSize = D~Size~new(32, 32)
    normal~ColorDepth = "Depth24Bit"
    normal~Images~AddStrip(D~Bitmap~new(srcDir"resources\columnIcons_32.bmp"))
    list~LargeImageList = normal       -- ooDialog: list~setImageList(imageList, NORMAL)

::method populateList private
    use strict arg list

    list~Columns~Add("Title", 150, "Left")     -- ooDialog: list~InsertColumnPx(0, "Title", 150)
    list~Columns~Add("Name", 75, "Left")
    list~Columns~Add("Last", 100, "Left")
    list~Columns~Add("e-mail", 150, "Left")

    -- ooDialog: addExtendedStyle("FULLROWSELECT UNDERLINEHOT ONECLICKACTIVATE SUBITEMIMAGES HEADERDRAGDROP")
    list~FullRowSelect = .true
    list~Activation = "OneClick"       -- (one click activates; the hot item is underlined)
    list~AllowColumnReorder = .true

    -- Each row: its title and the title's icon, then each subitem's text and
    -- icon (ooDialog: an LvItem, three LvSubItems, an LvFullRow)
    call addRow list, "Business manager",    6, "Tom",    14, "Sawyer",     26, "ts@google.com",       11
    call addRow list, "Software Developer",  1, "Sam",    14, "Frank",      15, "boo@gmail.com",       12
    call addRow list, "Mechanical Engineer", 0, "Tamara", 13, "Ecclestone", 16, "tameccle@yahoo.com",   9
    call addRow list, "Lawyer",              5, "Mary",   13, "Tyler",      17, "fkan@qualcom.com",    10
    call addRow list, "Doctor",              2, "Cienna", 13, "Acer",       18, "ca@sharp.org",        11
    call addRow list, "Clerk",               3, "Harry",  14, "Houdini",    19, "HH@magic.net",        12
    call addRow list, "Nurse",               4, "Mike",   14, "Thompson",   18, "mike@microsoft.com",  10
    call addRow list, "Drywall Finisher",    7, "Larry",  14, "Goodell",    20, "walls49@yahoo.com",    9
    call addRow list, "Biochemist",          8, "Kumar",  14, "Patel",      18, "kpatel@sequenom.com", 10

/* (.NET version) the drawing of the report view */
::method onDrawHeader unguarded
    use arg lv, e
    e~DrawDefault = .true

::method onDrawItem unguarded
    use arg lv, e
    e~DrawDefault = (lv~View~string \== "Details")   -- (the report view's cells: onDrawSubItem)

::method onDrawSubItem unguarded
    expose small
    use arg lv, e
    F = .net~System~Windows~Forms
    D = .net~System~Drawing
    g = e~Graphics
    b = e~Bounds
    if e~Item~Selected then do
        g~FillRectangle(D~SystemBrushes~Highlight, b)
        color = D~SystemColors~HighlightText
    end
    else do
        e~DrawBackground
        color = lv~ForeColor
    end
    img = e~SubItem~Tag
    if img \== .nil then small~Draw(g, b~X + 2, b~Y + (b~Height - 16) % 2, img)
    r = D~Rectangle~new(b~X + 21, b~Y, b~Width - 21, b~Height)
    F~TextRenderer~DrawText(g, e~SubItem~Text, lv~Font, r, color, "VerticalCenter, EndEllipsis, NoPrefix")

::method autoRun                       -- (.NET version) unattended: each view, a sort by Last both ways, then OK
    expose list
    do id over .array~of(IDC_RB_REPORT, IDC_RB_LIST, IDC_RB_SMALL_ICON, IDC_RB_ICON, IDC_RB_REPORT)
        self~newRadioButton(id)~PerformClick
        say "(auto)" self~newRadioButton(id)~Text":" list~View
    end
    e = .net~System~Windows~Forms~ColumnClickEventArgs~new(2)
    self~onColClick(list, e)
    say "(auto) by Last:" list~Items[0]~SubItems[2]~Text "..." list~Items[8]~SubItems[2]~Text
    self~onColClick(list, e)
    say "(auto) and back:" list~Items[0]~SubItems[2]~Text "..." list~Items[8]~SubItems[2]~Text
    list~Refresh
    say "(auto)" list~Items~Count "rows," list~SmallImageList~Images~Count "small icons, first row's:" list~Items[0]~SubItems[1]~Tag
    self~ok

/* (.NET version) a row: the item's text and icon, then each subitem's text and icon */
::routine addRow
    use arg list, text, img, n1, i1, n2, i2, n3, i3
    item = list~Items~Add(text, img)
    item~SubItems[0]~Tag = img
    do k = 1 to 3
        s = item~SubItems~Add(arg(2 + 2 * k))
        s~Tag = arg(3 + 2 * k)
    end

/* (.NET version) the comparer the ListView calls for each two rows: by one
   column's text, ascending or descending (the original's internal sort,
   caseless off) */
::class ColumnSorter subclass NetObject
::method activate class
    .net~extend(self, "System.Collections.IComparer")
::method init
    expose column ascending
    use strict arg column, ascending
    self~init:super
::method Compare
    expose column ascending
    use arg a, b
    r = a~SubItems[column]~Text~compareTo(b~SubItems[column]~Text)
    if ascending then return r
    return -r
