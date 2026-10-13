/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 1995, 2004 IBM Corporation. All rights reserved.             */
/* Copyright (c) 2005-2018 Rexx Language Association. All rights reserved.    */
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
/* Name: REGISTRY.REX                                                       */
/* Type: Open Object Rexx Script                                            */
/*                                                                          */
/* Description:                                                             */
/* This examples demonstrates the use of the WindowsRegistry class to read  */
/* and manipulate the Windows registry                                      */
/*                                                                          */
/****************************************************************************/


/* (.NET version of ooDialog's winsystem\registry.rex: winsystm.cls's
   WindowsRegistry is .NET's Microsoft.Win32.Registry. A key is a .NET
   RegistryKey, not a handle in Current_Key: Registry~LocalMachine,
   ~CurrentUser are the roots, OpenSubKey(name [, writable]) opens one (.nil
   when it is not there), CreateSubKey creates or opens one, GetSubKeyNames
   and GetValueNames list, GetValue / GetValueKind / SetValue / DeleteValue /
   DeleteSubKey as the original's getValue, setValue, deleteValue, delete.
   What .NET does not have:
   - a key's class name and its last write time (Query): the counts only;
   - RegSaveKey / RegRestoreKey (Save, Restore, which need the backup and
     restore privileges, an administrator's): saveKey and restoreKey below
     write and read a .reg file (Windows Registry Editor Version 5.00, as
     regedit's export: regedit can import it too), from .NET's reads and
     writes. The files go to the temporary folder, not to the root of the
     drive (where a user cannot write today).
   The System key is opened to query only (the original asked for write
   access too, and wrote nothing; a user who is not an administrator is
   refused it), and its control set is the first subkey that has a Control
   key (the original took the first subkey: today's first one, ActivationBroker,
   has none). Unattended (argument "auto"): no message boxes, no regedit,
   and the key it creates and the files it writes are removed at the end.) */

parse arg arg1
auto = arg1~strip~caselessEquals("auto")                 -- (.NET version) unattended

regeditor = "regedit.exe"

tempDir = .net~System~IO~Path~GetTempPath               -- (.NET version: the original wrote to "\")
FileControl = tempDir || "control.reg"
FileNewKey = tempDir || "testuser.reg"

Reg = .net~Microsoft~Win32~Registry                      -- ooDialog: r = .WindowsRegistry~new

/* There is no Current_Key: each RegistryKey is an object of its own. */

/* Open the HKEY_LOCAL_MACHINE\System key, to query only. */
syskey = Reg~LocalMachine~OpenSubKey("SYSTEM")           -- ooDialog: r~open(,"SYSTEM","QUERY WRITE")
if syskey \== .nil then do
   keys = syskey~GetSubKeyNames                         -- ooDialog: r~List(,keys.)
   bk = .nil
   do name over keys while bk == .nil                   -- (.NET version: the first with a Control key)
      bk = syskey~OpenSubKey(name"\Control")
      first = name
   end
   if bk \== .nil then do

      /* Display information about the Control key. */
      say "Control has" bk~SubKeyCount "subkeys, and" bk~ValueCount "values."   -- ooDialog: q. = r~Query (and its class, date, time)

      do name over bk~GetSubKeyNames                    /* list all subkeys of Control */
          say name
      end
      say "-----"

      /* list all values of the Control key */
      do name over bk~GetValueNames                     -- ooDialog: r~ListValues(,vals.)
         say name "=" valueText(bk, name) "("bk~GetValueKind(name)")"
      end
      /* save HKEY_LOCAL_MACHINE\System\XXX\Control to a file */
      if .net~System~IO~File~Exists(FileControl) then say "The file" FileControl "already exists"
      else do
         call saveKey bk, FileControl                   -- ooDialog: r~Save(bk,FileControl)
         say "HKEY_LOCAL_MACHINE\System\"first"\Control has been saved to" FileControl
      end
      bk~Close  /* close Control key */
   end
   syskey~Close   /* close System key */
   say "-----"
end

/* open the HKEY_LOCAL_MACHINE\SOFTWARE key. */
sw = Reg~LocalMachine~OpenSubKey("SOFTWARE")
if sw \== .nil then do
   say "subkeys =" sw~SubKeyCount                       -- ooDialog: kinfo. = r~query (class name, date, time too)
   say "values =" sw~ValueCount
   say "-- list --"
   do name over sw~GetSubKeyNames
      say name
   end
   say "-----"
   sw~Close  /* close HKEY_LOCAL_MACHINE\SOFTWARE */
end

/* create a new subkey under HKEY_CURRENT_USER and modify it */
savekey = .nil
Kind = .net~Microsoft~Win32~RegistryValueKind
savekey = Reg~CurrentUser~CreateSubKey("TEST_USER")    -- ooDialog: r~create(r~Current_User,"TEST_USER")
if savekey \== .nil then do

   savekey~SetValue("", "Test User")  /* set the default value */

   /* add other values */
   savekey~SetValue("PROFESSION", "Developer")
   savekey~SetValue("BIRTHYEAR", .net~int32(1972), Kind~DWord)   /* type NUMBER for numbers */
   savekey~SetValue("LOCATION", "EUROPE", Kind~ExpandString)

   /* Multiple strings: an array of them, given to .NET as a string[] (the
      original joined them with "0"x) */
   A_Multi_SZ = .array~of("This is the first line", "This is the second line", "And this is the last line!")
   savekey~SetValue("ADDITIONAL", .net~as(A_Multi_SZ, "string[]"), Kind~MultiString)  /* use type MULTI */
   call explore "Explore key \\HKEY_CURRENT_USER\TEST_USER and close RegEdit to continue.", auto

   /* retrieve the previously added values */
   say "The following entries have been added to the registry:"
   say "default:" savekey~GetValue("")
   say "PROFESSION:" savekey~GetValue("PROFESSION")
   say "BIRTHYEAR:" savekey~GetValue("BIRTHYEAR") "of type" savekey~GetValueKind("BIRTHYEAR")
   say "LOCATION:" savekey~GetValue("LOCATION")         -- (.NET expands it, as the original's getvalue)

   say "ADDITIONAL:"
   if savekey~GetValueKind("ADDITIONAL") = "MultiString" then    /* that's what we expect */
   do line over savekey~GetValue("ADDITIONAL")          -- (.NET gives the strings as an array)
       say "   " line
   end

   savekey~DeleteValue("BIRTHYEAR")   /* delete a value */
   d1 = savekey~CreateSubKey("OREXX\DATA1")  /* Create a key and a subkey at once */
   d1~Close
   lk = savekey~CreateSubKey("OREXX\DATA2")  /* Create another key + subkey */
   if lk \== .nil then do
      lk~Close
      savekey~DeleteSubKey("OREXX\DATA2")  /* Delete subkey DATA2 */
   end
end

if savekey \== .nil then do
   /* save newly created key TEST_USER to a file */
   if .net~System~IO~File~Exists(FileNewKey) then say "The file" FileNewKey "already exists"
   else do
       call saveKey savekey, FileNewKey
       say "\\HKEY_CURRENT_USER\TEST_USER has been saved to" FileNewKey
   end
   savekey~Close
   /* DeleteSubKey deletes a key without subkeys, so delete the key's subkeys
      first step by step (DeleteSubKeyTree would delete them all at once) */
   ok = deleteKey(Reg~CurrentUser, "TEST_USER\OREXX\DATA1")
   ok = deleteKey(Reg~CurrentUser, "TEST_USER\OREXX")
   ok = deleteKey(Reg~CurrentUser, "TEST_USER")  /* and now delete the key */

   if ok then do
       call explore "\\HKEY_CURRENT_USER\TEST_USER has been deleted." ,
             || " Explore and close RegEdit to continue.", auto
   end
   else say "Delete of key TEST_USER failed"
   back = Reg~CurrentUser~CreateSubKey("TEST_USER")    /* create key again to restore */
   if back \== .nil then do
       back~Close
       if restoreKey(Reg~CurrentUser, FileNewKey) then do   -- ooDialog: r~Restore(,FileNewKey)
           call explore "\\HKEY_CURRENT_USER\TEST_USER has been restored." ,
                || " Explore and close RegEdit to continue.", auto
           say "Restored:"
           k = Reg~CurrentUser~OpenSubKey("TEST_USER")
           do name over k~GetValueNames
              say "   " name "=" valueText(k, name) "("k~GetValueKind(name)")"
           end
           do name over k~GetSubKeyNames
              say "    subkey" name
           end
           k~Close
           if \auto then say "Please remove \\HKEY_CURRENT_USER\TEST_USER using" RegEditor
       end
       else say "Restoring failed"
   end
   if auto then do                                      -- (.NET version, unattended: leave nothing behind)
       Reg~CurrentUser~DeleteSubKeyTree("TEST_USER", .false)
       .net~System~IO~File~Delete(FileControl)
       .net~System~IO~File~Delete(FileNewKey)
       say "TEST_USER and the files removed."
   end
   else say "The files" FileControl "and" FileNewKey "have been created, please delete manually to cleanup."
end
return 0

::requires "net.cls"                                     -- ooDialog: ::requires "winsystm.cls"

/* (.NET version) A message box, then regedit, waited for: the original's
   RxMessageBox and "REGEDIT". Nothing when unattended. regedit asks to run
   as administrator: started through the shell, which asks the user. */
::routine explore
  use strict arg msg, auto
  if auto then return
  .net~System~Windows~Forms~MessageBox~Show(msg, "WindowsRegistry")
  psi = .net~System~Diagnostics~ProcessStartInfo~new("regedit.exe")
  psi~UseShellExecute = .true
  p = .net~System~Diagnostics~Process~Start(psi)
  if p \== .nil then p~WaitForExit
  return

/* (.NET version) A value as text: numbers in decimal, binary data in hex,
   several strings joined by " | " */
::routine valueText
  use strict arg key, name
  v = key~GetValue(name, "", .net~Microsoft~Win32~RegistryValueOptions~DoNotExpandEnvironmentNames)
  caseOf = key~GetValueKind(name)~string
  select case caseOf                                     -- (not the expression itself: ooRexx bug, SELECT CASE: unreported)
    when "Binary" then return .net~System~Convert~ToHexString(v)
    when "MultiString" then return v~makeString("L", " | ")
    otherwise return v
  end

/* (.NET version) DeleteSubKey: .true when it went, as the original's 0 */
::routine deleteKey
  use strict arg root, name
  signal on syntax
  root~DeleteSubKey(name)
  return .true
syntax:
  say "  " condition("O")~message
  return .false

/* (.NET version) The original's Save: the key, its values and its subkeys
   written as regedit exports them (UTF-16, "Windows Registry Editor Version
   5.00") */
::routine saveKey
  use strict arg key, file
  out = .mutableBuffer~new("Windows Registry Editor Version 5.00" || "0d0a"x)
  call saveTree key, out
  .net~System~IO~File~WriteAllText(file, out~string, .net~System~Text~Encoding~Unicode)
  return

::routine saveTree
  use strict arg top, out
  numeric digits 20                                      -- (a DWORD's 4294967296)
  NoExpand = .net~Microsoft~Win32~RegistryValueOptions~DoNotExpandEnvironmentNames
  -- The keys in the order regedit writes them, without recursion: a key, then
  -- its subkeys and theirs (a queue of the keys still to write, the subkeys of
  -- each going in front of those already there).
  pending = .queue~new
  pending~queue(top)
  do while pending~items > 0
    key = pending~pull
    out~append("0d0a"x || "[" || key~Name || "]" || "0d0a"x)
    do name over key~GetValueNames
      if name == "" then line = "@="
      else line = '"' || regQuote(name) || '"='
      v = key~GetValue(name, .nil, NoExpand)
      caseOf = key~GetValueKind(name)~string
      select case caseOf                                 -- (not the expression itself: ooRexx bug, SELECT CASE: unreported)
        when "String" then line ||= '"' || regQuote(v) || '"'
        when "DWord" then do
          if v < 0 then v += 4294967296                 -- (.NET gives an Int32)
          line ||= "dword:" || d2x(v, 8)~lower
        end
        when "QWord" then line ||= "hex(b):" || hexBytes(.net~System~BitConverter~GetBytes(.net~int64(v)))
        when "ExpandString" then line ||= "hex(2):" || hexBytes(utf16(v || "00"x))
        when "MultiString" then line ||= "hex(7):" || hexBytes(utf16(v~makeString("L", "00"x) || "0000"x))
        when "Binary" then line ||= "hex:" || hexBytes(v)
        otherwise line ||= "hex(0):"
      end
      out~append(line || "0d0a"x)
    end
    subs = .array~new
    do name over key~GetSubKeyNames
      sub = openSubKey(key, name)                        -- (.nil: not there, or not allowed)
      if sub \== .nil then subs~append(sub)
    end
    do i = subs~items to 1 by -1
      pending~push(subs[i])
    end
    if key \== top then key~Close
  end
  return

/* A subkey opened to read, or .nil when it is not there or not allowed (a
   SecurityException: some of the System key's need an administrator) */
::routine openSubKey
  use strict arg key, name
  signal on syntax
  return key~OpenSubKey(name)
syntax:
  return .nil

::routine regQuote
  use strict arg s
  return s~changeStr("\", "\\")~changeStr('"', '\"')

::routine utf16
  use strict arg s
  return .net~System~Text~Encoding~Unicode~GetBytes(s)

/* bytes as regedit writes them: "48,00,65,00" */
::routine hexBytes
  use strict arg bytes
  if bytes~items = 0 then return ""
  return .net~System~BitConverter~ToString(bytes)~changeStr("-", ",")~lower

/* (.NET version) The original's Restore: the keys and values of a file that
   saveKey wrote (or regedit exported: lines continued with "\" too), put
   back under the root they name. .true when it worked. */
::routine restoreKey
  use strict arg root, file
  signal on syntax
  Kind = .net~Microsoft~Win32~RegistryValueKind
  Conv = .net~System~Convert
  text = .net~System~IO~File~ReadAllText(file)            -- (the BOM says UTF-16)
  lines = text~changeStr("0d0a"x, "0a"x)~changeStr("\" || "0a"x || "  ", "")~makeArray("0a"x)
  prefix = root~Name || "\"
  key = .nil
  do line over lines
    select
      when line~strip == "" | line~abbrev("Windows Registry") then nop
      when line~left(1) == "[" then do
        if key \== .nil then key~Close
        path = line~substr(2, line~length - 2)
        if \path~caselessAbbrev(prefix) then raise syntax 93.900 array ("not under" root~Name":" path)
        key = root~CreateSubKey(path~substr(prefix~length + 1))
      end
      otherwise do
        if line~left(1) == "@" then do; name = ""; rest = line~substr(3); end
        else do
          q = unquote(line)                           -- the name, and what follows it
          name = q[1]; rest = q[2]~substr(2)          -- (after its "=")
        end
        select
          when rest~left(1) == '"' then key~SetValue(name, unquote(rest)[1])
          when rest~abbrev("dword:") then key~SetValue(name, .net~int32(rest~substr(7)~x2d(8)), Kind~DWord)
          otherwise do
            parse var rest kindText ":" hex
            bytes = Conv~FromHexString(hex~changeStr(",", ""))
            select case kindText
              when "hex(2)" then key~SetValue(name, fromUtf16(bytes)~strip("T", "00"x), Kind~ExpandString)
              when "hex(7)" then key~SetValue(name, .net~as(fromUtf16(bytes)~strip("T", "00"x)~makeArray("00"x), "string[]"), Kind~MultiString)
              when "hex(b)" then key~SetValue(name, .net~System~BitConverter~ToInt64(bytes, 0), Kind~QWord)
              otherwise key~SetValue(name, bytes, Kind~Binary)
            end
          end
        end
      end
    end
  end
  if key \== .nil then key~Close
  return .true
syntax:
  say "  " condition("O")~message
  return .false

/* A quoted string at the start of s: its text, unescaped, and what follows
   its closing quote */
::routine unquote
  use strict arg s
  out = .mutableBuffer~new
  i = 2
  do while i <= s~length
    c = s~subchar(i)
    if c == "\" then do; out~append(s~subchar(i + 1)); i += 2; iterate; end
    if c == '"' then return .array~of(out~string, s~substr(i + 1))
    out~append(c); i += 1
  end
  return .array~of(out~string, "")

::routine fromUtf16
  use strict arg bytes
  return .net~System~Text~Encoding~Unicode~GetString(bytes)
