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
/** ooDialog\Samples\oodStandardRoutines.rex  Standard Public Routines Demo
 *
 * This example application pops up a dialog from which any of the standard
 * public routines provided by the ooDialog framework can be selected and
 * displayed.
 *
 * (.NET version, on Windows Forms through oodnet.cls, whose public routines
 * have ooDialog's names, arguments and results: the methods that show them,
 * below initDialog and ok, are the original's, unchanged. The dialog of
 * rc\oodStandardDialogs.rc is built in defineDialog, with its coordinates.
 * The original's ok begins with REPLY, so that the routine's dialog runs on
 * another thread; here it runs on the dialog's, as .NET's dialogs do.)
 */
    .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended
    dlg = .StandardRoutines~new
    dlg~execute("SHOWTOP")

return 0
-- End of entry point.

::requires "oodnet.cls"

::class 'StandardRoutines' subclass NetDialog

::constant COMMON_TITLE    "Standard Public Routines Demo"

::method init                          -- (.NET version) the .rc's DIALOGEX
  forward class (super) continue
  self~create(0, 0, 413, 201, "User Input Common Public Routines", "CENTER", , "Ms Shell Dlg", 8)

::method defineDialog                  -- (.NET version) the .rc's controls
  self~createStatic(IDC_STATIC, 10, 10, 393, 18, , "The ooDialog framework provides a number of easy to use public routines that obtain user input in a standard way.  These routines allow the use of simple graphical elements in Rexx applications that collect user input in a standard way.")
  self~createGroupBox(IDC_STATIC, 11, 33, 392, 139, , "Select the Common Public Routine to Display")
  buttons = .array~of(-
    .array~of(IDC_RB_ASKDIALOG_R,        "AskDialog Routine",        25,  56), .array~of(IDC_RB_CHECKLIST_R,       "CheckList Routine",       159,  56), -
    .array~of(IDC_RB_ERRORDIALOG_R,      "ErrorDialog Routine",     272,  56), .array~of(IDC_RB_FILENAMEDIALOG_R,  "FileNameDialog Routine",   25,  79), -
    .array~of(IDC_RB_INFODIALOG_R,       "InfoDialog Routine",      159,  79), .array~of(IDC_RB_INPUTBOX_R,        "InputBox Routine",        272,  79), -
    .array~of(IDC_RB_INTEGERBOX_R,       "IntegerBox Routine",       25, 103), .array~of(IDC_RB_LISTCHOICE_R,      "ListChoice Routine",      159, 103), -
    .array~of(IDC_RB_MESSAGEDIALOG_R,    "MessageDialog Routine",   272, 103), .array~of(IDC_RB_MULTIINPUTBOX_R,   "MultiInputBox Routine",    25, 128), -
    .array~of(IDC_RB_MULTILISTCHOICE_R,  "MultiListChoice Routine", 159, 128), .array~of(IDC_RB_PASSWORDBOX_R,     "PasswordBox Routine",     272, 128), -
    .array~of(IDC_RB_SINGLESELECTION_R,  "SingleSelection Routine",  25, 152), .array~of(IDC_RB_TIMEDMESSAGE_R,    "TimedMessage Routine",    159, 152))
  do b over buttons
    self~createRadioButton(b[1], b[3], b[4], 90, 10, , b[2])
  end
  self~createPushButton(IDOK, 161, 177, 90, 14, "DEFAULT", "Display Selected Routine")
  self~createPushButton(IDCANCEL, 353, 177, 50, 14, , "Close")

::method initDialog
    self~newRadioButton(IDC_RB_ASKDIALOG_R)~Checked = .true

::method ok unguarded
    select
        when self~newRadioButton(IDC_RB_ASKDIALOG_R)~Checked then self~askDialog
        when self~newRadioButton(IDC_RB_CHECKLIST_R)~Checked then self~checkList
        when self~newRadioButton(IDC_RB_ERRORDIALOG_R)~Checked then self~errorDialog
        when self~newRadioButton(IDC_RB_FILENAMEDIALOG_R)~Checked then self~fileNameDialog
        when self~newRadioButton(IDC_RB_INFODIALOG_R)~Checked then self~infoDialog
        when self~newRadioButton(IDC_RB_INTEGERBOX_R)~Checked then self~integerBox
        when self~newRadioButton(IDC_RB_INPUTBOX_R)~Checked then self~inputBox
        when self~newRadioButton(IDC_RB_LISTCHOICE_R)~Checked then self~listChoice
        when self~newRadioButton(IDC_RB_MESSAGEDIALOG_R)~Checked then self~messageDialog
        when self~newRadioButton(IDC_RB_MULTIINPUTBOX_R)~Checked then self~multiInputBox
        when self~newRadioButton(IDC_RB_MULTILISTCHOICE_R)~Checked then self~multiListChoice
        when self~newRadioButton(IDC_RB_PASSWORDBOX_R)~Checked then self~passwordBox
        when self~newRadioButton(IDC_RB_SINGLESELECTION_R)~Checked then self~singleSelection
        when self~newRadioButton(IDC_RB_TIMEDMESSAGE_R)~Checked then self~timedMessage
        otherwise nop
    end
    -- End select

::method autoRun                       -- (.NET version) unattended: every routine once, then Close
    do b over .array~of(IDC_RB_ASKDIALOG_R, IDC_RB_CHECKLIST_R, IDC_RB_ERRORDIALOG_R, IDC_RB_INFODIALOG_R, -
                        IDC_RB_INTEGERBOX_R, IDC_RB_LISTCHOICE_R, IDC_RB_MESSAGEDIALOG_R, IDC_RB_MULTIINPUTBOX_R, -
                        IDC_RB_MULTILISTCHOICE_R, IDC_RB_PASSWORDBOX_R, IDC_RB_SINGLESELECTION_R, IDC_RB_TIMEDMESSAGE_R)
        self~newRadioButton(b)~Checked = .true
        self~ok
    end
    self~cancel

::method askDialog private

    msg = 'AskDialog routine:'                     || .endOfLine~copies(2) || -
          'This routine is good for getting input' || .endOfLine || -
          'from the user, when the input can be'   || .endOfLine || -
          'supplied by a simple Yes or No answer.' || .endOfLine~copies(2) || -
          'Was this information helpful to you?'

    if AskDialog(msg) then do
        msg = 'Glad this example is of use.' || .endOfLine~copies(2) || -
              'Did you notice the default button has changed?'

        ret = AskDialog(msg, 'N')
    end
    else do
        msg = 'Well, the text for the message is a littel contrived.' || .endOfLine~copies(2) || -
              'Did you notice the default button has changed?'

        ret = AskDialog(msg, 'N')
    end


::method checkList private
    chks = .array~new
    chks[3] = .true
    chks[4] = .true

    labels = .array~of("Jan", "Feb", "Mar", "April in Paris is nice",      -
                       "May", "Jun", "Jul", "Aug",                         -
                        "Sep", "Oct", "Nov", "Dec")

    ar = CheckList('Select a few months:', self~COMMON_TITLE, labels, chks, , 4)

    msg = 'Check list routine results:' || .endOfLine~copies(2)
    if ar \= .nil then do i=1 to ar~items
        if ar[i] = 1 then msg ||= '  CheckList['i']  (' || labels[i] || ') is checked.' || .endOfLine
    end
    else do
        msg ||= 'The user canceled.'
    end

    self~displayResult(msg, 'Check List Public Routine')


::method errorDialog private

    msg = 'ErrorDialog routine:'                        || .endOfLine~copies(2) || -
          'This routine is good for displaying error'   || .endOfLine || -
          'messages to the user.  Serious warning'      || .endOfLine || -
          'messages might also be appropriate for this' || .endOfLine || -
          'routine.'

    return ErrorDialog(msg)


::method fileNameDialog private

    ooRexxHome = value("REXX_HOME", , 'ENVIRONMENT' )
    if ooRexxHome~length == 0 then path = 'C:\Program Files\ooRexx\'
    else path = ooRexxHome || '\'

    delimiter = '0'x
    filemask  = 'All Files (*.*)'delimiter'*.*'delimiter

    fileName = FileNameDialog(path, self~hwnd, filemask)

    if fileName == 0 then msg = 'You did not select a file.'
    else msg = 'You selected' fileName 'as your pick.'
    self~displayResult(msg, 'File Name Dilaog Public Routine')


::method infoDialog private

    msg = 'InfoDialog routine:'                        || .endOfLine~copies(2) || -
          'This routine is good for displaying short'  || .endOfLine || -
          'bits of information to the user, when no'   || .endOfLine || -
          'reply from the user is needed.'

    return InfoDialog(msg)


::method inputBox private

    width = 60
    data  = Inputbox('Please enter some fact:', self~COMMON_TITLE, , 200)
    if data \== '' then msg = 'You entered:' data 'is that a fact?'
    else msg = 'You canceled and did not enter any fact.'
    self~displayResult(msg, 'Input Box Public Routine', .true)


::method integerBox private

    integer = Integerbox('Please enter a numeric value now:', self~COMMON_TITLE)
    if integer \== '' then msg = 'You entered:' integer
    else msg = 'You canceled and did not enter any value.'
    self~displayResult(msg, 'Integer Box Public Routine')


::method listChoice private

    day = ListChoice('Select your favorite day:', self~COMMON_TITLE,          -
                     .array~of("Monday", "Tuesday", "Wednesday", "Tursday",   -
                               "Friday", "Saturday", "Sunday"), 102)
    if day \== .nil then do
        msg = 'So, your favorite day is' day'?'
        self~displayResult(msg, 'List Choice Public Routine', .true)
    end
    else do
        msg = 'You canceled and did not pick a favorite day.'
        self~displayResult(msg, 'List Choice Public Routine')
    end


::method messageDialog private

    msg = 'MessageDialog routine:'                        || .endOfLine~copies(2) || -
          'The message dialog gives the progammer more'   || .endOfLine || -
          'flexibilty in crafting a dialog to inform the' || .endOfLine || -
          'user or to solicit information from the user.' || .endOfLine~copies(2) || -
          'That is a good thing, is it not?'

    do while .true
        ret = MessageDialog(msg, self~hwnd, self~COMMON_TITLE, 'YESNOCANCEL', 'INFORMATION')
        if ret == self~IDCANCEL then return

        if ret == self~IDNO then do
            msg1 = 'No is not an appropriate answer!'
            ret = MessageDialog(msg1, self~hwnd, self~COMMON_TITLE, 'RETRYCANCEL', 'EXCLAMATION', 'DEFBUTTON2')
            if ret == self~IDCANCEL then return
        end
        else do
            msg1 = 'Yes is the correct answer.'
            ret = MessageDialog(msg1, self~hwnd, self~COMMON_TITLE, 'CANCELTRYCONTINUE', 'INFORMATION', 'DEFBUTTON3')
            if ret == self~IDCANCEL then return
            else if ret = self~IDTRYAGAIN then iterate

            msg2 = 'I could continue asking questions all day.'
            ret = MessageDialog(msg2, self~hwnd, self~COMMON_TITLE, 'ABORTRETRYIGNORE', 'WARNING', 'DEFBUTTON3')
            if ret == self~IDABORT then return
        end
    end


::method multiInputBox private

    editWidth = 100
    tab       = '09'x
    labels    = .array~of("&First name", "Last &name", "&State")

    ar = MultiInputBox('Enter employee information:', self~COMMON_TITLE,       -
                       labels, .array~of("Ueli", "Wahli", ''), 100)

    msg = 'Multi Input Box routine results:' || .endOfLine~copies(2)
    if ar \== .nil then do i = 1 to 3
        msg ||= labels[i]~changeStr('&', '') || tab || ':' ar[i] || .endOfLine
    end
    else do
        msg ||= 'You canceled the dialog.'
    end
    self~displayResult(msg, 'Multi Input Box Public Routine')


::method multiListChoice private

    labels = .array~of("Monday", "Tuesday", "Wednesday", "Tursday", "Friday", "Saturday", "Sunday")

    msg = 'Multi List Choice routine results:' || .endOfLine~copies(2)
    ar = MultiListChoice('Select several days:', self~COMMON_TITLE, labels)
    if ar \= .nil then do
        msg ||= 'You selected' || .endOfLine
        do i = 1 to ar~items
            msg ||= '  ' ar[i] || .endOfLine
        end
    end
    else do
        msg ||= 'You did not select any days.'
    end
    self~displayResult(msg, 'Multi List Choice Public Routine')


::method passwordBox private

  -- This just shows that the password box increases in width to fit the prompt.
  	p = Passwordbox('Please enter a password, and be quick about it:', self~COMMON_TITLE)
    msg = 'The password entered was:' p
    self~displayResult(msg, 'Password Box Public Routine')

  	p = Passwordbox('Password:', self~COMMON_TITLE)
    msg = 'The password entered was:' p
    self~displayResult(msg, 'Password Box Public Routine')



::method singleSelection private

    labels = .array~of("Jan", "Feb", "Mar", "Apr", "May", "Jun", "July is the hottest month", -
                       "Aug", "Sep", "Oct", "Nov", "Dec")
    selected = 7

    choice = SingleSelection('Select one:', self~COMMON_TITLE, labels, selected)
    msg = 'You selected' labels[choice]
    self~displayResult(msg, 'Single Selection Public Routine')

    -- This shows the radio buttons do not have to be all in 1 row.  Here we
    -- break the buttons up so that no more than 6 are in 1 row.
    selected = 3
    maxInRow = 6
    choice = SingleSelection('Select one, one more time:', self~COMMON_TITLE, labels, selected, , maxInRow)
    msg = 'You selected' labels[choice]
    self~displayResult(msg, 'Single Selection Public Routine')



::method timedMessage private

    x = TimedMessage('Please read this message.  You will have to be quick.', 'Message', 2000)


::method displayResult private
    use strict arg msg, title, isQuestion = .false

    icon = "INFORMATION"
    bttn = "OK"
    if isQuestion then do
        icon = "QUESTION"
        bttn = "YESNO"
    end
    j = MessageDialog(msg, self~hwnd, title, icon, bttn)

