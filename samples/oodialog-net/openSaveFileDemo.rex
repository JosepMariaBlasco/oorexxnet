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

/** openSaveFileDemo.rex
 *
 *  This application shows several examples of using the Common Item Dialog.
 *
 * The Common Item Dialog (formerly known as the Common File Dialog) is used in
 * two variations: the Open dialog and the Save dialog. These two dialogs share
 * most of their functionality, but each have some unique methods.
 *
 *  One of the features of the Common Item Dialog is that it allows its state to
 *  be saved on a per instance basis  in addition to the per process basis.
 *  This is done by generating a GUID and assigning it to the dialog before it
 *  is configured.  Then, for each dialog with the same GUID, the operating
 *  system saves its state separately.  (genGUID.rex makes one.)
 *
 * (.NET version of ooDialog's examples\openSaveFileDemo.rex, on Windows Forms
 * through oodnet.cls: osfDialogs.rc's dialog is
 * OsfDialogs_IDD_SIMPLE_OSF_DIALOGS, from osfDialogsrc.cls. .NET's
 * OpenFileDialog and SaveFileDialog are the Common Item Dialog: ClientGuid
 * (setClientGuid), Title, CheckFileExists (FILEMUSTEXIST), Multiselect
 * (ALLOWMULTISELECT), ShowPreview (FORCEPREVIEWPANEON), ShowPinnedPlaces
 * (HIDEPINNEDPLACES), Filter and FilterIndex (setFileTypes,
 * setFileTypeIndex), DefaultExt, FileName and InitialDirectory. They have no
 * labels of their own for the file name box or the OK button, and no
 * HIDEMRUPLACES; nothing to release. The tool tips are a .NET ToolTip.)
 */

    .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended

    dlg = .CommonSaveDialog~new        -- ooDialog: .CommonSaveDialog~new(srcDir'resources\osfDialogs.rc', IDD_SIMPLE_OSF_DIALOGS)
    dlg~execute("SHOWTOP")

    return 0

::requires "osfDialogsrc.cls"

::class 'CommonSaveDialog' subclass OsfDialogs_IDD_SIMPLE_OSF_DIALOGS

::constant GUID_OPEN          '021b0a3d-cb16-4def-ab42-7fc259fd84d9'
::constant GUID_SAVE          'beff4495-fa60-468b-90c3-1dcb6fde0e78'
::constant GUID_OPEN_MULTI    'b6c25d80-198e-4baa-aad8-1249e4f15b3f'
::constant GUID_OPEN_CUSTOM   '745c45cb-3464-46fc-96cf-8628ad4bf63b'
::constant GUID_SAVE_DEFAULT  'fe2c5305-d7f9-43cd-9d7b-9c3d4d1b79be'
::constant GUID_OPEN_FOLDER   'ce5ad183-b42f-4f37-a5d6-78d1cffea2e6'


/** initDialog()
 *
 * Simple standard init dialog method.  We save references to our commonly used
 * controls, and connect the button click event for the push button.
 *
 * We also use this method to find the installed directory of ooRexx.
 */
::method initDialog
    expose rbOpen rbSave rbOpenMulti rbOpenCustom rbSaveDefault rbOpenFolder edit rexx_home

    rbOpen        = self~newRadioButton(IDC_RB_OPEN)
    rbOpen~Checked = .true                                  -- ooDialog: ~~check
    rbSave        = self~newRadioButton(IDC_RB_SAVE)
    rbOpenMulti   = self~newRadioButton(IDC_RB_OPEN_MULTI)
    rbOpenCustom  = self~newRadioButton(IDC_RB_OPEN_CUSTOM)
    rbSaveDefault = self~newRadioButton(IDC_RB_SAVE_DEFAULT)
    rbOpenFolder  = self~newRadioButton(IDC_RB_OPEN_FOLDER)

    edit = self~newEdit(IDC_EDIT_OSF)

    self~connectButtonEvent(IDC_PB_SHOW_OSF, 'CLICKED', onShowOSFDialog)

    rexx_home = value('REXX_HOME', , 'ENVIRONMENT')
    if rexx_home == '' then rexx_home = 'C:\Program Files'

    self~addToolTips


/** onShowOSFDialog()
 *
 * When the user clicks on the 'Show' push button, we put up the example Common
 * Item Dialog specified by the user through the radio buttons.
 */
::method onShowOSFDialog unguarded
    expose rbOpen rbSave rbOpenMulti rbOpenCustom rbOpenFolder rbSaveDefault

    select
      when rbOpen~Checked then return self~openExample
      when rbSave~Checked then return self~saveExample
      when rbOpenMulti~Checked then return self~openMultifilesExample
      when rbOpenCustom~Checked then return self~openCustomExample
      when rbSaveDefault~Checked then return self~saveDefaultExample
      when rbOpenFolder~Checked then return self~openFolderExample
      otherwise return 0  -- Can not really happen
    end


/** openExample()
 *
 *  Displays the most simple Open File Dialog example.  We just show the dialog
 *  and get the result, a file that need not exist.
 */
::method openExample unguarded private

    ofd = .net~System~Windows~Forms~OpenFileDialog~new
    ofd~ClientGuid = .net~System~Guid~new(self~GUID_OPEN)
    ofd~CheckFileExists = .false                            -- (the option FILEMUSTEXIST taken away)

    if self~showFileDialog(ofd) == "Cancel" then text = 'The user canceled the open'
    else text = 'Open file:' ofd~FileName

    self~showResult(text)
    return 0


/** saveExample()
 *
 *  Displays the most simple Save File Dialog example.
 */
::method saveExample unguarded private

    sfd = .net~System~Windows~Forms~SaveFileDialog~new
    sfd~ClientGuid = .net~System~Guid~new(self~GUID_SAVE)

    if self~showFileDialog(sfd) == "Cancel" then text = 'The user canceled the save'
    else text = 'Save to file:' sfd~FileName

    return self~showResult(text)


/** openMultiFilesExample()
 *
 * Displays a basic open file dialog that allows the user to pick multiple file
 * names at one time.
 */
::method openMultiFilesExample unguarded private

    ofd = .net~System~Windows~Forms~OpenFileDialog~new
    ofd~ClientGuid = .net~System~Guid~new(self~GUID_OPEN_MULTI)
    ofd~Multiselect = .true                                 -- ooDialog: ALLOWMULTISELECT

    msg = .nil
    if self~showFileDialog(ofd) == "Cancel" then do
        text = 'The user canceled the open operation.'
    end
    else do
        files = ofd~FileNames                               -- (a .NET array is a Rexx Array: from 1)
        if files~Length == 1 then do
            text = 'Open file:' files[1]
        end
        else do
            text = 'Open files (file names only):'
            msg = 'Open files (complete file names as returned):' || .endOfLine~copies(2)
            do f over files
                text ||= ' ' || fileSpec('N', f)
                msg  ||= f || .endOfLine
            end
        end
    end

    self~showResult(text)

    if msg \== .nil then do
        title = 'Complete Open File Names'
        j = MessageDialog(msg, self~hwnd, title, 'OK', 'INFORMATION')
    end
    return 0


/** openCustomExample()
 *
 *  Displays an Open File Dialog that has some easy to use customizations.
 */
::method openCustomExample unguarded private

    ofd = .net~System~Windows~Forms~OpenFileDialog~new
    ofd~ClientGuid = .net~System~Guid~new(self~GUID_OPEN_CUSTOM)
    ofd~CheckFileExists = .false

    ofd~Title = "The ooRexx Project's Open File Dialog"
    -- (ooDialog: setFileNameLabel('Type in, or select an existing, file to open
    -- here:') and setOkButtonLabel('Finished'): .NET's dialogs have no such)

    ofd~ShowPreview = .true                                 -- FORCEPREVIEWPANEON
    ofd~ShowPinnedPlaces = .false                           -- HIDEPINNEDPLACES (HIDEMRUPLACES: none)

    if self~showFileDialog(ofd) == "Cancel" then text = 'The user canceled the open'
    else text = 'Open file:' ofd~FileName

    return self~showResult(text)


/** saveDefaultExample()
 *
 * Displays a save file dialog that uses file type filters and sets the initial
 * file name and directory location.
 */
::method saveDefaultExample unguarded private
    expose rexx_home

    sfd = .net~System~Windows~Forms~SaveFileDialog~new
    sfd~ClientGuid = .net~System~Guid~new(self~GUID_SAVE_DEFAULT)

    sfd~Filter = 'Rexx Program File|*.rex|Rexx Class File|*.cls|Text File|*.txt'   -- ooDialog: setFileTypes(array)
    sfd~FilterIndex = 2                                     -- (from 1, as setFileTypeIndex)
    sfd~DefaultExt = 'cls'
    sfd~InitialDirectory = rexx_home                        -- ooDialog: setSaveAsItem(rexx_home'\ooDialog.cls')
    sfd~FileName = 'ooDialog.cls'

    if self~showFileDialog(sfd) == "Cancel" then text = 'The user canceled the save operation.'
    else text = 'Save file:' sfd~FileName

    return self~showResult(text)


/** openFolderExample()
 *
 * Displays a basic open file dialog.  The main point here is to demonstrate
 * how to control which directory is initially selected when the dialog opens.
 */
::method openFolderExample unguarded private
    expose rexx_home

    ofd = .net~System~Windows~Forms~OpenFileDialog~new
    ofd~ClientGuid = .net~System~Guid~new(self~GUID_OPEN_FOLDER)
    ofd~InitialDirectory = rexx_home                        -- ooDialog: setFolder(rexx_home)

    if self~showFileDialog(ofd) == "Cancel" then text = 'The user canceled the open operation.'
    else text = 'Open file:' ofd~FileName

    return self~showResult(text)


/** showFileDialog()
 *
 * (.NET version) Shows a file dialog, owned by this one (ooDialog:
 * ofd~show(self)): "OK" or "Cancel". Unattended: "Cancel", shown to no one.
 */
::method showFileDialog unguarded private
    use strict arg fd
    if .NetDialog~auto then do
        say "(auto)" fd~GetType~Name "with ClientGuid" fd~ClientGuid~ToString
        return "Cancel"
    end
    return fd~ShowDialog(self~form)~string


/** showResult()
 *
 * A convenience method that updates the edit box with the results for each
 * open / save file dialog.
 */
::method showResult unguarded private
    expose edit
    use strict arg text

    edit~Text = text                                        -- ooDialog: edit~setText(text)
    return 0


/** addToolTips()
 *
 * A convenience method to add a tool tip for each radio button.  The tool tips
 * let us show some text explaining the type of Open / Save File dialog that
 * will be displayed when the specific radio button is selected.
 *
 * (.NET version) One ToolTip serves them all; it breaks its text at the new
 * lines by itself (ooDialog: setMaxTipWidth). The text is pretty long, so to
 * ensure the user has enough time to read it all, we set the delay before
 * the tool tip disappears to twice the default delay time.
 */
::method addToolTips private
    expose rbOpen rbSave rbOpenMulti rbOpenCustom rbSaveDefault rbOpenFolder edit tips

    tips = .net~System~Windows~Forms~ToolTip~new
    tips~AutoPopDelay = tips~AutoPopDelay * 2               -- ooDialog: setDelayTime('AUTOPOP', getDelayTime('AUTOPOP') * 2)

    text = "Select this Radio Button to show " || .endOfLine || -
           "a simple Open File Dialog that"    || .endOfLine || -
           "allows the user to type in a"      || .endOfLine || -
           "file name."
    tips~SetToolTip(rbOpen, text)                           -- ooDialog: createToolTip, then addTool(rbOpen, text)

    text = "Select this Radio Button to show " || .endOfLine || -
           "a simple Save File Dialog that"    || .endOfLine || -
           "allows the user to type in a"      || .endOfLine || -
           "file name."
    tips~SetToolTip(rbSave, text)

    text = "Select this Radio Button to show"  || .endOfLine || -
           "an Open File Dialog that allows"   || .endOfLine || -
           "the user to select multiple files" || .endOfLine || -
           "at one time."
    tips~SetToolTip(rbOpenMulti, text)

    text = "Select this Radio Button to show"       || .endOfLine || -
           "an Open File Dialog that has some"      || .endOfLine || -
           "simple customizations of the apparence" || .endOfLine || -
           "of the dialog."
    tips~SetToolTip(rbOpenCustom, text)

    text = "Select this Radio Button to show"  || .endOfLine || -
           "a Save File Dialog that sets a"    || .endOfLine || -
           "default save as file name and a"   || .endOfLine || -
           "file type filter."
    tips~SetToolTip(rbSaveDefault, text)

    text = "Select this Radio Button to show"  || .endOfLine || -
           "an Open File Dialog that sets"    || .endOfLine || -
           "the initial direcotry that the"    || .endOfLine || -
           "dialog opens in."
    tips~SetToolTip(rbOpenFolder, text)

::method autoRun                       -- (.NET version) unattended: each kind of dialog (cancelled), then Done
    expose rbOpen rbSave rbOpenMulti rbOpenCustom rbSaveDefault rbOpenFolder edit tips
    do rb over .array~of(rbOpen, rbSave, rbOpenMulti, rbOpenCustom, rbSaveDefault, rbOpenFolder)
        rb~Checked = .true
        self~onShowOSFDialog
        say "(auto)" rb~Text":" edit~Text "- tip:" tips~GetToolTip(rb)~left(33)
    end
    self~cancel
