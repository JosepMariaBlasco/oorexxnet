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
 * Name: employee11tab.rex
 * Type: Open Object REXX Script
 *
 * (.NET version of ooDialog's tutorial\employee11tab.rex, on Windows Forms
 * through oodnet.cls: the PropertySheetDialog is a NetPropertySheet (a
 * TabControl and OK / Cancel), each RcPSPDialog page a subclass of the class
 * that employee11tab.rc's dialog became (employee11tabrc.cls), its controls on
 * a tab; the pages' setActive, killActive, wasActivated and the sheet's
 * setCurSel are ooDialog's. The context menu of the .rc is a NetPopupMenu
 * (assignTo, connectContextMenu, show); a typed character is .NET's KeyPress,
 * refused with e~Handled; the controls are used through their .NET members.
 * Unattended, the database is a file of its own in the temporary folder.)
 */

  .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended
  if .NetDialog~auto then call SysFileDelete .AcmeEmployeesDlg~autoDataBase   -- (.NET version) from an empty database

  -- Note to self, we do not use data attributes in this app, need explanation.
  -- ooDialog: .application~setDefaults("O", sd"employee11tab.h", .false): here the ids are names

  -- Create the dialog pages.
  p1 = .EmployeeAdd~new                                  -- ooDialog: .EmployeeAdd~new(sd"employee11tab.rc", IDD_EMPLOYEES_ADD)
  p2 = .EmployeeEdit~new
  p3 = .EmployeeBrowse~new
  p4 = .EmployeeList~new

  pages = .array~of(p1, p2, p3, p4)
  dlg = .AcmeEmployeesDlg~new(pages, "NOAPPLYNOW", "Acme Software - Employee Manager Version 10.00.0")

  dlg~execute

  if .NetDialog~auto then do                             -- (.NET version) what was saved
    say "(auto) the sheet ended:" dlg~getResult
    db = .AcmeEmployeesDlg~autoDataBase
    if SysFileExists(db) then do
      do l over .stream~new(db)~arrayIn; say "(auto) saved:" l; end
      call SysFileDelete db
    end
    else say "(auto) nothing saved"
  end

  return 0

::requires "employee11tabrc.cls"


/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\
  AcmeEmployeesDlg - The property sheet dialog for this application.
\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'AcmeEmployeesDlg' subclass NetPropertySheet

::constant  DATABASE    'employee11tab.db'

::method autoDataBase class                              -- (.NET version) unattended: a database of its own, in the temporary folder
  return .net~System~IO~Path~Combine(.net~System~IO~Path~GetTempPath, 'employee11tab-auto.db')

::attribute employees
::attribute empCount
::attribute empIndex

::method init
    expose dbChanged

    forward class (super) continue

    self~readDataBase

    dbChanged = .false

    if self~employees~items == 0 then self~startPage = 1
    else self~startPage = 4

    do page over self~pages
      page~configure(self~employees, self~empCount, self~empIndex)
    end


::method newEmployeeNotify
    expose dbChanged
    use strict arg emp

    dbChanged = .true

    self~empCount += 1
    self~employees[self~empCount] = emp
    self~empIndex = self~empCount

    self~notifyPages

    listPage = self~pages[4]

    -- If the user has not yet visited the List Employees page, then there is
    -- no list view to update.  Instead, when the user first visits that page,
    -- the list view will be filled with all existing employees.
    if listPage~wasActivated then listPage~newEmployeeNotify


::method editedEmployeeNotify
    expose dbChanged
    use strict arg emp

    dbChanged = .true
    self~employees[self~empIndex] = emp

    listPage = self~pages[4]
    if listPage~wasActivated then listPage~editedEmployeeNotify

    self~setCurSel( , 4)


::method selectedEmployeeNotify
    use strict arg index

    self~empIndex = index
    self~notifyPages


::method maybeDeleteEmployee
    expose dbChanged

    emp = self~employees[self~empIndex]

    pronoun = 'him'
    if \ emp~male then pronoun = 'her'

    title = "Acme Software - Deleting Employee:" emp~name
    msg   = "Deleting" emp~name "will permanently remove" pronoun "from"        || .endOfLine ||           -
            'the database.  No further pay checks can be issued to' emp~name'.' || .endOfLine~copies(2) || -
            "Are you sure you want to continue this action?"

    answer = MessageDialog(msg, self~hwnd, title, 'YESNO', 'QUESTION', 'DEFBUTTON2')
    if answer == self~IDYES then do
        oldIndex = self~empIndex

        self~employees~delete(self~empIndex)
        self~empCount -= 1
        self~empIndex = 1

        listPage = self~pages[4]
        if listPage~wasActivated then listPage~deleteEmployeeNotify(oldIndex)

        self~notifyPages
        dbChanged = .true
    end

::method leaving
    expose dbChanged

    if dbChanged & self~getResult == 'CLOSEDOK' then do
        self~writeDataBase
    end


::method notifyPages private

    do page over self~pages
      page~empCount = self~empCount
      page~empIndex = self~empIndex
    end


::method readDataBase private

    db = self~DATABASE
    if .NetDialog~auto then db = self~class~autoDataBase   -- (.NET version)

    fsObj = .stream~new(db)
    if fsObj~query('EXISTS') == '' then do
        self~employees = .array~new(10)
        self~empCount  = 0
        self~empIndex  = 0
    end
    else do
        lines = fsObj~makeArray
        fsObj~close

        emps = .array~new(lines~items)
        do l over lines
            l = l~strip
            if l~length == 0 | l~abbrev("#") | l~abbrev("/*") then iterate

            parse var l name', 'city', 'pos', 'male', 'married', 'fullTime .

            if male == 'M' then male = .true
            else male = .false

            if married == 'M' then married = .true
            else married = .false

            if fullTime == 'F' then fullTime = .true
            else fullTime = .false

            emp = .Employee~new(name, city, pos, male, married, fullTime)
            emps~append(emp)
        end

        self~employees = emps
        self~empCount  = emps~items
        self~empIndex  = 1
    end


::method writeDataBase private

    db = self~DATABASE
    if .NetDialog~auto then db = self~class~autoDataBase   -- (.NET version)

    fsObj = .stream~new(db)

    fsObj~open('WRITE REPLACE')

    if fsObj~state == 'READY' then do e over self~employees
        line = e~toCSV
        fsObj~lineout(line)
    end
    else do
      title = "Acme Software - Internal Error Detected"
      msg   = "The database could not be opened to record current changes."
      j = MessageDialog(msg, 0, title, 'OK', 'ERROR')
    end

    fsObj~close



::method autoRun                         -- (.NET version) unattended: employees added, browsed, edited, listed; OK saves them
    add = self~pages[1]; edit = self~pages[2]; browse = self~pages[3]; list = self~pages[4]
    say "(auto) start page:" self~curSel "(the database is empty)"
    do e over .array~of("John Smith,Munich,Lawyer", "Jim Beam,Tucson,CEO")
      parse var e name "," city "," pos
      add~empView~editName~Text = name
      add~empView~cbCity~SelectedItem = city
      add~empView~lbPosition~SelectedItem = pos
      add~newPushButton(IDC_PB_ADD_A)~PerformClick
    end
    say "(auto) employees:" self~empCount
    add~onChar(add~empView~editName, .net~System~Windows~Forms~KeyPressEventArgs~new(.net~char(",")))
    self~setCurSel( , 3)
    say "(auto) browsing:" browse~empView~editName~Text "of" browse~empView~cbCity~Text
    browse~onEmpChange(browse~newUpDown(IDC_UPD)~Value, -1)
    say "(auto) browsing:" browse~empView~editName~Text "of" browse~empView~cbCity~Text
    self~setCurSel( , 2)
    edit~empView~cbCity~SelectedItem = "Houston"
    say "(auto) editing" edit~empView~editName~Text": Save enabled" edit~newPushButton(IDC_PB_SAVE_E)~Enabled
    edit~newPushButton(IDC_PB_SAVE_E)~PerformClick
    say "(auto) page after Save:" self~curSel
    lv = list~newListView(IDC_LV_EMPLOYEES)
    do i = 0 to lv~Items~Count - 1
      row = lv~Items[i]~SubItems; line = ""
      do j = 0 to row~Count - 1; line = line"|"row[j]~Text; end
      say "(auto) list:" line"|"
    end
    list~contextMenuItem(IDM_BROWSE)~PerformClick        -- the context menu's Browse Employees...
    say "(auto) page after Browse Employees...:" self~curSel
    self~ok

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\
  EmployeeAdd - A dialog class for a page in the PropertySheetDialog.  This page
                allows the user to add employee records.
\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'EmployeeAdd' subclass Employee11tab_IDD_EMPLOYEES_ADD

::attribute employees
::attribute empCount
::attribute empIndex
::attribute empView
::attribute empInitial

::method configure
    expose isChanged
    use arg employees, count, index

    self~employees = employess
    self~empCount  = count
    self~empIndex  = index
    self~empInitial = .Employee~new()

    self~connectEditEvent(IDC_EDIT_NAME_A,      "CHANGE",    onChange)
    self~connectComboBoxEvent(IDC_CB_CITY_A,    "SELCHANGE", onChange)
    self~connectListBoxEvent(IDC_LB_POSITION_A, "SELCHANGE", onChange)
    self~connectButtonEvent(IDC_RB_MALE_A,      "CLICKED",   onChange)
    self~connectButtonEvent(IDC_RB_FEMALE_A,    "CLICKED",   onChange)
    self~connectButtonEvent(IDC_CHK_MARRIED_A,  "CLICKED",   onChange)
    self~connectButtonEvent(IDC_CHK_FULLTIME_A, "CLICKED",   onChange)
    isChanged = .false

    self~connectButtonEvent(IDC_PB_PRINT_A, "CLICKED", onPrint)
    self~connectButtonEvent(IDC_PB_ADD_A, "CLICKED", onAdd)

::method initDialog
    expose cbCity lbPosition editName

    self~setControls
    self~empView~fillBoxes

    editName~KeyPress += .net~handler(self, "onChar")    -- ooDialog: editName~connectCharEvent(onChar)

    -- If we are the start page, it means there are no employees.  So we put up
    -- a message box informing the user she needs to add employees through this
    -- page.
    if self~propSheet~startPage == 1 then do
        title = "Acme Software - Employee Manager"
        msg   = "The Employee Database is empty." || .endOfLine~copies(2) ||     -
                "Use the 'Add Employees' page to add employees."

        ret = MessageDialog(msg, self~hwnd, title)
    end


::method setActive unguarded

    self~defaultForm
    return 0

::method killActive unguarded
  expose isChanged
  use arg psDlg

  if isChanged then do
      title = "Acme Software - Add Employee"
      msg   = 'The addition of the new employee is not'  || .endOfLine ||           -
              'complete.  Leaving this page will result' || .endOfLine ||           -
              'in all changes being lost.'               || .endOfLine~copies(2) || -
              'To leave this page and abandon changes,'  || .endOfLine ||           -
              'press Ok.  To stay on the page and con-'  || .endOfLine ||           -
              'tinue adding a new employee, press Cancel'

      ret = MessageDialog(msg, self~hwnd, title, "OKCANCEL", "WARNING", 'DEFBUTTON2')
      if ret == self~IDCANCEL then return .false
  end

  return .true


::method onPrint unguarded

    currentEmployee = self~empView~createEmployee
    currentEmployee~print(self)
    return 0


::method onAdd unguarded

    newEmployee = self~empView~createEmployee
    self~propSheet~newEmployeeNotify(newEmployee)

    self~defaultForm
    return 0


::method onChar unguarded
    use arg editControl, e                               -- ooDialog: use arg char, isShift, isCtrl, isAlt, misc, editControl

    if e~KeyChar == ',' then do
      e~Handled = .true                                  -- ooDialog: reply ' '~c2d (a space in its place: here nothing)

      msg   = 'Employee names can not contain a comma. You can not type a comma here'
      title = "Unacceptable Character"
      self~showBalloon(editControl, title, msg, "ERROR") -- ooDialog: editControl~showBalloon(title, msg, "ERROR")
    end


::method onChange unguarded
    expose isChanged pbPrint pbAdd editName

    if isChanged then do
        if self~empView~sameAs(self~empInitial) then isChanged = .false
    end
    else do
        if \ self~empView~sameAs(self~empInitial) then isChanged = .true
    end

    -- The Add and Print buttons are only enabled when there is some change and
    -- the employee name is not blank.  The status of the buttons *could* change
    -- on any change, but only *will* change under certain cicrcumstances.
    -- Rather than try to track and determine those exact circumstances, we just
    -- check if the buttons should be enabled or not and do that on each change.
    if isChanged, editName~Text~strip \== '' then do
        pbPrint~Enabled = .true
        pbAdd~Enabled = .true
    end
    else do
    		pbPrint~Enabled = .false
        pbAdd~Enabled = .false
    end

    return 0


::method setControls private
    expose editName cbCity lbPosition rbMale rbFemale chkMarried chkFullTime pbPrint pbAdd

    editName    = self~newEdit(IDC_EDIT_NAME_A)
    cbCity      = self~newComboBox(IDC_CB_CITY_A)
    lbPosition  = self~newListBox(IDC_LB_POSITION_A)
    rbMale      = self~newRadioButton(IDC_RB_MALE_A)
    rbFemale    = self~newRadioButton(IDC_RB_FEMALE_A)
    chkMarried  = self~newCheckBox(IDC_CHK_MARRIED_A)
    chkFullTime = self~newCheckBox(IDC_CHK_FULLTIME_A)

    self~empView = .EmployeeView~new(editName, cbCity, lbPosition, rbMale, rbFemale, chkMarried, chkFullTime)

    pbPrint = self~newPushButton(IDC_PB_PRINT_A)
    pbAdd   = self~newPushButton(IDC_PB_ADD_A)


::method defaultForm private
    expose pbPrint pbAdd

    pbPrint~Enabled = .false
    pbAdd~Enabled = .false

    self~empView~displayEmployee(self~empInitial)
    self~empView~editName~Select



/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\
  EmployeeEdit - A dialog class for a page in the PropertySheetDialog.  This
                 page allows the user to edit an existing employee's record
\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'EmployeeEdit' subclass Employee11tab_IDD_EMPLOYEES_EDIT

::attribute employees
::attribute empCount
::attribute empIndex
::attribute empInitial
::attribute empView

::method configure
    expose isChanged
    use arg employees, count, index

    self~employees = employees
    self~empCount  = count
    self~empIndex  = index

    self~empInitial = .nil

    self~connectEditEvent(IDC_EDIT_NAME_E,      "CHANGE",    onChange)
    self~connectComboBoxEvent(IDC_CB_CITY_E,    "SELCHANGE", onChange)
    self~connectListBoxEvent(IDC_LB_POSITION_E, "SELCHANGE", onChange)
    self~connectButtonEvent(IDC_RB_MALE_E,      "CLICKED",   onChange)
    self~connectButtonEvent(IDC_RB_FEMALE_E,    "CLICKED",   onChange)
    self~connectButtonEvent(IDC_CHK_MARRIED_E,  "CLICKED",   onChange)
    self~connectButtonEvent(IDC_CHK_FULLTIME_E, "CLICKED",   onChange)
    isChanged = .false

    self~connectButtonEvent(IDC_PB_PRINT_E, "CLICKED", onPrint)
    self~connectButtonEvent(IDC_PB_SAVE_E, "CLICKED", onSave)
    self~connectButtonEvent(IDC_PB_RESET_E, "CLICKED", onReset)


::method initDialog
    expose cbCity lbPosition

    self~setControls
    self~empView~fillBoxes


::method setActive unguarded

  self~setEmpRecord
  return 0


::method onPrint unguarded

    if self~empInitial \== .nil then do
        currentEmployee = self~empView~createEmployee
        currentEmployee~print(self)
    end
    return 0

::method onSave unguarded

    editedEmployee = self~empView~createEmployee
    self~propSheet~editedEmployeeNotify(editedEmployee)

    return 0


::method onReset unguarded
    self~setEmpRecord


::method onChange unguarded
    expose isChanged pbPrint pbSave pbReset editName

    if self~empInitial == .nil then return 0

    if isChanged then do
        if self~empView~sameAs(self~empInitial) then isChanged = .false
    end
    else do
        if \ self~empView~sameAs(self~empInitial) then isChanged = .true
    end

    txt = editName~Text~strip

    if txt == '' then do
    		pbPrint~Enabled = .false
        pbSave~Enabled = .false
        pbReset~Enabled = .true
    end
    else if isChanged then do
        pbPrint~Enabled = .true
        pbSave~Enabled = .true
        pbReset~Enabled = .true
    end
    else do
        pbPrint~Enabled = .true
        pbSave~Enabled = .false
        pbReset~Enabled = .false
    end

    return 0


::method setControls private
    expose cbCity lbPosition rbMale rbFemale chkMarried chkFullTime editName pbPrint pbSave pbReset

    cbCity      = self~newComboBox(IDC_CB_CITY_E)
    lbPosition  = self~newListBox(IDC_LB_POSITION_E)
    rbMale      = self~newRadioButton(IDC_RB_MALE_E)
    rbFemale    = self~newRadioButton(IDC_RB_FEMALE_E)
    chkMarried  = self~newCheckBox(IDC_CHK_MARRIED_E)
    chkFullTime = self~newCheckBox(IDC_CHK_FULLTIME_E)
    editName    = self~newEdit(IDC_EDIT_NAME_E)

    self~empView = .EmployeeView~new(editName, cbCity, lbPosition, rbMale, rbFemale, chkMarried, chkFullTime)

    pbReset = self~newPushButton(IDC_PB_RESET_E)
    pbSave  = self~newPushButton(IDC_PB_SAVE_E)
    pbPrint = self~newPushButton(IDC_PB_PRINT_E)


::method setEmpRecord
    expose pbSave pbPrint pbReset isChanged

    if self~empCount < 1 then do
        self~empView~disable
        pbSave~Enabled = .false
        pbPrint~Enabled = .false
        pbReset~Enabled = .false
        return 0
    end

    isChanged = .false
    pbSave~Enabled = .false
    pbPrint~Enabled = .true

    self~empInitial = self~employees[self~empIndex]
    self~empView~displayEmployee(self~empInitial)
    self~empView~editName~Select



/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\
  EmployeeBrowse - A dialog class for a page in the PropertySheetDialog.  This
                   page allows the user to scroll through employee records one
                   at a time.
\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'EmployeeBrowse' subclass Employee11tab_IDD_EMPLOYEES_BROWSE

::attribute employees
::attribute empCount
::attribute empIndex
::attribute empView

::method configure
    use arg employees, count, empIndex

    self~employees = employees
    self~empCount  = count
    self~empIndex  = empIndex

    self~connectButtonEvent(IDC_PB_PRINT_B, "CLICKED", onPrint)
    self~connectUpDownEvent(IDC_UPD, "DELTAPOS", onEmpChange)


::method initDialog
    expose upDown

    self~setControls
    self~empView~fillBoxes


::method setActive unguarded

    self~updateUpdown
    return 0


::method onPrint unguarded

    if self~empCount > 0 then do
        currentEmployee = self~empView~createEmployee
        currentEmployee~print(self)
    end
    return 0


::method onEmpChange unguarded
    use arg curPos, increment

    self~setEmpRecord(curPos + increment)
    return 0                                             -- ooDialog: .UpDown~deltaPosReply


::method setEmpRecord private
    expose upDown
    use strict arg empIndex

    if empIndex < 1 then return self~noRecord('bottom')
    else if empIndex > upDown~Maximum then return self~noRecord('top')   -- ooDialog: upDown~getRange~max

    emp = self~employees[empIndex]
    self~empView~displayEmployee(emp)

    self~propSheet~selectedEmployeeNotify(empIndex)


::method setControls private
    expose cbCity lbPosition rbMale rbFemale chkMarried chkFullTime editName upDown pbPrint

    cbCity      = self~newComboBox(IDC_CB_CITY_B)
    lbPosition  = self~newListBox(IDC_LB_POSITION_B)
    rbMale      = self~newRadioButton(IDC_RB_MALE_B)
    rbFemale    = self~newRadioButton(IDC_RB_FEMALE_B)
    chkMarried  = self~newCheckBox(IDC_CHK_MARRIED_B)
    chkFullTime = self~newCheckBox(IDC_CHK_FULLTIME_B)
    editName    = self~newEdit(IDC_EDIT_NAME_B)

    self~empView = .EmployeeView~new(editName, cbCity, lbPosition, rbMale, rbFemale, chkMarried, chkFullTime)

    upDown  = self~newUpDown(IDC_UPD)
    pbPrint = self~newPushButton(IDC_PB_PRINT_B)


::method noRecord private
    use strict arg direction
    return MessageDialog('At the' direction 'of the records', self~hwnd, -
                         'Employee Records')


::method updateUpdown private
    expose pbPrint upDown

    if self~empCount < 1 then do
        upDown~Minimum = 0; upDown~Maximum = 0           -- ooDialog: upDown~setRange(0, 0)
        upDown~Value = 0                                 -- ooDialog: upDown~setPosition(0)
        upDown~Enabled = .false
        pbPrint~Enabled = .false
        self~empView~blank
    end
    else do
        upDown~Enabled = .true
        upDown~Minimum = 1; upDown~Maximum = self~empCount   -- ooDialog: upDown~setRange(1, self~empCount)
        upDown~Value = self~empIndex                     -- ooDialog: upDown~setPosition(self~empIndex)
        pbPrint~Enabled = .true
        self~empView~displayEmployee(self~employees[self~empIndex])
    end



/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\
  EmployeeList - A dialog class for a page in the PropertySheetDialog.  This
                 page allows the user to look at multiple employee records in
                 one view.
\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'EmployeeList' subclass Employee11tab_IDD_EMPLOYEES_LIST

::attribute employees
::attribute empCount
::attribute empIndex

::method configure
    expose contextMenu
    use arg employees, count, index

    self~employees = employees
    self~empCount  = count
    self~empIndex  = index

    self~connectListViewEvent(IDC_LV_EMPLOYEES, "SELECTCHANGED", onSelectionChanged)

    mb = .Employee11tab_IDM_CONTEXT_MENUBAR~new          -- ooDialog: .ScriptMenuBar~new(.application~srcDir'employee11tab.rc', IDM_CONTEXT_MENUBAR)
    contextMenu = mb~getPopup(IDM_POP_CONTEXT)

::method newEmployeeNotify
    expose lv

    emp = self~employees[self~empIndex]
    self~addEmployeeRow(lv, emp)

    self~ensureSelection


::method editedEmployeeNotify
    expose lv

    emp   = self~employees[self~empIndex]
    index = self~empIndex - 1

    gender = 'Male'
    if \ emp~male then gender = 'Female'

    mStatus = 'Married'
    if \ emp~married then mStatus = 'Unmarried'

    eStatus = 'Full Time'
    if \ emp~fullTime then eStatus = 'Part Time'

    row = lv~Items[index]~SubItems                       -- ooDialog: lv~setItemText(index, column, text)
    row[0]~Text = emp~name
    row[1]~Text = emp~city
    row[2]~Text = emp~position
    row[3]~Text = gender
    row[4]~Text = mStatus
    row[5]~Text = eStatus

    self~ensureSelection


::method initDialog
    expose lv contextMenu

    lv = self~newListView(IDC_LV_EMPLOYEES)

    lv~CheckBoxes = .true                                -- ooDialog: lv~addExtendedStyle('CHECKBOXES GRIDLINES FULLROWSELECT')
    lv~GridLines = .true
    lv~FullRowSelect = .true

    lv~Columns~Add("Name", self~px(50), "Left")                  -- ooDialog: lv~insertColumn(0, "Name", 50)
    lv~Columns~Add("City", self~px(40), "Left")
    lv~Columns~Add("Position", self~px(40), "Left")
    lv~Columns~Add("Gender", self~px(30), "Left")
    lv~Columns~Add("Marital Status", self~px(30), "Left")
    lv~Columns~Add("Employment Classification", self~px(40), "Left")

    do i = 1 to self~empCount
      self~addEmployeeRow(lv, self~employees[i])
    end

    self~ensureSelection

    contextMenu~assignTo(self, .true)
    contextMenu~connectContextMenu(onContext, lv~Handle)   -- ooDialog: lv~hwnd


::method onSelectionChanged unguarded
    use arg lv, e                                        -- ooDialog: use arg id, itemIndex, state

    if e~IsSelected then do                              -- ooDialog: state == 'SELECTED'
      self~propSheet~selectedEmployeeNotify(e~ItemIndex + 1)
    end


::method setActive unguarded
    expose lv

    self~ensureSelection
    return 0


::method onContext
  expose contextMenu lv
  use arg hwnd, x, y

  if x == -1, y == -1 then do
      -- The keyboard was used, not the mouse.  Position the context menu
      -- towards the bottom right corner of the list view.
      rect = lv~RectangleToScreen(lv~ClientRectangle)    -- ooDialog: lv~windowRect
      x = rect~Right - .net~System~Windows~Forms~SystemInformation~VerticalScrollBarWidth - 15   -- ooDialog: .SM~cxVScroll
      y = rect~Bottom - 15

      pos = .NetPoint~new(x, y)
  end
  else do
      pos = .NetPoint~new(x, y)

      p = lv~PointToClient(.net~System~Drawing~Point~new(x, y))   -- ooDialog: lv~screen2client(p)
      index = (lv~HitTest(p)~Item == .nil)~?(-1, 0)     -- ooDialog: lv~hitTestInfo(p)

      if index == -1 then do
        contextMenu~disable(.array~of(IDM_EDIT, IDM_DELETE))
        self~ensureSelection
      end
  end

  ret = contextMenu~show(pos)

  return 0

::method contextMenuItem                 -- (.NET version) for autoRun: an item of the context menu
    expose contextMenu
    return contextMenu~find(arg(1))

::method browseEmployees unguarded
    self~propSheet~setCurSel( , 3)
    return 0

::method addEmployee unguarded
    self~propSheet~setCurSel( , 1)
    return 0

::method editEmployee unguarded
    self~propSheet~setCurSel( , 2)
    return 0

::method deleteEmployee unguarded
    self~propSheet~maybeDeleteEmployee
    return 0

::method deleteEmployeeNotify unguarded
    expose lv
    use strict arg index

    lv~Items~RemoveAt(index - 1)                         -- ooDialog: lv~delete(index - 1)
    self~ensureSelection

    return 0

::method ensureSelection private
    expose lv

    index = self~empIndex - 1
    if index < 0 then index = 0
    if index >= lv~Items~Count then return 0             -- (.NET version) an empty list: nothing to select
    lv~Items[index]~Selected = .true                     -- ooDialog: lv~select(index)
    lv~Items[index]~Focused = .true                      -- ooDialog: lv~focus(index)

    return 0


::method addEmployeeRow private
    use strict arg list, employee

    gender = 'Male'
    if \ employee~male then gender = 'Female'

    mStatus = 'Married'
    if \ employee~married then mStatus = 'Unmarried'

    eStatus = 'Full Time'
    if \ employee~fullTime then eStatus = 'Part Time'

    e = employee
    row = .net~System~Windows~Forms~ListViewItem~new(e~name)   -- ooDialog: list~addRow( , , e~name, e~city, ...)
    do t over .array~of(e~city, e~position, gender, mStatus, eStatus); row~SubItems~Add(t); end
    list~Items~Add(row)


/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\
  Employee - A class that reflects a single, specific, employee.
\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'Employee'

::attribute name
::attribute city
::attribute position
::attribute male
::attribute married
::attribute fullTime

::method init
    expose name city position male married fullTime
    use strict arg name = "", city = "New York", position = "Software Developer",     -
                   male = .true, married = .false, fullTime = .true

::method isValid
    expose name
    return name \== ''


::method print
    expose name city position male married fullTime
    use strict arg dlg

    eol = .endOfLine
    tab = '09'x

    if \ self~isValid then do
        title = "Acme Software - Internal Error Detected"
        msg = "Attempting to print invalid employee record." || eol~copies(2)  -
              "Employee record has no assigned name."
        icon = 'ERROR'
    end
    else do
        title = "Acme Software - Employee:"

        if male then msg = "Mr." name
        else msg = "Ms." name

        if married then msg ||= " (married) "

        msg ||= eol

        if fullTime then status = 'Full Time Employee'
        else status = 'Part Time Employee'

        msg ||= eol || "City:"       || tab~copies(2) || city     || eol || -
                       "Profession:" || tab           || position || eol || -
                       'Status:'     || tab~copies(2) || status

        icon = 'INFORMATION'
    end

    j = MessageDialog(msg, dlg~hwnd, title, , icon)


::method toCSV
    expose name city position male married fullTime
    use strict arg

    if male then mf = "M"
    else mf = "F"

    if married then mu = "M"
    else mu = 'U'

    if fullTime then fp = 'F'
    else fp = 'P'

    txt = name', 'city', 'position', 'mf', 'mu', 'fp

    return txt



/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\
  EmployeeView - A class containing the dialog controls used to display an
                 employee in a dialog.
\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'EmployeeView' public

::attribute editName
::attribute cbCity
::attribute lbPosition
::attribute rbMale
::attribute rbFemale
::attribute chkMarried
::attribute chkFullTime

::method init
  expose editName cbCity lbPosition rbMale rbFemale chkMarried chkFullTime
  use strict arg editName, cbCity, lbPosition, rbMale, rbFemale, chkMarried, chkFullTime

/** fillBoxes()
 * Fills the city combo box and the position list box with the correct items.
 */
::method fillBoxes
    expose cbCity lbPosition
    use strict arg

    cbCity~Items~Add("Munich")                           -- ooDialog: cbCity~add("Munich")
    cbCity~Items~Add("New York")
    cbCity~Items~Add("San Francisco")
    cbCity~Items~Add("Stuttgart")
    cbCity~Items~Add("San Diego")
    cbCity~Items~Add("Tucson")
    cbCity~Items~Add("Houston")
    cbCity~Items~Add("Los Angeles")

    lbPosition~Items~Add("Business Manager")             -- ooDialog: lbPosition~add(...)
    lbPosition~Items~Add("Engineering Manager")
    lbPosition~Items~Add("Software Developer")
    lbPosition~Items~Add("Software QA")
    lbPosition~Items~Add("Accountant")
    lbPosition~Items~Add("Security")
    lbPosition~Items~Add("Secretary")
    lbPosition~Items~Add("Recptionist")
    lbPosition~Items~Add("Lab Manager")
    lbPosition~Items~Add("Lawyer")
    lbPosition~Items~Add("CEO")


/** displayEmployee()
 * Sets the state of the controls to reflect the specified employee
 */
::method displayEmployee
    use strict arg emp

    self~editName~Text = emp~name                        -- ooDialog: editName~setText, cbCity~select, lbPosition~select
    self~cbCity~SelectedItem = emp~City
    self~lbPosition~SelectedItem = emp~Position

    if emp~male then do
        self~rbMale~Checked = .true
        self~rbFemale~Checked = .false
    end
    else do
        self~rbFemale~Checked = .true
        self~rbMale~Checked = .false
    end

    if emp~married then self~chkMarried~Checked = .true
    else self~chkMarried~Checked = .false

    if emp~fullTime then self~chkFullTime~Checked = .true
    else self~chkFullTime~Checked = .false


/** disable()
 * Disables all the controls and sets the edit control text to the empty string.
 */
::method disable
    use strict arg

    self~editName~Text = ""

    self~editName~Enabled = .false
    self~cbCity~Enabled = .false
    self~lbPosition~Enabled = .false

    self~rbMale~Enabled = .false
    self~rbFemale~Enabled = .false
    self~chkMarried~Enabled = .false
    self~chkFullTime~Enabled = .false


/** blank()
 * Sets all the controls to a 'blank' state.
 */
::method blank
    use strict arg

    self~editName~Text = ""
    --self~cbCity~
    self~lbPosition~SelectedIndex = -1                   -- ooDialog: deselectIndex

    self~rbMale~Checked = .false
    self~rbFemale~Checked = .false
    self~chkMarried~Checked = .false
    self~chkFullTime~Checked = .false


/** match()
 * Tests if the state of the controls match the specified employee.
 */
::method sameAs
    use strict arg emp

    if self~editName~Text      \== emp~name     then return .false
    if self~cbCity~Text       \== emp~City     then return .false
    if self~lbPosition~Text   \== emp~Position then return .false

    if self~rbMale~Checked        & \ emp~male     then return .false
    if \ self~rbMale~Checked      &   emp~male     then return .false

    if self~chkMarried~Checked    & \ emp~married  then return .false
    if \ self~chkMarried~Checked  &   emp~married  then return .false

    if self~chkFullTime~Checked   & \ emp~fullTime then return .false
    if \ self~chkFullTime~Checked &  emp~fullTime  then return .false

    return .true

/** createEmployee()
 * Instantiates a new Employee object using the current state of the controls,
 * and returns it if it is valid.  If it is not valid, returns .nil
 */
::method createEmployee
    use strict arg

    name     = self~editName~Text~strip
    city     = self~cbCity~Text
    position = self~lbPosition~Text
    male     = self~rbMale~Checked
    married  =  self~chkMarried~Checked
    fullTime = self~chkFullTime~Checked

    emp = .Employee~new(name, city, position, male, married, fullTime)

    if emp~isValid then return emp
    else return .nil


