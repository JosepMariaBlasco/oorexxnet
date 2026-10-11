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
 * Name: textScroll.rex
 * Type: Open Object REXX Script
 *
 * (.NET version of ooDialog's tutorial\textScroll.rex, on Windows Forms
 * through oodnet.cls: textScroll.rc's dialog is TextScroll_100, from
 * textScrollrc.cls; its owner-drawn button is a panel to draw on, and
 * scrollInControl moves the text across it with a timer. "Fontname" and
 * "fontsize" are DATA13 and DATA14, as ooDialog names them: FONTNAME and
 * FONTSIZE are the dialog's own methods.)
 */

.NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended
dlg = .MyDialogClass~new                                 -- ooDialog: .MyDialogClass~new(sd"textScroll.rc", 100)
if dlg~initCode <> 0 then return 99
dlg~execute("SHOWTOP")

return 0


::requires "textScrollrc.cls"

::class 'MyDialogClass' subclass TextScroll_100

::method init

    forward class (super) continue
    if self~initCode <> 0 then return self~initCode

    self~data13 = "Arial"
    self~text = "This is a goofy scrolling text demonstration"
    self~data14 = 24
    self~connectButtonEvent(11, "CLICKED", "Display")

    return self~initCode


::method initDialog

   -- Set the background color of the button to the backgroud color of a button.
   self~newPushButton(10)~BackColor = .net~System~Drawing~SystemColors~Control   -- ooDialog: setControlSysColor(10, COLOR_BTNFACE)


::method display
    self~getData
    self~scrollInControl(10, self~text, self~data13, self~data14, "BOLD")

::method autoRun                         -- (.NET version) unattended: Display, until the text has crossed, then Leave
    self~newPushButton(11)~PerformClick
    say "(auto) scrolling:" self~scrolling
    start = time("E")
    do while self~scrolling & time("E") - start < 20
        .net~System~Windows~Forms~Application~DoEvents
        call SysSleep 0.01
    end
    say "(auto) scrolling:" self~scrolling
    self~newPushButton(1)~PerformClick
