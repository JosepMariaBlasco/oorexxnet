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
/* addManyRows.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with addManyRows.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "AddManyRows_IDD_ADD_ROWS" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 411, 238, "Large Item Count List View", "CENTER", , "Ms Shell Dlg", 8)

::method defineDialog                  -- the .rc's controls
  self~createListView(IDC_LV, 10, 10, 391, 153, "REPORT SHOWSELALWAYS")
  self~createPushButton(IDC_PB_SORT_REXX, 10, 214, 62, 14, "", "Rexx Sort")
  self~createPushButton(IDC_PB_SORT_INTERN, 10, 195, 62, 14, "", "Internal Sort")
  self~createGroupBox(IDC_GB_TIMES, 77, 168, 269, 60, "", "Time in seconds (2000 rows):")
  self~createStatic(IDC_ST_CREATE, 86, 185, 107, 8, "", "Create full rows:")
  self~createStatic(IDC_ST_INSERT, 86, 207, 107, 8, "", "Insert full rows:")
  self~createStatic(IDC_ST_INTERNAL, 226, 185, 107, 8, "", "Internal sort:")
  self~createStatic(IDC_ST_REXXSORT, 226, 207, 107, 8, "", "Rexx sort:")
  self~createPushButton(IDOK, 351, 214, 50, 14, "DEFAULT", "OK")

::class "AddManyRows_IDD_INTRO" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 241, 130, "Progress Bar Example - Set Up", "CENTER", , "Ms Shell Dlg", 8)

::method defineDialog                  -- the .rc's controls
  self~createStatic(IDC_STATIC, 12, 10, 209, 19, "", "The upcoming example creates a list-view with a large number of items.  Select the number of items for the list-view")
  self~createGroupBox(IDC_STATIC, 11, 34, 104, 85, "", "Pre-sets")
  self~createRadioButton(IDC_RB_1000, 21, 49, 35, 10, "", "1,000", "IDC_RB_1000")
  self~createRadioButton(IDC_RB_2000, 74, 49, 35, 10, "", "2,000", "IDC_RB_2000")
  self~createRadioButton(IDC_RB_5000, 21, 73, 35, 10, "", "5,000", "IDC_RB_5000")
  self~createRadioButton(IDC_RB_10000, 74, 73, 35, 10, "", "10,000", "IDC_RB_10000")
  self~createRadioButton(IDC_RB_15000, 21, 98, 35, 10, "", "15,000", "IDC_RB_15000")
  self~createRadioButton(IDC_RB_25000, 74, 98, 35, 10, "", "25,000", "IDC_RB_25000")
  self~createCheckBox(IDC_CK_FREEFORM, 126, 39, 80, 10, "", "Use Free-form", "USEFREEFORM")
  self~createGroupBox(IDC_STATIC, 126, 57, 104, 39, "", "Free-form")
  self~createEdit(IDC_ED_ITEMS, 151, 73, 40, 14, "", "IDC_ED_ITEMS")
  self~createUpDown(IDC_SP_ITEMS, 179, 73, 11, 14, "AUTOBUDDY SETBUDDYINT ALIGNRIGHT")
  self~createPushButton(IDOK, 127, 106, 50, 14, "DEFAULT", "OK")
  self~createPushButton(IDCANCEL, 181, 106, 50, 14, "", "Cancel")

::class "AddManyRows_IDD_SORT_PARAMS" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 295, 162, "Set Up the Sort", "CENTER", , "Ms Shell Dlg", 8)

::method defineDialog                  -- the .rc's controls
  self~createGroupBox(IDC_STATIC, 10, 10, 275, 116, "", "Sort Parameters:")
  self~createGroupBox(IDC_STATIC, 29, 31, 59, 77, "", "Column:")
  self~createRadioButton(IDC_RB_ITEM, 38, 48, 39, 8, "GROUP", "Item", "ITEM")
  self~createRadioButton(IDC_RB_SUBITEM, 38, 67, 39, 8, "", "Subitem", "SUBITEM")
  self~createEdit(IDC_ED_COL, 38, 87, 31, 12, "", "IDC_ED_COL")
  self~createUpDown(IDC_SP_COL, 57, 87, 11, 14, "AUTOBUDDY SETBUDDYINT ALIGNRIGHT")
  self~createGroupBox(IDC_STATIC, 107, 31, 160, 77, "", "")
  self~createRadioButton(IDC_RB_ASCENDING, 124, 48, 48, 8, "", "Ascending", "ASCENDING")
  self~createRadioButton(IDC_RB_DESCENDING, 192, 48, 55, 8, "", "Descending", "DESCENDING")
  self~createRadioButton(IDC_RB_CASE, 124, 67, 60, 8, "GROUP", "Case Sensitive", "CASESENSITIVE")
  self~createRadioButton(IDC_RB_CASELESS, 192, 67, 65, 8, "", "Case Insensitive", "CASEINSENSITIVE")
  self~createPushButton(IDOK, 180, 138, 50, 14, "DEFAULT", "OK")
  self~createPushButton(IDCANCEL, 235, 138, 50, 14, "", "Cancel")
