/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 2013-2014 Rexx Language Association. All rights reserved.    */
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

/** saveFileWithFilter.rex
 *
 *  This example shows how to use the Common Item Dialog in file save mode.
 *
 *  This example shows 2 things.  1.) How to use a filter with the dialog.
 *  2.) How to connect event notifications.
 *
 *  For the purpose of the example, we use a hypothetical case that the
 *  application wants the user to pick a file to save to, but the data being
 *  saved can not be saved to file with the extension of .exe, or .dll, or .cls.
 *
 *  To achieve this a filter is used so that the save dialog does not show any
 *  files with those extensions.  To ensure the user does not type in a file
 *  name with those extensions, when the user picks a file name, the OnFileOk
 *  event is used to check the file name the user picked.
 *
 *  To give the example a little variety, a dialog is first put up to allow the
 *  user to pick some or all of the extensions to filter out and the Save File
 *  Dialog can be shown multiple times.
 *
 * (.NET version of ooDialog's examples\saveFileWithFilter.rex, on Windows
 * Forms through oodnet.cls. Its .rc's dialog is the same as osfDialogs.rc's
 * IDD_SAVE_FILE: OsfDialogs_IDD_SAVE_FILE, from osfDialogsrc.cls. .NET's
 * SaveFileDialog is the Common Item Dialog, but has no item filter (the
 * Shell's IShellItemFilter, ooDialog's ShellItemFilter): its view shows every
 * file. Its FileOk event is onFileOk: the handler sets e~Cancel to refuse
 * the file (ooDialog: S_FALSE). setClientGuid is ClientGuid, setFolder
 * InitialDirectory; nothing to release.)
 */

    .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended

    dlg = .CommonSaveDialog~new        -- ooDialog: .CommonSaveDialog~new(srcDir'resources\saveFileWithFilter.rc', IDD_SAVE_FILE)
    dlg~execute("SHOWTOP")

    return 0

::requires "osfDialogsrc.cls"

::class 'CommonSaveDialog' subclass OsfDialogs_IDD_SAVE_FILE

-- Do not copy this GUID into your own code.  Always generate your own GUID.
::constant GUID   'a25b89e4-db67-4423-ae66-a4836bb76024'

/** initDialog()
 *
 * Simple standard init dialog method.  We save references to our commonly used
 * controls, set the .exe check box to checked on start up, and connect the
 * button click event for the push button and the 'None' check box.  Each time
 * the None check box is clicked we toggle the state of the other 3 check boxex.
 *
 * We also use this method to find the installed directory of ooRexx.
 */
::method initDialog
    expose ckExe ckDll ckCls ckNone edit rexx_home

    ckExe  = self~newCheckBox(IDC_CK_EXE)
    ckExe~Checked = .true                                   -- ooDialog: ~~check
    ckDll  = self~newCheckBox(IDC_CK_DLL)
    ckCls  = self~newCheckBox(IDC_CK_CLS)
    ckNone = self~newCheckBox(IDC_CK_NONE)

    edit = self~newEdit(IDC_EDIT)

    self~connectButtonEvent(IDC_CK_NONE, 'CLICKED', onCheckNone)
    self~connectButtonEvent(IDC_PB_SHOW, 'CLICKED', onShowSaveDialog)

    rexx_home = value('REXX_HOME', , 'ENVIRONMENT')
    if rexx_home == '' then rexx_home = 'C:\Program Files'


/** onShowSaveDialog()
 *
 * When the user clicks on the 'Show Save File Dialog' push button, we put up
 * the Save File Dialog and then report the results in the edit control.
 *
 * (.NET version) The user could simply type in the name: myfile.exe in the
 * edit box.  We prevent that with the dialog's FileOk event, whose handler,
 * a CDEvents object, refuses such a file.
 */
::method onShowSaveDialog unguarded
    expose edit rexx_home

    -- Setting the client GUID has the operating system preserve the state for
    -- this specific save file dialog.
    sfd = .net~System~Windows~Forms~SaveFileDialog~new
    sfd~ClientGuid = .net~System~Guid~new(self~GUID)       -- ooDialog: sfd~setClientGuid(self~GUID)

    -- The filter variable is a simple string of words.  Each word in the string
    -- is a file extension to filter out.
    filter = self~getCurrentFilter

    -- If the filter is 'None', the None check box is checked.  No point in
    -- setting the event handler at all for that case.
    if filter \== 'None' then do
        eventHandler = .CDevents~new
        eventHandler~filter = filter
        sfd~FileOk += .net~handler(eventHandler, "ONFILEOK")   -- ooDialog: sfd~advise(eventHandler)
    end

    -- We set the initial folder to the install directory of ooRexx because we
    -- know that directory contains .exe, .dll, and .cls files.
    sfd~InitialDirectory = rexx_home                        -- ooDialog: sfd~setFolder(rexx_home)

    -- We are all set, show the dialog and get the user's response:
    if .NetDialog~auto then do                              -- (.NET version) unattended: cancelled, after the
        say "(auto) filter:" filter                         -- check a Save would have made
        if filter \== 'None' then say "(auto) Save of" rexx_home"\rexx.exe:" eventHandler~check(rexx_home"\rexx.exe", 0)
        ret = "Cancel"
    end
    else ret = sfd~ShowDialog(self~form)~string            -- ooDialog: sfd~show(self)
    if ret == "Cancel" then text = 'The user canceled the save'
    else text = 'Save to file:' sfd~FileName

    -- Have the edit box display the result.
    edit~Text = text                                        -- ooDialog: edit~setText(text)


/** onCheckNone()
 *
 *  The event handler for the CLICK event.  This method is invoked whenever the
 *  user clicks on the 'None' check box.  If the click checks the check box we
 *  uncheck all the othe check boxes and disable them.  If the click unchecks
 *  the check box we re-enable the other check boxes.
 */
::method onCheckNone unguarded
    expose ckExe ckDll ckCls ckNone

    if ckNone~Checked then do
        do ck over .array~of(ckExe, ckDll, ckCls)          -- ooDialog: ck~~uncheck~disable
            ck~Checked = .false
            ck~Enabled = .false
        end
    end
    else do
        ckExe~Enabled = .true
        ckDll~Enabled = .true
        ckCls~Enabled = .true
    end


/** getCurrentFilter()
 *
 * A simple private helper method.  We create a string with each file extension
 * name for every extension whose check box is checked.  If the None check box
 * is checked we use the string 'None'  The file extension names need to be
 * separated by spaces so that we have a string of 'words.'
 */
::method getCurrentFilter unguarded private
    expose ckExe ckDll ckCls ckNone

    if ckNone~Checked then do
        f = 'None'
    end
    else do
        f = ''
        if ckExe~Checked then f = '.exe'
        if ckDll~Checked then f ||= ' .dll'
        if ckCls~Checked then f ||= ' .cls'
    end

    if f == '' then f = 'None'
    return f

::method autoRun                       -- (.NET version) unattended: .exe, then .dll and .cls too, then None, then Done
    expose ckDll ckCls ckNone edit
    self~onShowSaveDialog
    ckDll~Checked = .true; ckCls~Checked = .true
    self~onShowSaveDialog
    ckNone~Checked = .true; self~onCheckNone
    self~onShowSaveDialog
    say "(auto)" edit~Text
    self~cancel


/* Class:  CDEvents
 *
 *  (.NET version) The handler of the Save File Dialog's FileOk event: invoked
 *  when the user has pushed Save, but before the dialog is closed.  It gives
 *  us a chance to veto the close (e~Cancel = .true; ooDialog's onFileOk
 *  returns S_FALSE).
 *
 *  Obviously, if the dialog does not close when the user presses the button, it
 *  can be disconcerting.  So, you should always put up some explanation of why
 *  the dialog does not close.
 */
::class 'CDEvents'

::attribute filter unguarded

::method onFileOk unguarded
  use arg sfd, e
  if \self~check(sfd~FileName, sfd) then e~Cancel = .true

/** check(file, owner): whether the file may be saved to; if not, says why
 *  (unattended: not shown) */
::method check unguarded
  use arg file, owner
  if self~filter == 'None' then return .true

  ext = self~getExtension(file)
  if self~filter~caselessWordPos(ext) <> 0 then do
      extList = self~nameExtensions(self~filter)
      title   = 'ooRexx Save File Selection Error'
      msg     = 'File:' file 'is not acceptable.' || .endOfLine~copies(2) || -
                'The file to save to must not have' extList
      j = MessageDialog(msg, owner, title, 'OK', 'ERROR')
      return .false
  end
  return .true

::method getExtension
    use strict arg file

    pos = file~lastpos('.')
    if pos > 0 then return file~substr(pos)
    else return ''

/** nameExtensions()
 *
 * Just a simple helper method to take the filter string: '.exe .dll' and turn
 * it into a phrase for the message box.
 */
::method nameExtensions unguarded private
    use strict arg exts

    count = exts~words
    str = 'an extension of '

    if count == 1 then do
      str ||= exts
    end
    else do i = 1 to count
        if i == count then str ||= 'or' exts~word(i)
        else str ||= exts~word(i) || ', '
    end
    return str || '.'
