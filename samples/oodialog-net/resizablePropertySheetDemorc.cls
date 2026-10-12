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
/* resizablePropertySheetDemo.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with resizablePropertySheetDemo.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "ResizablePropertySheetDemo_IDD_LISTVIEW_DLG" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(6, 15, 300, 250, "List View Control", "", , "Arial", 9)

::method defineDialog                  -- the .rc's controls
  self~createListView(IDC_LV_MAIN, 7, 7, 286, 236, "REPORT")

::class "ResizablePropertySheetDemo_IDD_NEWCONTROLS_DLG" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 325, 300, "Example using ControlDialog objects", "CENTER", , "Arial", 9)

::method defineDialog                  -- the .rc's controls
  self~createTab(IDC_TAB, 10, 5, 305, 265, "")
  self~createPushButton(IDC_PB_PREVIOUS, 10, 278, 60, 14, "", "Previous Control")
  self~createPushButton(IDC_PB_NEXT, 80, 278, 60, 14, "", "Next Control")
  self~createPushButton(IDOK, 185, 278, 60, 14, "DEFAULT", "Ok")
  self~createPushButton(IDCANCEL, 255, 278, 60, 14, "", "Cancel")

::class "ResizablePropertySheetDemo_IDD_PROGRESSBAR_DLG" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(6, 15, 300, 250, "Progress Bar Control", "", , "Arial", 9)

::method defineDialog                  -- the .rc's controls
  self~createStatic(IDC_ST_PROCESSA, 26, 12, 35, 8, "CENTER", "Process A")
  self~createProgressBar(IDC_PBAR_PROCESSA, 36, 27, 13, 199, "VERTICAL")
  self~createStatic(IDC_ST_PERCENTA, 32, 229, 21, 8, "CENTER", "100%")
  self~createStatic(IDC_ST_PROCESSB, 79, 12, 35, 8, "CENTER", "Process B")
  self~createProgressBar(IDC_PBAR_PROCESSB, 89, 27, 13, 199, "VERTICAL")
  self~createStatic(IDC_ST_PERCENTB, 85, 229, 21, 8, "CENTER", "100%")
  self~createStatic(IDC_ST_PROCESSC, 132, 12, 35, 8, "CENTER", "Process C")
  self~createProgressBar(IDC_PBAR_PROCESSC, 142, 27, 13, 199, "VERTICAL")
  self~createStatic(IDC_ST_PERCENTC, 139, 229, 21, 8, "CENTER", "100%")
  self~createStatic(IDC_ST_PROCESSD, 184, 12, 35, 8, "CENTER", "Process D")
  self~createProgressBar(IDC_PBAR_PROCESSD, 195, 27, 13, 199, "VERTICAL SMOOTH")
  self~createStatic(IDC_ST_PERCENTD, 192, 229, 21, 8, "CENTER", "100%")
  self~createStatic(IDC_ST_PROCESSE, 236, 12, 35, 8, "CENTER", "Process E")
  self~createProgressBar(IDC_PBAR_PROCESSE, 248, 27, 13, 199, "VERTICAL SMOOTH")
  self~createStatic(IDC_ST_PERCENTE, 244, 229, 21, 8, "CENTER", "100%")

::class "ResizablePropertySheetDemo_IDD_TAB_DLG" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(6, 15, 300, 250, "Tab Control", "", , "Arial", 9)

::method defineDialog                  -- the .rc's controls
  self~createTab(IDC_TAB_MAIN, 5, 5, 290, 240, "")
  self~createPushButton(IDC_PB_OWNERDRAW, 17, 63, 267, 162, "OWNERDRAW", "")

::class "ResizablePropertySheetDemo_IDD_TRACKBAR_DLG" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(6, 15, 300, 250, "Track Bar Control", "", , "Arial", 9)

::method defineDialog                  -- the .rc's controls
  self~createStatic(IDC_ST_FRAME_LEFT, 7, 7, 136, 236, "FRAME", "")
  self~createTrackBar(IDC_TB_HORZ_BOTTOM, 10, 30, 119, 20, "")
  self~createStatic(IDC_ST_HORZ_BOTTOM, 41, 56, 60, 27, "", "Text")
  self~createTrackBar(IDC_TB_HORZ_TOP, 10, 97, 119, 20, "TOP")
  self~createStatic(IDC_ST_HORZ_TOP, 41, 128, 60, 27, "", "Text")
  self~createTrackBar(IDC_TB_HORZ_BOTH, 10, 168, 119, 32, "BOTH ENABLESELRANGE")
  self~createStatic(IDC_ST_HORZ_BOTH, 41, 203, 60, 30, "", "Text")
  self~createStatic(IDC_ST_FRAME_RIGHT, 163, 7, 130, 236, "FRAME", "")
  self~createTrackBar(IDC_TB_VERT_RIGHT, 176, 33, 19, 192, "VERTICAL ENABLESELRANGE")
  self~createStatic(IDC_ST_VERT_RIGHT, 177, 17, 22, 8, "", "Text")
  self~createTrackBar(IDC_TB_VERT_LEFT, 212, 33, 19, 192, "VERTICAL TOP")
  self~createStatic(IDC_ST_VERT_LEFT, 216, 17, 27, 8, "", "Text")
  self~createTrackBar(IDC_TB_VERT_BOTH, 257, 33, 27, 192, "VERTICAL BOTH")
  self~createStatic(IDC_ST_VERT_BOTH, 261, 17, 21, 8, "", "Text")

::class "ResizablePropertySheetDemo_IDD_TREEVIEW_DLG" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(6, 15, 300, 250, "Tree View Control", "", , "Arial", 9)

::method defineDialog                  -- the .rc's controls
  self~createTreeView(IDC_TV_MAIN, 7, 7, 286, 236, "HASLINES HASBUTTONS LINESATROOT")
