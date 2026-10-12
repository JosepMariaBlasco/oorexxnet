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
/* oodpbar.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with oodpbar.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "Oodpbar_IDD_ONE" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(13, 25, 280, 180, "Progress Bars", "", , "MS Shell Dlg", 10)

::method defineDialog                  -- the .rc's controls
  self~createProgressBar(IDC_PBAR_A, 19, 22, 13, 130, "VERTICAL")
  self~createProgressBar(IDC_PBAR_B, 59, 22, 13, 130, "VERTICAL SMOOTH")
  self~createProgressBar(IDC_PBAR_C, 99, 22, 13, 130, "VERTICAL")
  self~createProgressBar(IDC_PBAR_D, 139, 22, 13, 130, "VERTICAL SMOOTH")
  self~createProgressBar(IDC_PBAR_E, 179, 22, 13, 130, "VERTICAL")
  self~createPushButton(IDOK, 223, 13, 50, 14, "DEFAULT", "Step")
  self~createPushButton(IDCANCEL, 223, 31, 50, 14, "", "Cancel")
  self~createPushButton(IDHELP, 223, 53, 50, 14, "", "Help")
  self~createStatic(11, 14, 160, 18, 8, "", "0")
  self~createStatic(21, 54, 160, 18, 8, "", "0")
  self~createStatic(31, 94, 160, 18, 8, "", "0")
  self~createStatic(41, 136, 160, 18, 8, "", "0")
  self~createStatic(51, 175, 160, 18, 8, "", "0")
  self~createStatic(-1, 14, 10, 22, 8, "", "100")
  self~createStatic(-1, 54, 10, 26, 8, "", "100")
  self~createStatic(-1, 94, 10, 26, 8, "", "100")
  self~createStatic(-1, 135, 10, 26, 8, "", "100")
  self~createStatic(-1, 175, 10, 26, 8, "", "100")
