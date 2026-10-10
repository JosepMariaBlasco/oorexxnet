/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 2022 Rexx Language Association. All rights reserved.         */
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
/*********************************************************************

 MSOutlook_monitorInput.rex: using OLE (object linking and embedding) with ooRexx

 -- cf. "winextensions.pdf", "Example 8.3. OLEObject - Monitor Outlook"

 Links:  <https://docs.microsoft.com/en-us/office/vba/api/overview/outlook>
         <https://docs.microsoft.com/en-us/office/vba/outlook/concepts/getting-started/concepts-outlook-vba-reference>
         <https://docs.microsoft.com/en-us/office/vba/api/overview/outlook/object-model>

 Open Microsoft Outlook, attach an ooRexx "ItemAdd" event listener
 to monitor the inbox for adding new mails. The program takes commands
 by watching every second whether one of the files 'pause.monitor',
 'restart.monitor' or 'stop.monitor' got created in the meantime by the user.

*********************************************************************/

/* Monitor OutLook for new mail */
 say; say; say 'ooRexx Mail Monitor version 1.0.0'
/*
 .NET version (ooRexx/.NET, https://github.com/JosepMariaBlasco/oorexxnet):
 - .net~createObject in place of .OLEObject~new;
 - .net~getConstant(o, name) for o~getConstant(name);
 - the event: inboxItems~ItemAdd += .net~handler(object, method) (-= to
   pause) for addEventMethod / connectEvents;
 - Rexx waits in .NET (.net~nextEvent(1)) instead of SysSleep(1): COM
   delivers the events while it does;
 - with the argument "auto" nothing waits for the user (for unattended runs);
 - .net~releaseObject where the program ends with the application, and
   ::requires "net.cls" at the end.
*/

 auto = arg(1)~strip~caselessEquals("auto")         -- (.NET version) unattended: monitor a few seconds
 outLook = .net~createObject("Outlook.Application")

 inboxID = .net~getConstant(outLook, "olFolderInBox")
 inboxItems = outLook~getNameSpace("MAPI")~getDefaultFolder(inboxID)~items

 -- (.NET version) an object's events: .net~events(o); a handler, .net~handler:
 -- the floating method printNewMail, as a method of an object of its own
 if \ .net~events(inboxItems)~hasItem("ItemAdd") then do
    say 'Inbox items is NOT connectable, quitting'
    return 99
 end

 listener = .Object~enhanced(.methods)               -- an object with the method printNewMail
 newMail = .net~handler(listener, "printNewMail")
 inboxItems~ItemAdd += newMail                       -- an error if it cannot connect

 monitor = .Monitor~new
 say 'ooRexx Mail Monitor - monitoring ...'
 do loops = 1 while monitor~isActive
    if auto & loops > 3 then leave                   -- (.NET version)
    .net~nextEvent(1)                               -- (.NET version) events come while Rexx waits in .NET
    status = monitor~getStatus

    select
        when status == 'disconnect' then do
            inboxItems~ItemAdd -= newMail
            say 'ooRexx Mail Monitor - paused ...'
        end
        when status == "reconnect" then do
            inboxItems~ItemAdd += newMail
            say 'ooRexx Mail Monitor - monitoring ...'
        end
        otherwise do
            nop
        end
    end
    -- End select
    end
    say 'ooRexx Mail Monitor version 1.0.0 ended'

return 0

::method printNewMail unguarded
  use arg mailItem
  say 'You have mail'
  say 'Subject:' mailItem~subject

::class 'Monitor'
::method init
  expose state active

  state = 'continue'
  active = .true
  j = SysFileDelete('stop.monitor')
  j = SysFileDelete('pause.monitor')
  j = SysFileDelete('restart.monitor')

::method isActive
  expose active
  return active

::method getStatus
  expose state active

  if SysIsFile('stop.monitor') then do
    j = SysFileDelete('stop.monitor')
    active = .false
    state = 'quit'
    return state
  end

  if SysIsFile('pause.monitor') then do
    j = SysFileDelete('pause.monitor')
    if state == "paused" then return "continue"

    if state \== 'quit' then do
        state = "paused"
        return 'disconnect'
    end
  end

  if SysIsFile('restart.monitor') then do
    j = SysFileDelete('restart.monitor')
    if state == 'continue' then return state
    if state \== 'quit' then do
        state = 'continue'
        return 'reconnect'
    end
  end
  return 'continue'

::requires "net.cls"
