/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 1995, 2004 IBM Corporation. All rights reserved.             */
/* Copyright (c) 2005-2022 Rexx Language Association. All rights reserved.    */
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

/* .NET version, for the ooRexx/.NET bridge: .OLEObject~GetObject(moniker) ->
   .net~getObject(moniker), .OLEObject~new(progID) -> .net~createObject(progID),
   and ::requires "net.cls" at the end; other changes are marked "(.NET version)".
   The argument "auto" (samples/check-samples.rex) makes it run unattended.    */
auto = arg(1)~strip~caselessEquals("auto")            -- (.NET version)
/**********************************************************************/
/*                                                                    */
/* WScriptShell.rex: OLE Automation with ooRexx                       */
/*                                                                    */
/* Show some features of the Windows Scripting Host Shell Object:     */
/*  - Query environment string                                        */
/*  - List special folders                                            */
/*  - Create a shortcut on the desktop                                */
/*  - Use a GUI popup                                                 */
/*                                                                    */
/**********************************************************************/

WshShellObj = .net~createObject("WScript.Shell")

WshEnv = WshShellObj~Environment
Say "Operating system:" WshEnv["OS"]
Say "You have" WshEnv["NUMBER_OF_PROCESSORS"] "processor(s) of",
    WshEnv["PROCESSOR_ARCHITECTURE"] "architecture in your system."

Say "The following directories represent special folders on your system:"
Do Folder Over WshShellObj~SpecialFolders
  Say "   " Folder
End

Say "Creating a shortcut for NOTEPAD.EXE on your Desktop..."
Desktop = WshShellObj~SpecialFolders("Desktop")
ShortCut = WshShellObj~CreateShortcut(Desktop || "\Shortcut to Notepad.lnk")
ShortCut~TargetPath = "%WINDIR%\notepad.exe"
ShortCut~Save

if auto then do                          -- (.NET version) unattended: no popup to answer,
  .net~createObject("Scripting.FileSystemObject")~DeleteFile(Desktop || "\Shortcut to Notepad.lnk")
  say "auto: the shortcut deleted again; no popup"   -- and no shortcut left behind
end
else WshShellObj~Popup("Processing of REXX script has finished!")

::requires "net.cls"
