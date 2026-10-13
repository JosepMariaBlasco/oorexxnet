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
  self~create(0, 0, 272, 270, "Sales Order", "CENTER", , "Ms Shell Dlg", 8)

::method defineDialog                  -- the .rc's controls
  self~createEdit(IDC_ORDER_ORDNO, 217, 30, 40, 14, "READONLY CENTER", "IDC_ORDER_ORDNO")
  self~createEdit(IDC_ORDER_CUSTNO, 217, 50, 40, 14, "READONLY RIGHT", "IDC_ORDER_CUSTNO")
  self~createStatic(IDC_STATIC, 169, 33, 32, 8, "", "Order No.")
  self~createStatic(IDC_STATIC, 169, 53, 44, 8, "", "Customer No.")
  self~createListView(IDC_ORDER_ITEMS, 17, 70, 240, 115, "REPORT")
  self~createStatic(IDC_STATIC, 169, 13, 16, 8, "", "Date")
  self~createStatic(IDC_STATIC, 113, 195, 30, 8, "", "Net Cost:")
  self~createStatic(IDC_STATIC, 113, 209, 31, 8, "", "Discount:")
  self~createPushButton(IDCANCEL, 17, 234, 35, 14, "DEFAULT", "Close")
  self~createStatic(IDC_STATIC, 113, 223, 15, 8, "", "Tax:")
  self~createStatic(IDC_ST_DISCOUNT_PC, 161, 209, 40, 8, "RIGHT", "0.00")
  self~createStatic(IDC_ST_TAX_PC, 161, 223, 40, 8, "RIGHT", "0.00")
  self~createStatic(IDC_ST_TAX, 212, 223, 40, 8, "RIGHT", "0.00")
  self~createStatic(IDC_ST_NET, 212, 195, 40, 8, "RIGHT", "0.00")
  self~createStatic(IDC_ST_DISCOUNT, 212, 209, 40, 8, "RIGHT", "0.00")
  self~createEdit(IDC_ORDER_NAMEADDR, 17, 23, 103, 39, "MULTILINE READONLY", "IDC_ORDER_NAMEADDR")
  self~createStatic(IDC_STATIC, 19, 9, 32, 8, "", "Customer:")
  self~createStatic(IDC_STATIC, 113, 237, 35, 8, "", "Total Cost:")
  self~createStatic(IDC_ST_TOTAL, 212, 237, 40, 11, "RIGHT BORDER", "0.00")
  self~createEdit(IDC_ORDER_DATE, 217, 10, 40, 14, "READONLY CENTER", "IDC_ORDER_DATE")

::class "OrderView_IDR_ORDER_MENU" subclass NetMenuBar public   -- the .rc's IDR_ORDER_MENU MENU
::method init
  forward class (super) continue
  p1 = .NetPopupMenu~new()
  p1~insertItem(, IDM_ORDER_DOTHIS, "An Action")
  self~insertPopup(, , p1, "Actions")
  p2 = .NetPopupMenu~new()
  p2~insertItem(, IDM_ORDER_ABOUT, "About")
  self~insertPopup(, , p2, "Help")
