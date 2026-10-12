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
/* comboBoxTypes.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with comboBoxTypes.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "ComboBoxTypes_IDD_COMBOBOX_TYPES" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 289, 169, "Combo Box Types", "CENTER", , "Ms Shell Dlg", 8)

::method defineDialog                  -- the .rc's controls
  self~createStatic(IDC_STATIC, 10, 10, 69, 11, "CENTER", "Simple")
  self~createStatic(IDC_STATIC, 110, 10, 69, 11, "CENTER", "Drop-down")
  self~createStatic(IDC_STATIC, 210, 10, 69, 11, "CENTER", "Drop-down list")
  self~createComboBox(IDC_CB_SIMPLE, 12, 29, 69, 71, "SIMPLE", "IDC_CB_SIMPLE")
  self~createComboBox(IDC_CB_DROPDOWN, 110, 29, 69, 71, "", "IDC_CB_DROPDOWN")
  self~createComboBox(IDC_CB_DROPDOWNLIST, 210, 29, 69, 71, "LIST", "IDC_CB_DROPDOWNLIST")
  self~createGroupBox(IDC_GB_SCHEME, 10, 107, 214, 52, "", "Color Scheme")
  self~createRadioButton(IDC_RB_NONE, 17, 123, 100, 8, "", "None (default appearance)", "NONEDEFAULTAPPEARANCE")
  self~createRadioButton(IDC_RB_RAINBOW, 17, 140, 100, 8, "", "Rainbow (Bk and Fg)", "RAINBOWBKANDFG")
  self~createRadioButton(IDC_RB_TEXTONLY, 136, 123, 82, 8, "", "Rainbow (text only)", "RAINBOWTEXTONLY")
  self~createRadioButton(IDC_RB_FIREBRICK, 136, 140, 82, 8, "", "Firebrick Red", "FIREBRICKRED")
  self~createPushButton(IDC_PB_DROP, 229, 107, 50, 14, "", "Drop Down")
  self~createPushButton(IDC_PB_CLOSE, 229, 126, 50, 14, "", "Close Up")
  self~createPushButton(IDOK, 229, 145, 50, 14, "DEFAULT", "Done")
