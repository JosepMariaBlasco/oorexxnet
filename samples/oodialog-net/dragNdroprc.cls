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
/* dragNdrop.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with dragNdrop.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "DragNdrop_IDD_NFL_DLG" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 526, 345, "NFL Dream Teams West vs East", "CENTER", , "Ms Shell Dlg", 8)

::method defineDialog                  -- the .rc's controls
  self~createStatic(IDC_STATIC, 14, 10, 82, 13, "CENTERIMAGE", "Top NFL Players:")
  self~createListView(IDC_LV_NFL, 10, 25, 242, 275, "REPORT SHOWSELALWAYS SINGLESEL")
  self~createStatic(IDC_STATIC, 278, 10, 103, 13, "CENTERIMAGE", "A Team Players (West):")
  self~createListView(IDC_LV_WEST, 274, 25, 242, 123, "REPORT SHOWSELALWAYS SINGLESEL")
  self~createStatic(IDC_STATIC, 278, 162, 82, 13, "CENTERIMAGE", "B Team Players (East):")
  self~createListView(IDC_LV_EAST, 274, 177, 242, 123, "REPORT SHOWSELALWAYS SINGLESEL")
  self~createStatic(IDC_STATIC, 11, 310, 237, 19, "", "Pick your A team and B team by dragging Top NFL Players to the West or East team.")
  self~createPushButton(IDOK, 411, 321, 50, 14, "DEFAULT", "OK")
  self~createPushButton(IDCANCEL, 466, 321, 50, 14, "", "Cancel")
