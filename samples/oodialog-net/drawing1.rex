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
 * Name: drawing1.rex
 * Type: Open Object REXX Script
 *
 * (.NET version of ooDialog's tutorial\drawing1.rex, on Windows Forms through
 * oodnet.cls: drawings.rc's dialog is Drawings_100, from drawingsrc.cls; its
 * owner-drawn button is a panel. ooDialog's device context and GDI pens are
 * System.Drawing's: control~CreateGraphics, a Pen (ooDialog's color 1 is dark
 * red, 2 dark green), DrawEllipse and DrawRectangle (a rectangle's right and
 * bottom become a width and a height). As in the original, what is drawn
 * this way is gone when the window is painted again: drawing2 keeps it.)
 */

.NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended
dlg = .MyDialogClass~new                                 -- ooDialog: .MyDialogClass~new(sd"drawings.rc", 100)
if dlg~initCode <> 0 then return 99
dlg~execute("SHOWTOP")

return 0

::requires "drawingsrc.cls"

::class 'MyDialogClass' subclass Drawings_100

::method init

    forward class (super) continue
    if self~initCode <> 0 then return self~initCode

    self~connectButtonEvent(11, "CLICKED", "circle")
    self~connectButtonEvent(12, "CLICKED", "myRectangle")

    return self~initCode


::method circle

    D = .net~System~Drawing
    g = self~control(10)~CreateGraphics                  -- ooDialog: dc = self~getControlDC(10)
    pen = D~Pen~new(D~Color~FromArgb(128, 0, 0), 5)      -- ooDialog: self~createPen(5, "SOLID", 1)

    g~DrawEllipse(pen, 10, 10, 320 - 10, 200 - 10)       -- ooDialog: self~drawArc(dc, 10, 10, 320, 200)

    pen~Dispose                                          -- ooDialog: deleteObject(pen), freeControlDC(10, dc)
    g~Dispose


::method myRectangle

    D = .net~System~Drawing
    g = self~control(10)~CreateGraphics
    pen = D~Pen~new(D~Color~FromArgb(0, 128, 0), 10)     -- ooDialog: self~createPen(10, "DOT", 2)
    pen~DashStyle = "Dot"

    g~DrawRectangle(pen, 10, 10, 320 - 10, 200 - 10)    -- ooDialog: self~rectangle(dc, 10, 10, 320, 200)

    pen~Dispose
    g~Dispose

::method autoRun                         -- (.NET version) unattended: Circle, Rectangle, then Leave
    self~newPushButton(11)~PerformClick
    self~newPushButton(12)~PerformClick
    say "(auto) drawn on a" self~control(10)~GetType~Name "of" self~control(10)~Width"x"self~control(10)~Height
    self~newPushButton(1)~PerformClick
