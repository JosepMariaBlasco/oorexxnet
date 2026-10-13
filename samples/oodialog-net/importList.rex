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

/**  importList.rex
 *
 * (.NET version of ooDialog's controls\ListView\subitem.editing\importList.rex,
 * on Windows Forms through oodnet.cls. The .rc is importListrc.cls, written
 * by rc2oodnet.rex -cls: its two dialogs and its menu bar (ooDialog's
 * ScriptMenuBar). Both dialogs inherit ResizingAdmin, as the original's: the
 * same defineSizing, oodnet.cls's ResizingAdmin doing what ooDialog's does.
 * The combo box and the edit control go into the ListView's Controls
 * (ooDialog: setParent); their events still come to us in .NET, so no
 * isGrandchild: KeyDown gives Enter and Escape (wantKeys: not the dialog's
 * default button), LostFocus the end of the editing. The ListView's
 * MouseClick and MouseDoubleClick, with HitTest, say which item and subitem
 * were clicked, and whether on the label (ooDialog: the CLICK and DBLCLK
 * events, hitTestInfo with the Mouse class); a .NET ListView has no scroll
 * event: the mouse wheel ends the editing (ooDialog: BEGINSCROLL,
 * ENDSCROLL). .BrowseForFolder is .NET's FolderBrowserDialog; the directory
 * shows with its end cut off when it is too long (ooDialog's
 * SS_PATHELLIPSIS cuts its middle).)
 */

    .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended

    files = getInitialFiles()
    if files == .nil then return 99

    if files~items == 0 then initDir = 'C:\'
    else initDir = filespec("location", files[1])

    dlg = .ImporterList~new                                 -- ooDialog: .ImporterList~new(sd"importList.rc", IDD_IMPORTER)
    if dlg~initCode = 0 then do
        dlg~fileList = files
        dlg~fileListDirectory = initDir
        dlg~Execute("SHOWTOP")
    end

return 0

::requires "importListrc.cls"

::class 'ImporterList' subclass ImportList_IDD_IMPORTER inherit ResizingAdmin

::constant NORMAL_HTEXT         'Review the import file Options, change if necessary, then click the "Process" button or use the "Process Current View" menu item to process the import files and continue working, click the "Ok" button to process the files and quit, or click the "Cancel" button to quit without processing.'
::constant EMPTY_LIST_HTEXT     'Click the "Import" button to poplulate the list view with the import files.'
::constant EMPTY_ONIMPORT_HTEXT 'The import file list is empty.  Reset the import directory and retry the import operation.'
::constant POST_PROCESS_HTEXT   'Double-click on the Import Directory text or use the Reset Dirctory menu item to set up a new import.'

::attribute fileList
::attribute fileListDirectory

::method defineSizing

    self~defaultLeft('STATIONARY', 'LEFT')
    self~defaultRight('STATIONARY', 'RIGHT')
    self~defaultTop('STATIONARY', 'TOP')
    self~defaultBottom('STATIONARY', 'BOTTOM')

    self~controlBottom(IDC_HEADER, 'MYTOP', 'TOP')

    self~controlLeft(IDCANCEL, 'STATIONARY', 'RIGHT')
    self~controlTop(IDCANCEL, 'STATIONARY', 'BOTTOM')
    self~controlRight(IDCANCEL, 'MYLEFT', 'LEFT')
    self~controlBottom(IDCANCEL, 'MYTOP', 'TOP')

    self~controlLeft(IDOK, 'STATIONARY', 'LEFT', IDCANCEL)
    self~controlTop(IDOK, 'STATIONARY', 'BOTTOM')
    self~controlRight(IDOK, 'MYLEFT', 'LEFT')
    self~controlBottom(IDOK, 'MYTOP', 'TOP')

    self~controlLeft(IDC_PB_IMPORT, 'STATIONARY', 'LEFT', IDOK)
    self~controlTop(IDC_PB_IMPORT, 'STATIONARY', 'BOTTOM')
    self~controlRight(IDC_PB_IMPORT, 'MYLEFT', 'LEFT')
    self~controlBottom(IDC_PB_IMPORT, 'MYTOP', 'TOP')

    self~controlLeft(IDC_PB_PROCESS, 'STATIONARY', 'LEFT', IDC_PB_IMPORT)
    self~controlTop(IDC_PB_PROCESS, 'STATIONARY', 'BOTTOM')
    self~controlRight(IDC_PB_PROCESS, 'MYLEFT', 'LEFT')
    self~controlBottom(IDC_PB_PROCESS, 'MYTOP', 'TOP')

    --self~controlLeft(IDC_ST_DIR_LABEL, 'STATIONARY', 'LEFT', IDC_PB_IMPORT)
    self~controlTop(IDC_ST_DIR_LABEL, 'STATIONARY', 'BOTTOM')
    self~controlRight(IDC_ST_DIR_LABEL, 'MYLEFT', 'LEFT')
    self~controlBottom(IDC_ST_DIR_LABEL, 'MYTOP', 'TOP')

    self~controlLeft(IDC_ST_DIRECTORY, 'STATIONARY', 'RIGHT', IDC_ST_DIR_LABEL)
    self~controlTop(IDC_ST_DIRECTORY, 'STATIONARY', 'BOTTOM')
    self~controlRight(IDC_ST_DIRECTORY, 'STATIONARY', 'LEFT', IDC_PB_PROCESS)
    self~controlBottom(IDC_ST_DIRECTORY, 'MYTOP', 'TOP')


    return 0

::method initDialog
    expose hText edit comboBox listView pbProcess pbImport textDir fileListDirectory menuBar

    menuBar = .ImportList_IDM_MENUBAR~new                   -- ooDialog: .ScriptMenuBar~new(... "importList.rc", IDM_MENUBAR)
    menuBar~attachTo(self)

    hText    = self~newStatic(IDC_HEADER)
    comboBox = self~newComboBox(IDC_CB)
    listView = self~newListView(IDC_LV)
    edit     = self~newEdit(IDC_EDIT)

    pbProcess = self~newPushButton(IDC_PB_PROCESS)
    pbImport  = self~newPushButton(IDC_PB_IMPORT)
    textDir   = self~newStatic(IDC_ST_DIRECTORY)

    self~connectEvent(IDC_LV, "MouseDoubleClick", onLVDClick)   -- ooDialog: connectListViewEvent(IDC_LV, "DBLCLK", ...)
    self~connectEvent(IDC_LV, "MouseClick", onLVSClick)         -- ooDialog: "CLICK"
    self~connectEvent(IDC_LV, "MouseWheel", onLVScroll)         -- ooDialog: "BEGINSCROLL", "ENDSCROLL"

    self~connectButtonEvent(IDC_PB_PROCESS, 'CLICKED', onProcess)
    self~connectButtonEvent(IDC_PB_IMPORT, 'CLICKED', onImport)
    ret = self~connectStaticEvent(IDC_ST_DIRECTORY, 'DBLCLK', onDirectory)

    menuBar~connectCommandEvent(IDM_PROCESS_VIEW, onProcess)
    menuBar~connectCommandEvent(IDM_IMPORT_DIRECTORY, onImport)
    menuBar~connectCommandEvent(IDM_RESET_DIRECTORY, onDirectory)

    self~form~Controls~Remove(comboBox)                     -- ooDialog: comboBox~setParent(listView)
    listView~Controls~Add(comboBox)
    comboBox~KeyDown += .net~handler(self, "ONEDITGRANDCHILDEVENT")   -- ooDialog: comboBox~isGrandchild(onEditGrandChildEvent)
    comboBox~LostFocus += .net~handler(self, "ONEDITGRANDCHILDEVENT")
    self~wantKeys(comboBox)

    self~form~Controls~Remove(edit)                         -- ooDialog: edit~setParent(listView)
    listView~Controls~Add(edit)
    edit~KeyDown += .net~handler(self, "ONEDITGRANDCHILDEVENT")
    edit~LostFocus += .net~handler(self, "ONEDITGRANDCHILDEVENT")
    self~wantKeys(edit)

    --comboBox~hide
    --edit~hide

    textDir~Text = fileListDirectory

    self~initListView
    self~onImport


::method onDirectory unguarded
    expose fileListDirectory fileList pbProcess pbImport textDir listView hText menuBar

    newDir = getNewDirectory(fileListDirectory, self)
    if newDir == .nil | newDir == '' then return 0

    fileListDirectory = newDir
    fileList          = .nil
    textDir~Text = fileListDirectory
    listView~Items~Clear                                    -- ooDialog: listView~deleteAll

    pbProcess~Enabled = .false
    menuBar~disable(IDM_PROCESS_VIEW)
    pbImport~Enabled = .true
    menuBar~enable(IDM_IMPORT_DIRECTORY)

    hText~Text = self~EMPTY_LIST_HTEXT

::method onImport unguarded
     expose hText listView pbProcess pbImport fileList fileListDirectory menuBar

     if fileList == .nil then do
         fileList = getFileList(fileListDirectory)
         if fileList == .nil then fileList = onErrorGetFiles(fileListDirectory)
         if fileList == .nil then return self~cancel:super
     end

     listView~Items~Clear
     call mssleep(500)            -- delay to allow ListView to display before content added

     listView~BeginUpdate
     do i = 1 to fileList~items
         buName = 'Z:' || filespec('PATH', fileList[i]) || filespec('NAME', fileList[i])
         listView~Items~Add(.net~System~Windows~Forms~ListViewItem~new(.array~of('Import', buName, fileList[i])))   -- ooDialog: addRow
     end
     listView~EndUpdate

     if fileList~items == 0 then do
         hText~Text = self~EMPTY_ONIMPORT_HTEXT
         pbProcess~Enabled = .false
         menuBar~disable(IDM_PROCESS_VIEW)
     end
     else do
         hText~Text = self~getNormalHText

         pbImport~Enabled = .false
         menuBar~disable(IDM_IMPORT_DIRECTORY)
         pbProcess~Enabled = .true
         menuBar~enable(IDM_PROCESS_VIEW)
     end


::method onProcess unguarded
     expose listView pbProcess pbImport hText menuBar

     buNamesImport  = .array~new
     buNamesReplace = .array~new
     importNames    = .array~new
     replaceNames   = .array~new
     count          = listView~Items~Count
     skipCount      = 0

     do i = 0 to count - 1
         verb = listView~Items[i]~SubItems[0]~Text           -- ooDialog: listView~itemText(i, 0)
         select
             when verb == 'Skip' then do
                 skipCount += 1
             end
             when verb == 'Import' then do
                 buNamesImport~append(listView~Items[i]~SubItems[1]~Text)
                 importNames~append(listView~Items[i]~SubItems[2]~Text)
             end
             when verb == 'Replace' then do
                 buNamesReplace~append(listView~Items[i]~SubItems[1]~Text)
                 replaceNames~append(listView~Items[i]~SubItems[2]~Text)
             end
         end
         -- End select
     end

     title = 'Import Manager'
     msg   = 'Projected Import Processing Statistics:'         || .endOfLine~copies(2)
     msg ||= 'Skipping files:' || '09'x  || skipCount          || .endOfLine
     msg ||= 'Importing files:' || '09'x || importNames~items  || .endOfLine
     msg ||= 'Replacing files:' || '09'x || replaceNames~items || .endOfLine~copies(2)
     msg ||= 'Process files?'

     if messageDialog(msg, self~hwnd, title, 'YESNO', 'INFORMATION') == self~IDNO then return 0

     col1width = 0
     col4width = 0
     do i = 1 to buNamesImport~items
         s = textSizePx(listView, buNamesImport[i])         -- ooDialog: listView~getTextSizePx
         if s~width > col1width then col1width = s~width

         s = textSizePx(listView, importNames[i])
         if s~width > col4width then col4width = s~width
     end

     do i = 1 to buNamesReplace~items
         s = textSizePx(listView, buNamesReplace[i])
         if s~width > col1width then col1width = s~width

         s = textSizePx(listView, replaceNames[i])
         if s~width > col4width then col4width = s~width
     end

    dlg = .ResultList~new                                   -- ooDialog: .ResultList~new("importList.rc", IDD_RESULTS)
    if dlg~initCode = 0 then do
        dlg~buNamesImport  = buNamesImport
        dlg~buNamesReplace = buNamesReplace
        dlg~importNames    = importNames
        dlg~replaceNames   = replaceNames
        dlg~col1width      = col1width
        dlg~col4width      = col4width
        dlg~execute("SHOWTOP")
    end

    listView~Items~Clear

    pbImport~Enabled = .false
    pbProcess~Enabled = .false
    menuBar~disable(IDM_IMPORT_DIRECTORY)
    menuBar~disable(IDM_PROCESS_VIEW)

    hText~Text = self~POST_PROCESS_HTEXT

    return 0


::method initListView private
   expose hText listView comboBox cbVisible editVisible

   baksize = 25
   impsize = 25
   optsize = 10 * 8
   impsize = (impsize + 3) * 8
   baksize = (baksize + 3) * 8

   listView~FullRowSelect = .true                           -- ooDialog: addExtendedStyle("FULLROWSELECT GRIDLINES HEADERDRAGDROP")
   listView~GridLines = .true
   listView~AllowColumnReorder = .true
   listView~Columns~Add("Option", optsize)                  -- ooDialog: insertColumnPX(0, "Option", optsize, "LEFT")
   listView~Columns~Add("Backup Filename to Import", impsize)
   listView~Columns~Add("Import To:", baksize)

   comboBox~Items~Add("Import")
   comboBox~Items~Add("Replace")
   comboBox~Items~Add("Skip")
   comboBox~SelectedIndex = 0                               -- ooDialog: selectIndex(1)
   cbVisible = .false
   editVisible = .false


::method ok unguarded
    expose pbProcess

    if pbProcess~Enabled then self~onProcess
    return self~ok:super

-- Used to process double click, and modify the list view if the double click
-- was on column 2
::method onLVDClick unguarded
   expose currentIndex currentColumn comboBox edit cbVisible editVisible
   use arg lv, e

   hit = lv~HitTest(e~Location)                             -- (.NET version) the item and subitem clicked
   if hit~Item == .nil | hit~SubItem == .nil then return 0
   itemIndex = hit~Item~Index
   columnIndex = hit~Item~SubItems~IndexOf(hit~SubItem)

   currentIndex  = itemIndex
   currentColumn = columnIndex

   if columnIndex == 2 then do
       text = lv~Items[itemIndex]~SubItems[columnIndex]~Text

       edit~Bounds = hit~SubItem~Bounds                     -- ooDialog: getSubitemRect(..., "BOUNDS"), setWindowPos

       edit~Text = text
       edit~Visible = .true
       edit~BringToFront
       edit~Focus                                           -- ooDialog: edit~assignFocus
       editVisible = .true
   end

   return 0

-- Used to process single click, and modify the list view if the single click
-- was on column 0
::method onLVSClick unguarded
   expose currentIndex currentColumn comboBox edit cbVisible editVisible
   use arg lv, e

   hit = lv~HitTest(e~Location)
   if hit~Item == .nil | hit~SubItem == .nil then return 0
   itemIndex = hit~Item~Index
   columnIndex = hit~Item~SubItems~IndexOf(hit~SubItem)

   currentIndex = itemIndex
   currentColumn = columnIndex

   if editVisible, columnIndex <> 2 then do
       -- This is not needed, lost focus event happens first.
       editVisible = .false
       edit~Visible = .false
   end

   if self~goodColumn0(itemIndex, columnIndex, hit) then do
       -- Set the combo box selection to match the current text of the list view
       -- item before it is shown.
       curText = lv~Items[itemIndex]~Text
       comboBox~SelectedItem = curText                      -- ooDialog: comboBox~select(curText)

       r = hit~Item~GetBounds(.net~System~Windows~Forms~ItemBoundsPortion~Label)                      -- ooDialog: getSubitemRect(itemIndex, columnIndex, "LABEL")
       comboBox~Location = .net~System~Drawing~Point~new(r~Left, r~Top - 3)   -- (its height is its font's)
       comboBox~Width = r~Width

       cbVisible = .true
       comboBox~Visible = .true
       comboBox~BringToFront
       comboBox~Focus
   end
   return 0


-- Used to detect when focus is on/off scroll
::method onLVScroll unguarded
    expose comboBox edit cbVisible editVisible

    return self~acceptUserInput('none')

-- The event handler for both the grandchild edit and comob box controls.
-- Invoked when the grandchild receives an enter, esc, or lost focus event.
::method onEditGrandChildEvent unguarded
    expose comboBox edit listView cbVisible editVisible currentIndex currentColumn
    use arg ctrl, e

    if .net~isInstance(e, "System.Windows.Forms.KeyEventArgs") then do   -- (.NET version) the event, as ooDialog names it
        caseOf = e~KeyCode~string
        select case caseOf                               -- (not the expression itself: ooRexx bug, SELECT CASE: #2114)
            when 'Enter' then keyEvent = 'enter'
            when 'Escape' then keyEvent = 'escape'
            otherwise return 0
        end
        e~SuppressKeyPress = .true
    end
    else keyEvent = 'killfocus'

    return self~acceptUserInput(keyEvent)

::method acceptUserInput private unguarded
    expose comboBox edit listView cbVisible editVisible currentIndex currentColumn
    use arg keyEvent

    if cbVisible then do
        text = comboBox~Text                                -- ooDialog: comboBox~selected
        cbVisible = .false
        comboBox~Visible = .false
        if keyEvent <> 'escape' then listView~Items[currentIndex]~SubItems[currentColumn]~Text = text   -- ooDialog: listView~modify
        if keyEvent == 'none' then do
            listView~Invalidate                             -- ooDialog: redrawItems, updateWindow
            listView~Update
        end
    end
    else if editVisible = .true then do
        text = edit~Text~strip
        editVisible = .false
        edit~Visible = .false
        if keyEvent <> 'escape' then listView~Items[currentIndex]~SubItems[currentColumn]~Text = text
    end

    return 0


-- Determines if a reported single click is a valid click for opening the combo
-- box.  Clicks that are below the last item in the view can have column == 0,
-- but the item index will be -1.  In addition, if the list view has more items
-- than fit on a single page, click to the right of the last column can return
-- 0 for the column index.  The only way to detect this situation is to check
-- the mouse postion and use hitTestInfo() to have the list view tell us whern
-- the mouse is.
-- (.NET version) the HitTest of the click itself says where it was
::method goodColumn0 unguarded private
    use strict arg index, colIndex, hit

    if colIndex == 0, index <> -1 then do
        if hit~Location~string~pos('Label') > 0 then return .true   -- ooDialog: info~info == 'OnLabel'
    end

    return .false

::method getNormalHText private

    return 'Review the import file Options, change if necessary, then click '     || -
           'the "Process" button or use the "Process Current View" menu item '    || -
           'to process the import files and continue working, click the "Ok" '    || -
           'button to process the files and quit, or click the "Cancel" button '  || -
           'to quit without processing.  The "Exit" menu item also quits without' || -
           'processing.'

::method autoRun                       -- (.NET version) unattended: an Option changed with the combo box, a destination edited, Process; Cancel
    expose listView comboBox edit
    WF = .net~System~Windows~Forms
    say "(auto)" listView~Items~Count "files from" self~fileListDirectory
    if listView~Items~Count < 2 then return self~cancel
    say "(auto) resizable:" self~form~FormBorderStyle~string", at least" self~form~MinimumSize~toString
    hdr = self~newStatic(IDC_HEADER); ok = self~newPushButton(IDOK); dir = self~newStatic(IDC_ST_DIRECTORY)
    before = listView~Width listView~Height ok~Left ok~Top dir~Width
    self~form~ClientSize = .net~System~Drawing~Size~new(self~form~ClientSize~Width + 100, self~form~ClientSize~Height + 60)
    say "(auto) 100 x 60 pixels larger: list, OK, directory" before "->" listView~Width listView~Height ok~Left ok~Top dir~Width "- header height" hdr~Height
    r = listView~Items[0]~GetBounds(WF~ItemBoundsPortion~Label)
    self~onLVSClick(listView, WF~MouseEventArgs~new("Left", 1, r~X + 4, r~Y + 3, 0))
    say "(auto) combo box:" comboBox~Visible "over row 1, showing" comboBox~Text
    comboBox~SelectedItem = "Replace"
    self~onEditGrandChildEvent(comboBox, WF~KeyEventArgs~new("Enter"))
    say "(auto) row 1:" listView~Items[0]~Text "- combo box:" comboBox~Visible
    r = listView~Items[1]~SubItems[2]~Bounds
    self~onLVDClick(listView, WF~MouseEventArgs~new("Left", 2, r~X + 4, r~Y + 3, 0))
    say "(auto) edit control:" edit~Visible "over" edit~Text
    edit~Text = "D:\elsewhere\file.txt"
    self~onEditGrandChildEvent(edit, WF~KeyEventArgs~new("Enter"))
    say "(auto) row 2 to:" listView~Items[1]~SubItems[2]~Text
    self~onProcess                     -- (unattended: the question answers No)
    dlg = .ResultList~new              -- what Yes would show
    dlg~buNamesImport = .array~of(listView~Items[1]~SubItems[1]~Text)
    dlg~importNames = .array~of(listView~Items[1]~SubItems[2]~Text)
    dlg~buNamesReplace = .array~of(listView~Items[0]~SubItems[1]~Text)
    dlg~replaceNames = .array~of(listView~Items[0]~SubItems[2]~Text)
    dlg~col1width = 200; dlg~col4width = 200
    dlg~execute
    self~cancel


::class 'ResultList' subclass ImportList_IDD_RESULTS inherit ResizingAdmin

::attribute buNamesImport
::attribute buNamesReplace
::attribute importNames
::attribute replaceNames
::attribute col1width
::attribute col4width

::method defineSizing

    self~defaultLeft('STATIONARY', 'LEFT')
    self~defaultRight('STATIONARY', 'RIGHT')
    self~defaultTop('STATIONARY', 'TOP')
    self~defaultBottom('STATIONARY', 'BOTTOM')

    self~controlLeft(IDOK, 'STATIONARY', 'RIGHT')
    self~controlTop(IDOK, 'STATIONARY', 'BOTTOM')
    self~controlRight(IDOK, 'MYLEFT', 'LEFT')
    self~controlBottom(IDOK, 'MYTOP', 'TOP')

    return 0

::method initDialog

    listView = self~newListView(IDC_LV_RESULTS)

    s = textSizePx(listView, "Importing")
    col0width = s~width

    s = textSizePx(listView, "Replacing")
    if s~width > col0width then col0widt = s~width

    s = textSizePx(listView, "-->")
    col2width = s~width

    -- Need some margins
    col0width += 12
    col2width += 12
    self~col1width += 12
    self~col4width += 12

    listView~FullRowSelect = .true
    listView~GridLines = .true
    listView~AllowColumnReorder = .true

    align = .net~System~Windows~Forms~HorizontalAlignment
    listView~Columns~Add("Action", col0width, align~Left)
    listView~Columns~Add("Source File", self~col1width, align~Left)
    listView~Columns~Add("To", col2width, align~Center)
    listView~Columns~Add("Destination File", self~col4width, align~Left)


    do i = 1 to self~buNamesImport~items
        listView~Items~Add(.net~System~Windows~Forms~ListViewItem~new(.array~of('Importing', self~buNamesImport[i], '-->', self~importNames[i])))
    end

    k = i
    do i = 1 to self~buNamesReplace~items
        k += 1
        listView~Items~Add(.net~System~Windows~Forms~ListViewItem~new(.array~of('Replacing', self~buNamesReplace[i], '-->', self~replaceNames[i])))
    end

::method autoRun                       -- (.NET version) unattended: what it shows; Close
    listView = self~newListView(IDC_LV_RESULTS)
    do i = 0 to listView~Items~Count - 1
        it = listView~Items[i]
        say "(auto) result:" it~SubItems[0]~Text it~SubItems[1]~Text it~SubItems[2]~Text it~SubItems[3]~Text
    end
    self~ok


-- (.NET version) ooDialog's getTextSizePx: the text's size in the control's font
::routine textSizePx
    use strict arg ctrl, text
    return .net~System~Windows~Forms~TextRenderer~MeasureText(text, ctrl~Font)   -- (a .NET Size: ~width, ~height)

-- Try to get a list of the files in the ooRexx installation to use for the list
::routine getInitialFiles

    initDir = value('REXX_HOME', , 'ENVIRONMENT')
    if initDir == '', .NetDialog~auto then do              -- (.NET version) unattended, without an installed ooRexx: this folder
        parse source . . me
        initDir = filespec('location', me)~strip('T', '\')
    end
    if initDir == '' then do
        title = 'Importer File Location Error'
        msg   = 'Could not locate the default importer file list'        || .endOfLine || -
                'directory.'                                             || .endOfLine~copies(2) || -
                'Do you wish to pick an alternative directory?'          || .endOfLine~copies(2) || -
                'Yes to select an alternative directory for the initial' || .endOfLine || -
                'file list. No to open the importer with an empty'       || .endOfLine || -
                'file list. Cancel to end the importer application.'

        ret = MessageDialog(msg, 0, title, 'YESNOCANCEL', 'WARNING')
        select
            when ret == .NetDialog~IDNO then return .array~new
            when ret == .NetDialog~IDCANCEL then return .nil
            otherwise nop
        end
        -- End select

        banner = 'Normally the importer opens with the default importer files, ' || -
                 'but the default files can not be located.  Select the folder ' || -
                 'to use for the initial import file list.'
        hint   = 'If this dialog is canceled, the importer will open with an empty file list.'

        initDir = browseFolder('Locate Importer Files', banner, hint, 'C:\')   -- ooDialog: .BrowseForFolder, CSIDL_DRIVES, NONEWFOLDERBUTTON
        if initDir == .nil then return .array~new
    end

    files = getFileList(initDir)
    if files == .nil then files = onErrorGetFiles()

    return files

::routine getFileList
    use strict arg directory

    fileSpec = directory'\*'
    ret = SysFileTree(fileSpec, f., 'FO')
    if ret <> 0 then do
        title = 'Operating System Error'
        msg   = 'Operating system error searching for files' || .endOfLine~copies(2) || -
                'Directory:'  || '09'x~copies(2) || directory   || .endOfLine || -
                'Error code:' || '09'x || ret         || .endOfLine || -
                'Error text:' || '09'x~copies(2) || SysGetErrorText(ret)

        ret = MessageDialog(msg, 0, title, 'OK', 'WARNING')
        return .nil
    end

    files = .array~new(f.0)
    do i = 1 to f.0
        files[i] = f.i
    end

    return files

::routine onErrorGetFiles
    use strict arg initialDir = 'C:\'

    title = 'Importer File Location Error'
    msg   = 'An operating system error occurred trying to get'       || .endOfLine || -
            'the file list.'                                         || .endOfLine~copies(2) || -
            'Do you wish to try again?'                              || .endOfLine~copies(2) || -
            'Abort closes the importer application.'

    ret = MessageDialog(msg, 0, title, 'ABORTRETRYIGNORE', 'ERROR')
    select
        when ret == .NetDialog~IDIGNORE then return .array~new
        when ret == .NetDialog~IDABORT then return .nil
        otherwise nop
    end
    -- End select

    banner = 'Select the directory containing the importer files.'
    hint   = 'If this dialog is canceled, the importer will use an empty file list.'

    initDir = browseFolder('Locate Importer Files', banner, hint, initialDir)
    if initDir == .nil then return .array~new

    files = getFileList(initDir)
    if files == .nil then files = onErrorGetFiles()

    return files


-- Use the BrowseForFolder class to prompted the user for a directory.
::routine getNewDirectory
    use strict arg initialDir = 'C:\', owner = .nil

    banner = 'Select a new import file directory.  The Import File Manager ' || -
             'will display the import files, allowing the import operation ' || -
             'to be configured and then processed.'
    hint   = 'If this dialog is canceled, the import file list will remain unchanged.'

    return browseFolder('Locate Importer Files', banner, hint, initialDir, owner)

-- (.NET version) ooDialog's .BrowseForFolder~new(title, banner, hint, start), its
-- root CSIDL_DRIVES, NONEWFOLDERBUTTON, its owner, getFolder: .NET's
-- FolderBrowserDialog (no title of its own, no hint line: the banner and the
-- hint are its description); the folder, or .nil
::routine browseFolder
    use strict arg title, banner, hint, start, owner = .nil
    if .NetDialog~auto then do
        say "(auto) browseForFolder:" title
        return .nil
    end
    bff = .net~System~Windows~Forms~FolderBrowserDialog~new
    bff~Description = banner hint
    bff~UseDescriptionForTitle = .false
    bff~RootFolder = "MyComputer"
    bff~SelectedPath = start
    bff~ShowNewFolderButton = .false
    if owner \== .nil then r = bff~ShowDialog(owner~form)
    else r = bff~ShowDialog
    if r~string \== "OK" then return .nil
    return bff~SelectedPath
