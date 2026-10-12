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
/* userStringDTP.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with userStringDTP.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "UserStringDTP_IDD_SYSTEMTIME" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 247, 150, "Adjust System Date & Time", "CENTER", , "Ms Shell Dlg", 8)

::method defineDialog                  -- the .rc's controls
  self~createGroupBox(IDC_STATIC, 11, 10, 226, 101, "", "Change the System Date and / or the Time")
  self~createStatic(IDC_ST_CUR_DATE, 23, 27, 45, 8, "", "Current Date:")
  self~createEdit(IDC_EDIT_CUR_DATE, 71, 25, 48, 14, "READONLY", "IDC_EDIT_CUR_DATE")
  self~createStatic(IDC_ST_CUR_TIME, 23, 46, 45, 8, "", "Current Time:")
  self~createEdit(IDC_EDIT_CUR_TIME, 71, 44, 48, 14, "READONLY", "IDC_EDIT_CUR_TIME")
  self~createStatic(IDC_ST_NEW_DATE, 143, 27, 35, 8, "", "New Date:")
  self~createEdit(IDC_EDIT_NEW_DATE, 181, 25, 48, 14, "READONLY", "IDC_EDIT_NEW_DATE")
  self~createStatic(IDC_ST_NEW_TIME, 143, 46, 35, 8, "", "New Time:")
  self~createEdit(IDC_EDIT_NEW_TIME, 181, 44, 48, 14, "READONLY", "IDC_EDIT_NEW_TIME")
  self~createDateTimePicker(IDC_DTP_SYSTIME, 11, 69, 226, 15, "")
  self~createStatic(IDC_ST_INVALID, 23, 93, 206, 8, "", "Invalid shortcut string: 05/12/3011 08:09:22")
  self~createPushButton(IDOK, 82, 126, 50, 14, "DEFAULT", "OK")
  self~createPushButton(IDCANCEL, 135, 126, 50, 14, "", "Cancel")
  self~createPushButton(IDHELP, 187, 126, 50, 14, "", "Help")

::class "UserStringDTP_IDD_HELP" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 409, 305, "Help for Setting the System Date and Time ", "CENTER", , "Ms Shell Dlg", 8)

::method defineDialog                  -- the .rc's controls
  self~createEdit(IDC_HELP_TEXT, 10, 10, 389, 271, "MULTILINE READONLY VSCROLL", "IDC_HELP_TEXT")
  self~createPushButton(IDOK, 350, 281, 49, 14, "DEFAULT", "Close")
