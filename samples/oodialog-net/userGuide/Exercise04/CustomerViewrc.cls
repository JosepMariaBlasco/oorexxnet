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
/* CustomerView.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with CustomerView.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "CustomerView_IDD_CUST_DIALOG" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 275, 239, "*CustomerName*", "CENTER SIZEBOX", , "Microsoft Sans Serif", 8)

::method defineDialog                  -- the .rc's controls
  self~createStatic(IDC_CUST_LBL_CUSTNAME, 18, 47, 22, 8, "", "Name:")
  self~createEdit(IDC_CUST_EDT_CUSTNO, 85, 20, 65, 15, "READONLY", "IDC_CUST_EDT_CUSTNO")
  self~createStatic(IDC_CUST_LBL_CUSTNO, 18, 22, 59, 8, "", "Customer Number:")
  self~createEdit(IDC_CUST_EDT_CUSTNAME, 85, 45, 165, 14, "READONLY", "IDC_CUST_EDT_CUSTNAME")
  self~createStatic(IDC_CUST_LBL_CUSTADDR, 18, 72, 28, 8, "", "Address:")
  self~createEdit(IDC_CUST_EDT_CUSTADDR, 85, 70, 167, 40, "MULTILINE READONLY", "IDC_CUST_EDT_CUSTADDR")
  self~createStatic(IDC_CUST_LBL_ZIP, 20, 120, 32, 8, "", "Zip Code:")
  self~createEdit(IDC_CUST_EDT_CUSTZIP, 85, 120, 65, 14, "READONLY", "IDC_CUST_EDT_CUSTZIP")
  self~createStatic(IDC_CUST_LBL_LASTORDER, 18, 177, 36, 8, "", "Last Order:")
  self~createStatic(IDC_CUST_STC_LASTORDERDETAILS, 88, 177, 145, 8, "", "   ")
  self~createStatic(IDC_CUST_LBL_DISCOUNT, 18, 149, 50, 8, "", "Discount Code:")
  self~createEdit(IDC_CUST_EDT_DISCOUNT, 85, 145, 20, 14, "READONLY", "IDC_CUST_EDT_DISCOUNT")
  self~createStatic(IDC_CUST_STC_ERRORMSG, 18, 215, 8, 8, "", "   ")
  self~createPushButton(IDC_CUST_BTN_RECORDCHANGES, 130, 195, 58, 14, "DEFAULT DISABLED", "Record Changes")
  self~createPushButton(IDC_CUST_BTN_SHOWLASTORDER, 195, 195, 58, 14, "", "Show Last Order")

::class "CustomerView_IDR_CUST_MENU" subclass NetMenuBar public   -- the .rc's IDR_CUST_MENU MENU
::method init
  forward class (super) continue
  p1 = .NetPopupMenu~new()
  p1~insertItem(, IDM_CUST_NEW, "New Customer...")
  p1~insertItem(, IDM_CUST_UPDATE, "Update...")
  p1~insertItem(, IDM_CUST_PRINT, "Print...")
  p1~insertItem(, IDM_CUST_LAST_ORDER, "Last Order")
  self~insertPopup(, , p1, "Actions")
