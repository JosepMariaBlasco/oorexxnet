/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 2008-2014 Rexx Language Association. All rights reserved.    */
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
/* winSystemDlgs.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with winSystemDlgs.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "WinSystemDlgs_IDD_WINDOW_TREE" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 289, 330, "Window Hierarchy", "CENTER", , "Ms Shell Dlg 2", 8)

::method defineDialog                  -- the .rc's controls
  self~createPushButton(IDOK, 229, 306, 50, 14, "DEFAULT", "OK")
  self~createTreeView(IDC_TREE_WINDOWS, 10, 10, 269, 291, "HASLINES HASBUTTONS LINESATROOT")

::class "WinSystemDlgs_IDD_MENU_TREE" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 289, 330, "Menu Hierarchy", "CENTER", , "Ms Shell Dlg 2", 8)

::method defineDialog                  -- the .rc's controls
  self~createPushButton(IDOK, 229, 306, 50, 14, "DEFAULT", "OK")
  self~createTreeView(IDC_TREE_MENUS, 10, 10, 269, 291, "HASLINES HASBUTTONS LINESATROOT")

::class "WinSystemDlgs_IDD_USER_PROMPT" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 186, 89, "Select Top Level Window", "CENTER", , "Ms Shell Dlg 2", 8)

::method defineDialog                  -- the .rc's controls
  self~createStatic(IDC_STATIC, 15, 14, 154, 32, "", "Enter the window title of the window whose menu you want to display.  You need to use the full and exact title of the window.")
  self~createGroupBox(IDC_STATIC, 5, 5, 176, 41, "", "")
  self~createEdit(IDC_EDIT_NAME, 5, 53, 176, 12, "", "IDC_EDIT_NAME")
  self~createPushButton(IDOK, 76, 72, 50, 14, "DEFAULT", "OK")
  self~createPushButton(IDCANCEL, 131, 72, 50, 14, "", "Cancel")

::class "WinSystemDlgs_IDD_WINDOW_LIST" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 286, 212, "Top-level Windows", "CENTER", , "Ms Shell Dlg 2", 8)

::method defineDialog                  -- the .rc's controls
  self~createStatic(IDC_STATIC_DESCRIPTION, 10, 10, 266, 35, "CENTER", "Select a top-level window in the list and push the Show button.  The selected window and its children will be graphically displayed.  Use the Refresh button to re-populate the list.")
  self~createGroupBox(IDC_STATIC, 10, 50, 266, 133, "", "Window List")
  self~createListView(IDC_LV_WINDOWS, 17, 68, 252, 104, "REPORT SHOWSELALWAYS SINGLESEL")
  self~createPushButton(IDC_PB_REFRESH, 10, 188, 50, 14, "DEFAULT", "Refresh")
  self~createPushButton(IDC_PB_SHOW, 171, 188, 50, 14, "DEFAULT", "Show")
  self~createPushButton(IDC_PB_QUIT, 226, 188, 50, 14, "", "Quit")
