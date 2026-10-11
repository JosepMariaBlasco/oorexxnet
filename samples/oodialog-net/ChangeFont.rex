/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 2009-2014 Rexx Language Association. All rights reserved.    */
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
 * (.NET version of ooDialog's simple/ChangeFont.rex, on Windows Forms through
 * oodnet.cls: a multi-line edit control, a file opened into it, its font
 * changed. ooDialog's createFontEx / setFont / deleteFont: a .NET Font,
 * assigned to the control's Font; .NET frees it.)
 */
  .NetDialog~auto = arg(1)~strip~caselessEquals("auto")   -- (.NET version) unattended
  dlg = .FileViewDialog~new
  dlg~create(30, 30, 260, 180, "File Viewing Dialog", "VISIBLE")
  dlg~execute("SHOWTOP")
return 0
-- End of entry point.

::requires "oodnet.cls"

::class 'FileViewDialog' subclass NetDialog

::method defineDialog
  styles = "VSCROLL HSCROLL MULTILINE"
  self~createEdit(IDC_EDIT, 5, 5, 250, 150, styles)
  self~createPushButton(IDC_PB_OPEN,          5, 160, 35, 15, ,          "Open", onOpen)
  self~createPushButton(IDC_PB_CHANGE_FONT,  50, 160, 45, 15, ,          "Change Font", onFont)
  self~createPushButton(IDOK,               220, 160, 35, 15, "DEFAULT", "OK")

::method initDialog
  expose editControl
  editControl = self~newEdit(IDC_EDIT)
  helpMsg = "Use the Open button to open a text file" || .endOfLine || -
            "and then use the Change Font button to"  || .endOfLine || -
            "change the font."
  editControl~Text = helpMsg
  self~newPushButton(IDC_PB_CHANGE_FONT)~Enabled = .false

::method onOpen
  expose editControl
  -- Have the open file dialog start in the same directory as the location of
  -- this program.
  parse source . . programSrc
  startDirectory = fileSpec('L', programSrc)
  fileName = fileNameDialog(startDirectory, , , 1, "Open a File for Editing")
  if fileName == 0 then return
  self~load(fileName)

::method load private                  -- (.NET version) the file into the edit control
  expose editControl
  use arg fileName
  editControl~Text = .net~System~IO~File~ReadAllText(fileName)
  self~newPushButton(IDC_PB_CHANGE_FONT)~Enabled = .true

::method onFont
  expose editControl
  editControl~Font = .net~System~Drawing~Font~new("Courier New", .net~single(12))
  self~newPushButton(IDC_PB_CHANGE_FONT)~Enabled = .false

::method autoRun                       -- (.NET version) unattended: this program, then its font
  parse source . . programSrc
  self~load(programSrc)
  self~newPushButton(IDC_PB_CHANGE_FONT)~PerformClick
  say "Font:" self~newEdit(IDC_EDIT)~Font~Name "- lines:" self~newEdit(IDC_EDIT)~Lines~Length
  self~ok
