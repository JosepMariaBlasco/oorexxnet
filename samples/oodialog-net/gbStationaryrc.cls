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
/* gbStationary.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with gbStationary.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "GbStationary_IDD_RESIZABLE" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 335, 301, "Resizable Dialog", "CENTER SIZEBOX", , "Ms Shell Dlg", 8)

::method defineDialog                  -- the .rc's controls
  self~createListView(IDC_LV_MAIN, 10, 10, 259, 170, "ICON")
  self~createPushButton(IDC_PB_TEST, 275, 95, 50, 14, "", "Test")
  self~createGroupBox(IDC_GB_TEST, 13, 186, 289, 66, "", "Group Box Stationary")
  self~createStatic(IDC_ST_NAMES, 26, 206, 24, 10, "", "Names:")
  self~createEdit(IDC_EDIT_NAMES, 55, 203, 95, 14, "", "IDC_EDIT_NAMES")
  self~createStatic(IDC_ST_LABELS, 168, 206, 24, 10, "", "Labels:")
  self~createEdit(IDC_EDIT_LABELS, 196, 203, 95, 14, "", "IDC_EDIT_LABELS")
  self~createStatic(IDC_ST_PLACES, 25, 228, 24, 10, "", "Places:")
  self~createEdit(IDC_EDIT_PLACES, 55, 225, 95, 14, "", "IDC_EDIT_PLACES")
  self~createPushButton(IDOK, 143, 257, 50, 14, "DEFAULT", "OK")
  self~createPushButton(IDCANCEL, 143, 277, 50, 14, "", "Cancel")
