/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 2013-2014 Rexx Language Association. All rights reserved.    */
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

/** genGUID.rex - simple GUID generating program.
 *
 * Copy and paste the output as needed.
 *
 * To run in console only mode use:
 *
 *   genGuid 1
 *
 * In graphical mode you can use copy and paste of the edit control displayed.
 *
 * (.NET version of ooDialog's examples\genGUID.rex, on Windows Forms through
 * oodnet.cls: genGUID.rc's dialog is GenGUID_IDD_GUID_GENERATOR, from
 * genGUIDrc.cls; .DlgUtil~getGUID is .NET's Guid.NewGuid, in the same
 * format.)
 */

    a = arg(1)~strip
    .NetDialog~auto = a~caselessEquals("auto")              -- (.NET version) unattended

    guid = .net~System~Guid~NewGuid~ToString               -- ooDialog: .DlgUtil~getGUID
    say guid

    if a == "" | .NetDialog~auto then do                    -- ooDialog: if arg() == 0
        dlg = .DisplayDlg~new                               -- ooDialog: .DisplayDlg~new(srcDir'resources\genGUID.rc', IDD_GUID_GENERATOR)
        if dlg~initCode = 0 then do
            dlg~guid   = guid
            dlg~execute("SHOWTOP")
        end
    end

return 0

::requires 'genGUIDrc.cls'

::class 'DisplayDlg' subclass GenGUID_IDD_GUID_GENERATOR

::attribute guid

::method initDialog
    expose guid
    self~newEdit(IDC_EDIT_GUID)~Text = guid              -- ooDialog: ~setText(guid)

::method autoRun                       -- (.NET version) unattended: the GUID shown, then Done
    say "(auto) shown:" self~newEdit(IDC_EDIT_GUID)~Text
    self~ok
