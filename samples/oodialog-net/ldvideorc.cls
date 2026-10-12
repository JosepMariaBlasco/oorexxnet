/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 1995, 2004 IBM Corporation. All rights reserved.             */
/* Copyright (c) 2005-2021 Rexx Language Association. All rights reserved.    */
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
/* ldvideo.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with ldvideo.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "Ldvideo_IDD_VIDEO_DLG" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(67, 32, 288, 251, "Video Archive", "", , "MS Shell Dlg", 10)

::method defineDialog                  -- the .rc's controls
  self~createEdit(IDC_EDIT_TAPE_NO, 64, 17, 42, 13, "", "IDC_EDIT_TAPE_NO")
  self~createPushButton(3001, 110, 16, 37, 15, "", "&Search")
  self~createEdit(IDC_EDIT_TAPE_LABEL, 64, 37, 85, 13, "", "IDC_EDIT_TAPE_LABEL")
  self~createEdit(IDC_EDIT_FILM1, 80, 72, 175, 13, "", "IDC_EDIT_FILM1")
  self~createEdit(IDC_EDIT_FILM2, 80, 92, 175, 13, "", "IDC_EDIT_FILM2")
  self~createEdit(IDC_EDIT_FILM3, 80, 111, 175, 13, "", "IDC_EDIT_FILM3")
  self~createEdit(IDC_EDIT_FILM4, 80, 130, 175, 13, "", "IDC_EDIT_FILM4")
  self~createComboBox(IDC_CB_LOCATION, 80, 168, 119, 43, "SORT", "IDC_CB_LOCATION")
  self~createListBox(IDC_LB_LENT_TO, 80, 188, 119, 49, "SORT PARTIAL", "IDC_LB_LENT_TO")
  self~createCheckBox(IDC_CK_LONGPLAY, 172, 15, 45, 10, "", "Long&play", "IDC_CK_LONGPLAY")
  self~createCheckBox(IDC_CK_HIFI, 172, 28, 53, 10, "", "&Hifi - quality", "IDC_CK_HIFI")
  self~createCheckBox(IDC_CK_WRITEPROTECT, 172, 41, 55, 10, "", "&Writeprotect", "IDC_CK_WRITEPROTECT")
  self~createRadioButton(IDC_RB_C120, 232, 15, 31, 10, "GROUP", "C120", "IDC_RB_C120")
  self~createRadioButton(IDC_RB_C180, 232, 27, 31, 10, "", "C180", "IDC_RB_C180")
  self~createRadioButton(IDC_RB_C240, 232, 40, 31, 10, "", "C240", "IDC_RB_C240")
  self~createPushButton(1, 217, 166, 50, 14, "DEFAULT", "OK")
  self~createPushButton(2, 217, 188, 50, 14, "", "Cancel")
  self~createStatic(2008, 18, 18, 43, 11, "", "Tape&number")
  self~createStatic(2006, 18, 38, 38, 11, "", "Tape label")
  self~createStatic(2001, 36, 74, 23, 11, "", "Film &1")
  self~createStatic(2002, 36, 93, 22, 11, "", "Film 2")
  self~createStatic(2003, 36, 112, 23, 11, "", "Film 3")
  self~createStatic(2004, 36, 131, 24, 11, "", "Film 4")
  self~createStatic(2005, 36, 169, 32, 11, "", "&Location")
  self~createStatic(2007, 36, 188, 26, 11, "", "Lent to")
  self~createGroupBox(-1, 12, 4, 145, 51, "", "Specification")
  self~createGroupBox(-1, 12, 61, 261, 89, "", "Titles")
  self~createGroupBox(-1, 12, 156, 261, 86, "", "Location and Possession")
  self~createGroupBox(-1, 165, 3, 105, 51, "", "Tape&information")
