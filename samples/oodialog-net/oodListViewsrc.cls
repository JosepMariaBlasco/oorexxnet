/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 2011-2021 Rexx Language Association. All rights reserved.    */
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
/* oodListViews.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with oodListViews.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "OodListViews_IDD_ADDRESS" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(9, 23, 281, 140, "Add New Record", "", , "MS Shell Dlg", 10)

::method defineDialog                  -- the .rc's controls
  self~createStatic(-1, 11, 26, 39, 8, "", "First name:")
  self~createEdit(IDC_EDIT_FNAME, 54, 25, 71, 12, "", "IDC_EDIT_FNAME")
  self~createStatic(-1, 134, 26, 40, 8, "", "Last name:")
  self~createEdit(IDC_EDIT_LNAME, 178, 25, 93, 12, "", "IDC_EDIT_LNAME")
  self~createStatic(-1, 11, 49, 38, 8, "", "Street:")
  self~createEdit(IDC_EDIT_STREET, 54, 48, 217, 12, "", "IDC_EDIT_STREET")
  self~createStatic(-1, 11, 69, 38, 8, "", "City:")
  self~createEdit(IDC_EDIT_CITY, 54, 68, 73, 12, "", "IDC_EDIT_CITY")
  self~createStatic(-1, 134, 69, 21, 8, "", "State:")
  self~createEdit(IDC_EDIT_STATE, 159, 68, 19, 12, "UPPER", "IDC_EDIT_STATE")
  self~createStatic(-1, 198, 69, 37, 8, "", "Zip Code:")
  self~createEdit(IDC_EDIT_ZIPCODE, 240, 68, 31, 12, "NUMBER UPPER", "IDC_EDIT_ZIPCODE")
  self~createStatic(-1, 11, 92, 19, 8, "", "Age:")
  self~createEdit(IDC_EDIT_AGE, 54, 91, 23, 12, "NUMBER", "IDC_EDIT_AGE")
  self~createRadioButton(IDC_RB_MALE, 100, 91, 27, 12, "GROUP", "Male", "IDC_RB_MALE")
  self~createRadioButton(IDC_RB_FEMALE, 141, 91, 41, 12, "", "Female", "IDC_RB_FEMALE")
  self~createCheckBox(IDC_CHK_EDITABLE, 11, 116, 84, 14, "", "Record can be edited", "IDC_CHK_EDITABLE")
  self~createPushButton(IDOK, 155, 116, 50, 14, "DEFAULT", "OK")
  self~createPushButton(IDCANCEL, 221, 117, 50, 14, "", "Cancel")

::class "OodListViews_IDD_LISTVIEWS" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 400, 242, "List Views", "CENTER", , "MS Shell Dlg", 10)

::method defineDialog                  -- the .rc's controls
  self~createTab(IDC_TAB, 10, 10, 380, 175, "")
  self~createCheckBox(IDC_CK_INFOTIPS, 10, 194, 81, 13, "", "Use Info Tips", "IDC_CK_INFOTIPS")
  self~createPushButton(IDC_PB_BACKWARD, 10, 218, 55, 14, "", "Backward")
  self~createPushButton(IDC_PB_FORWARD, 72, 218, 55, 14, "", "Forward")
  self~createPushButton(IDC_PB_ADDRECORD, 134, 218, 55, 14, "", "Add Record")
  self~createPushButton(IDC_PB_EDITRECORD, 197, 218, 55, 14, "", "Edit Record")
  self~createPushButton(IDOK, 275, 218, 55, 14, "DEFAULT", "OK")
  self~createPushButton(IDCANCEL, 335, 218, 55, 14, "", "Cancel")

::class "OodListViews_IDD_PAGE" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 380, 160, "", "", , "MS Shell Dlg", 10)

::method defineDialog                  -- the .rc's controls
  self~createListView(IDC_LISTVIEW, 3, 3, 368, 154, "LIST SHOWSELALWAYS")
