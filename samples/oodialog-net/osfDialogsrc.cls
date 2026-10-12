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
/* osfDialogs.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with osfDialogs.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "OsfDialogs_IDD_SAVE_FILE" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 257, 123, "Save File Dialog Example", "CENTER", , "Ms Shell Dlg", 8)

::method defineDialog                  -- the .rc's controls
  self~createStatic(IDC_STATIC, 11, 10, 235, 11, "", "Result of the Save File Dialog execution will be shown here:")
  self~createEdit(IDC_EDIT, 10, 23, 236, 12, "READONLY", "IDC_EDIT")
  self~createStatic(IDC_STATIC, 11, 49, 235, 11, "", "Filter (remove from view) files with these extensions:")
  self~createGroupBox(IDC_STATIC, 10, 59, 236, 32, "", "")
  self~createCheckBox(IDC_CK_EXE, 21, 72, 35, 9, "", "*.exe", "EXE")
  self~createCheckBox(IDC_CK_DLL, 71, 72, 35, 9, "", "*.dll", "DLL")
  self~createCheckBox(IDC_CK_CLS, 117, 72, 35, 9, "", "*.cls", "CLS")
  self~createCheckBox(IDC_CK_NONE, 197, 72, 35, 9, "", "None", "NONE")
  self~createPushButton(IDC_PB_SHOW, 10, 99, 85, 14, "DEFAULT", "Show Save File Dialog")
  self~createPushButton(IDCANCEL, 197, 99, 50, 14, "", "Done")

::class "OsfDialogs_IDD_SIMPLE_OSF_DIALOGS" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 256, 193, "Open File or Save File Demonstration", "CENTER", , "Ms Shell Dlg", 8)

::method defineDialog                  -- the .rc's controls
  self~createGroupBox(IDC_STATIC, 10, 10, 236, 106, "", "Pick the Open / Save File Dialog to display:")
  self~createRadioButton(IDC_RB_OPEN, 23, 27, 66, 11, "", "Simple Open File", "SIMPLEOPENFILE")
  self~createRadioButton(IDC_RB_SAVE, 23, 49, 66, 11, "", "Simple Save File", "SIMPLESAVEFILE")
  self~createRadioButton(IDC_RB_OPEN_MULTI, 23, 72, 85, 11, "", "Open Multiple Files", "OPENMULTIPLEFILES")
  self~createRadioButton(IDC_RB_OPEN_CUSTOM, 117, 27, 110, 11, "", "Open File Easy Customizations", "OPENFILEEASYCUSTOMIZATIONS")
  self~createRadioButton(IDC_RB_SAVE_DEFAULT, 117, 49, 110, 11, "", "Save File Default Name", "SAVEFILEDEFAULTNAME")
  self~createRadioButton(IDC_RB_OPEN_FOLDER, 117, 72, 110, 11, "", "Open File in Specified Folder", "OPENFILEINSPECIFIEDFOLDER")
  self~createPushButton(IDC_PB_SHOW_OSF, 84, 93, 50, 14, "DEFAULT", "Show")
  self~createStatic(IDC_STATIC, 10, 136, 235, 11, "", "Result of the Open / Save File Dialog execution will be shown here:")
  self~createEdit(IDC_EDIT_OSF, 10, 149, 236, 12, "READONLY", "IDC_EDIT_OSF")
  self~createPushButton(IDCANCEL, 196, 169, 50, 14, "", "Done")
