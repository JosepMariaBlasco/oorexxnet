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
/* ProductView.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with ProductView.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "ProductView_IDD_PRODUCT_VIEW" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 248, 228, "Product", "CENTER SIZEBOX", , "Ms Shell Dlg", 8)

::method defineDialog                  -- the .rc's controls
  self~createStatic(IDC_PROD_STATIC1, 25, 28, 54, 8, "", "Product Number:")
  self~createStatic(IDC_PROD_STATIC2, 25, 53, 48, 8, "", "Product Name:")
  self~createStatic(IDC_PROD_STATIC3, 25, 78, 32, 8, "", "List Price:")
  self~createStatic(IDC_PROD_STATIC5, 151, 78, 20, 8, "", "UOM:")
  self~createStatic(IDC_PROD_STATIC4, 25, 103, 36, 8, "", "Description")
  self~createEdit(IDC_PROD_NO, 95, 25, 50, 14, "READONLY", "IDC_PROD_NO")
  self~createEdit(IDC_PROD_NAME, 95, 51, 130, 13, "READONLY", "IDC_PROD_NAME")
  self~createEdit(IDC_PROD_LIST_PRICE, 95, 75, 40, 14, "READONLY", "IDC_PROD_LIST_PRICE")
  self~createEdit(IDC_PROD_UOM, 175, 75, 40, 14, "READONLY", "IDC_PROD_UOM")
  self~createGroupBox(IDC_PROD_SIZE_GROUP, 31, 151, 189, 30, "", "Size Category")
  self~createRadioButton(IDC_PROD_RADIO_SMALL, 46, 165, 33, 8, "DISABLED", "Small", "IDC_PROD_RADIO_SMALL")
  self~createRadioButton(IDC_PROD_RADIO_MEDIUM, 110, 165, 41, 8, "DISABLED", "Medium", "IDC_PROD_RADIO_MEDIUM")
  self~createRadioButton(IDC_PROD_RADIO_LARGE, 168, 165, 34, 8, "DISABLED", "Large", "IDC_PROD_RADIO_LARGE")
  self~createPushButton(IDC_PROD_SAVE_CHANGES, 180, 195, 52, 14, "DEFAULT DISABLED", "Save Changes")
  self~createEdit(IDC_PROD_DESCRIPTION, 95, 100, 125, 30, "MULTILINE", "IDC_PROD_DESCRIPTION")

::class "ProductView_IDD_PRODUCT_VIEW_ABOUT" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 204, 109, "About Product View", "CENTER", , "Ms Shell Dlg", 8)

::method defineDialog                  -- the .rc's controls
  self~createPushButton(IDOK, 143, 88, 50, 14, "DEFAULT", "OK")
  self~createStatic(IDC_PRODABT_ICON_PLACE, 16, 7, 102, 71, "", "")
  self~createStatic(IDC_PRODABT_STATIC1, 15, 84, 110, 15, "", "A view of a Product component.")
  self~createStatic(IDC_PRODABT_STATIC2, 130, 9, 65, 65, "", "An example of an About box using .ResDialog.")

::class "ProductView_IDR_PRODUCT_VIEW_MENU" subclass NetMenuBar public   -- the .rc's IDR_PRODUCT_VIEW_MENU MENU
::method init
  forward class (super) continue
  p1 = .NetPopupMenu~new()
  p1~insertItem(, IDM_PROD_UPDATE, "&Update Product")
  p1~insertItem(, IDM_PROD_REFRESH, "Refresh Data")
  p1~insertItem(, IDM_PROD_PRINT, "Print...")
  p1~insertItem(, IDM_PROD_CLOSE, "Close")
  self~insertPopup(, , p1, "Actions")
  p2 = .NetPopupMenu~new()
  p2~insertItem(, IDM_PROD_ABOUT, "About...")
  self~insertPopup(, , p2, "Help")
