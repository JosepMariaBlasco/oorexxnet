/* windows-info.rex: a few Windows-only corners of .NET.
   The registry, special folders, drives, the clipboard (it needs a
   single-threaded apartment: every Rexx thread is one on Windows) and the
   system sounds. Nothing to click.                                         */

numeric digits 20                                      -- (byte counts)
reg = .net~Microsoft~Win32~Registry
key = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
say "Windows:  " reg~GetValue(key, "ProductName", "?") "build" reg~GetValue(key, "CurrentBuild", "?")

env = .net~System~Environment
say "Documents:" env~GetFolderPath("MyDocuments")      -- Environment.SpecialFolder, by name
say "Desktop:  " env~GetFolderPath("Desktop")

say "Drives:"
do d over .net~System~IO~DriveInfo~GetDrives
  if d~IsReady then
    say "  " d~Name d~DriveType~string~left(9) (d~AvailableFreeSpace % 2**30)"/"(d~TotalSize % 2**30) "GB free"
  else say "  " d~Name d~DriveType "(not ready)"
end

signal on syntax name noClipboard
clipboard = .net~System~Windows~Forms~Clipboard
old = ""
if clipboard~ContainsText then old = clipboard~GetText
clipboard~SetText("Copied by Rexx at" time())
say "Clipboard:" clipboard~GetText
if old \== "" then clipboard~SetText(old)            -- put back what was there
signal afterClipboard
noClipboard:
say "Clipboard: not available here ("condition("O")~message")"
afterClipboard:

say "Sounds:    Asterisk, then Exclamation"
.net~System~Media~SystemSounds~Asterisk~Play
call SysSleep 0.5
.net~System~Media~SystemSounds~Exclamation~Play

::requires "net.cls"
