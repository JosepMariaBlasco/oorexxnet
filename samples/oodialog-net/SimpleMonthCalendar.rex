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
/**
 * This program displays a month calendar control in a small dialog and prompts
 * the user to pick their birthday. Each time the user selects a new date, that
 * date is shown in a static text control.
 *
 * (.NET version of ooDialog's simple/SimpleMonthCalendar.rex, on Windows
 * Forms through oodnet.cls. The original's .rc dialog is built here, with its
 * coordinates; the month calendar sizes itself in .NET.)
 */
  .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended
  dlg = .SimpleMonthCalendar~new
  dlg~execute("SHOWTOP")
return 0
-- End of entry point.

::requires "oodnet.cls"

::class 'SimpleMonthCalendar' subclass NetDialog

::method init                          -- (.NET version) the .rc's DIALOG and FONT
  forward class (super) continue
  self~create(0, 0, 254, 124, "Simple Month Calendar", "CENTER", , "Ms Shell Dlg", 8)

::method defineDialog                  -- (.NET version) the .rc's controls
  self~createMonthCalendar(IDC_MC, 7, 7, 147, 105)
  self~createStatic(IDC_STATIC, 169, 10, 75, 23, "CENTER", "Pick you birth date.")
  self~createStatic(IDC_ST_BIRTHDATE, 169, 58, 75, 23, "CENTER")
  self~createPushButton(IDOK, 194, 100, 50, 14, "DEFAULT", "OK")

::method initDialog
  expose dateText
  self~connectMonthCalendarEvent(IDC_MC, "SELECT", onSelect)
  dateText = self~newStatic(IDC_ST_BIRTHDATE)

::method onSelect unguarded            -- .NET: (sender, DateRangeEventArgs)
  expose dateText
  use arg sender, e
  dateText~Text = self~formatDate(e~Start)

::method formatDate private            -- a .NET DateTime: "October 11, 2026"
  use strict arg date
  return date~ToString("MMMM d, yyyy", .net~System~Globalization~CultureInfo~InvariantCulture)

::method autoRun                       -- (.NET version) unattended: pick a date, then OK
  mc = self~newMonthCalendar(IDC_MC)
  mc~SetDate(.net~System~DateTime~new(2000, 2, 29))
  self~onSelect(mc, .net~System~Windows~Forms~DateRangeEventArgs~new(mc~SelectionStart, mc~SelectionEnd))
  say "Selected:" self~newStatic(IDC_ST_BIRTHDATE)~Text
  self~ok
