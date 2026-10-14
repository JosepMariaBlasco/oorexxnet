/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 1995, 2004 IBM Corporation. All rights reserved.             */
/* Copyright (c) 2005-2021 Rexx Language Association. All rights reserved.    */
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
/* oleinfo.rc as oodnet.cls classes, one for each dialog (written by rc2oodnet.rex -cls).
   A program that subclasses ooDialog's RcDialog with oleinfo.rc subclasses
   these instead. */

::requires "oodnet.cls"

::class "Oleinfo_MainDialog" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(6, 15, 294, 318, "Open Object Rexx OLE/ActiveX Object Viewer", "", , "MS Shell Dlg", 10)

::method defineDialog                  -- the .rc's controls
  self~createPushButton(200, 8, 296, 50, 14, "", "Exit")
  self~createPushButton(IDHELP, 236, 296, 50, 14, "", "Help")
  self~createStatic(-1, 8, 8, 52, 9, "", "ProgID")
  self~createStatic(-1, 8, 22, 52, 8, "", "Name")
  self~createStatic(-1, 8, 36, 52, 9, "", "Documentation")
  self~createEdit(101, 68, 22, 162, 11, "READONLY", "DATA101")
  self~createEdit(102, 68, 36, 162, 11, "READONLY", "DATA102")
  self~createPushButton(103, 236, 6, 50, 14, "", "Look up")
  -- (by hand: the .rc gives this group box the id 200 of the Exit button; ooDialog does not mind, oodnet.cls would)
  self~createGroupBox(-1, 8, 84, 278, 136, "", "List of methods, properties and events")
  self~createGroupBox(201, 8, 224, 278, 60, "", "Details")
  self~createEdit(105, 72, 236, 208, 11, "READONLY", "DATA105")
  self~createEdit(106, 72, 250, 208, 11, "READONLY", "DATA106")
  self~createStatic(-1, 12, 236, 58, 9, "", "Method signature")
  self~createStatic(-1, 12, 250, 58, 9, "", "Documentation")
  self~createStatic(-1, 12, 268, 58, 9, "", "Show:")
  self~createCheckBox(107, 72, 268, 32, 9, "", "Types", "TYPES")
  self~createCheckBox(108, 116, 268, 36, 9, "", "Flags", "FLAGS")
  self~createCheckBox(109, 160, 268, 48, 9, "", "Member ID", "MEMBERID")
  self~createGroupBox(202, 8, 52, 278, 28, "", "Progress")
  self~createProgressBar(110, 12, 62, 270, 12, "")
  self~createListView(104, 13, 95, 268, 121, "LIST SHOWSELALWAYS SINGLESEL")
  self~createComboBox(100, 67, 8, 164, 284, "SORT", "DATA100")

::class "Oleinfo_RegistryDialog" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(6, 15, 198, 219, "Registry Information", "", , "MS Shell Dlg", 10)

::method defineDialog                  -- the .rc's controls
  self~createPushButton(IDOK, 8, 196, 50, 14, "DEFAULT", "OK")
  self~createPushButton(IDCANCEL, 140, 196, 50, 14, "", "Cancel")
  self~createStatic(-1, 8, 8, 96, 12, "", "ProgIDs from the registry")
  self~createListBox(200, 8, 24, 180, 164, "SORT", "DATA200")
  self~createPushButton(201, 74, 196, 50, 14, "", "Search")

::class "Oleinfo_ResultDialog" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(6, 15, 251, 219, "Result of method invocation", "", , "MS Shell Dlg", 10)

::method defineDialog                  -- the .rc's controls
  self~createPushButton(IDOK, 100, 196, 50, 14, "DEFAULT", "OK")
  self~createStatic(-1, 8, 8, 48, 9, "", "Return Value")
  self~createEdit(400, 64, 8, 174, 11, "READONLY", "DATA400")
  self~createGroupBox(402, 8, 24, 232, 160, "", "Out Parameters")
  self~createListBox(401, 16, 36, 216, 144, "USETAB", "DATA401")

::class "Oleinfo_HelpDialog" subclass NetDialog public
::method init
  forward class (super) continue
  self~create(6, 15, 345, 208, "Help", "", , "Fixedsys", 10)

::method defineDialog                  -- the .rc's controls
  self~createPushButton(IDOK, 290, 188, 50, 14, "DEFAULT", "OK")
  self~createEdit(500, 4, 7, 336, 176, "MULTILINE READONLY VSCROLL", "DATA500")
