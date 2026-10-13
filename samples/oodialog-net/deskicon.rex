/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 1995, 2004 IBM Corporation. All rights reserved.             */
/* Copyright (c) 2005-2014 Rexx Language Association. All rights reserved.    */
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
/*****************************************************************************/
/* Name: DESKICON.REX                                                        */
/* Type: Open Object Rexx Script                                             */
/*                                                                           */
/* Description: Sample how to create a desktop icon using the AddDesktopIcon */
/*              method from the WindowsProgramManager class                  */
/*                                                                           */
/*              TODO change this to a GUI application by creating a dialog   */
/*                   that explains what is happening and has push buttons    */
/*                   to iniate the actions.                                  */
/*                                                                           */
/*****************************************************************************/


/* (.NET version of ooDialog's winsystem\deskicon.rex, through oodnet.cls for
   its dialogs. winsystm.cls's AddDesktopIcon is addDesktopIcon below: the
   desktop's folder is .NET's (Environment~GetFolderPath: DesktopDirectory
   for PERSONAL, CommonDesktopDirectory for COMMON), the shortcut is made by
   the WScript.Shell COM object, through the bridge (.net~createObject: .NET
   has no shortcuts of its own). rexx.exe and rexx.ico are looked for where
   the running rexx is (.rexxInfo~executable). Unattended (argument "auto"):
   a personal shortcut, the dialogs show nothing, and the shortcuts are
   removed at the end.) */

.NetDialog~auto = arg(1)~strip~caselessEquals("auto")    -- (.NET version) unattended

made = .array~new                                        -- (.NET version) the shortcuts made, for "auto"

/* Create a shortcut to notepad editor with shortcut key CONTROL+ALT+N.
 * The shortcut will be a personal shortcut for the current user.  "PERSONAL"
 * is the default.
 */
failed = addDesktopIcon("My Notepad 1","%SystemRoot%\system32\notepad.exe",,,"%HOMEDRIVE%%HOMEPATH%",,,"n")

if failed then call errorDialog "Error.  Could not create the 'My Notepad 1' shortcut."
else made~append(.array~of("My Notepad 1", "PERSONAL"))

/* Create a shortcut to run REXXTRY, use the REXX.ICO icon, working diretory is
 * %TEMP%, th argument is REXXTRY, the shortcut key is CTRL+ALT+T. The shortcut
 * should be common for all users, but on Vista you can not write to the all
 * users area unless you have elevated Administrator pivileges.
 */
-- (.NET version: Environment~OSVersion; SysVersion's "10.0.20348" compared
-- with 6 as strings fails today)
if .net~System~Environment~OSVersion~Version~Major >= 6 then do
  msg = "The next shortcut is intended to be an 'All Users' shortcut." || '0d0a0d0a'x || -
        "But, on Vista you can not write to the 'All Users' area without" || '0d0a'x || -
        "elevated privileges.  If you run this program with elevated" || '0d0a'x || -
        "privileges, then creating an 'All Users' shortcut will succeed," || '0d0a'x || -
        "otherwise it will fail.  You can choose to create an 'All Users'" || '0d0a'x || -
        "shortcut, or a 'Personal' shortcut.  (Creating a 'Personal'" || '0d0a'x || -
        "shortcut will always succeed.)"|| '0d0a0d0a'x || -
        "Create an 'All Users' shortcut?"

  isYes = askDialog(msg, "N")                            -- (.NET version: No the default, for "auto")
  if isYes then location = "COMMON"
  else location = "PERSONAL"
end
else do
  location = "COMMON"
end

rexxDir = filespec("location", .rexxInfo~executable)     -- (.NET version) where rexx.exe and rexx.ico are
failed = addDesktopIcon("RexxTry",rexxDir"rexx.exe",rexxDir"rexx.ico",0,"%TEMP%",location,"rexxtry","T","MAXIMIZED")

if failed then call errorDialog "Error.  Could not create the 'RexxTry' shortcut."
else made~append(.array~of("RexxTry", location))

/* Create a shortcut to NOTEPAD editor, with the working diretory as c:\temp.
 * The shortcut will be a personal shortcut for the current user.
 */
failed = addDesktopIcon("My Notepad 2","notepad.exe", , ,VALUE( 'TEMP',, 'ENVIRONMENT' ) || '\',"PERSONAL", , ,"MAXIMIZED")

if failed then call errorDialog "Error.  Could not create the 'My Notepad 2' shortcut."
else made~append(.array~of("My Notepad 2", "PERSONAL"))

if .NetDialog~auto then do                               -- (.NET version) unattended: listed, then removed
  do item over made
    file = desktopFolder(item[2]) || "\" || item[1] || ".lnk"
    say "(auto) made" file (.net~System~IO~File~Exists(file))~?("", "(MISSING)")
    .net~System~IO~File~Delete(file)
  end
end

return 0

::requires "oodnet.cls"                                  -- ooDialog: ::requires "winsystm.cls", "ooDialog.cls"

/* (.NET version) winsystm.cls's AddDesktopIcon(name, program [, icon
   [, iconNr [, workDir [, location [, arguments [, hotKey [, run]]]]]]]):
   a shortcut on the desktop; .true when it failed (as the original's
   result) */
::routine addDesktopIcon
  use strict arg name, program, icon = "", iconNr = 0, workDir = "", location = "PERSONAL", -
                 arguments = "", hotKey = "", run = ""
  signal on syntax
  shell = .net~createObject("WScript.Shell")
  link = shell~CreateShortcut(desktopFolder(location) || "\" || name || ".lnk")
  link~TargetPath = program
  if arguments \== "" then link~Arguments = arguments
  if icon \== "" then link~IconLocation = icon || "," || iconNr
  if workDir \== "" then link~WorkingDirectory = workDir
  if hotKey \== "" then link~Hotkey = "Ctrl+Alt+" || hotKey~upper
  caseOf = run~upper                               -- 1 normal, 3 maximized, 7 minimized
  select case caseOf                                     -- (not the expression itself: ooRexx bug, SELECT CASE: #2114)
    when "MAXIMIZED" then link~WindowStyle = 3
    when "MINIMIZED" then link~WindowStyle = 7
    otherwise nop
  end
  link~Save
  return .false
syntax:
  say "addDesktopIcon:" condition("O")~message
  return .true

/* The desktop's folder: the user's (PERSONAL) or everybody's (COMMON) */
::routine desktopFolder
  use strict arg location
  if location~upper == "COMMON" then return .net~System~Environment~GetFolderPath("CommonDesktopDirectory")
  return .net~System~Environment~GetFolderPath("DesktopDirectory")
