/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 1995, 2004 IBM Corporation. All rights reserved.             */
/* Copyright (c) 2005-2014 Rexx Language Association. All rights reserved.    */
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
 * Name: drawing4.rex
 * Type: Open Object REXX Script
 *
 * (.NET version of ooDialog's tutorial\drawing4.rex, on Windows Forms through
 * oodnet.cls: a UserDialog with an owner-drawn button, a panel here; its
 * Paint draws a circle and centred text, as drawing3.)
 */

    .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended
    dlg = .OwnerDrawDlg~new
    if dlg~initCode <> 0 then return 99
    dlg~execute("SHOWTOP")

return 0

::requires "oodnet.cls"

::class 'OwnerDrawDlg' subclass NetDialog

::method init

    forward class (super) continue
    self~create(6, 15, 187, 135, "Owner-drawn Button Dialog", "CENTER")

    self~connectDraw(10, "drawIt")                       -- ooDialog: connectDraw(10, "drawIt", .true)

::method defineDialog
    self~createPushButton(10, 6, 6, 175, 123, "OWNER", "")

::method drawIt unguarded
    use arg sender, e                                    -- ooDialog: use arg id, lp, drawObj, itemID, flags, dc, r, itemData
    D = .net~System~Drawing
    g = e~Graphics                                       -- ooDialog: dc
    r = sender~ClientRectangle                           -- ooDialog: r

    -- Create a pen to draw a circle with.
    pen    = D~Pen~new(D~Color~FromArgb(128, 0, 0), 5)   -- ooDialog: drawObj~createPen(5, "SOLID", 1)

    -- Create a font to use to draw text with.
    font    = D~Font~new("Arial", .net~single(24), "Bold, Italic")   -- weight 700, italic

    -- Get the midpoint of the button rectangle and center the text there
    x = r~Right % 2; y = r~Bottom % 2
    format = D~StringFormat~new                          -- ooDialog: setTextAlign(dc, 'CENTER BASELINE NOUPDATECP')
    format~Alignment = "Center"
    format~LineAlignment = "Center"

    -- Get a rectangle indented 5 from the button's area.
    left = r~Left + 5; top = r~Top + 5; right = r~Right - 10; bottom = r~Bottom - 10

    -- Draw a circle, within the rectangle
    g~DrawEllipse(pen, left, top, right - left, bottom - top)

    -- Write some text at the position we calculated above.
    g~DrawString('Circle', font, D~Brushes~Black, x, y, format)

    format~Dispose
    font~Dispose
    pen~Dispose

    return .true

::method autoRun                         -- (.NET version) unattended: drawn, then closed
    self~redrawControl(10)
    say "(auto) drawn on a" self~control(10)~ClientRectangle~Width"x"self~control(10)~ClientRectangle~Height "panel"
    self~ok
