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
/* employe7.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with employe7.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "Employe7_IDD_EMPLOYEE_LIST" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(6, 15, 278, 117, "Acme Software - List of Employees", "CENTER", , "Courier New", 12)

::method defineDialog                  -- the .rc's controls
  self~createListBox(IDC_LB_EMPLOYEES_LIST, 10, 22, 258, 66, "USETAB", "IDC_LB_EMPLOYEES_LIST")
  self~createStatic(-1, 10, 7, 26, 8, "", "Name")
  self~createStatic(-1, 101, 7, 60, 8, "", "Profession")
  self~createStatic(-1, 201, 7, 60, 8, "", "City")
  self~createPushButton(IDOK, 218, 93, 50, 14, "DEFAULT", "OK")

::class "Employe7_IDD_EMPLOYEES7" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(6, 15, 235, 184, "Acme Software - Employees Version 7", "CENTER", , "Tahoma", 10)

::method defineDialog                  -- the .rc's controls
  self~createGroupBox(IDC_GB2, 165, 10, 60, 44, "", "Mode")
  self~createRadioButton(IDC_RB_ADD, 174, 20, 46, 12, "", "&Adding", "ADDING")
  self~createRadioButton(IDC_RB_BROWSE, 174, 37, 46, 12, "", "&Browsing", "BROWSING")
  self~createStatic(-1, 12, 20, 30, 8, "", "Person:")
  self~createEdit(IDC_EDIT_NAME, 40, 20, 120, 12, "", "IDC_EDIT_NAME")
  self~createUpDown(IDC_UPD, 150, 20, 10, 12, "AUTOBUDDY")
  self~createStatic(-1, 12, 37, 16, 8, "", "City:")
  self~createComboBox(IDC_CB_CITY, 40, 37, 120, 56, "LIST", "IDC_CB_CITY")
  self~createStatic(-1, 12, 58, 30, 8, "", "Position:")
  self~createListBox(IDC_LB_POSITION, 10, 68, 150, 82, "SORT", "IDC_LB_POSITION")
  self~createGroupBox(IDC_GB1, 165, 65, 60, 66, "", "Statistics")
  self~createRadioButton(IDC_RB_MALE, 174, 80, 46, 12, "", "&Male", "MALE")
  self~createRadioButton(IDC_RB_FEMALE, 174, 95, 46, 12, "", "&Female", "FEMALE")
  self~createCheckBox(IDC_CHK_MARRIED, 174, 112, 46, 12, "", "Ma&rried", "MARRIED")
  self~createPushButton(IDC_PB_ADD, 165, 135, 60, 14, "", "A&dd")
  self~createPushButton(IDC_PB_PRINT, 10, 160, 45, 14, "", "&Print")
  self~createPushButton(IDC_PB_LIST, 60, 160, 65, 14, "", "&List Employees")
  self~createPushButton(IDOK, 130, 160, 45, 14, "DEFAULT", "D&one")
  self~createPushButton(IDCANCEL, 180, 160, 45, 14, "", "&Cancel")

::class "Employe7_IDM_MENUBAR" subclass NetMenuBar public   -- the .rc's IDM_MENUBAR MENU
::method init
  forward class (super) continue
  p1 = .NetPopupMenu~new
  p1~insertItem(, IDCANCEL, "&Cancel")
  p1~insertItem(, IDOK, "E&xit")
  self~insertPopup(, , p1, "&File")
  p2 = .NetPopupMenu~new
  p2~insertItem(, IDM_ADD, "&Add")
  p2~insertItem(, IDM_PRINT, "&Print")
  p2~insertSeparator
  p2~insertItem(, IDM_LIST, "&List", "GRAYED")
  self~insertPopup(, , p2, "&Employees")
  p3 = .NetPopupMenu~new
  p3~insertSeparator
  p3~insertItem(, IDM_ABOUT, "&About")
  self~insertPopup(, , p3, "&Help")
