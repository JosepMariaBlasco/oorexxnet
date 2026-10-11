/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 1995, 2004 IBM Corporation. All rights reserved.             */
/* Copyright (c) 2014-2014 Rexx Language Association. All rights reserved.    */
/*                                                                            */
/* This program and the accompanying materials are made available under       */
/* the terms of the Common Public License v1.0 which accompanies this         */
/* distribution. A copy is also available at the following address:           */
/* https://www.oorexx.org/license.html                         */
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
 * Name: drawing5.rex
 * Type: Open Object REXX Script
 *
 * (.NET version of ooDialog's tutorial\drawing5.rex, on Windows Forms through
 * oodnet.cls: as drawing4, with the time drawn every second. ooDialog's Alarm
 * that calls paint again (on a Rexx thread) is a Windows Forms timer (on the
 * dialog's thread); the font and pen are made once, freed when it ends.)
 */

    .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended
    dlg = .OwnerDrawDlg~new
    if dlg~initCode <> 0 then return 99
    dlg~execute("SHOWTOP")

return 0

::requires "oodnet.cls"

::class 'OwnerDrawDlg' subclass NetDialog

::method init
    expose timeFont circlePen pleaseQuit

    forward class (super) continue
    self~create(6, 15, 187, 135, "Owner-drawn Button Dialog", "CENTER")

    self~connectDraw(10, "drawIt")                       -- ooDialog: connectDraw(10, "drawIt", .true)

    -- Create a font to use to draw text with.
    D = .net~System~Drawing
    timeFont = D~Font~new("Arial", .net~single(24), "Bold, Italic")   -- ooDialog: createFontEx("Arial", 24, properties)

    -- Create a pen to draw a circle with.
    circlePen = D~Pen~new(D~Color~FromArgb(128, 0, 0), 5)   -- ooDialog: self~createPen(5, "SOLID", 1)

    pleaseQuit = .false
    self~drawn = ""                                      -- (.NET version)

::method defineDialog
    self~createPushButton(10, 6, 6, 175, 123, "OWNER", "")

::method initDialog
    expose oneSecondAlarm drawSurface

    drawSurface    = self~newPushButton(10)
    oneSecondAlarm = self~startTimer(1000, "paint")      -- ooDialog: .Alarm~new(.TimeSpan~fromSeconds(1), .Message~new(self, paint)), again each time


::method paint unguarded
    expose drawSurface pleaseQuit

    if pleaseQuit then return

    drawSurface~Invalidate                               -- ooDialog: drawSurface~update

::method drawIt unguarded
    expose timeFont circlePen
    use arg sender, e                                    -- ooDialog: use arg id, lp, drawObj, itemID, flags, dc, r, itemData
    D = .net~System~Drawing
    g = e~Graphics                                       -- ooDialog: dc
    r = sender~ClientRectangle                           -- ooDialog: r

    now = .DateTime~new~normalTime

    -- Erases the entire drawing surface, this could be improved, maybe, by only
    -- erasing what needs to be erased.
    g~FillRectangle(D~SystemBrushes~Control, r)          -- ooDialog: self~rectangle(dc, r~left, r~top, r~right, r~bottom, 'FILL')
    g~DrawRectangle(D~Pens~Black, r~Left, r~Top, r~Width - 1, r~Height - 1)   -- (with its border: the DC's default pen)

    -- Get the midpoint of the button rectangle and center the text there
    x = r~Right % 2; y = r~Bottom % 2
    format = D~StringFormat~new                          -- ooDialog: setTextAlign(dc, 'CENTER BASELINE NOUPDATECP')
    format~Alignment = "Center"
    format~LineAlignment = "Center"

    -- Get a rectangle indented 5 from the button's area.
    left = r~Left + 5; top = r~Top + 5; right = r~Right - 10; bottom = r~Bottom - 10

    -- Draw a circle, within the rectangle
    g~DrawEllipse(circlePen, left, top, right - left, bottom - top)

    -- Write the time at the position we calculated above.
    g~DrawString(now, timeFont, D~Brushes~Black, x, y, format)

    format~Dispose
    self~drawn = now                                     -- (.NET version) for autoRun

    return .true

::attribute drawn                                        -- (.NET version) the time drawn last

::method leaving
    expose timeFont circlePen
    timeFont~Dispose                                     -- ooDialog: self~deleteFont(timeFont)
    circlePen~Dispose                                    -- ooDialog: self~deleteObject(circlePen)


::method cancel unguarded
    expose pleaseQuit oneSecondAlarm
    pleaseQuit = .true
    oneSecondAlarm~Stop                                  -- ooDialog: oneSecondAlarm~cancel
    return self~cancel:super

::method ok unguarded                                    -- (.NET version) the same when it ends with OK (autoRun)
    expose pleaseQuit oneSecondAlarm
    pleaseQuit = .true
    oneSecondAlarm~Stop
    return self~ok:super

::method autoRun                         -- (.NET version) unattended: three seconds of the clock, then closed
    start = time("E")
    do while time("E") - start < 3
        .net~System~Windows~Forms~Application~DoEvents
        call SysSleep 0.05
    end
    say "(auto) the clock shows the time:" (self~drawn~length > 0)
    self~ok
