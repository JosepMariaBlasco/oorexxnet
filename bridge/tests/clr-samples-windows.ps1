# Runs BSF4ooRexx's CLR.CLS samples that need Windows (Windows Forms,
# MessageBox, system sounds, the event log, speech...), unchanged, on this
# bridge's CLR.CLS compatibility package. Most of them open windows, play
# sounds or wait for a click: the script says what each should do, runs it,
# checks its output where it can and asks the person at the keyboard whether
# it did. Everything goes to clr-samples-windows.log (in the current
# directory). See notes/clr-compat.md.
#
#   powershell -ExecutionPolicy Bypass -File bridge\tests\clr-samples-windows.ps1 [-Samples DIR] [-Out DIR]
#
# -Samples: a copy of BSF4ooRexx's samples\clr (with raffel\ and baginski\);
# fetched with `svn export` when not given (or download the snapshot of
# https://sourceforge.net/p/bsf4oorexx/code/HEAD/tree/trunk/bsf4oorexx.dev/oorexx.net/samples/clr/
# and pass its directory). -Out: the bridge's build (build.ps1 first).
# System.Speech, a package in .NET (it was in .NET Framework's GAC), is
# fetched from nuget.org for sample 15.
param([string]$Samples = '', [string]$Out = (Join-Path $env:USERPROFILE 'build\rexxnet'))
$ErrorActionPreference = 'Continue'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'; $env:DOTNET_NOLOGO = '1'
if (-not (Test-Path (Join-Path $Out 'rexxnet.dll'))) { throw "no rexxnet.dll in $Out (run bridge\build.ps1 first)" }
$log = Join-Path (Get-Location) 'clr-samples-windows.log'
"CLR.CLS samples on Windows, $(Get-Date -Format s)" | Set-Content $log

$work = Join-Path ([IO.Path]::GetTempPath()) ('clr-samples-' + [guid]::NewGuid())
$clr = Join-Path $work 'clr'
if ($Samples) { Copy-Item -Recurse $Samples $clr -ErrorAction Stop }      # (the samples write files where they run)
else {
    if (-not (Get-Command svn.exe -ErrorAction SilentlyContinue)) { throw 'no svn: pass -Samples DIR (see the comment at the top of this script)' }
    New-Item -ItemType Directory -Force $work | Out-Null
    & svn.exe export -q https://svn.code.sf.net/p/bsf4oorexx/code/trunk/bsf4oorexx.dev/oorexx.net/samples/clr $clr
    if ($LASTEXITCODE) { throw 'svn export failed' }
}

# System.Speech next to sample 15 (the bridge looks for an unknown assembly
# name as name.dll in the current directory)
try {
    $nupkg = Join-Path $work 'system.speech.zip'
    Invoke-WebRequest -UseBasicParsing -OutFile $nupkg https://api.nuget.org/v3-flatcontainer/system.speech/8.0.0/system.speech.8.0.0.nupkg
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($nupkg)
    $entry = $zip.Entries | Where-Object { $_.FullName -eq 'runtimes/win/lib/net8.0/System.Speech.dll' }
    [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $clr 'baginski\System.Speech.dll'), $true)
    $zip.Dispose()
} catch { Write-Output "(System.Speech could not be fetched: sample 15 will fail) $_" }

$env:PATH = "$Out;$env:PATH"; $env:REXX_PATH = $Out

# Dir, file, what it should do, text its output must contain ('' if none),
# and how: 'auto' (no question), 'ask' (the person says), 'stdin' (an empty
# line as its input), 'timed' (stopped after 10 seconds)
$list = @(
    @('raffel',   '01-helloworld-clr.rxj',      'prints Hello World', 'Hello World from ooRexx.NET', 'auto'),
    @('raffel',   '02-eventlog-clr.rxj',        'lists the Application event log, beeping once per entry (stopped after 10 s)', ' :: ', 'timed'),
    @('raffel',   '03-systemevents-clr.rxj',    'registers a SystemEvents.TimeChanged handler and ends (an empty line given)', 'Waiting for "TimeChanged" event', 'stdin'),
    @('raffel',   '04-forms-clr.rxj',           'a window with a progress bar and a Start button: click Start, the bar fills and the button shows the percentage; then close the window', '', 'ask'),
    @('baginski', '01-systemsounds.rxj',        'plays five system sounds (Beep, Asterisk, Exclamation, Hand, Question)', 'Question', 'ask'),
    @('baginski', '02-streamwriter.rxj',        'writes 02-textfile.txt', 'The textfile was successfully created.', 'auto'),
    @('baginski', '03-streamreader.rxj',        'reads 02-textfile.txt back', '[~~First Heading~~]', 'auto'),
    @('baginski', '04-messagebox.rxj',          'a MessageBox: click its button', '', 'ask'),
    @('baginski', '05-messagebox.advanced.rxj', 'MessageBoxes with buttons and icons: answer them; it says what you clicked', '', 'ask'),
    @('baginski', '06-process.demonstration.rxj', 'MessageBoxes, then Notepad with 02-textfile.txt, google.com in the default browser, then in "IExplore" (Edge, or an error, where there is no Internet Explorer), F11 sent twice (SendKeys), Notepad maximized: close what it opens', '', 'ask'),
    @('baginski', '07-MAC.rxj',                 'computes a MAC, writes it to 07-MAC.txt and opens that with the default editor (on Linux this last step fails)', '', 'ask'),
    @('baginski', '08-WebClient.rxj',           'downloads https://wu.ac.at and counts some HTML5 tags in it (needs the internet; the counts depend on the page as it is today: zero is possible)', 'analyzing web page at:', 'ask'),
    @('baginski', '09-clock.rxj',               'a clock in the console, every second: press a key to end it', 'The current time is', 'ask'),
    @('baginski', '10-gui.introduction.rxj',    'a "Hello World" window with an icon and a label: close it', '', 'ask'),
    @('baginski', '11-drawing.rxj',             'prints the properties of images\html5.jpg, then shows it resized in a window: close it', '', 'ask'),
    @('baginski', '12-savefile.rxj',            'a "Save Text" window: type something, click Save, a Save File dialog opens on another Rexx thread (it needs an STA thread): save, it confirms; close the window', '', 'ask'),
    @('baginski', '13-loadfile.rxj',            'an Open File dialog when the window loads: pick a text file, its text is shown; close the window', '', 'ask'),
    @('baginski', '15-text.to.speech.rxj',      'speaks a text, then reads 02-textfile.txt aloud word by word (a line "''0'' is not recognized..." is the sample''s own: its line 49 ends in a continuation); long', '', 'ask')
)

$results = @()
foreach ($s in $list) {
    $dir, $file, $what, $want, $how = $s
    $name = "$dir/$file"
    Write-Output ''; Write-Output "=== $name"; Write-Output "    should: $what"
    $outFile = Join-Path $work ($file + '.out')
    Push-Location (Join-Path $clr $dir)
    try {
        if ($how -eq 'timed') {
            $p = Start-Process rexx.exe -ArgumentList $file -NoNewWindow -PassThru `
                -RedirectStandardOutput $outFile -RedirectStandardError ($outFile + '.err')
            if (-not $p.WaitForExit(10000)) { Stop-Process -Id $p.Id -Force }
            Get-Content ($outFile + '.err') -ErrorAction SilentlyContinue | Add-Content $outFile
            Get-Content $outFile -TotalCount 5
        } elseif ($how -eq 'stdin') {
            '' | & rexx.exe $file 2>&1 | ForEach-Object { "$_" } | Tee-Object -FilePath $outFile
        } else {
            if ($how -eq 'ask') { Read-Host '    press Enter to start it' | Out-Null }
            & rexx.exe $file 2>&1 | ForEach-Object { "$_" } | Tee-Object -FilePath $outFile
        }
    } finally { Pop-Location }
    $text = (Get-Content $outFile -Raw -ErrorAction SilentlyContinue) + ''
    $seen = ($want -eq '') -or $text.Contains($want)
    $verdict = if ($seen) { 'ok' } else { "FAIL (no `"$want`" in its output)" }
    if ($how -eq 'ask') {
        $answer = Read-Host '    did it do that? [y = yes / anything else: what happened]'
        if ($answer -ne 'y' -and $answer -ne 'Y') { $verdict = "FAIL ($answer)" }
    }
    Write-Output "    -> $verdict"
    $results += "$verdict  $name"
    Add-Content $log "`n=== $name ($how): $verdict`n    should: $what"
    $lines = @($text -split "`r?`n")
    if ($lines.Count -gt 60) { $lines = $lines[0..59] + "... ($($lines.Count - 60) more lines)" }
    Add-Content $log ($lines | ForEach-Object { "    | $_" })
}

Add-Content $log "`n=== summary"
Add-Content $log $results
Write-Output ''; $results
$fails = @($results | Where-Object { $_ -notlike 'ok*' }).Count
"CLR.CLS samples on Windows: $($list.Count - $fails) of $($list.Count) ok" | Tee-Object -Append -FilePath $log
Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
Write-Output "log: $log"
