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
/* samples\ooDialog\rc\walker.rc       Animation demo                 */
/*--------------------------------------------------------------------*/
/* walker.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with walker.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "Walker_IDD_WALKER" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(7, 19, 347, 255, "Animation Demonstration - Sprites with Open Object Rexx", "", , "MS Shell Dlg", 10)

::method defineDialog                  -- the .rc's controls
  self~createEdit(IDC_EDIT_MOVEX, 45, 23, 25, 12, "", "IDC_EDIT_MOVEX")
  self~createEdit(IDC_EDIT_MOVEY, 118, 23, 25, 12, "", "IDC_EDIT_MOVEY")
  self~createEdit(IDC_EDIT_DELAY, 199, 23, 38, 12, "", "IDC_EDIT_DELAY")
  self~createCheckBox(IDC_CB_SMOOTH, 260, 22, 77, 15, "", "&Smooth corner wrap", "IDC_CB_SMOOTH")
  self~createCheckBox(IDC_CB_GOTCHA, 12, 237, 77, 15, "", "&Quit on 'Got-cha'", "IDC_CB_GOTCHA")
  self~createPushButton(IDC_PB_RESTART, 230, 237, 50, 14, "DISABLED", "Restart")
  self~createPushButton(IDOK, 290, 237, 50, 14, "DEFAULT", "OK")
  self~createPushButton(IDC_DRAW_BUTTON, 3, 62, 341, 164, "OWNERDRAW", "Button1")
  self~createStatic(-1, 1, 58, 345, 170, "FRAME", "")
  self~createStatic(-1, 12, 25, 30, 9, "", "Move &X:")
  self~createStatic(-1, 87, 25, 28, 9, "", "Move &Y:")
  self~createStatic(-1, 172, 24, 24, 10, "", "&Delay:")
  self~createGroupBox(-1, 1, 6, 345, 40, "", "Move sequence")
