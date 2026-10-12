/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 2009-2014 Rexx Language Association. All rights reserved.    */
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
/* upDown.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with upDown.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "UpDown_IDD_UP_DOWN" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 296, 159, "Up-down Controls", "CENTER", , "Ms Shell Dlg 2", 8)

::method defineDialog                  -- the .rc's controls
  self~createStatic(IDC_ST_DECIMAL, 10, 13, 45, 8, "RIGHT", "Decimal:")
  self~createEdit(IDC_EDIT_DECIMAL, 59, 10, 67, 14, "RIGHT NUMBER", "IDC_EDIT_DECIMAL")
  self~createUpDown(IDC_UD_DECIMAL, 115, 10, 12, 14, "AUTOBUDDY SETBUDDYINT WRAP ALIGNRIGHT")
  self~createEdit(IDC_EDIT_HEXADECIMAL, 184, 10, 52, 14, "RIGHT NUMBER", "IDC_EDIT_HEXADECIMAL")
  self~createUpDown(IDC_UD_HEXADECIMAL, 184, 10, 12, 14, "AUTOBUDDY SETBUDDYINT ALIGNLEFT")
  self~createStatic(IDC_ST_HEXADECIMAL, 242, 13, 44, 8, "", ":Hexadecimal")
  self~createPushButton(IDC_PB_ACCEL, 55, 30, 71, 14, "", "Change Acceleration")
  self~createPushButton(IDC_PB_RANGE, 215, 30, 71, 14, "", "Change Range")
  self~createGroupBox(IDC_STATIC, 10, 52, 126, 96, "", "Client Records")
  self~createStatic(IDC_STATIC, 20, 70, 22, 8, "RIGHT", "Client:")
  self~createEdit(IDC_EDIT_CLIENT, 45, 66, 81, 14, "READONLY", "IDC_EDIT_CLIENT")
  self~createUpDown(IDC_UD_CLIENT, 115, 66, 12, 14, "AUTOBUDDY ALIGNRIGHT")
  self~createStatic(IDC_STATIC, 31, 86, 43, 8, "RIGHT", "Age:")
  self~createEdit(IDC_EDIT_AGE, 77, 84, 49, 14, "READONLY", "IDC_EDIT_AGE")
  self~createStatic(IDC_STATIC, 31, 105, 43, 8, "RIGHT", "Gender:")
  self~createEdit(IDC_EDIT_GENDER, 77, 103, 49, 14, "READONLY", "IDC_EDIT_GENDER")
  self~createStatic(IDC_STATIC, 31, 125, 43, 8, "RIGHT", "Paid to Date:")
  self~createEdit(IDC_EDIT_PAID, 77, 122, 49, 14, "READONLY", "IDC_EDIT_PAID")
  self~createGroupBox(IDC_STATIC, 142, 52, 144, 66, "", "Miscellaneous Operations")
  self~createPushButton(IDC_PB_BASE, 148, 64, 50, 14, "", "Change Base")
  self~createPushButton(IDC_PB_POS, 148, 82, 50, 14, "", "Get Position")
  self~createPushButton(IDC_PB_BUDDY, 148, 100, 50, 14, "", "Get Buddy")
  self~createGroupBox(IDC_STATIC, 205, 64, 72, 48, "", "Up-down")
  self~createRadioButton(IDC_RB_DECIMAL, 219, 76, 40, 10, "", "Decimal", "DECIMAL")
  self~createRadioButton(IDC_RB_HEXADECIMAL, 219, 95, 56, 10, "", "Hexadecimal", "HEXADECIMAL")
  self~createPushButton(IDOK, 178, 135, 50, 14, "DEFAULT", "OK")
  self~createPushButton(IDCANCEL, 236, 135, 50, 14, "", "Cancel")
