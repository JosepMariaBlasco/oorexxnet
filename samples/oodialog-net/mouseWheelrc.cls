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
/* mouseWheel.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with mouseWheel.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "MouseWheel_IDD_HELP" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 409, 305, "Help for the Mouse Wheel Demonstration", "CENTER", , "Ms Shell Dlg", 8)

::method defineDialog                  -- the .rc's controls
  self~createEdit(IDC_HELP_TEXT, 10, 10, 389, 271, "MULTILINE READONLY VSCROLL", "IDC_HELP_TEXT")
  self~createPushButton(IDOK, 350, 281, 49, 14, "DEFAULT", "Close")

::class "MouseWheel_IDD_MOUSE_DLG" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 485, 303, "Mouse Wheel Demonstration", "CENTER", , "Ms Shell Dlg 2", 8)

::method defineDialog                  -- the .rc's controls
  self~createEdit(IDC_EDIT_DATA, 10, 10, 465, 208, "MULTILINE VSCROLL HSCROLL", "IDC_EDIT_DATA")
  self~createGroupBox(IDC_STATIC, 10, 223, 319, 70, "", "When To Scroll With Mouse Wheel")
  self~createRadioButton(IDC_RB_ANYWHERE, 19, 237, 131, 10, "", "Mouse is anywhere", "IDC_RB_ANYWHERE")
  self~createRadioButton(IDC_RB_DIALOG, 19, 256, 131, 10, "", "Mouse is over dialog", "IDC_RB_DIALOG")
  self~createRadioButton(IDC_RB_ON_EDIT_OK, 19, 275, 131, 10, "", "Mouse over edit controls / Ok button", "IDC_RB_ON_EDIT_OK")
  self~createRadioButton(IDC_RB_FOCUSED_ANYWHERE, 161, 237, 165, 10, "", "Multi-line edit focused / mouse anywhere", "IDC_RB_FOCUSED_ANYWHERE")
  self~createRadioButton(IDC_RB_FOCUSED_DIALOG, 161, 256, 165, 10, "", "Multi-line edit focused / mouse over dialog", "IDC_RB_FOCUSED_DIALOG")
  self~createRadioButton(IDC_RB_FOCUSED_EDIT, 161, 275, 165, 10, "", "Multi-line edit focused / mouse over edit control", "IDC_RB_FOCUSED_EDIT")
  self~createStatic(IDC_STATIC, 340, 233, 33, 14, "CENTERIMAGE", "Command:")
  self~createEdit(IDC_EDIT_COMMAND, 377, 233, 98, 14, "", "IDC_EDIT_COMMAND")
  self~createPushButton(IDOK, 371, 279, 50, 14, "DEFAULT", "OK")
  self~createPushButton(IDHELP, 426, 279, 50, 14, "", "Help")
