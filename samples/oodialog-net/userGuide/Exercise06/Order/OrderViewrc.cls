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
/* OrderView.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with OrderView.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "OrderView_IDD_ORDER_DIALOG" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 272, 271, "Sales Order", "CENTER", , "Ms Shell Dlg", 8)

::method defineDialog                  -- the .rc's controls
  self~createDateTimePicker(IDC_ORDER_DATE, 185, 15, 70, 15, "")
  self~createEdit(IDC_ORDER_ORDNO, 215, 35, 40, 14, "", "IDC_ORDER_ORDNO")
  self~createEdit(IDC_ORDER_CUSTNO, 215, 55, 40, 14, "", "IDC_ORDER_CUSTNO")
  self~createStatic(IDC_STATIC, 174, 38, 32, 8, "", "Order No.")
  self~createStatic(IDC_STATIC, 170, 58, 44, 8, "", "Customer No.")
  self~createListView(IDC_ORDER_ITEMS, 20, 75, 240, 115, "ICON")
  self~createStatic(IDC_STATIC, 158, 18, 16, 8, "", "Date")
  self~createStatic(IDC_STATIC, 116, 200, 35, 8, "", "Total Cost:")
  self~createStatic(IDC_STATIC, 116, 214, 29, 8, "", "Discount")
  self~createPushButton(IDCANCEL, 190, 245, 37, 14, "DEFAULT", "Cancel")
  self~createStatic(IDC_STATIC, 116, 228, 13, 8, "", "Tax")
  self~createStatic(IDC_STATIC, 164, 214, 40, 8, "RIGHT", "0.00")
  self~createStatic(IDC_STATIC, 164, 228, 40, 8, "RIGHT", "0.00")
  self~createStatic(IDC_STATIC, 215, 228, 40, 8, "RIGHT", "0.00")
  self~createStatic(IDC_STATIC, 215, 200, 40, 8, "RIGHT", "0.00")
  self~createStatic(IDC_STATIC, 215, 214, 40, 8, "RIGHT", "0.00")
  self~createEdit(IDC_ORDER_NAMEADDR, 20, 30, 103, 39, "", "IDC_ORDER_NAMEADDR")
  self~createStatic(IDC_STATIC, 28, 16, 32, 8, "", "Customer:")

::class "OrderView_IDR_ORDER_MENU" subclass NetMenuBar public   -- the .rc's IDR_ORDER_MENU MENU
::method init
  forward class (super) continue
  p1 = .NetPopupMenu~new()
  p1~insertItem(, IDM_ORDER_DOTHIS, "An Action")
  self~insertPopup(, , p1, "Actions")
  p2 = .NetPopupMenu~new()
  p2~insertItem(, IDM_ORDER_ABOUT, "About")
  self~insertPopup(, , p2, "Help")
