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
/* OrderMgrView.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with OrderMgrView.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "OrderMgrView_IDD_ORDMGR" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 310, 209, "Dialog", "CENTER MINIMIZEBOX", , "Ms Shell Dlg", 8)

::method defineDialog                  -- the .rc's controls
  self~createPushButton(IDC_ORDMGR_EXIT, 245, 186, 60, 15, "", "Exit Application")
  self~createPushButton(IDC_ORDMGR_RESET, 5, 186, 50, 15, "", "Reset Icons")
  self~createListView(IDC_ORDMGR_ICONS, 5, 5, 300, 175, "ICON")

::class "OrderMgrView_IDR_ORDMGR_MENU" subclass NetMenuBar public   -- the .rc's IDR_ORDMGR_MENU MENU
::method init
  forward class (super) continue
  p1 = .NetPopupMenu~new()
  p1~insertItem(, IDM_ORDMGR_NEWORDER, "New Order...")
  p1~insertItem(, IDM_ORDMGR_ORDERLIST, "Order List...")
  p1~insertItem(, IDM_ORDMGR_ORDERSEARCH, "Order Search...")
  self~insertPopup(, , p1, "Orders")
  p2 = .NetPopupMenu~new()
  p2~insertItem(, IDM_ORDMGR_CUSTLIST, "Customer List...")
  p2~insertItem(, IDM_ORDMGR_CUSTSEARCH, "Customer Search...")
  self~insertPopup(, , p2, "Customers")
  p3 = .NetPopupMenu~new()
  p3~insertItem(, IDM_ORDMGR_PRODLIST, "Product List...")
  p3~insertSeparator
  p3~insertItem(, IDM_ORDMGR_PRODSEARCH, "Product Search...")
  self~insertPopup(, , p3, "Products")
  p4 = .NetPopupMenu~new()
  p4~insertItem(, IDM_ORDMGR_PRODNEW, "Product...")
  p4~insertItem(, IDM_ORDMGR_CUSTNEW, "Customer...")
  p4~insertItem(, IDM_ORDMGR_ORDERNEW, "Order...")
  self~insertPopup(, , p4, "New")
  p5 = .NetPopupMenu~new()
  p5~insertItem(, IDM_ORDMGR_ABOUT, "About")
  p5~insertItem(, IDM_MESSAGE_SENDER1, "Message Sender")
  p5~insertItem(, IDM_PERSON1, "Person")
  self~insertPopup(, , p5, "Help")
