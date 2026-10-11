/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 1995, 2004 IBM Corporation. All rights reserved.             */
/* Copyright (c) 2005-2014 Rexx Language Association. All rights reserved.    */
/*                                                                            */
/* This program and the accompanying materials are made available under       */
/* the terms of the Common Public License v1.0 which accompanies this         */
/* distribution. A copy is also available at the following address:           */
/* https://www.oorexx.org/license.html                         */
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
 * Name: employee10menuRc.rex
 * Type: Open Object REXX Script
 *
 * (.NET version of ooDialog's tutorial\employee10menuRc.rex, on Windows Forms
 * through oodnet.cls: employe7.rc's dialogs are Employe7_IDD_EMPLOYEES7 and
 * Employe7_IDD_EMPLOYEE_LIST, and its menu Employe7_IDM_MENUBAR (a
 * NetMenuBar, ooDialog's ScriptMenuBar), all from employe7rc.cls. The ids of
 * employe7.h are names, so the .h is not needed. The controls are .NET's:
 * ~Text, ~Checked, ~Enabled, ~Items~Add, ~SelectedItem in place of ooDialog's
 * getText, checked, enable, add, select. The up-down without a number is a
 * small scroll bar (~Minimum, ~Maximum, ~Value).)
 */

    .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended
    -- ooDialog: .application~setDefaults('O', sd'employe7.h', .false): here the ids are names

    dlg = .MyDialogClass~new                             -- ooDialog: .MyDialogClass~new(sd"employe7.rc", IDD_EMPLOYEES7)
    if dlg~initCode <> 0 then return 99
    dlg~execute("SHOWTOP")

return 0


::requires "employe7rc.cls"

::class 'MyDialogClass' subclass Employe7_IDD_EMPLOYEES7

::attribute employees
::attribute empCount

::method init
    expose menuBar

    forward class (super) continue
    if self~initCode <> 0 then return self~initCode

    self~employees = .array~new(10)
    self~empCount = 0

    self~connectButtonEvent(IDC_PB_PRINT, "CLICKED", "onPrint")
    self~connectButtonEvent(IDC_PB_ADD, "CLICKED", "onAdd")
    self~connectButtonEvent(IDC_PB_LIST, "CLICKED", "onList")
    self~connectButtonEvent(IDC_RB_ADD, "CLICKED", "onAdding")
    self~connectButtonEvent(IDC_RB_BROWSE, "CLICKED", "onBrowsing")

    self~connectEditEvent(IDC_EDIT_NAME, "CHANGE", onNameChange)
    self~connectUpDownEvent(IDC_UPD, "DELTAPOS", onEmpChange)

    menuBar = .Employe7_IDM_MENUBAR~new                  -- ooDialog: .ScriptMenuBar~new(sd"employe7.rc", IDM_MENUBAR, 0)
    menuBar~connectCommandEvent(IDM_ADD, "onAdd", self)
    menuBar~connectCommandEvent(IDM_PRINT, "onPrint", self)
    menuBar~connectCommandEvent(IDM_LIST, "onList", self)
    menuBar~connectCommandEvent(IDM_ABOUT, "about", self)

    return self~initCode

::method initDialog
    expose cbCity lbPosition menuBar

    cbCity = self~newComboBox(IDC_CB_CITY)
    cbCity~Items~Add("Munich")                           -- ooDialog: cbCity~add("Munich")
    cbCity~Items~Add("New York")
    cbCity~Items~Add("San Francisco")
    cbCity~Items~Add("Stuttgart")
    cbCity~Items~Add("San Diego")
    cbCity~Items~Add("Tucson")
    cbCity~Items~Add("Houston")
    cbCity~Items~Add("Los Angeles")

    lbPosition = self~newListBox(IDC_LB_POSITION)
    lbPosition~Items~Add("Business Manager")
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

    menuBar~attachTo(self, 1)

    self~setControls
    self~defaultForm


::method onPrint
    expose cbCity lbPosition rbMale chkMarried editName

    title = "Acme Software - Employee:"

    if rbMale~Checked then msg = "Mr."
    else msg = "Ms."
    msg ||= editName~Text

    if chkMarried~Checked then msg ||= " (married) "
    msg ||= "A"x || "City:" cbCity~Text || "A"x || "Profession:" lbPosition~Text

    j = MessageDialog(msg, self~hwnd, title, , INFORMATION)

::method onAdd
    expose cbCity lbPosition rbMale chkMarried editName pbList upDown rbBrowse

    self~empCount += 1
    self~employees[self~empCount] = .directory~new
    self~employees[self~empCount]['NAME'] = editName~Text
    self~employees[self~empCount]['CITY'] = cbCity~Text
    self~employees[self~empCount]['POSITION'] = lbPosition~Text

    if rbMale~Checked then sex = 1
    else sex = 2

    self~employees[self~empCount]['SEX'] = sex
    self~employees[self~empCount]['MARRIED'] = chkMarried~Checked

    upDown~Minimum = 1                                   -- ooDialog: upDown~setRange(1, self~empCount)
    upDown~Maximum = self~empCount
    if self~empCount == 1 then do
      rbBrowse~Enabled = .true
      upDown~Value = 1                                   -- ooDialog: upDown~setPosition(1)
    end

    self~defaultForm

::method onNameChange
    expose menuBar editName rbAdd pbAdd pbPrint

    if rbAdd~Checked then do
        if editName~Text~strip~length == 0 then do
            pbAdd~Enabled = .false
            pbPrint~Enabled = .false
            menuBar~disable(IDM_ADD)
            menuBar~disable(IDM_PRINT)
        end
        else do
            pbAdd~Enabled = .true
            pbPrint~Enabled = .true
            menuBar~enable(IDM_ADD)
            menuBar~enable(IDM_PRINT)
        end
    end

::method onEmpChange
    use arg curPos, increment

    self~setEmpRecord(curPos + increment)
    return 0                                             -- ooDialog: .UpDown~deltaPosReply

::method onAdding
    self~defaultForm

::method onBrowsing
    expose upDown pbAdd menuBar

    pbAdd~Enabled = .false
    menuBar~disable(IDM_ADD)
    upDown~Enabled = .true
    self~setEmpRecord(upDown~Value)

::method setEmpRecord
    expose upDown editName cbCity lbPosition rbMale rbFemale chkMarried
    use strict arg emp

    if emp < 1 then return self~noRecord('bottom')
    else if emp > upDown~Maximum then return self~noRecord('top')   -- ooDialog: upDown~getRange~max

    editName~Text = self~employees[emp]['NAME']

    cbCity~SelectedItem = self~employees[emp]['CITY']
    lbPosition~SelectedItem = self~employees[emp]['POSITION']

    if self~employees[emp]['SEX'] = 1 then do
        rbMale~Checked = .true
        rbFemale~Checked = .false
    end
    else do
        rbFemale~Checked = .true
        rbMale~Checked = .false
    end

    chkMarried~Checked = self~employees[emp]['MARRIED']


::method onList
   lDlg = .EmployeeListClass~new                         -- ooDialog: .EmployeeListClass~new(sd"employe7.rc", IDD_EMPLOYEE_LIST)
   lDlg~parent = self
   lDlg~execute("SHOWTOP")


::method fillList
    use strict arg list
    do id = 1 to self~empCount
        if self~employees[id]['SEX'] = 1 then title = "Mr."; else title = "Ms."
        addstring = title self~employees[id]['NAME']
        addstring = addstring || "9"x || self~employees[id]['POSITION']
        addstring = addstring || "9"x || self~employees[id]['CITY']
        list~Items~Insert(id - 1, addstring)             -- ooDialog: list~insert(id, addstring)
    end

::method about
    call infoDialog "Sample to demonstrate ooDialog menus."

::method setControls private
    expose rbMale rbFemale rbAdd rbBrowse chkMarried editName pbList pbAdd pbPrint upDown

    pbAdd      = self~newPushButton(IDC_PB_ADD)
    pbList     = self~newPushButton(IDC_PB_LIST)
    pbPrint    = self~newPushButton(IDC_PB_PRINT)
    rbMale     = self~newRadioButton(IDC_RB_MALE)
    rbFemale   = self~newRadioButton(IDC_RB_FEMALE)
    rbAdd      = self~newRadioButton(IDC_RB_ADD)
    rbBrowse   = self~newRadioButton(IDC_RB_BROWSE)
    chkMarried = self~newCheckBox(IDC_CHK_MARRIED)
    editName   = self~newEdit(IDC_EDIT_NAME)
    upDown     = self~newUpDown(IDC_UPD)

::method defaultForm private
    expose menuBar cbCity lbPosition rbMale rbFemale rbAdd rbBrowse chkMarried -
           editName pbAdd pbList pbPrint upDown

    editName~Text = ""
    cbCity~SelectedItem = "New York"
    lbPosition~SelectedItem = "Software Developer"

    rbMale~Checked = .true
    rbFemale~Checked = .false
    chkMarried~Checked = .false

    rbAdd~Checked = .true
    pbAdd~Enabled = .false
    pbPrint~Enabled = .false
    menuBar~disable(IDM_ADD)
    menuBar~disable(IDM_PRINT)
    upDown~Enabled = .false

    editName~Select                                      -- ooDialog: editName~assignFocus

    if self~empCount < 1 then do
        pbList~Enabled = .false
        rbBrowse~Enabled = .false
        upDown~Minimum = 0                               -- ooDialog: upDown~setRange(0, 0)
        upDown~Maximum = 0
        upDown~Value = 0                                 -- ooDialog: upDown~setPosition(0)
    end
    else do
        pbList~Enabled = .true
        menuBar~enable(IDM_LIST)
    end

::method noRecord private
    use strict arg direction
    return MessageDialog('At the' direction 'of the records', self~hwnd, -
                         'Employee Records')

::method autoRun                         -- (.NET version) unattended: two employees, browsing, the list, Exit
    expose menuBar editName rbBrowse upDown
    say "(auto) Add enabled with no name:" self~newPushButton(IDC_PB_ADD)~Enabled menuBar~isEnabled(IDM_ADD)
    editName~Text = "John Smith"
    say "(auto) Add enabled with a name:" self~newPushButton(IDC_PB_ADD)~Enabled menuBar~isEnabled(IDM_ADD)
    self~newPushButton(IDC_PB_ADD)~PerformClick
    editName~Text = "Jane Doe"
    self~newComboBox(IDC_CB_CITY)~SelectedItem = "Tucson"
    self~newRadioButton(IDC_RB_FEMALE)~Checked = .true
    say "(auto) the two groups: Adding" self~newRadioButton(IDC_RB_ADD)~Checked", Female" self~newRadioButton(IDC_RB_FEMALE)~Checked
    menuBar~item(IDM_ADD)~PerformClick
    rbBrowse~PerformClick
    say "(auto) browsing" upDown~Value":" editName~Text "of" self~newComboBox(IDC_CB_CITY)~Text
    self~onEmpChange(upDown~Value, 1)
    say "(auto) browsing" upDown~Value + 1":" editName~Text "of" self~newComboBox(IDC_CB_CITY)~Text
    menuBar~item(IDM_LIST)~PerformClick
    menuBar~item(IDOK)~PerformClick                      -- File, Exit: the dialog's ok


::class 'EmployeeListClass' subclass Employe7_IDD_EMPLOYEE_LIST

::attribute parent

::method initDialog
    lb = self~newListBox(IDC_LB_EMPLOYEES_LIST)
    self~parent~fillList(lb)
    self~setListTabulators(IDC_LB_EMPLOYEES_LIST, 90, 190)   -- ooDialog: lb~setTabulators(90, 190)

::method autoRun                         -- (.NET version) unattended: what the list shows, then OK
    list = self~newListBox(IDC_LB_EMPLOYEES_LIST)
    do i = 0 to list~Items~Count - 1; say "(auto) |"list~Items[i]~changeStr("9"x, "<tab>")"|"; end
    self~ok
