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
/* ticketWizard.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with ticketWizard.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "TicketWizard_30" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(4, 12, 196, 143, "", "", , "System", 8)

::method defineDialog                  -- the .rc's controls
  self~createListBox(31, 6, 20, 93, 105, "MULTI", "MOVIELIST")
  self~createEdit(32, 109, 23, 84, 12, "", "PRODUCED")
  self~createEdit(33, 109, 53, 84, 12, "", "STAR")
  self~createEdit(34, 109, 83, 84, 12, "", "DIRECTOR")
  self~createComboBox(35, 109, 113, 84, 33, "LIST", "WITH")
  self~createGroupBox(-1, 3, 9, 99, 118, "", "The upcoming movies")
  self~createStatic(-1, 109, 10, 60, 8, "", "Produced by:")
  self~createStatic(-1, 109, 40, 60, 8, "", "Starring:")
  self~createStatic(-1, 109, 70, 83, 8, "", "Director:")
  self~createStatic(-1, 109, 100, 60, 8, "", "with:")

::class "TicketWizard_IDD_FONT_PICKER" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 208, 95, "Font Selection", "CENTER", , "Ms Shell Dlg 2", 8)

::method defineDialog                  -- the .rc's controls
  self~createGroupBox(IDC_STATIC, 7, 7, 194, 62, "", "Select a font for the upcoming example program")
  self~createStatic(IDC_STATIC, 13, 20, 80, 8, "CENTER", "Font Name:")
  self~createStatic(IDC_STATIC, 116, 20, 80, 8, "CENTER", "Font Size:")
  self~createComboBox(IDC_COMBO_NAME, 13, 33, 80, 40, "LIST SORT", "IDC_COMBO_NAME")
  self~createComboBox(IDC_COMBO_SIZE, 116, 33, 80, 40, "LIST", "IDC_COMBO_SIZE")
  self~createPushButton(IDOK, 96, 74, 50, 14, "DEFAULT", "OK")
  self~createPushButton(IDCANCEL, 151, 74, 50, 14, "", "Cancel")
