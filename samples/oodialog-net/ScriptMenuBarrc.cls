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
/* ScriptMenuBar.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with ScriptMenuBar.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "ScriptMenuBar_IDD_ABOUT_DIALOG" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 231, 121, "About Script Menu Bar Example", "CENTER", , "Ms Shell Dlg", 8)

::method defineDialog                  -- the .rc's controls
  self~createStatic(IDC_ST_BITMAP, 16, 7, 102, 71, "", "")
  self~createStatic(IDC_ST_ABOUT, 141, 10, 76, 82, "CENTER", "An example of using a script menu bar in ooDialog.")
  self~createStatic(IDC_STATIC, 16, 96, 107, 15, "", "ooDialog an ooRexx Extenstion")
  self~createPushButton(IDOK, 170, 97, 50, 14, "DEFAULT", "OK")

::class "ScriptMenuBar_IDD_SCRIPTMENUBAR_DLG" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 217, 195, "Example Dialog with a ScriptMenuBar", "CENTER", , "Ms Shell Dlg", 8)

::method defineDialog                  -- the .rc's controls
  self~createStatic(IDC_STATIC, 15, 12, 92, 12, "", "Example List-View Control")
  self~createListView(IDC_LV, 10, 29, 197, 117, "REPORT SHOWSELALWAYS SINGLESEL")
  self~createPushButton(IDOK, 102, 158, 50, 14, "DEFAULT", "OK")
  self~createPushButton(IDCANCEL, 157, 158, 50, 14, "", "Cancel")

::class "ScriptMenuBar_IDR_MENU_LV" subclass NetMenuBar public   -- the .rc's IDR_MENU_LV MENU
::method init
  forward class (super) continue
  p1 = .NetPopupMenu~new(IDM_POP_FILE)
  p1~insertItem(, IDM_ADD_ITEMS, "Add Items from File")
  p1~insertItem(, IDM_OPEN_LIST_VIEW, "Open List-View", "GRAYED CHECKED")
  p1~insertItem(, IDM_CLOSE_LIST_VIEW, "Close List-View")
  p1~insertSeparator(, IDM_SEP1)
  p1~insertItem(, IDOK, "Exit")
  self~insertPopup(, IDM_POP_FILE, p1, "File")
  p2 = .NetPopupMenu~new(IDM_POP_STYLE)
  p2~insertItem(, IDM_CHECKBOXES, "Check Boxes")
  p2~insertItem(, IDM_GRID_LINES, "Grid Lines")
  p2~insertItem(, IDM_FULL_ROW_SELECT, "Full Row Select")
  p2~insertItem(, IDM_UNDERLINE_HOT, "Underline When Hot")
  self~insertPopup(, IDM_POP_STYLE, p2, "Style")
  p3 = .NetPopupMenu~new(IDM_POP_OPERATIONS)
  p3~insertItem(, IDM_INSERT_ITEM, "Insert Item")
  p3~insertItem(, IDM_DELETE_ITEM, "Delete Item")
  p3~insertSeparator(, IDM_SEP2)
  p3~insertItem(, IDM_EDIT_ITEM, "Edit Item")
  p3~insertItem(, IDM_CAPITALIZE_ITEM, "Capitalize Item")
  self~insertPopup(, IDM_POP_OPERATIONS, p3, "Operations")
  p4 = .NetPopupMenu~new(IDM_POP_HELP)
  p4~insertItem(, IDM_CONTENTS, "Contents")
  p4~insertItem(, IDM_INDEX, "Index ...")
  p4~insertItem(, IDM_SEARCH, "Search ...")
  p4~insertSeparator(, IDM_SEP3)
  p4~insertItem(, IDM_ABOUT, "About")
  self~insertPopup(, IDM_POP_HELP, p4, "Help")
