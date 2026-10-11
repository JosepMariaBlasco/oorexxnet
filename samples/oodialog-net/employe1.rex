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
 * Name: employe1.rex
 * Type: Open Object REXX Script
 *
 * (.NET version of ooDialog's tutorial\employe1.rex, on Windows Forms through
 * oodnet.cls: the dialog of employe1.rc is the class Employe1_100 of
 * employe1rc.cls, written from the .rc by rc2oodnet.rex -cls; a UserDialog
 * that loads the .rc is that class. Its data attributes are named as
 * ooDialog names them.)
 */

.NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended
dlg = .MyDialog~new                                      -- ooDialog: .UserDialog~new, then load(sd"employe1.rc", 100)
if dlg~initCode <> 0 then exit
if dlg~execute("SHOWTOP") = 1 then do
    say dlg~name
    say dlg~city
    say dlg~profession
    say dlg~male
    say dlg~female
    say dlg~married
end

::requires "employe1rc.cls"

::class MyDialog subclass Employe1_100   -- (.NET version) only for autoRun
::method autoRun                         -- unattended: a name, Male, Married, then OK
    self~newEdit(21)~Text = "John Smith"
    self~newRadioButton(31)~Checked = .true
    self~newCheckBox(41)~Checked = .true
    self~ok
