/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 2012-2014 Rexx Language Association. All rights reserved.    */
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
/* PersonView.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with PersonView.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "PersonView_IDD_DIALOG1" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 179, 166, "Person Record", "CENTER", , "Ms Shell Dlg", 8)

::method defineDialog                  -- the .rc's controls
  self~createPushButton(IDOK, 66, 142, 50, 14, "DEFAULT", "OK")
  self~createPushButton(IDCANCEL, 121, 142, 50, 14, "", "Cancel")
  self~createStatic(IDC_STATIC, 75, 19, 46, 8, "", "Personnel No:")
  self~createEdit(IDC_PERS_NO, 125, 15, 40, 14, "READONLY", "IDC_PERS_NO")
  self~createStatic(IDC_STATIC, 11, 36, 43, 8, "", "Family Name:")
  self~createEdit(IDC_PERS_FAMILYNAME, 10, 45, 85, 14, "", "IDC_PERS_FAMILYNAME")
  self~createEdit(IDC_PERS_FIRSTNAME, 106, 45, 60, 14, "", "IDC_PERS_FIRSTNAME")
  self~createStatic(IDC_STATIC, 107, 37, 36, 8, "", "First Name:")
  self~createStatic(IDC_STATIC, 12, 71, 18, 8, "", "DOB:")
  self~createEdit(IDC_PERS_DOB, 45, 70, 50, 15, "", "IDC_PERS_DOB")
  self~createStatic(IDC_STATIC, 12, 95, 28, 8, "", "Position:")
  self~createStatic(IDC_STATIC, 12, 119, 22, 8, "", "Salary:")
  self~createEdit(IDC_PERS_POSITION, 45, 93, 120, 14, "", "IDC_PERS_POSITION")
  self~createEdit(IDC_PERS_SALARY, 45, 117, 40, 14, "", "IDC_PERS_SALARY")
