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
/****************************************************************************/
/* Name: DESKTOP.REX                                                        */
/* Type: Open Object Rexx Script                                            */
/*                                                                          */
/* Description: Sample how to add groups and shortcuts to the desktop       */
/*   Creates a group and shortcuts to programs on the windows dektop        */
/*   using the WindowsProgramManager class                                  */
/*                                                                          */
/*   TODO change this to a GUI application.                                 */
/*                                                                          */
/* (.NET version of ooDialog's winsystem\desktop.rex. winsystm.cls's
   WindowsProgramManager talked to Program Manager by DDE: its groups are,
   today, folders of the Start menu's Programs, its items shortcuts in them.
   Here: the folder is .NET's (Environment~GetFolderPath("Programs"),
   Directory~CreateDirectory, Directory~Delete); a shortcut is made by the
   WScript.Shell COM object, through the bridge (.net~createObject: .NET
   has no shortcuts of its own); ShowGroup opens the folder in Explorer.
   Unattended (argument "auto"): no pauses, no Explorer; what was made is
   listed, and removed at the end.) */

parse arg arg1
auto = arg1~strip~caselessEquals("auto")                 -- (.NET version) unattended

pm = .ProgramManager~new                                 -- ooDialog: pm = .WindowsProgramManager~new

pm~AddGroup("My Own Group")
pm~AddItem("My own notepad", "notepad.exe", "NOTEPAD.EXE",0)
pm~AddItem("My own calculator", "calc.exe",,,,1)
pm~AddItem("My own write", "write.exe",,,"c:\")
if auto then say "Made:" pm~items~makeString("L", ", ")
else pm~ShowGroup("My own group", "MAX")
say "press enter to delete the 'My own write' item"
if \auto then pull
pm~DeleteItem("My own write")

if auto then say "Left:" pm~items~makeString("L", ", ")
else pm~ShowGroup("My Own Group")
say "press enter to delete the 'My Own Group' group"
if \auto then pull
pm~DeleteGroup("My Own Group")
say "Deleted."

::requires "net.cls"                                     -- ooDialog: ::requires "winsystm.cls"

/* (.NET version) The part of WindowsProgramManager this program uses: a
   group is a folder of the Start menu's Programs, an item a shortcut in the
   group last added or shown. */
::class ProgramManager

::method init
  expose programs group
  programs = .net~System~Environment~GetFolderPath("Programs")
  group = ""

::method groupPath private
  expose programs
  use strict arg name
  return programs || "\" || name

::method AddGroup
  expose group
  use strict arg name
  .net~System~IO~Directory~CreateDirectory(self~groupPath(name))
  group = name
  return 0

/* AddItem(name, program [, icon [, iconNr [, workDir [, last [, hotKey [, run]]]]]]):
   a shortcut to program, in the current group */
::method AddItem
  expose group
  use strict arg name, program, icon = "", iconNr = 0, workDir = "", last = 0, hotKey = "", run = ""
  shell = .net~createObject("WScript.Shell")
  link = shell~CreateShortcut(self~groupPath(group) || "\" || name || ".lnk")
  link~TargetPath = program
  if icon \== "" then link~IconLocation = icon || "," || iconNr
  if workDir \== "" then link~WorkingDirectory = workDir
  if hotKey \== "" then link~Hotkey = "Ctrl+Alt+" || hotKey
  select case run~upper                            -- 1 normal, 3 maximized, 7 minimized
    when "MAX", "MAXIMIZED" then link~WindowStyle = 3
    when "MIN", "MINIMIZED" then link~WindowStyle = 7
    otherwise nop
  end
  link~Save
  return 0

::method DeleteItem
  expose group
  use strict arg name
  .net~System~IO~File~Delete(self~groupPath(group) || "\" || name || ".lnk")
  return 0

/* ShowGroup(name [, how]): the folder in Explorer (MAX, MIN: its window
   maximized, minimized) */
::method ShowGroup
  expose group
  use strict arg name, how = ""
  group = name
  psi = .net~System~Diagnostics~ProcessStartInfo~new("explorer.exe", '"' || self~groupPath(name) || '"')
  select case how~upper
    when "MAX" then psi~WindowStyle = "Maximized"
    when "MIN" then psi~WindowStyle = "Minimized"
    otherwise nop
  end
  .net~System~Diagnostics~Process~Start(psi)
  return 0

::method DeleteGroup
  expose group
  use strict arg name
  .net~System~IO~Directory~Delete(self~groupPath(name), .true)
  group = ""
  return 0

/* (.NET version) The current group's items, for the unattended run */
::method items
  expose group
  names = .array~new
  do f over .net~System~IO~Directory~GetFiles(self~groupPath(group), "*.lnk")
    names~append(filespec("name", f))
  end
  return names
