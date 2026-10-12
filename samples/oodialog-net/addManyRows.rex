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
 *  This example shows how to use the standard dialog, the ProgressDialog
 *  dialog, to show the user how a lengthy operation is progressing.  It also
 *  demonstrates how much faster an internal sort can be than using a Rexx sort.
 *
 *  The main points of the example are:
 *
 *  1.) It shows how to use the ProgressDialog class.
 *
 *  2.) It shows how to add items to list-views.
 *
 *  3.) It shows to sort on a column in the list-view.
 *
 *  NOTE: During a Rexx sort of the items in a list-view, the list-view invokes
 *        the Rexx method to do a comparison of 2 items.  Each callback from the
 *        native code the list-view is running in, to the Rexx interpreter, is
 *        relatively expensive.  As the number of items to sort grows, the
 *        number of comparisons grows far from linearly, and the expensive
 *        callbacks into the interpreter truely dominate.  Do not use the Rexx
 *        sort for a large number of items.
 *
 *  This example times the operations where a progress dialog is displayed and
 *  shows those times in the main dialog.
 *
 * (.NET version of ooDialog's examples\addManyRows.rex, on Windows Forms
 * through oodnet.cls: addManyRows.rc's dialogs are the classes of
 * addManyRowsrc.cls. ProgressDialog and Alerter are oodnet.cls's, with
 * ooDialog's methods. The list-view is a .NET ListView: a row is a
 * ListViewItem made from an Array of its 12 texts (ooDialog: LvItem,
 * LvSubItem, LvFullRow), the extended styles are its properties. The
 * internal sort is .NET's Array.Sort of the rows by the column's texts; the
 * Rexx sort is the ListView's own sort calling a Rexx IComparer
 * (RexxItemSorter, .net~extend) for each comparison, as the original's
 * list-view calls doRexxSort. An up-down that steps by 100 is a
 * NumericUpDown's Increment (ooDialog: DELTAPOS answering delta * 100).)
 */

    .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended

    -- Allow the user to pick the number of items to be inserted into the
    -- list-view.
    dlgIntro = .ExampleSetUpDlg~new                         -- ooDialog: ~new(srcDir'resources\addManyRows.rc', IDD_INTRO)
    if dlgIntro~execute('SHOWTOP') == dlgIntro~IDCANCEL then do
      ret = MessageDialog('You are missing out on an excellent example', ,'User Canceled', 'OK', 'WARNING')
      return 99
    end

    dlg = .AddManyRowsDlg~new                               -- ooDialog: ~new(srcDir'resources\addManyRows.rc', IDD_ADD_ROWS)
    if dlg~initCode = 0 then do
        dlg~itemCount = dlgIntro~selectedCount
        dlg~execute("SHOWTOP")
    end

return 0
-- End of entry point.

::requires "addManyRowsrc.cls"
::requires "net.cls"                   -- (.NET version) NetObject, for RexxItemSorter

/** AddManyRowsDlg
 * Our main example dialog subclass.
 */
::class 'AddManyRowsDlg' subclass AddManyRows_IDD_ADD_ROWS

::attribute itemCount
::attribute createRowsTime
::attribute insertRowsTime
::attribute insertedRows
::attribute internalSortTime
::attribute rexxSortTime

/** initDialog()
 * initDialog is the place to do any initialization that requires the underlying
 * dialog to exist.  Here we set the list-view's extended styles and fill the
 * list-view with its items.  (.NET version) The dialog is not shown yet.
 */
::method initDialog
    expose list rows createCanceled insertCanceled

    list = self~newListView(IDC_LV)
    list~FullRowSelect = .true          -- ooDialog: addExtendedStyle("FULLROWSELECT GRIDLINES CHECKBOXES HEADERDRAGDROP")
    list~GridLines = .true
    list~CheckBoxes = .true
    list~AllowColumnReorder = .true

    list~Columns~Add("Line text", self~px(75))   -- ooDialog: list~InsertColumn(0, "Line text", 75): dialog units
    list~Columns~Add("Line number", self~px(55))
    list~Columns~Add("Numbers", self~px(50))
    do 9
      list~Columns~Add("Characters", self~px(55))
    end

    self~connectButtonEvent(IDC_PB_SORT_INTERN, 'CLICKED', onSortInternally)
    self~connectButtonEvent(IDC_PB_SORT_REXX, 'CLICKED', onSortRexx)

    rows = self~createRows(list)

    self~newGroupBox(IDC_GB_TIMES)~Text = 'Time in seconds (' || self~itemCount || ' rows):'
    self~setStatics


/** setStatics
 * Helper method to set up the static controls that are used to display the
 * timings.  How they are set is dependent on whether the user canceled the
 * creation or the insertion of the rows.
 */
::method setStatics private
    expose createCanceled insertCanceled staticInternal staticRexxSort

    staticCreate   = self~newStatic(IDC_ST_CREATE)
    staticInsert   = self~newStatic(IDC_ST_INSERT)
    staticInternal = self~newStatic(IDC_ST_INTERNAL)
    staticRexxSort = self~newStatic(IDC_ST_REXXSORT)

    if createCanceled then do
        staticCreate~Text = 'Create full rows:' self~createRowsTime '(canceled)'
        staticInsert~Text = 'Insert full rows: N/A'
        staticInternal~Visible = .false
        staticRexxSort~Visible = .false
        self~newPushButton(IDC_PB_SORT_INTERN)~Enabled = .false
        self~newPushButton(IDC_PB_SORT_REXX)~Enabled = .false
        staticCreate~Width *= 2         -- ooDialog: windowRect, then resizeTo
        return 0
    end

    staticCreate~Text = 'Create full rows:' self~createRowsTime

    if insertCanceled then do
        staticInsert~Text = 'Insert full rows:' self~insertRowsTime '(canceled after inserting' self~insertedRows 'rows)'
        staticInternal~Visible = .false
        staticRexxSort~Visible = .false
        self~newPushButton(IDC_PB_SORT_INTERN)~Enabled = .false
        self~newPushButton(IDC_PB_SORT_REXX)~Enabled = .false
        staticInsert~Width *= 2
        return 0
    end

    staticInsert~Text = 'Insert full rows:' self~insertRowsTime


/** onSortInternally()
 * The event handler for the Internal Sort push button.  We put up a dialog to
 * let the user decide what and how to sort.  (.NET version) The sort is
 * .NET's: Array.Sort of the rows by the texts of the column, compared
 * ordinally, with or without case.
 */
::method onSortInternally unguarded
    expose list staticInternal

    dlg = .SortSetupDlg~new
    if dlg~execute('SHOWTOP') == dlg~IDCANCEL then return 0

    column = dlg~column; ascending = dlg~ascending; caseless = dlg~caseless

    j = time('E')
    n = list~Items~Count
    items = .net~System~Array~CreateInstance(.net~type("System.Windows.Forms.ListViewItem"), n)
    list~Items~CopyTo(items, 0)
    keys = .net~System~Array~CreateInstance(.net~type("string"), n)
    do i = 1 to n                       -- (a .NET array is a Rexx Array, from 1; SubItems is a collection, from 0)
        keys[i] = items[i]~SubItems[column]~Text
    end
    SC = .net~System~StringComparer
    .net~System~Array~Sort(keys, items, caseless~?(SC~OrdinalIgnoreCase, SC~Ordinal))
    if \ ascending then .net~System~Array~Reverse(items)
    list~BeginUpdate
    list~Items~Clear
    list~Items~AddRange(items)
    list~EndUpdate
    self~internalSortTime = time('e')

    staticInternal~Text = 'Internal sort:' self~internalSortTime


/** onSortRexx()
 * The event handler for the Rexx Sort push button.  We put up a dialog to
 * let the user decide what and how to sort.  We also warn the user that the
 * sort can take a very long time depending on the number of items in the
 * list-view
 */
::method onSortRexx unguarded
    expose list staticRexxSort

    count = self~itemCount
    if count > 1500 & count <= 2000 then do
        msg = "A Rexx sort with" count 'items can take' || .endOfLine || -
              'some time.  Please be patient.'                        || .endOfLine~copies(2)
    end
    else if count > 2000 then do
        msg = "A Rexx sort with" count 'items is not a' || .endOfLine || -
              'good idea, it can take too long.'                      || .endOfLine~copies(2) || -
              'If you want to perform this sort out of' || .endOfLine || -
              'curiousity, start the sort and then let' || .endOfLine || -
              'it alone. Windows will say the window'   || .endOfLine || -
              'is not responding.  But it will event-'  || .endOfLine || -
              'ually finish.'                                         || .endOfLine~copies(2)
    end

    if msg~length > 3 then do
        msg || = 'Do you want to continue?'
        title = 'Cautionary Statement - Think Twice'
        if MessageDialog(msg, self~hwnd, title, 'YESNO', 'WARNING') == self~IDNO then return 0
    end

    dlg = .SortSetupDlg~new
    if dlg~execute('SHOWTOP') == dlg~IDCANCEL then return 0

    msg  = 'Performing a list-view item sort using a Rexx method.  Please be patient...'
    capt = 'Rexx ooDialog Dialog Method Sort'

    pbDlg = .ProgressDialog~new(capt, msg)
    pbDlg~msgHeight = 2
    pbDlg~marqueeMode = .true
    pbDlg~marqueePause = 50
    pbDlg~noStatus = .true

    j = time('E')
    pbDlg~begin

    -- (.NET version) The ListView sorts, asking a Rexx IComparer to compare
    -- each two items; then it stops sorting by it (else it would sort each
    -- item added).
    list~ListViewItemSorter = .RexxItemSorter~new(dlg~column, dlg~ascending, dlg~caseless)
    say "(Rexx sort:" list~ListViewItemSorter~comparisons "comparisons)"
    list~ListViewItemSorter = .nil

    pbDlg~endNow
    self~rexxSortTime = time('e')

    staticRexxSort~Text = 'Rexx sort:' self~rexxSortTime


/** createRows()
 * Here we create a ListViewItem for every row, (.NET version) each from an
 * Array of the texts of its 12 columns.
 *
 * All the rows are put into an array.  The array is then used to insert all
 * the items into the list-view.
 */
::method createRows private
    expose createCanceled insertCanceled
    use arg list

    j = time('E')
    createCanceled = .false
    insertCanceled = .false

    count = self~itemCount
    rows = .array~new(count)

    step = (count * 2) / 100
    if \ step~datatype('W') then step = trunc(step)

    pbDlg = .ProgressDialog~new
    pbDlg~msgText = 'Creating and inserting full rows into the list-view. This will take some time.'

    if self~itemCount > 30000 then do
      extra = .endOfLine~copies(2) || 'It is possible that inserting' self~itemCount 'items will take a while.'
      pbDlg~msgText || = extra
      pbDlg~msgHeight = 5
    end

    a = .Alerter~new
    pbDlg~setInterruptible(a)

    pbDlg~begin
    pbDlg~updateStatus('0 full rows created')

    LVI = .net~System~Windows~Forms~ListViewItem
    do i = 1 to count
        texts = .array~of('Line' i, i, random(1, 200))
        do 9
          texts~append(self~randomChars)
        end
        rows[i] = LVI~new(texts)        -- ooDialog: .LvItem, 11 .LvSubItem, a .LvFullRow

        if i // step = 0 then do
              pbDlg~increase
              pbDlg~updateStatus(i 'full rows created')
        end

        if a~isCanceled then do
              pbDlg~updateStatus('canceled after creating' i 'full rows')
              r = SysSleep(1.5)
              pbDlg~endNow
              leave
        end
    end

    self~createRowsTime = time('e')
    self~itemCount = rows~items

    if a~isCanceled then do
        createCanceled = .true
        return rows
    end

    j = time('r')
    pbDlg~updateStatus('0 full rows inserted')

    list~BeginUpdate                    -- ooDialog: list~prepare4nItems(rows~items)
    do i = 1 to rows~items
        list~Items~Add(rows[i])         -- ooDialog: list~addFullRow(rows[i])

        if i // step = 0 then do
                pbDlg~increase
                pbDlg~updateStatus(i 'full rows inserted')
        end

        if a~isCanceled then do
                pbDlg~updateStatus('canceled after inserting' i 'full rows')
                r = SysSleep(1.5)
                pbDlg~endNow
                leave
        end
    end
    list~EndUpdate

    self~insertRowsTime = time('e')

    if a~isCanceled then do
        self~insertedRows = i
        insertCanceled = .true
    end
    else do
        pbDlg~complete
        pbDlg~updateStatus('finished inserting' rows~items 'full rows')
        r = SysSleep(1.5)
        pbDlg~endNow
    end

    return rows

/** randomChars()
 * Simple method to generate some random string of characters.
 */
::method randomChars private

    len   = random(1, 7)
    chars = ''
    do i = 1 to len
        upper = random(0, 1)
        if upper then chars || = random(65, 90)~d2c
        else chars || = random(97, 122)~d2c
    end
    return chars

::method autoRun                       -- (.NET version) unattended: both sorts, the times, then OK
    expose list
    self~onSortInternally
    say "(auto)" list~Items~Count "rows; internal sort:" self~internalSortTime "s; first:" list~Items[0]~SubItems[3]~Text
    self~onSortRexx
    say "(auto) Rexx sort:" self~rexxSortTime "s; first:" list~Items[0]~SubItems[3]~Text
    say "(auto) create" self~createRowsTime "s, insert" self~insertRowsTime "s"
    self~ok


/** RexxItemSorter
 * (.NET version) The comparer the ListView calls for each two items it
 * compares: a Rexx class extending System.Collections.IComparer, its Compare
 * method ooDialog's doRexxSort.
 */
::class RexxItemSorter subclass NetObject
::attribute comparisons get
::method activate class
    .net~extend(self, "System.Collections.IComparer")
::method init
    expose rexxColumn rexxAscending rexxCaseless comparisons
    use strict arg rexxColumn, rexxAscending, rexxCaseless
    comparisons = 0
    self~init:super
::method Compare
    expose rexxColumn rexxAscending rexxCaseless comparisons
    use arg lvRow1, lvRow2

    comparisons += 1
    text1 = lvRow1~SubItems[rexxColumn]~Text    -- (the item's own text: SubItems[0])
    text2 = lvRow2~SubItems[rexxColumn]~Text

    if rexxAscending then do
        if rexxCaseless then return text1~caselessCompareTo(text2)
        else return text1~compareTo(text2)
    end
    else do
        if rexxCaseless then return text2~caselessCompareTo(text1)
        else return text2~compareTo(text1)
    end


/** ExampleSetUpDlg
 * A simple helper dialog for our example.  We let the user choose the number of
 * list-view items to insert.
 */
::class 'ExampleSetUpDlg' subclass AddManyRows_IDD_INTRO

::attribute selectedCount

::method initDialog
    expose selectedCount updItems chkFreeForm radios

    radios = .array~of(IDC_RB_1000, IDC_RB_2000, IDC_RB_5000, IDC_RB_10000, IDC_RB_15000, IDC_RB_25000)
    selectedCount = 5000
    self~newRadioButton(IDC_RB_5000)~Checked = .true

    -- (.NET version) The edit and its up-down are one NumericUpDown
    -- (newUpDown(IDC_SP_ITEMS) and newEdit(IDC_ED_ITEMS) give it); it steps
    -- by 100, as the original's DELTAPOS answer makes its up-down do.
    updItems = self~newUpDown(IDC_SP_ITEMS)
    updItems~Maximum = 50000            -- ooDialog: setRange(r), r~min = 500, r~max = 50000
    updItems~Minimum = 500
    updItems~Value = 10000              -- ooDialog: setPosition(10000)
    updItems~Increment = 100
    updItems~Enabled = .false

    chkFreeForm = self~newCheckBox(IDC_CK_FREEFORM)
    self~connectButtonEvent(IDC_CK_FREEFORM, 'CLICKED', onClick)

::method onClick unguarded
    expose chkFreeForm updItems radios

    on = chkFreeForm~Checked
    updItems~Enabled = on
    do id over radios
        self~newRadioButton(id)~Enabled = \ on
    end

::method ok unguarded
    expose chkFreeForm updItems radios selectedCount

    if chkFreeForm~Checked then do
        selectedCount = updItems~Value~format(, 0)
    end
    else do
        j = 1
        do id over radios
            if self~newRadioButton(id)~Checked then leave
            j += 1
        end

        select
            when j = 1 then selectedCount = 1000
            when j = 2 then selectedCount = 2000
            when j = 3 then selectedCount = 5000
            when j = 4 then selectedCount = 10000
            when j = 5 then selectedCount = 15000
            when j = 6 then selectedCount = 25000
            otherwise       selectedCount = 0
        end
        -- End select
    end

    return self~ok:super

::method autoRun                       -- (.NET version) unattended: free-form, 1500 rows, OK
    expose chkFreeForm updItems
    chkFreeForm~Checked = .true
    self~onClick
    updItems~Value = 1500
    say "(auto) free-form:" updItems~Value "rows; 5,000 enabled:" self~newRadioButton(IDC_RB_5000)~Enabled
    self~ok


/** SortSetUpDlg
 * A dialog to let the user choose what and how they want sorted.
 */
::class 'SortSetUpDlg' subclass AddManyRows_IDD_SORT_PARAMS

::attribute column
::attribute ascending
::attribute caseless

::method initDialog
    expose column ascending caseless rbItem rbAscending rbCaseless upDown

    column    = 0
    ascending = .true
    caseless  = .true

    rbItem      = self~newRadioButton(IDC_RB_ITEM)
    rbAscending = self~newRadioButton(IDC_RB_ASCENDING)
    rbCaseless  = self~newRadioButton(IDC_RB_CASELESS)
    do rb over .array~of(rbItem, rbAscending, rbCaseless)   -- ooDialog: ~~check
        rb~Checked = .true
    end

    upDown = self~newUpDown(IDC_SP_COL)  -- (.NET version) with its edit, one NumericUpDown
    upDown~Minimum = 1                   -- ooDialog: setRange(1, 11)
    upDown~Maximum = 11
    upDown~Value = 3                     -- ooDialog: setPosition(3)
    upDown~Enabled = .false

    self~connectButtonEvent(IDC_RB_ITEM, 'CLICKED', onItemClick)
    self~connectButtonEvent(IDC_RB_SUBITEM, 'CLICKED', onSubItemClick)

    rbItem~Select                       -- ooDialog: rbItem~assignFocus

::method onItemClick unguarded
    expose upDown
    upDown~Enabled = .false

::method onSubItemClick unguarded
    expose upDown
    upDown~Enabled = .true

::method ok unguarded
    expose column ascending caseless rbItem rbAscending rbCaseless upDown

    if rbItem~Checked then column = 0
    else column = upDown~Value~format(, 0)

    ascending = rbAscending~Checked
    caseless = rbCaseless~Checked

    return self~ok:super

::method autoRun                       -- (.NET version) unattended: subitem 3, descending, case sensitive
    expose upDown
    self~newRadioButton(IDC_RB_SUBITEM)~Checked = .true
    self~onSubItemClick
    self~newRadioButton(IDC_RB_DESCENDING)~Checked = .true
    self~newRadioButton(IDC_RB_CASE)~Checked = .true
    say "(auto) sort: still checked, Item:" self~newRadioButton(IDC_RB_ITEM)~Checked", Ascending:" -
        self~newRadioButton(IDC_RB_ASCENDING)~Checked", Case Insensitive:" self~newRadioButton(IDC_RB_CASELESS)~Checked
    self~ok
