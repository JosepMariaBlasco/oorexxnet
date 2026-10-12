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
/* treeViewCustomDraw.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with treeViewCustomDraw.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "TreeViewCustomDraw_IDD_ADD_TREE_ITEM" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 209, 91, "Add New Item", "CENTER", , "MS Shell Dlg", 10)

::method defineDialog                  -- the .rc's controls
  self~createStatic(IDC_STATIC, 10, 13, 20, 8, "", "Name:")
  self~createEdit(IDC_EDIT_NAME, 34, 11, 106, 14, "", "IDC_EDIT_NAME")
  self~createGroupBox(IDC_STATIC, 15, 32, 123, 49, "", "Add new item as:")
  self~createRadioButton(IDC_RB_SIBLING, 23, 46, 32, 10, "", "Sibling", "SIBLING")
  self~createRadioButton(IDC_RB_CHILD, 23, 63, 32, 10, "", "Child", "CHILD")
  self~createCheckBox(IDC_CHK_FOLDER, 85, 46, 41, 10, "", "Folder", "FOLDER")
  self~createPushButton(IDOK, 149, 47, 50, 14, "DEFAULT", "OK")
  self~createPushButton(IDCANCEL, 149, 67, 50, 14, "", "Cancel")

::class "TreeViewCustomDraw_IDD_TREE_DLG" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(40, 60, 274, 311, "Crazy Sam's Emporium - Inventory", "MAXIMIZEBOX", , "MS Shell Dlg", 10)

::method defineDialog                  -- the .rc's controls
  self~createTreeView(IDC_TREE, 10, 10, 254, 231, "HASLINES HASBUTTONS LINESATROOT")
  self~createPushButton(IDC_PB_NEW, 10, 250, 62, 14, "", "New Item")
  self~createPushButton(IDC_PB_DELETE, 10, 268, 62, 14, "", "Delete Item")
  self~createPushButton(IDC_PB_INFO, 10, 287, 62, 14, "", "Item Information")
  self~createPushButton(IDC_PB_SORT, 89, 250, 62, 14, "", "Reverse Sort")
  self~createPushButton(IDC_PB_EXP_ALL, 89, 268, 62, 14, "", "Expand All")
  self~createPushButton(IDC_PB_COL_ALL, 89, 287, 62, 14, "", "Collapse All")
  self~createPushButton(IDHELP, 202, 268, 62, 14, "", "Help")
  self~createPushButton(IDCANCEL, 202, 287, 62, 14, "", "Close")
