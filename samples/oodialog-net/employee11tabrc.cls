/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 1995, 2004 IBM Corporation. All rights reserved.             */
/* Copyright (c) 2005-2014 Rexx Language Association. All rights reserved.    */
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
/* employee11tab.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with employee11tab.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "Employee11tab_IDD_EMPLOYEES_ADD" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 227, 160, "Add Employees", "", , "Tahoma", 10)

::method defineDialog                  -- the .rc's controls
  self~createStatic(-1, 12, 20, 30, 8, "", "Person:")
  self~createEdit(IDC_EDIT_NAME_A, 40, 20, 102, 12, "", "IDC_EDIT_NAME_A")
  self~createStatic(-1, 12, 37, 16, 8, "", "City:")
  self~createComboBox(IDC_CB_CITY_A, 40, 37, 102, 56, "LIST", "IDC_CB_CITY_A")
  self~createStatic(-1, 12, 58, 30, 8, "", "Position:")
  self~createListBox(IDC_LB_POSITION_A, 10, 68, 132, 82, "SORT", "IDC_LB_POSITION_A")
  self~createGroupBox(IDC_GB1, 153, 16, 64, 80, "", "Statistics")
  self~createRadioButton(IDC_RB_MALE_A, 161, 27, 40, 12, "", "&Male", "MALE")
  self~createRadioButton(IDC_RB_FEMALE_A, 161, 42, 40, 12, "", "&Female", "FEMALE")
  self~createCheckBox(IDC_CHK_MARRIED_A, 161, 59, 40, 12, "", "Ma&rried", "MARRIED")
  self~createCheckBox(IDC_CHK_FULLTIME_A, 161, 78, 40, 12, "", "Full Time", "FULLTIME")
  self~createPushButton(IDC_PB_ADD_A, 167, 117, 50, 14, "", "Add")
  self~createPushButton(IDC_PB_PRINT_A, 167, 136, 50, 14, "", "Print")

::class "Employee11tab_IDD_EMPLOYEES_BROWSE" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 227, 160, "Browse Employees", "", , "Tahoma", 10)

::method defineDialog                  -- the .rc's controls
  self~createStatic(-1, 12, 20, 30, 8, "", "Person:")
  self~createEdit(IDC_EDIT_NAME_B, 40, 20, 102, 12, "READONLY", "IDC_EDIT_NAME_B")
  self~createUpDown(IDC_UPD, 132, 20, 10, 12, "AUTOBUDDY")
  self~createStatic(-1, 12, 37, 16, 8, "", "City:")
  self~createComboBox(IDC_CB_CITY_B, 40, 37, 102, 56, "LIST", "IDC_CB_CITY_B")
  self~createStatic(-1, 12, 58, 30, 8, "", "Position:")
  self~createListBox(IDC_LB_POSITION_B, 10, 68, 132, 82, "SORT", "IDC_LB_POSITION_B")
  self~createGroupBox(IDC_GB1, 153, 16, 64, 80, "", "Statistics")
  self~createRadioButton(IDC_RB_MALE_B, 161, 27, 40, 12, "", "&Male", "MALE")
  self~createRadioButton(IDC_RB_FEMALE_B, 161, 42, 40, 12, "", "&Female", "FEMALE")
  self~createCheckBox(IDC_CHK_MARRIED_B, 161, 59, 40, 12, "", "Ma&rried", "MARRIED")
  self~createCheckBox(IDC_CHK_FULLTIME_B, 161, 78, 40, 12, "", "Full Time", "FULLTIME")
  self~createPushButton(IDC_PB_PRINT_B, 167, 136, 50, 14, "", "Print")

::class "Employee11tab_IDD_EMPLOYEES_EDIT" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 227, 160, "Edit Employees", "", , "Tahoma", 10)

::method defineDialog                  -- the .rc's controls
  self~createStatic(-1, 12, 20, 30, 8, "", "Person:")
  self~createEdit(IDC_EDIT_NAME_E, 40, 20, 102, 12, "", "IDC_EDIT_NAME_E")
  self~createStatic(-1, 12, 37, 16, 8, "", "City:")
  self~createComboBox(IDC_CB_CITY_E, 40, 37, 102, 56, "LIST", "IDC_CB_CITY_E")
  self~createStatic(-1, 12, 58, 30, 8, "", "Position:")
  self~createListBox(IDC_LB_POSITION_E, 10, 68, 132, 82, "SORT", "IDC_LB_POSITION_E")
  self~createGroupBox(IDC_GB1, 153, 16, 64, 80, "", "Statistics")
  self~createRadioButton(IDC_RB_MALE_E, 161, 27, 40, 12, "", "&Male", "MALE")
  self~createRadioButton(IDC_RB_FEMALE_E, 161, 42, 40, 12, "", "&Female", "FEMALE")
  self~createCheckBox(IDC_CHK_MARRIED_E, 161, 59, 40, 12, "", "Ma&rried", "MARRIED")
  self~createCheckBox(IDC_CHK_FULLTIME_E, 161, 78, 40, 12, "", "Full Time", "FULLTIME")
  self~createPushButton(IDC_PB_RESET_E, 167, 98, 50, 14, "", "Reset")
  self~createPushButton(IDC_PB_SAVE_E, 167, 117, 50, 14, "", "Save")
  self~createPushButton(IDC_PB_PRINT_E, 167, 136, 50, 14, "", "Print")

::class "Employee11tab_IDD_EMPLOYEES_LIST" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 227, 160, "List Employees", "", , "Tahoma", 10)

::method defineDialog                  -- the .rc's controls
  self~createListView(IDC_LV_EMPLOYEES, 10, 10, 207, 140, "REPORT SHOWSELALWAYS SINGLESEL")

::class "Employee11tab_IDM_CONTEXT_MENUBAR" subclass NetMenuBar public   -- the .rc's IDM_CONTEXT_MENUBAR MENU
::method init
  forward class (super) continue
  p1 = .NetPopupMenu~new(IDM_POP_CONTEXT)
  p1~insertItem(, IDM_BROWSE, "&Browse Employees...")
  p1~insertSeparator(, IDM_SEP1)
  p1~insertItem(, IDM_ADD, "&Add Employee...")
  p1~insertItem(, IDM_EDIT, "&Edit Employee...")
  p1~insertSeparator(, IDM_SEP2)
  p1~insertItem(, IDM_DELETE, "&Delete Employee...")
  self~insertPopup(, IDM_POP_CONTEXT, p1, "Context")
