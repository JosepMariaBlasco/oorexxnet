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
/* importList.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with importList.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "ImportList_IDD_IMPORTER" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(40, 60, 412, 330, "Import File Manager - Preview Verison 1.00.04", "MAXIMIZEBOX", , "Tahoma", 9)

::method defineDialog                  -- the .rc's controls
  self~createStatic(IDC_HEADER, 10, 10, 392, 29, "", "Review Import File Options, change if necessary, then click Import to import and continue working, Ok to import and quit, Cancel to abort.")
  self~createListView(IDC_LV, 10, 44, 392, 250, "REPORT SHOWSELALWAYS")
  self~createComboBox(IDC_CB, 10, 265, 40, 12, "LIST  HIDDEN", "IDC_CB")
  self~createEdit(IDC_EDIT, 55, 265, 40, 12, "NOBORDER  HIDDEN", "IDC_EDIT")
  self~createStatic(IDC_ST_DIR_LABEL, 11, 306, 59, 14, "RIGHT CENTERIMAGE", "Import Directory:")
  self~createStatic(IDC_ST_DIRECTORY, 75, 306, 110, 14, "CENTERIMAGE ELLIPSIS", "C:\Rexx\ooRexx")
  self~createPushButton(IDC_PB_PROCESS, 245, 306, 50, 14, "DEFAULT", "Process")
  self~createPushButton(IDC_PB_IMPORT, 191, 306, 50, 14, "DEFAULT", "Import")
  self~createPushButton(IDOK, 300, 306, 50, 14, "DEFAULT", "OK")
  self~createPushButton(IDCANCEL, 352, 306, 50, 14, "", "Cancel")

::class "ImportList_IDD_RESULTS" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 412, 335, "Processing Results", "CENTER", , "Tahoma", 9)

::method defineDialog                  -- the .rc's controls
  self~createListView(IDC_LV_RESULTS, 11, 10, 391, 291, "REPORT SHOWSELALWAYS")
  self~createPushButton(IDOK, 352, 311, 50, 14, "DEFAULT", "Close")

::class "ImportList_IDM_MENUBAR" subclass NetMenuBar public   -- the .rc's IDM_MENUBAR MENU
::method init
  forward class (super) continue
  p1 = .NetPopupMenu~new(0)
  p1~insertItem(, IDM_RESET_DIRECTORY, "Reset Directory")
  p1~insertItem(, IDM_PROCESS_VIEW, "Process Current View")
  p1~insertItem(, IDM_IMPORT_DIRECTORY, "Import Current Directory")
  p1~insertItem(, IDOK, "Exit")
  self~insertPopup(, 0, p1, "File")
