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
/* fiscalReports.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with fiscalReports.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "FiscalReports_IDD_FISCAL_REPORTS" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(0, 0, 333, 122, "Acme Widgets: Fiscal Reports", "CENTER", , "Ms Shell Dlg", 8)

::method defineDialog                  -- the .rc's controls
  self~createGroupBox(IDC_GB_REPORTS, 10, 11, 313, 41, "", "Report Type:")
  self~createRadioButton(IDC_RB_BAL_SHEET, 19, 29, 63, 8, "", "Balance Sheet", "BALANCESHEET")
  self~createRadioButton(IDC_RB_PAYROLL, 87, 29, 37, 8, "", "Payroll", "PAYROLL")
  self~createRadioButton(IDC_RB_CASH_FLOW, 135, 29, 49, 8, "", "Cash Flow", "CASHFLOW")
  self~createRadioButton(IDC_RB_INCOME_STMT, 192, 29, 73, 8, "", "Income Statement", "INCOMESTATEMENT")
  self~createRadioButton(IDC_RB_EARNINGS, 277, 29, 43, 8, "", "Earnings", "EARNINGS")
  self~createStatic(IDC_STATIC, 10, 61, 94, 8, "", "Period && Start Date:")
  self~createDateTimePicker(IDC_DTP_REPORT, 10, 72, 313, 15, "")
  self~createPushButton(IDC_PB_PRINT, 218, 98, 50, 14, "DEFAULT", "Print")
  self~createPushButton(IDOK, 273, 98, 50, 14, "", "Done")
