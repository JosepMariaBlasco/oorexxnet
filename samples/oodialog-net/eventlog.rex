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
/* Name: eventlog.rex                                                       */
/* Type: Open Object Rexx Script                                            */
/*                                                                          */
/* Description: Example of how to use the WindowsEventLog class             */
/*                                                                          */
/****************************************************************************/


/* (.NET version of ooDialog's winsystem\eventlog.rex: winsystm.cls's
   WindowsEventLog is .NET's System.Diagnostics.EventLog. EventLog~GetEventLogs
   lists the logs; a log's Entries are its records, by position from 0 (each
   record's number is its Index); EventLog~WriteEntry writes one; and
   System.Diagnostics.Eventing.Reader's EventLogSession tells whether a log
   is full and clears it, backing it up first (as an .evtx file, the format
   of today's logs). Differences:
   - the original's read buffer attributes (minimumRead...) have no
     counterpart: .NET reads the records as they are asked for; the
     Application log's own settings are shown instead;
   - records are read by position, not by record number: the oldest is
     Entries[0], the most recent Entries[Count - 1];
   - .NET writes a record only under a registered source, and registering
     one (EventLog~CreateEventSource) needs an administrator: the program
     registers each source it writes under, writes, and removes the source
     again (the original wrote under sources nobody registered: Windows
     allowed it). The strings become the record's message.
   - the Security log, writing records and clearing a log need an
     administrator, as in the original: without one, the error is shown.
   Unattended (argument "auto"): the questions are answered "no" (nothing is
   written, nothing cleared, the long listings are skipped); the pauses go
   on by themselves.) */

parse arg arg1
.local~autoRun = arg1~strip~caselessEquals("auto")       -- (.NET version) unattended

/* main program */

D = .net~System~Diagnostics
Reader = D~Eventing~Reader
session = Reader~EventLogSession~GlobalSession          -- (.NET version) IsLogFull, ClearLog

/******************************************************************************/
say "=============================================================================="
say "  Display some settings of the Application event log.  The original showed"
say "  WindowsEventLog's read buffer here, which .NET does not have."
say
/******************************************************************************/
log = D~EventLog~new("Application")                     -- ooDialog: log = .WindowsEventLog~new
say "  Maximum size:                    " log~MaximumKilobytes "KBs"
say "  When full:                       " log~OverflowAction
say "  Minimum retention:               " log~MinimumRetentionDays "days"
log~Close
say

/******************************************************************************/
say "=============================================================================="
say "  Open each event log on this computer and display information about the"
say "  log.  Then close the log."
say
/******************************************************************************/
do log over D~EventLog~GetEventLogs                     -- ooDialog: log~getLogNames(logNames), log~open( , name)
  name = log~Log
  info = logInfo(log, session)
  if info~isA(.directory) then do
    say "  Event log:         " name
    say "  Total records:     " info~number             -- ooDialog: log~getNumber
    say "  First record number" info~first              -- ooDialog: log~getFirst
    say "  Last record number " info~last               -- ooDialog: log~getLast
    say "  Log is full?       " logicalToText(info~full)   -- ooDialog: log~isFull
  end
  else do
     say "  Error opening the" name "event log:" info
  end
  log~Close
  say
end


/******************************************************************************/
say "=============================================================================="
say "Going to read the 3 oldest records in the Application event Log,"
say "oldest first."
/******************************************************************************/
ok = doPause(.false)

count = 0

log = D~EventLog~new("Application")
total = log~Entries~Count
if total < 3 then do
  say "To few records ("total") for this demonstration."
end
else do
  -- The oldest record is the first entry, whatever its record number.
  count = displayRecords(readRecords(log, "FORWARDS", 0, 3))   -- ooDialog: log~readRecords( , , , firstRec, 3)
end
log~Close

say "=========================================================================="
say count "records read"
say

/******************************************************************************/
say "=========================================================================="
say "Going to read the 3 most recent records in the System event Log, the"
say "most recent first."
/******************************************************************************/
ok = doPause(.false)

count = 0

log = D~EventLog~new("System")
total = log~Entries~Count
if total < 3 then do
  say "To few records (" || total || ") for this demonstration."
end
else do
  -- The most recent record is the last entry.
  count = displayRecords(readRecords(log, "BACKWARDS", total - 1, 3))   -- ooDialog: log~readRecords("BACKWARDS", , "System", lastRec, 3)
end
log~Close

say "=========================================================================="
say count "records read"
say

/******************************************************************************/
say "=========================================================================="
say "Going to read the 3 oldest records in the System event Log, in reverse"
say "chronological older.  The log is opened once, used for every operation,"
say "then closed."
/******************************************************************************/
ok = doPause(.false)

count = 0

log = D~EventLog~new("System")                          -- ooDialog: log~open("", "System")
totalRecs = log~Entries~Count

if totalRecs < 3 then do
  say "To few records (" || totalRecs || ") for this demonstration."
end
else do
  -- Start at the third oldest, and go back.
  startRec = 0 + 3 - 1
  count = displayRecords(readRecords(log, "BACKWARDS", startRec, 3))
end

log~Close

say "=========================================================================="
say count "records read"
say


/******************************************************************************/
say "=========================================================================="
say "Going to read the complete Security event log forwards.  If there are"
say "a log of records, this will produce substantial output.  You can cancel"
say "if you wish."
/******************************************************************************/
ok = doPause(.true)
count = 0

if ok then do
  signal on syntax name securityError                   -- (.NET version: not an administrator)
  log = D~EventLog~new("Security")
  total = log~Entries~Count
  signal off syntax
  if total == 0 then do
    -- On many systems the security log is empty.
    say "The Security event log has no event records."
  end
  else do
    count = displayRecords(readRecords(log, "FORWARDS", 0, total))
  end
  log~Close
end
else do
  say "Skipping this demonstartion."
end
signal afterSecurity
securityError:
say "Error reading the Security event log:" condition("O")~message
afterSecurity:

say "=========================================================================="
say count "records read"
say


/******************************************************************************/
say "=========================================================================="
say "Going to read the complete System event log in reverse chronological"
say "order.  If there are a lot of records, this will produce substantial"
say "output.  You can cancel if you wish."
/******************************************************************************/
ok = doPause(.true)
count = 0

if ok then do
  log = D~EventLog~new("System")
  total = log~Entries~Count
  if total == 0 then do
    say "The System event log has no event records."
  end
  else do
    count = displayRecords(readRecords(log, "BACKWARDS", total - 1, total))
  end
  log~Close
end
else do
  say "Skipping this demonstartion."
end

say "=========================================================================="
say count "records read"
say


/******************************************************************************/
say "=========================================================================="
say "Going to write some records to the Application event log."
say "You can skip this step if you do not want records added to"
say "your Application event log."

/* Some notes on how the event logging service works.  Applications that
   write records to one of the event logs register a source: a subkey of
   the log's key, under the EventLog service in the registry:

   HKEY_LOCAL_MACHINE
   	  System
   	     CurrentControlSet
   	        Services
           	   EventLog
   	              Application
   							     MyApplication
   	              Security
           	      System

   .NET writes a record only under a registered source, and registering one
   needs an administrator: writeRecord() registers the source in the
   Application log when it is not there, writes, and removes it again.
*/

/******************************************************************************/
ok = doPause(.true)

if ok then do
  type = 4  -- Information
  call writeRecord "MyLog", type, 22, 33, "01 1a ff 4b 0C"x, "String1", "sTring2"
  call writeRecord "Application2", type, 0, 0, "1A 1B 1C 0000 00"x, "First String", "Second String"
  call writeRecord "Security1", type, 0, 0, "1A1B1C000000"x, "Tom", "John", "Larry", "Frank"
  call writeRecord "Security2", type, 0, 0, "04 03 01 1B 1C 00 FF 00 FE 00 FD"x, "One", "Two"
  call writeRecord "System1", type, 0, 0, "1A 1B 1C 00 00 00"x, "1", "2", "3", "4"
  call writeRecord "System2", type, 0, 0, "1A1B1C000000"x, "House", "Apartment"
  call writeRecord "NotRegisteredAppliaction1", type, 0, 0, "1A1B1C0000FF00"x, "Cat", "Dog", "Rabbit"
  rawData = "4d 61 72 6b 20 4d 69 65 73 66 65 6c 64 0d 0a"x
  call writeRecord "NotRegisteredAppliaction2", type, 0, 0, rawData, "ooRexx", "example"
end
else do
  say "Skipping this demonstartion."
end

say "=========================================================================="
say


/******************************************************************************/
say "=============================================================================="
say "The next and last demonstration will clear the Application event log."
/******************************************************************************/

backupFile = getWriteableFileName()

if backupFile == "" then do
  say "Could not determine with certainty a writeable location for a backup file."
  say "You may want to skip this demonstration, the log will not be backed up."
end
else do
  say "The log will first be backed up to this file:"
  say " " backupFile
end

say
say "You can skip this step if you do not want to clear"
say "your Application event log."
say
say "If this is the first time you ran this example, you"
say "may want to skip this test so that you can see the"
say "records written to the log in the previous demonstration."
say "(If you elected to write any records.)"
say
say "If you previously ran this example and saved the Application"
say "log, you may want to move the back up file to a different"
say "location.  The same back up file name is used each time the"
say "example executes."

ok = doPause(.true)
if ok then do
  signal on syntax name clearError
  if backupFile \== "" then session~ClearLog("Application", backupFile)   -- ooDialog: log~clear(, , backupFile)
  else session~ClearLog("Application")
  signal off syntax
  say "The Application event log was cleared successfully."
end

return 0   /* leave program */

clearError:
say "Error clearing the Application event log:" condition("O")~message
return 0

::requires "net.cls"                                     -- ooDialog: ::requires "winsystm.cls"

/* (.NET version) A log's number of records, first and last record numbers,
   and whether it is full; or the error's message (the Security log, not
   being an administrator) */
::routine logInfo
  use strict arg log, session
  signal on syntax
  d = .directory~new
  entries = log~Entries
  d~number = entries~Count
  if d~number > 0 then do
    d~first = entries[0]~Index
    d~last = entries[d~number - 1]~Index
  end
  else do; d~first = 0; d~last = 0; end
  d~full = .false
  info = session~GetLogInformation(log~Log, "LogName")
  if info~IsLogFull \== .nil then d~full = info~IsLogFull
  return d
syntax:
  return condition("O")~message

/* (.NET version) count records from position start, forwards or backwards:
   the original's readRecords, as an Array of EventLogEntry objects */
::routine readRecords
  use strict arg log, direction, start, count
  entries = log~Entries
  records = .array~new
  step = 1
  if direction == "BACKWARDS" then step = -1
  i = start
  do count while i >= 0 & i < entries~Count
    records~append(entries[i])
    i += step
  end
  return records

/* Routine to display the event log records */
::routine displayRecords
  use strict arg records

  say records~items "records read"

  do record over records
    say "=========================================================================="
    user = record~UserName
    if user == .nil then user = "N/A"
    say 'Type     : 'record~EntryType
    say 'Date     : 'record~TimeGenerated~ToShortDateString
    say 'Time     : 'record~TimeGenerated~ToLongTimeString
    say 'Source   : 'record~Source
    say 'ID       : 'record~InstanceId // 65536          -- (the event id, as Event Viewer shows it)
    say 'UserId   : 'user
    say 'Computer : 'record~MachineName
    say 'Detail   : 'record~Message~changeStr('0d0a'x, ' ')~changeStr('0a'x, ' ')~strip
    say 'Data     : '.net~System~Convert~ToHexString(record~Data)
  end

return records~items

/* (.NET version) A record written under a source: registered first if it is
   not (in the Application log), removed again after. The original's
   log~write(, source, type, category, id, binaryData, strings...) */
::routine writeRecord
  use strict arg source, type, category, id, binaryData, ...
  D = .net~System~Diagnostics
  strings = .context~args~section(6)
  signal on syntax
  registered = .false
  if \D~EventLog~SourceExists(source) then do
    D~EventLog~CreateEventSource(source, "Application")
    registered = .true
  end
  entryType = .array~of("Error", "Warning", , "Information", , , , "SuccessAudit")[type]  -- (1, 2, 4, 8)
  if type = 16 then entryType = "FailureAudit"
  bytes = .net~System~Convert~FromHexString(binaryData~c2x)
  D~EventLog~WriteEntry(source, strings~makeString("L", " "), entryType, id, .net~int16(category), bytes)
  say "Record" source "successfully written"
  if registered then D~EventLog~DeleteEventSource(source)
  return
syntax:
  say "Error writing record" source":" condition("O")~message
  return

/* Simple routine to do a logical into text */
::routine logicalToText
  use strict arg logical
  if logical then return "True"
  else return "False"

/* Simple routine to pause the program */
::routine doPause
  use arg confirm

  say
  if confirm then do
    say "Continue? (y/n)"
    if .autoRun then do; say "n  (unattended)"; answer = "n"; end   -- (.NET version)
    else parse lower pull answer
    ok = (answer~left(1) == 'y')
  end
  else do
    say "Press Enter to continue"
    if \.autoRun then pull                              -- (.NET version)
    ok = .true
  end
  say

return ok

::routine getWriteableFileName

  -- Find this user's Documents directory, surely that is writeable.

  documentsFolder = .net~System~Environment~GetFolderPath("MyDocuments")   -- ooDialog: Shell.Application's nameSpace(5)

  backupFile = ""

  -- Check that we got a good directory
  if SysIsFileDirectory(documentsFolder) then do
    -- Unfortunately, we can not use a network mapped drive and it is not
    -- uncommon for people to have their My Documents directory on a network
    -- share.
    if \documentsFolder~abbrev("\\"), .net~System~IO~DriveInfo~new(documentsFolder~left(1))~DriveType \= "Network" then do
      backupFile = documentsFolder || '\applicationBackup_01.evtx'
    end
  end

  if backupFile == "" then do
    -- Keep looking, see if we can write to the current directory.
    currentDir = directory()
    if canWriteToDir(currentDir) then do
      backupFile = currentDir || "\applicationBackup_01.evtx"
    end
    else do
      -- As a last resort, try the temp directory
      tempDir = value("TEMP", , 'ENVIRONMENT')
      if canWriteToDir(tempDir) then do
        backupFile = tempDir || "\applicationBackup_01.evtx"
      end
    end
  end

return backupFile

::routine canWriteToDir
  use strict arg dir

  tmpFile = dir || '\' || "tmpFileWriteTest.deleteMe"

  -- Write to the file, close it, test it, delete it.
  j = lineout(tmpFile, "Delete this file if you find it")
  j = lineout(tmpFile)
  if SysIsFile(tmpFile) then do
    answer = .true
  end
  else do
    answer = .false
  end

  j = SysFileDelete(tmpFile)

return answer
