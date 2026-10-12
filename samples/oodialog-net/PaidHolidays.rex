/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 2010-2014 Rexx Language Association. All rights reserved.    */
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
 * Simple example of using the month calendar control.
 *
 * Although this example is relatively simple, it shows how to use a number of
 * features of the month calendar:
 *
 *   * How to size a month calendar to its optimal size.
 *   * How to restrict the range of months the calendar displays.
 *   * How to determine which month(s) are currently displayed in the control.
 *   * How to customize the calendar and display certain dates in bold.
 *
 * The application is for a hypothetical company, used to show the paid holidays
 * for the current year. The dialog displays a month calendar for the current
 * year and as the user pages through the months, the paid holidays are high-
 * lighted in the calendar by bolding the dates.
 *
 * Note that to keep this simple, the "current" year is rather hard-coded.
 *
 * (.NET version of ooDialog's controls\PaidHolidays.rex, on Windows Forms
 * through oodnet.cls: paidHolidays.rc's dialog is
 * PaidHolidays_IDD_HOLIDAY_DLG, from paidHolidaysrc.cls. The month calendar
 * is a .NET MonthCalendar: it takes its optimal size by itself
 * (SingleMonthSize; ooDialog: getMinRect), MinDate and MaxDate restrict it
 * (setRange), GetDisplayRange gives the months showing (getMonthRange). The
 * dates in bold are given all at once, BoldedDates: .NET has no GETDAYSTATE
 * event, the calendar asks for nothing as it pages. The controls are moved
 * in pixels, as the original moves them.)
 */

  .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended

  dlg = .HolidayCalendarDlg~new        -- ooDialog: .HolidayCalendarDlg~new(sd"paidHolidays.rc", IDD_HOLIDAY_DLG)
  if dlg~initCode == 0 then do
    dlg~execute("SHOWTOP")
  end
  else do
    say
    say "Error creating dialog, aborting."
    return 99
  end

return 0

::requires "paidHolidaysrc.cls"

::class 'HolidayCalendarDlg' subclass PaidHolidays_IDD_HOLIDAY_DLG

::method initDialog
  expose calendar

  calendar = self~newMonthCalendar(IDC_MC_HOLIDAYS)

  -- Size the calendar to its optimal size
  self~sizeCalendar(calendar)

  -- Restrict the calendar so that it only displays the year 2011.
  DT = .net~System~DateTime
  calendar~SetDate(DT~new(2011, 1, 1))                 -- (first: today is out of the range)
  calendar~MinDate = DT~new(2011, 1, 1)                -- ooDialog: calendar~setRange(.array~of(start, end))
  calendar~MaxDate = DT~new(2011, 12, 31)

  -- The paid holidays, in bold (ooDialog: the .DayState objects of the months
  -- showing, and of each month the calendar asks for in GETDAYSTATE)
  holidays = .array~new
  do d over "0117 0221 0530 0704 0905 1124 1125 1223 1230"~makeArray(" ")
    holidays~append(DT~new(2011, d~left(2), d~right(2)))
  end
  calendar~BoldedDates = holidays

  -- Which months are currently displayed in the calendar (.NET version:
  -- GetDisplayRange(.false) includes the partially shown ones; ooDialog:
  -- getMonthRange(monthsShowing, 'P'))
  r = calendar~GetDisplayRange(.false)
  say "Months showing:" r~Start~ToString("yyyy-MM") "to" r~End~ToString("yyyy-MM")

-- This function resizes the calendar to its optimal size, the size of one full
-- month (.NET version: SingleMonthSize).  The static text is then placed to the
-- right of the calendar, 1/2 the margin away, and the Ok button so that its top
-- edge is at the bottom edge of the calendar and its right edge at the right
-- margin; the dialog is sized to hold them, with the same margins.
::method sizeCalendar private
  use strict arg calendar

  D = .net~System~Drawing
  calendar~Size = calendar~SingleMonthSize           -- ooDialog: getMinRect(r), resizeTo

  static = self~newStatic(IDC_ST_MSG)
  button = self~newPushButton(IDOK)

  -- (.NET version) the controls' Bounds are in the dialog's client coordinates
  mcRect = calendar~Bounds
  stRect = static~Bounds
  okRect = button~Bounds

  -- The position of the top left corner of the month calendar control defines
  -- the margins
  marginLeft = mcRect~Left
  marginTop  = mcRect~Top

  newWidth = (marginLeft * 2) + (marginLeft % 2) + mcRect~Width + stRect~Width
  newHeight = (marginTop * 2) + mcRect~Height + okRect~Height
  self~form~ClientSize = D~Size~new(newWidth, newHeight)  -- (.NET version: the client area; no frame to add)

  static~Location = D~Point~new(mcRect~Right + (marginLeft % 2), stRect~Top)
  button~Location = D~Point~new(newWidth - marginLeft - okRect~Width, mcRect~Bottom)

::method autoRun                       -- (.NET version) unattended: the bold dates, the next month, then OK
  expose calendar
  say "(auto) bold:" calendar~BoldedDates~items "dates, the first" calendar~BoldedDates[1]~ToString("MMMM d") -
      "- size" calendar~Width"x"calendar~Height "- client" self~form~ClientSize~Width"x"self~form~ClientSize~Height
  calendar~SetDate(.net~System~DateTime~new(2011, 7, 4))
  r = calendar~GetDisplayRange(.true)
  say "(auto) now showing:" r~Start~ToString("MMMM yyyy")
  self~ok
