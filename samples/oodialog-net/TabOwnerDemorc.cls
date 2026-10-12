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
/* TabOwnerDemo.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with TabOwnerDemo.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "TabOwnerDemo_IDD_BLANK_DLG" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(6, 15, 300, 250, "Blank Dialog", "", , "Arial", 19)

::method defineDialog                  -- the .rc's controls
  self~createPushButton(IDC_PB_PREVIOUS, 5, 10, 60, 14, "", "Previous Control")
  self~createPushButton(IDC_PB_NEXT, 75, 10, 60, 14, "", "Next Control")

::class "TabOwnerDemo_IDD_LISTVIEW_DLG" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(6, 15, 300, 250, "List View Control", "", , "Arial", 9)

::method defineDialog                  -- the .rc's controls
  self~createListView(IDC_LV_MAIN, 7, 7, 286, 236, "REPORT")

::class "TabOwnerDemo_IDD_PROGRESSBAR_DLG" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(6, 15, 300, 250, "Progress Bar Control", "", , "Arial", 9)

::method defineDialog                  -- the .rc's controls
  self~createProgressBar(IDC_PBAR_PROCESSA, 37, 27, 13, 199, "VERTICAL")
  self~createProgressBar(IDC_PBAR_PROCESSB, 86, 27, 13, 199, "VERTICAL")
  self~createProgressBar(IDC_PBAR_PROCESSC, 135, 27, 13, 199, "VERTICAL")
  self~createProgressBar(IDC_PBAR_PROCESSD, 182, 27, 13, 199, "VERTICAL SMOOTH")
  self~createProgressBar(IDC_PBAR_PROCESSE, 236, 27, 13, 199, "VERTICAL SMOOTH")
  self~createStatic(IDC_ST_PERCENTA, 34, 229, 21, 8, "", "100%")
  self~createStatic(IDC_ST_PERCENTB, 83, 229, 21, 8, "", "100%")
  self~createStatic(IDC_ST_PERCENTC, 132, 229, 21, 8, "", "100%")
  self~createStatic(IDC_ST_PERCENTD, 180, 229, 21, 8, "", "100%")
  self~createStatic(IDC_ST_PERCENTE, 234, 229, 21, 8, "", "100%")
  self~createStatic(-1, 25, 12, 36, 8, "", "Process A")
  self~createStatic(-1, 74, 12, 36, 8, "", "Process B")
  self~createStatic(-1, 123, 12, 36, 8, "", "Process C")
  self~createStatic(-1, 170, 12, 36, 8, "", "Process D")
  self~createStatic(-1, 224, 12, 36, 8, "", "Process E")

::class "TabOwnerDemo_IDD_TAB_DLG" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(6, 15, 300, 250, "Tab Control", "", , "Arial", 9)

::method defineDialog                  -- the .rc's controls
  self~createTab(IDC_TAB_MAIN, 9, 19, 282, 215, "")
  self~createPushButton(IDC_PB_OWNERDRAW, 17, 63, 267, 162, "OWNERDRAW", "")

::class "TabOwnerDemo_IDD_TRACKBAR_DLG" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(6, 15, 300, 250, "Track Bar Control", "", , "Arial", 9)

::method defineDialog                  -- the .rc's controls
  self~createTrackBar(IDC_TB_HORZ_BOTTOM, 10, 30, 119, 20, "")
  self~createStatic(IDC_ST_HORZ_BOTTOM, 41, 56, 60, 27, "", "Text")
  self~createTrackBar(IDC_TB_HORZ_TOP, 10, 97, 119, 20, "TOP")
  self~createStatic(IDC_ST_HORZ_TOP, 41, 128, 60, 27, "", "Text")
  self~createTrackBar(IDC_TB_HORZ_BOTH, 10, 168, 119, 32, "BOTH ENABLESELRANGE")
  self~createStatic(IDC_ST_HORZ_BOTH, 41, 203, 60, 30, "", "Text")
  self~createTrackBar(IDC_TB_VERT_RIGHT, 176, 33, 19, 192, "VERTICAL ENABLESELRANGE")
  self~createStatic(IDC_ST_VERT_RIGHT, 177, 17, 22, 8, "", "Text")
  self~createTrackBar(IDC_TB_VERT_LEFT, 212, 33, 19, 192, "VERTICAL TOP")
  self~createStatic(IDC_ST_VERT_LEFT, 216, 17, 27, 8, "", "Text")
  self~createTrackBar(IDC_TB_VERT_BOTH, 257, 33, 27, 192, "VERTICAL BOTH")
  self~createStatic(IDC_ST_VERT_BOTH, 261, 17, 21, 8, "", "Text")
  self~createStatic(-1, 7, 7, 136, 236, "FRAME", "")
  self~createStatic(-1, 163, 7, 130, 236, "FRAME", "")

::class "TabOwnerDemo_IDD_TREEVIEW_DLG" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(6, 15, 300, 250, "Tree View Control", "", , "Arial", 9)

::method defineDialog                  -- the .rc's controls
  self~createTreeView(IDC_TV_MAIN, 7, 7, 286, 236, "HASLINES HASBUTTONS LINESATROOT")
