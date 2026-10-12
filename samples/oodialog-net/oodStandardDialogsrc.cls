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
/* oodStandardDialogs.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with oodStandardDialogs.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "OodStandardDialogs_IDD_STDDLGS" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 413, 201, "User Input Common Dialog Library", "CENTER", , "Ms Shell Dlg", 8)

::method defineDialog                  -- the .rc's controls
  self~createStatic(IDC_STATIC, 77, 10, 258, 37, "", "The ooDialog framework provides a number of easy to use dialogs that obtain user input in a standard way.  These dialogs allow programmers to include simple graphical elements in their Rexx applications and collect user input in a standard way.")
  self~createGroupBox(IDC_STATIC, 11, 58, 392, 107, "", "Select the Common Dialog to Display")
  self~createRadioButton(IDC_RB_CHECKLIST, 25, 79, 90, 10, "", "CheckList Dialog", "IDC_RB_CHECKLIST")
  self~createRadioButton(IDC_RB_INPUTBOX, 159, 79, 90, 10, "", "InputBox Dialog", "IDC_RB_INPUTBOX")
  self~createRadioButton(IDC_RB_INTEGERBOX, 272, 79, 90, 10, "", "Integer Dialog", "IDC_RB_INTEGERBOX")
  self~createRadioButton(IDC_RB_LISTCHOICE, 25, 107, 90, 10, "", "ListChoice Dialog", "IDC_RB_LISTCHOICE")
  self~createRadioButton(IDC_RB_MULTIINPUTBOX, 159, 107, 90, 10, "", "MultiInputBox Dialog", "IDC_RB_MULTIINPUTBOX")
  self~createRadioButton(IDC_RB_MULTILISTCHOICE, 272, 107, 90, 10, "", "MultiListChoice Dialog", "IDC_RB_MULTILISTCHOICE")
  self~createRadioButton(IDC_RB_PASSWORDBOX, 25, 134, 90, 10, "", "PasswordBox Dialog", "IDC_RB_PASSWORDBOX")
  self~createRadioButton(IDC_RB_SINGLESELECTION, 159, 134, 90, 10, "", "SingleSelection Dialog", "IDC_RB_SINGLESELECTION")
  self~createRadioButton(IDC_RB_TIMEDMESSAGE, 272, 134, 90, 10, "", "TimedMessage Dialog", "IDC_RB_TIMEDMESSAGE")
  self~createPushButton(IDOK, 161, 177, 90, 14, "DEFAULT", "Display Selected Dialog")
  self~createPushButton(IDCANCEL, 353, 177, 50, 14, "", "Close")

::class "OodStandardDialogs_IDD_STDRTNS" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 413, 201, "User Input Common Public Routines", "CENTER", , "Ms Shell Dlg", 8)

::method defineDialog                  -- the .rc's controls
  self~createStatic(IDC_STATIC, 10, 10, 393, 18, "", "The ooDialog framework provides a number of easy to use public routines that obtain user input in a standard way.  These routines allow the use of simple graphical elements in Rexx applications that collect user input in a standard way.")
  self~createGroupBox(IDC_STATIC, 11, 33, 392, 139, "", "Select the Common Public Routine to Display")
  self~createRadioButton(IDC_RB_ASKDIALOG_R, 25, 56, 90, 10, "", "AskDialog Routine", "IDC_RB_ASKDIALOG_R")
  self~createRadioButton(IDC_RB_CHECKLIST_R, 159, 56, 90, 10, "", "CheckList Routine", "IDC_RB_CHECKLIST_R")
  self~createRadioButton(IDC_RB_ERRORDIALOG_R, 272, 56, 90, 10, "", "ErrorDialog Routine", "IDC_RB_ERRORDIALOG_R")
  self~createRadioButton(IDC_RB_FILENAMEDIALOG_R, 25, 79, 90, 10, "", "FileNameDialog Routine", "IDC_RB_FILENAMEDIALOG_R")
  self~createRadioButton(IDC_RB_INFODIALOG_R, 159, 79, 90, 10, "", "InfoDialog Routine", "IDC_RB_INFODIALOG_R")
  self~createRadioButton(IDC_RB_INPUTBOX_R, 272, 79, 90, 10, "", "InputBox Routine", "IDC_RB_INPUTBOX_R")
  self~createRadioButton(IDC_RB_INTEGERBOX_R, 25, 103, 90, 10, "", "IntegerBox Routine", "IDC_RB_INTEGERBOX_R")
  self~createRadioButton(IDC_RB_LISTCHOICE_R, 159, 103, 90, 10, "", "ListChoice Routine", "IDC_RB_LISTCHOICE_R")
  self~createRadioButton(IDC_RB_MESSAGEDIALOG_R, 272, 103, 90, 10, "", "MessageDialog Routine", "IDC_RB_MESSAGEDIALOG_R")
  self~createRadioButton(IDC_RB_MULTIINPUTBOX_R, 25, 128, 90, 10, "", "MultiInputBox Routine", "IDC_RB_MULTIINPUTBOX_R")
  self~createRadioButton(IDC_RB_MULTILISTCHOICE_R, 159, 128, 90, 10, "", "MultiListChoice Routine", "IDC_RB_MULTILISTCHOICE_R")
  self~createRadioButton(IDC_RB_PASSWORDBOX_R, 272, 128, 90, 10, "", "PasswordBox Routine", "IDC_RB_PASSWORDBOX_R")
  self~createRadioButton(IDC_RB_SINGLESELECTION_R, 25, 152, 90, 10, "", "SingleSelection Routine", "IDC_RB_SINGLESELECTION_R")
  self~createRadioButton(IDC_RB_TIMEDMESSAGE_R, 159, 152, 90, 10, "", "TimedMessage Routine", "IDC_RB_TIMEDMESSAGE_R")
  self~createPushButton(IDOK, 161, 177, 90, 14, "DEFAULT", "Display Selected Routine")
  self~createPushButton(IDCANCEL, 353, 177, 50, 14, "", "Close")
