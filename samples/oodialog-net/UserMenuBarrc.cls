/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 2011-2014 Rexx Language Association. All rights reserved.    */
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
/* UserMenuBar.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with UserMenuBar.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "UserMenuBar_IDD_ABOUT_DIALOG" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 231, 105, "About User Menu Bar Example", "CENTER", , "Ms Shell Dlg", 8)

::method defineDialog                  -- the .rc's controls
  self~createStatic(IDC_ST_BITMAP, 16, 7, 102, 71, "", "")
  self~createStatic(IDC_ST_ABOUT, 141, 10, 76, 56, "CENTER", "An example of using a menu bar in ooDialog.")
  self~createStatic(IDC_STATIC, 16, 83, 107, 15, "", "ooDialog an ooRexx Extenstion")
  self~createPushButton(IDOK, 170, 84, 50, 14, "DEFAULT", "OK")

::class "UserMenuBar_IDD_ACCEL_DIALOG" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 227, 163, "Set Acceleration", "CENTER", , "Ms Shell Dlg", 8)

::method defineDialog                  -- the .rc's controls
  self~createStatic(IDC_STATIC, 9, 9, 224, 8, "CENTER", "Example: After 1 second(s) accelerate 2x.")
  self~createStatic(IDC_STATIC, 15, 38, 16, 8, "", "After")
  self~createEdit(IDC_EDIT_ACCEL_SECONDS0, 36, 35, 29, 14, "RIGHT", "IDC_EDIT_ACCEL_SECONDS0")
  self~createUpDown(IDC_UPD_ACCEL_SECONDS0, 53, 35, 12, 14, "AUTOBUDDY SETBUDDYINT ALIGNRIGHT")
  self~createStatic(IDC_STATIC, 73, 38, 67, 8, "", "second(s) accelerate")
  self~createEdit(IDC_EDIT_ACCEL0, 145, 36, 29, 14, "RIGHT", "IDC_EDIT_ACCEL0")
  self~createUpDown(IDC_UPD_ACCEL0, 163, 36, 12, 14, "AUTOBUDDY SETBUDDYINT ALIGNRIGHT")
  self~createStatic(IDC_STATIC, 178, 38, 8, 8, "", "X.")
  self~createStatic(IDC_STATIC, 15, 63, 16, 8, "", "After")
  self~createEdit(IDC_EDIT_ACCEL_SECONDS1, 36, 60, 29, 14, "RIGHT", "IDC_EDIT_ACCEL_SECONDS1")
  self~createUpDown(IDC_UPD_ACCEL_SECONDS1, 53, 60, 12, 14, "AUTOBUDDY SETBUDDYINT ALIGNRIGHT")
  self~createStatic(IDC_STATIC, 73, 63, 67, 8, "", "second(s) accelerate")
  self~createEdit(IDC_EDIT_ACCEL1, 145, 61, 29, 14, "RIGHT", "IDC_EDIT_ACCEL1")
  self~createUpDown(IDC_UPD_ACCEL1, 163, 61, 12, 14, "AUTOBUDDY SETBUDDYINT ALIGNRIGHT")
  self~createStatic(IDC_STATIC, 178, 63, 8, 8, "", "X.")
  self~createStatic(IDC_STATIC, 15, 89, 16, 8, "", "After")
  self~createEdit(IDC_EDIT_ACCEL_SECONDS2, 36, 86, 29, 14, "RIGHT", "IDC_EDIT_ACCEL_SECONDS2")
  self~createUpDown(IDC_UPD_ACCEL_SECONDS2, 53, 86, 12, 14, "AUTOBUDDY SETBUDDYINT ALIGNRIGHT")
  self~createStatic(IDC_STATIC, 73, 89, 67, 8, "", "second(s) accelerate")
  self~createEdit(IDC_EDIT_ACCEL2, 145, 87, 29, 14, "RIGHT", "IDC_EDIT_ACCEL2")
  self~createUpDown(IDC_UPD_ACCEL2, 163, 87, 12, 14, "AUTOBUDDY SETBUDDYINT ALIGNRIGHT")
  self~createStatic(IDC_STATIC, 178, 117, 8, 8, "", "X.")
  self~createStatic(IDC_STATIC, 15, 117, 16, 8, "", "After")
  self~createEdit(IDC_EDIT_ACCEL_SECONDS3, 36, 114, 29, 14, "RIGHT", "IDC_EDIT_ACCEL_SECONDS3")
  self~createUpDown(IDC_UPD_ACCEL_SECONDS3, 53, 114, 12, 14, "AUTOBUDDY SETBUDDYINT ALIGNRIGHT")
  self~createStatic(IDC_STATIC, 73, 117, 67, 8, "", "second(s) accelerate")
  self~createEdit(IDC_EDIT_ACCEL3, 145, 115, 29, 14, "RIGHT", "IDC_EDIT_ACCEL3")
  self~createUpDown(IDC_UPD_ACCEL3, 163, 115, 12, 14, "AUTOBUDDY SETBUDDYINT ALIGNRIGHT")
  self~createStatic(IDC_STATIC, 178, 89, 8, 8, "", "X.")
  self~createPushButton(IDOK, 115, 142, 50, 14, "DEFAULT", "OK")
  self~createPushButton(IDCANCEL, 170, 142, 50, 14, "", "Cancel")

::class "UserMenuBar_IDD_MAIN_DIALOG" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 223, 150, "User Menu Bar Example", "CENTER", , "Ms Shell Dlg", 8)

::method defineDialog                  -- the .rc's controls
  self~createStatic(IDC_ST_EDIT, 10, 32, 40, 12, "RIGHT", "Enter text:")
  self~createEdit(IDC_EDIT, 52, 30, 160, 12, "", "IDC_EDIT")
  self~createStatic(IDC_ST_UPD, 10, 63, 40, 12, "RIGHT", "Spin Me:")
  self~createEdit(IDC_EDIT_BUDDY, 52, 60, 65, 14, "RIGHT NUMBER", "IDC_EDIT_BUDDY")
  self~createUpDown(IDC_UPD, 257, 66, 12, 16, "AUTOBUDDY SETBUDDYINT WRAP ALIGNRIGHT")
  self~createPushButton(IDOK, 107, 115, 50, 14, "DEFAULT", "OK")
  self~createPushButton(IDCANCEL, 162, 115, 50, 14, "", "Cancel")

::class "UserMenuBar_IDD_INSERT_DIALOG" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 283, 149, "Insert Text", "CENTER", , "Ms Shell Dlg", 8)

::method defineDialog                  -- the .rc's controls
  self~createPushButton(IDOK, 171, 128, 50, 14, "DEFAULT", "OK")
  self~createPushButton(IDCANCEL, 226, 128, 50, 14, "", "Cancel")
  self~createStatic(IDC_STATIC, 7, 11, 269, 8, "CENTER", "Select the Text to Insert")
  self~createRadioButton(IDC_RB_WICKED, 11, 33, 141, 8, "", "The wicked flee when none pursueth ...", "THEWICKEDFLEEWHENNONEPURSUETH")
  self~createRadioButton(IDC_RB_LOTUS, 11, 53, 122, 8, "", "Lotus 123 had its ups and downs.", "LOTUS123HADITSUPSANDDOWNS")
  self~createRadioButton(IDC_RB_IDES, 11, 74, 186, 8, "", "Ides of March - name of March 15 in Roman calendar.", "IDESOFMARCHNAMEOFMARCH15INROMANCALENDAR")
  self~createRadioButton(IDC_RB_TITANIC, 11, 95, 226, 8, "", "472 lifeboat seats not used when 1,503 people died on the Titanic.", "IDC_RB_TITANIC")

::class "UserMenuBar_IDD_POSITION_DIALOG" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 186, 95, "Set New Position", "CENTER", , "Ms Shell Dlg", 8)

::method defineDialog                  -- the .rc's controls
  self~createPushButton(IDOK, 74, 74, 50, 14, "DEFAULT", "OK")
  self~createPushButton(IDCANCEL, 129, 74, 50, 14, "", "Cancel")
  self~createStatic(IDC_STATIC, 9, 11, 170, 8, "CENTER", "Pick a new position for the up-down control.")
  self~createStatic(IDC_STATIC, 11, 41, 44, 8, "", "New Position:")
  self~createEdit(IDC_EDIT_POSITION, 56, 38, 68, 14, "RIGHT", "IDC_EDIT_POSITION")
  self~createUpDown(IDC_UPD_POSITION, 112, 38, 12, 14, "AUTOBUDDY SETBUDDYINT ALIGNRIGHT")

::class "UserMenuBar_IDD_RANGE_DIALOG" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 203, 164, "Set UpDown Range", "CENTER", , "Ms Shell Dlg", 8)

::method defineDialog                  -- the .rc's controls
  self~createStatic(IDC_STATIC, 11, 9, 185, 13, "CENTER", "Set the start and end values for the range.")
  self~createStatic(IDC_ST_EXPLANATION, 11, 36, 180, 35, "", "The complete possible range for an UpDown control is -2147,483,648 to 2,147,483,647.  The start value does not have to be lower than the end value.  5 to -5 is a valid range.")
  self~createStatic(IDC_STATIC, 8, 85, 41, 8, "RIGHT", "Start value:")
  self~createEdit(IDC_EDIT_LOW, 51, 84, 70, 12, "", "IDC_EDIT_LOW")
  self~createUpDown(IDC_UPD_LOW, 109, 84, 12, 12, "AUTOBUDDY SETBUDDYINT ALIGNRIGHT")
  self~createStatic(IDC_STATIC, 8, 117, 41, 8, "RIGHT", "End value:")
  self~createEdit(IDC_EDIT_HIGH, 51, 116, 70, 12, "", "IDC_EDIT_HIGH")
  self~createUpDown(IDC_UPD_HIGH, 109, 116, 12, 12, "AUTOBUDDY SETBUDDYINT ALIGNRIGHT")
  self~createPushButton(IDOK, 91, 143, 50, 14, "DEFAULT", "OK")
  self~createPushButton(IDCANCEL, 146, 143, 50, 14, "", "Cancel")

::class "UserMenuBar_IDD_SELECT_DIALOG" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 277, 122, "Select Text", "CENTER", , "Ms Shell Dlg", 8)

::method defineDialog                  -- the .rc's controls
  self~createGroupBox(IDC_STATIC, 7, 10, 261, 34, "", "The current text in the edit control available for selection is:")
  self~createPushButton(IDOK, 165, 101, 50, 14, "DEFAULT", "OK")
  self~createPushButton(IDCANCEL, 220, 101, 50, 14, "", "Cancel")
  self~createStatic(IDC_ST_CURRENT_TEXT, 11, 26, 256, 10, "ELLIPSIS", "Static")
  self~createStatic(IDC_STATIC, 11, 58, 86, 8, "", "Selection start position")
  self~createStatic(IDC_STATIC, 120, 58, 70, 8, "", "Selection end position")
  self~createEdit(IDC_EDIT_START, 11, 72, 40, 14, "RIGHT NUMBER", "IDC_EDIT_START")
  self~createUpDown(IDC_UPD_START, 39, 72, 12, 14, "AUTOBUDDY SETBUDDYINT WRAP ALIGNRIGHT")
  self~createEdit(IDC_EDIT_END, 120, 72, 40, 14, "RIGHT NUMBER", "IDC_EDIT_END")
  self~createUpDown(IDC_UPD_END, 148, 72, 12, 14, "AUTOBUDDY SETBUDDYINT WRAP ALIGNRIGHT")
