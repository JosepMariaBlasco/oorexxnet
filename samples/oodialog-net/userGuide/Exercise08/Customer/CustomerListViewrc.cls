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
/* CustomerListView.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with CustomerListView.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "CustomerListView_IDD_CUSTLIST_DIALOG" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 225, 273, "Customer List", "CENTER SIZEBOX", , "Ms Shell Dlg", 8)

::method defineDialog                  -- the .rc's controls
  self~createPushButton(IDCANCEL, 150, 235, 50, 14, "", "Cancel")
  self~createListView(IDC_CUSTLIST_LIST, 15, 10, 190, 215, "REPORT")
  self~createPushButton(IDC_CUSTLIST_SHOWCUST, 89, 235, 54, 14, "DEFAULT DISABLED", "Show Customer")

::class "CustomerListView_IDR_CUSTLIST_MENU" subclass NetMenuBar public   -- the .rc's IDR_CUSTLIST_MENU MENU
::method init
  forward class (super) continue
  p1 = .NetPopupMenu~new()
  p1~insertItem(, IDM_CUSTLIST_NEWCUST, "New Customer...")
  self~insertPopup(, , p1, "Actions")
  p2 = .NetPopupMenu~new()
  p2~insertItem(, IDM_CUSTLIST_ABOUT, "About...")
  self~insertPopup(, , p2, "Help")
