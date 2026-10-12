/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 2013-2022 Rexx Language Association. All rights reserved.    */
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
 * An example showing usage of the BrowseForFolder class.  This example shows
 * how to use the class to browse virtual folders, in this case the Printers
 * folder.
 *
 * The BrowseForFolder object puts up the same Windows Shell browse dialog as
 * does the SimpleFolderBrowse object, but it is much more configurable.
 *
 * This example uses the browse for folder dialog to let the user select a
 * printer.
 *
 * The example puts up a regular dialog and on the push of a button shows the
 * browse for folder dialog set to browse only printers.  The user's pick is
 * is displayed in an edit box.
 *
 * (.NET version of ooDialog's examples\browsePrinters.rex, on Windows Forms
 * through oodnet.cls. .NET picks a printer with its PrintDialog, not with the
 * Shell's folder browser: no item ID lists, no COM to release, and the
 * printer comes as its name (PrinterSettings.PrinterName). The short display
 * name is that name; the long one, which the Shell gives as the printer's
 * place among the Shell's folders, is here the name and whether it is the
 * default printer. The ids are names, so no constDir.)
 */

    .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended

    dlg = .PrintersDialog~new
    dlg~execute("SHOWTOP")

    return 0

::requires "oodnet.cls"

::class 'PrintersDialog' subclass NetDialog

/** init()
 *
 *  Typical UserDialog init() method.  Initializes the super class, the starts
 *  the dialog template by creating the frame in the template.  Internally, the
 *  create() method will invoke the define() method.  When create() returns,
 *  the dialog template will be complete.
 */
::method init
  forward class (super) continue

  self~create(30, 30, 257, 123, "Browse For Printers Example", "CENTER")


/** define()
 *
 *  A typical define() method for a UserDialog.  We create a push button in the
 *  dialog template that allows the user to show the browse for folder dialog.
 *
 *  An edit control and two radio buttons are created, the edit control shows
 *  the result of the user's selection in the browse for folder dialog.  The
 *  radio button control how the selection is returned from the browse for
 *  folder dialog.
 */
::method defineDialog

    self~createStaticText(IDC_ST_RESULTS, 10, 10, 30, 11, , "Results:")
    self~createEdit(IDC_EDIT, 10, 24, 237, 11, 'AUTOSCROLLH')
    self~createRadioButton(IDC_RB_LONG_NAME, 10, 60, 90, 14, "AUTO", 'Long Display Name')
    self~createRadioButton(IDC_RB_SHORT_NAME, 10, 79, 90, 14, "AUTO", 'Short Display Name')
    self~createPushButton(IDC_PB_BROWSE, 10, 99, 65, 14, "DEFAULT", "Browse Printers", onBrowse)
    self~createPushButton(IDCANCEL, 197, 99, 50, 14, , "Done")


/** onBrowse()
 *
 * The event handler for the Browse Printers push button.  (.NET version) We
 * configure a PrintDialog, display it, and report the user's actions in the
 * edit control.
 */
::method onBrowse unguarded
    expose rbShort edit

    pd = .net~System~Windows~Forms~PrintDialog~new      -- ooDialog: .BrowseForFolder~new(title, banner, hint),
    pd~UseEXDialog = .true                              -- root CSIDL_PRINTERS, options BROWSEFORPRINTER

    if .NetDialog~auto then r = "Cancel"                -- (.NET version) unattended: as if cancelled
    else r = pd~ShowDialog(self~form)~string            -- (the owner window, as bff~owner = self)
    if r \== "OK" then do
        edit~Text = 'The user canceled.'
        return 0
    end

    ps = pd~PrinterSettings
    if rbShort~Checked then do
        name = ps~PrinterName
    end
    else do
        name = ps~PrinterName (ps~IsDefaultPrinter)~?("(the default printer)", "")
    end

    text = 'The user picked: ' name
    edit~Text = text

    return 0


/** initDialog()
 *
 * Simple init dialog method.  We get references to the edit control and one of
 * the two radio buttons.  Since the radio buttons are auto and there are only 2
 * of them we only need one reference to be able to tell which is checked.
 */
::method initDialog
    expose rbShort edit

    edit = self~newEdit(IDC_EDIT)
    rbShort = self~newRadioButton(IDC_RB_SHORT_NAME)
    rbShort~Checked = .true                             -- ooDialog: rbShort~check

::method autoRun                       -- (.NET version) unattended: Browse (cancelled), the installed printers listed, Done
    expose edit
    self~onBrowse
    say "(auto)" edit~Text
    say "(auto) printers:" .net~System~Drawing~Printing~PrinterSettings~InstalledPrinters~Count
    self~cancel
