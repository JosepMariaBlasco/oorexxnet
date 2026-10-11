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
 * Name: employe5.rex
 * Type: Open Object REXX Script
 *
 * (.NET version of ooDialog's tutorial\employe5.rex, on Windows Forms through
 * oodnet.cls: employe3.rc's dialog is Employe3_100, from employe3rc.cls. The
 * buttons are connected in init, as in the original: NetDialog connects them
 * once the controls exist.)
 */

.NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended
dlg = .MyDialogClass~new                                 -- ooDialog: .MyDialogClass~new(sd"employe3.rc", 100)
if dlg~initCode <> 0 then exit
dlg~execute("SHOWTOP")

exit

::requires "employe3rc.cls"

::class MyDialogClass subclass Employe3_100

::attribute employees
::attribute empCount
::attribute empCurrent

::method init
    forward class (super) continue
    if self~initCode <> 0 then return self~initCode

    self~employees = .array~new(10)
    self~empCount = 1
    self~empCurrent = 1
    self~connectButtonEvent(10, "CLICKED", "Print")   /* connect button 10 with a method */
    self~connectButtonEvent(12, "CLICKED", "Add")     /* connect button 12 with a method */

    return self~initCode

::method initDialog
    self~city = "New York"
    self~male = 1
    self~female = 0
    self~addComboEntry(22, "Munich")
    self~addComboEntry(22, "New York")
    self~addComboEntry(22, "San Francisco")
    self~addComboEntry(22, "Stuttgart")
    self~addListEntry(23, "Business Manager")
    self~addListEntry(23, "Software Developer")
    self~addListEntry(23, "Broker")
    self~addListEntry(23, "Police Man")
    self~addListEntry(23, "Lawyer")

::method print
    self~getData

    if self~male = 1 then title = "Mr."
    else title = "Ms."
    if self~married = 1 then addition = " (married) "
    else addition = ""

    call infoDialog title self~name addition || "A"x || "City:" self~city || "A"x ||  -
                     "Profession:" self~name

::method add
    self~employees[self~empCount] = .directory~new
    self~employees[self~empCount]['NAME'] = self~getControlData(21)
    self~employees[self~empCount]['CITY'] = self~getControlData(22)
    self~employees[self~empCount]['PROFESSION'] = self~getControlData(23)

    if self~getControlData(31) = 1 then sex = 1
    else sex = 2
    self~employees[self~empCount]['SEX'] = sex

    self~employees[self~empCount]['MARRIED'] = self~getControlData(41)
    self~empCount += 1
    self~empCurrent = self~empCount
    self~setControlData(21, "");


::method set
    self~setControlData(21, self~employees[self~empCurrent]['NAME'])
    self~setControlData(22, self~employees[self~empCurrent]['CITY'])
    self~setControlData(23, self~employees[self~empCurrent]['PROFESSION'])

    if self~employees[self~empCurrent]['SEX'] = 1 then do
       self~setControlData(31, 1)
       self~setControlData(32, 0)
    end
    else do
       self~setControlData(31, 0)
       self~setControlData(32, 1)
    end
    self~setControlData(41, self~employees[self~empCurrent]['MARRIED'])

::method autoRun                         -- (.NET version) unattended: two employees added, Print, OK
    self~name = "John Smith"; self~profession = "Broker"
    self~newPushButton(12)~PerformClick
    self~name = "Jane Doe"; self~city = "Munich"; self~female = 1
    self~newPushButton(12)~PerformClick
    say "(auto) employees:" self~empCount - 1 "-" self~employees[1]['NAME']"," self~employees[2]['NAME'] "of" self~employees[2]['CITY']
    self~name = "Jim Beam"
    self~newPushButton(10)~PerformClick
    self~ok
