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
/****************************************************************************/
/* Name: ftyperex.rex                                                       */
/* Type: ooRexx Script                                                      */
/*                                                                          */
/* Description:                                                             */
/* This script reads the registry entries for the Ftype REXXScript OPEN     */
/* type and allows to change it between REXX.EXE and REXXHIDE.EXE.          */
/*                                                                          */
/* It uses the WindowsRegistry Class and the UserDialog Class.              */
/*                                                                          */
/****************************************************************************/

/* (.NET version of ooDialog's ftyperex.rex, through oodnet.cls: the
   registry is .NET's Microsoft.Win32.Registry in place of winsystm.cls's
   WindowsRegistry: ClassesRoot~OpenSubKey(key, .true) opens it to query and
   write (.nil when it is not there; an error when writing is not allowed),
   GetValueNames and GetValue list its values, SetValue, Flush and Close as
   the original's. The dialog is oodnet.cls's SingleSelection. Unattended
   (argument "auto"), it chooses what is set now and writes nothing.) */

/* See if user gave directions */
parse arg Interface
.NetDialog~auto = Interface~strip~caselessEquals("auto")   -- (.NET version) unattended

/* The user may decide between Windowed or ooDialog Version */
/* Default is ooDialog Version */
/* If the Ftype Setting is to rexxhide, the WINDOWED Version will NOT work */
/* Verify if the given parm starts with "W", TRANSLATE changes it to UPPER CASE */
if Interface~LEFT(1)~TRANSLATE = "C" then Interface = "CONSOLE"
else Interface = "ooDialog"


/* create a new registry object */
/* Set from default HKEY_LOCAL_MACHINE to HKEY_CLASSES_ROOT */
r = .net~Microsoft~Win32~Registry~ClassesRoot            -- ooDialog: r = .WindowsRegistry~new, r~Current_Key = r~CLASSES_ROOT

/* Open the Key with Options QUERY and WRITE */
signal on syntax name noWrite                            -- (.NET version: not allowed to write raises an error)
key = r~OpenSubKey("REXXScript\Shell\Open\Command", .true)   -- ooDialog: r~open(,"REXXScript\Shell\Open\Command","QUERY WRITE")
signal off syntax
if key == .nil then signal noWrite

/* Retrieves all value entries of a given key */
names = key~GetValueNames                                -- ooDialog: q. = r~Query, r~ListValues(,vals.)
if names~items > 0 then do
  /* vals.1.data: the data of the first entry */
  vals.1.data = key~GetValue(names[1])~string
  /* verify, which is the current entry, TRANSLATE it to UPPER CASE */
  if vals.1.data~TRANSLATE~LASTPOS('REXX.EXE') = 0 then do
    if vals.1.data~TRANSLATE~LASTPOS('REXXHIDE.EXE') = 0 then do
      call errorDialog 'ftyperex is not prepared to work with this setting:' vals.1.data
    end
    else do /* remember the current entry */
      was = "rexxhide.exe"
    end
  end
  else do /* remember the current entry */
    was = "rexx.exe"
  end
end
else do
  call errorDialog 'Error reading the registry. Program aborted.'
  exit
end


/* Ask user, what to do */
if Interface = "CONSOLE" then do
  /* Test, if rexxhide was set. In this case, show Message Box */
  if was = "rexxhide.exe" then do
     call errorDialog "Ftype is curently set to rexxhide.exe. You must use the ooDialog interface."
     exit
  end
  /* The next lines use an plain text interface */
  /* Show the curent content */
  say 'Current Ftype Setting is : ' || vals.1.data
  say 'Please enter a number + <Enter> to set it to :'
  say '1 to start it with rexx.exe'
  say '2 to start it with rexxhide.exe'
  say 'Any other entry to leave without changes'
  say
  /* Get selection */
  pull answer
end
else do
  /* The next lines use an "Single Selection Dialog" as interface to the user */
  sel.1 = "Start it with rexx.exe"
  sel.2 = "Start it with rexxhide.exe"
  /* Get the current state, to make preselection in the dialog */
  if was = "rexx.exe" then answer = '1'
    else if was = "rexxhide.exe" then answer = '2'

  dlg = .SingleSelection~new("Please select what to do","Ftype setting for REXXScript",sel.,answer,,answer)
  answer = dlg~execute
  /* end of userinteraction */
end

/* verify what to do */
select
  when answer = '1' then do
    newval = LEFT(vals.1.data,LASTPOS(was,vals.1.data)-1)|| 'rexx.exe" "%1" %*'
  end

  when answer = '2' then do
    newval = LEFT(vals.1.data,LASTPOS(was,vals.1.data)-1)|| 'rexxhide.exe" "%1" %*'
  end
  otherwise exit
end

if .NetDialog~auto then do                               -- (.NET version) unattended: nothing written
  say "(auto) the setting would be:" newval
  key~Close
  exit
end

/* Set the new value */
/* Sets a named value of a given key */
/* If name is blank or omitted, the default value is set */
key~SetValue("", newval)                                 -- ooDialog: r~SetValue(r~Current_Key,"",newval,NORMAL)

/* Forces the system to write the cache buffer of a given key to disk */
key~Flush                                                -- ooDialog: r~flush(r~Current_Key)

/* Closes a previously opened key */
/* Since it can take several seconds before all data is written to disk,*/
/* FLUSH was used before to empty the cache */
key~Close                                                -- ooDialog: r~close(r~Current_Key)

msg = 'The Ftype setting for RexxScript is now:' || '0d0a'x || newval
if interface = "CONSOLE" then say msg
else call InfoDialog msg

exit

noWrite:                                                 -- (.NET version: a label, for both ways of failing)
  msg = 'Error opening the registry key with write access' || '0d0a0d0a'x || -
        'If you are on Vista you  must run this program with' || '0d0a'x || -
        'elevated privileges to see the expected outcome.'
  call ErrorDialog msg
  exit

::requires "oodnet.cls"   -- ooDialog: "winsystm.cls" (the registry), "ooDialog.cls"
