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
 * Name: drawing3.rex
 * Type: Open Object REXX Script
 *
 * (.NET version of ooDialog's tutorial\drawing3.rex, on Windows Forms through
 * oodnet.cls: drawings.rc's dialog is Drawings_100, from drawingsrc.cls.
 * ooDialog's extended DRAW arguments (the device context and the item's
 * rectangle) are .NET Paint's e~Graphics and the control's ClientRectangle;
 * text centred with a StringFormat in place of setTextAlign.)
 */

.NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended
dlg = .MyDialogClass~new                                 -- ooDialog: .MyDialogClass~new(sd"drawings.rc", 100)
if dlg~initCode <> 0 then return 99
dlg~execute("SHOWTOP")

return 0

::requires "drawingsrc.cls"

::class 'MyDialogClass' subclass Drawings_100

::attribute graphicObject

::method init

    forward class (super) continue
    if self~initCode <> 0 then return self~initCode

    self~connectButtonEvent(11, "CLICKED", "circle")
    self~connectButtonEvent(12, "CLICKED", "myRectangle")
    self~connectDraw(10, "drawIt")                       -- ooDialog: connectDraw(10, "drawIt", .true)

    self~graphicObject = "NONE"

    return self~initCode


::method drawIt unguarded
    use arg sender, e                                    -- ooDialog: use arg id, lp, drawObj, itemID, flags, dc, r, itemData
    D = .net~System~Drawing
    g = e~Graphics                                       -- ooDialog: dc
    r = sender~ClientRectangle                           -- ooDialog: r

    if self~graphicObject = "NONE" then return .true

    if self~graphicObject = "CIRCLE" then do
        pen = D~Pen~new(D~Color~FromArgb(128, 0, 0), 5)  -- ooDialog: drawObj~createPen(5, "SOLID", 1)
    end
    else do
        pen = D~Pen~new(D~Color~FromArgb(0, 128, 0), 8)  -- ooDialog: drawObj~createPen(8, "SOLID", 2)
    end

    font = D~Font~new("Arial", .net~single(24), "Bold, Italic")   -- ooDialog: createFontEx("Arial", 24, properties)

    -- Get the midpoint of the button rectangle and center the text there
    x = r~Right % 2; y = r~Bottom % 2
    format = D~StringFormat~new                          -- ooDialog: setTextAlign(dc, 'CENTER BASELINE NOUPDATECP')
    format~Alignment = "Center"
    format~LineAlignment = "Center"

    -- Get a draw rectangle indented 5 from the button's area.
    left = r~Left + 5; top = r~Top + 5; right = r~Right - 10; bottom = r~Bottom - 10

    if self~graphicObject = "CIRCLE" then do
        -- Draw the circle, within our draw rectangle
        g~DrawEllipse(pen, left, top, right - left, bottom - top)
    end
    else do
        -- Draw the rectangle, indented like the circle above.
        g~DrawRectangle(pen, left, top, right - left, bottom - top)
    end

    -- Write the text at the position we calculated above.
    g~DrawString(self~graphicObject, font, D~Brushes~Black, x, y, format)

    format~Dispose
    font~Dispose
    pen~Dispose

    return .true


::method circle unguarded
    self~graphicObject = "CIRCLE"
    self~redrawControl(10, 1)


::method myRectangle unguarded
    self~graphicObject = "RECTANGLE"
    self~redrawControl(10, 1)

::method autoRun                         -- (.NET version) unattended: Circle, Rectangle, then Leave
    self~newPushButton(11)~PerformClick
    say "(auto) drawn:" self~graphicObject
    self~newPushButton(12)~PerformClick
    say "(auto) drawn:" self~graphicObject
    self~newPushButton(1)~PerformClick
