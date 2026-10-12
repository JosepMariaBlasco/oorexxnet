/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 1995, 2004 IBM Corporation. All rights reserved.             */
/* Copyright (c) 2005-2021 Rexx Language Association. All rights reserved.    */
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
/****************************************************************************/
/* Name: oovideo.rex                                                        */
/* Type: ooRexx Script                                                      */
/*                                                                          */
/* Description: Video archive                                               */
/*                                                                          */
/*
 * Note: this program uses the public routine, locate(), to get the full path
 * name to the directory this source code file is located. In places, the
 * variable holding this value has been callously abbreviated to 'sd' which
 * stands for source directory.
 *
 * (.NET version, on Windows Forms through oodnet.cls: rc\ldvideo.rc's
 * dialog is a class of ldvideorc.cls (rc2oodnet.rex -cls), the program's
 * RcDialog its subclass. As ooDialog's, new takes the dialog's data stem,
 * A., whose tails are the controls' ids (here their names: IDC_EDIT_TAPE_NO),
 * set into the controls when the dialog starts and filled from them after
 * OK, and CONNECTBUTTONS, which connects each push button to the method its
 * text names (&Search: search). The sounds are in resources\.)
 *
 ****************************************************************************/

  .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended
  srcDir = filespec("location", .context~package~name)   -- ooDialog: locate()

  -- ooDialog: .application~useGlobalConstDir('O', srcDir'rc\ldvideo.h'): here the ids are names

 logfile = srcDir'oovideo.log'
 a.IDC_EDIT_TAPE_NO = "10000"
 a.IDC_EDIT_TAPE_LABEL = "Actionfilms 1"
 a.IDC_EDIT_FILM1 = "Gone with the Wind"
 a.IDC_EDIT_FILM2 = "True Lies"
 a.IDC_EDIT_FILM3 = "Rambo 4"
 a.IDC_EDIT_FILM4  = ""
 a.IDC_CB_LOCATION = "Unknown"
 a.IDC_LB_LENT_TO = "Maria Shell"
 do i over .array~of(IDC_CK_LONGPLAY, IDC_CK_HIFI, IDC_CK_WRITEPROTECT, IDC_RB_C120, IDC_RB_C180, IDC_RB_C240)
    a.i = 0                                                -- ooDialog: do i = .constDir[IDC_CK_LONGPLAY] to .constDir[IDC_RB_C240]
 end
 a.IDC_RB_C180 = 1
 a.IDC_CK_HIFI = 1

 dlg = .MyDialog~new(A., , "CONNECTBUTTONS")              -- ooDialog: .MyDialog~new(srcDir"rc\ldvideo.rc", IDD_VIDEO_DLG, A., , "CONNECTBUTTONS")

 if dlg~initcode > 0 then do
    call errorDialog "Couldn't load the Video dialog"
    return 99
 end
 else if dlg~execute("SHOWTOP") = .MyDialog~IDOK then do
    o=.stream~new(logfile)
    o~open('write replace')
    o~lineout("OOVideo - Data:")
    o~lineout("Nr      :" a.IDC_EDIT_TAPE_NO)
    o~lineout("Titel   :" a.IDC_EDIT_TAPE_LABEL)
    o~lineout("Film 1  :" a.IDC_EDIT_FILM1)
    o~lineout("Film 2  :" a.IDC_EDIT_FILM2)
    o~lineout("Film 3  :" a.IDC_EDIT_FILM3)
    o~lineout("Film 4  :" a.IDC_EDIT_FILM4)
    o~lineout("Lent to :" a.IDC_LB_LENT_TO)
    o~lineout("Location:" a.IDC_CB_LOCATION)
    o~lineout("Longplay:" a.IDC_CK_LONGPLAY)
    o~lineout("Hifi    :" a.IDC_CK_HIFI)
    o~lineout("Protect :" a.IDC_CK_WRITEPROTECT)
    if (a.IDC_RB_C120 = 1) then o~lineout("Tape    : C120")
    if (a.IDC_RB_C180 = 1) then o~lineout("Tape    : C180")
    if (a.IDC_RB_C240 = 1) then o~lineout("Tape    : C240")
    o~close()
    'type "'logfile'"'
 end

 return

/*--------------------------------- requires -------------------------*/

::requires "ldvideorc.cls"          -- ooDialog: "ooDialog.cls", "samplesSetup.rex"

/*--------------------------------- dialog class --------------------*/

::class 'MyDialog' subclass Ldvideo_IDD_VIDEO_DLG   -- ooDialog: subclass RcDialog

::method initDialog
   expose sd

   sd = filespec("location", .context~package~name)     -- ooDialog: locate()

   cb = self~newComboBox(IDC_CB_LOCATION)
   cb~Items~Add("Drawer 1")                               -- ooDialog: cb~add("Drawer 1")
   cb~Items~Add("Drawer 2")
   cb~Items~Add("Behind the door")
   cb~Items~Add("Under the bed")
   cb~Items~Add("On the floor")
   cb~Items~Add("Unknown")

   lb = self~newListBox(IDC_LB_LENT_TO)
   lb~Items~Add("Hans-Maria Baier")                       -- ooDialog: lb~add("Hans-Maria Baier")
   lb~Items~Add("John Smith")
   lb~Items~Add("Peter Fonda")
   lb~Items~Add("Maria Shell")
   lb~Items~Add("Mike Miller")

   return 0

::method autoRun unguarded             -- (.NET version) unattended: what the stem put in, Search, a few changes, OK
   say "(auto) from the stem: tape" self~newEdit(IDC_EDIT_TAPE_NO)~Text"," self~newEdit(IDC_EDIT_FILM2)~Text"," -
       "location" self~newComboBox(IDC_CB_LOCATION)~Text", lent to" self~newListBox(IDC_LB_LENT_TO)~SelectedItem"," -
       "C180" self~newRadioButton(IDC_RB_C180)~Checked", Hifi" self~newCheckBox(IDC_CK_HIFI)~Checked
   self~newPushButton(3001)~PerformClick                  -- Search, connected by CONNECTBUTTONS
   self~newEdit(IDC_EDIT_FILM4)~Text = "Casablanca"
   self~newRadioButton(IDC_RB_C240)~Checked = .true
   self~newListBox(IDC_LB_LENT_TO)~SelectedItem = "Peter Fonda"
   self~newEdit(IDC_EDIT_TAPE_NO)~Text = ""
   self~ok                                                -- refused: no tape number
   self~newEdit(IDC_EDIT_TAPE_NO)~Text = "10001"
   self~ok

::method validate
   expose sd
   tst = self~newEdit(IDC_EDIT_TAPE_NO)~Text             -- ooDialog: ~getText
   if tst <> "" then do
      call Play sd"resources\take.wav"                   -- ooDialog: sd"wav\take.wav"
      return .true
   end
   else do
      msg = "The tape number can not be blank.  Use cancel to quit, if needed."
      title = 'Video Archive Database Warning'
      ret = MessageDialog(msg, self~hwnd, title, 'OK', 'WARNING')
   end

  return .false

::method cancel unguarded
   expose sd

   ret = Play(sd"resources\cancel.wav", yes)             -- ooDialog: sd"wav\cancel.wav"

   msg   = "Do you really want to cancel?       "
   title = 'Exiting Video Database Application'

   ret = MessageDialog(msg, self~hwnd, title, 'YESNO', 'QUESTION')

   if ret  == self~IDYES then return self~cancel:super
   else return 0

::method search unguarded

   msg = "Entry not found in Video Archive database."
   title = 'Video Archive Database Warning'
   ret = MessageDialog(msg, self~hwnd, title, 'OK', 'WARNING')

   return 0

