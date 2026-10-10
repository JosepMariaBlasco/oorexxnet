# Packages the bridge for Windows as a zip of binaries, for people who want to
# try it without building it: build.ps1's output, System.Speech.dll (from
# nuget.org: CLR.CLS's speech sample), bridge\dist\windows (README.txt,
# check.rex), docs\guide.md, notes\clr-compat.md and the PowerShell sample
# (hello.ps1), in one folder rexxnet\.
# The package is checked before it is zipped: check.rex run from outside the
# folder, finding rexxnet.dll through the PATH and net.cls through REXX_PATH.
#
#   powershell -ExecutionPolicy Bypass -File bridge\package-windows.ps1 [-Dest DIR]
#
# Writes rexxnet-windows-x64-YYYYMMDD-COMMIT.zip into DEST (default: the
# current directory). Needs what build.ps1 needs, and git.
param([string]$Dest = (Get-Location).Path)
$ErrorActionPreference = 'Continue'
$repo = Split-Path $PSScriptRoot

$commit = (& git -C $repo rev-parse --short HEAD)
if ($LASTEXITCODE -or -not $commit) { throw "not a git checkout: $repo" }
$commit = $commit.Trim()
$dirty = & git -C $repo status --porcelain --untracked-files=no   # (logs written into the checkout do not count)
if ($dirty) { Write-Warning "uncommitted changes in $repo : the package will not match commit $commit" }
$date = Get-Date -Format yyyyMMdd
$name = "rexxnet-windows-x64-$date-$commit"

$stage = Join-Path ([IO.Path]::GetTempPath()) ('rexxnet-pkg-' + [guid]::NewGuid())
$dir = Join-Path $stage 'rexxnet'
try {
    & (Join-Path $PSScriptRoot 'build.ps1') -Out $dir
    if (-not (Test-Path (Join-Path $dir 'rexxnet.dll'))) { throw 'the build failed' }

    # System.Speech: in .NET Framework's GAC once, a NuGet package now
    $nupkg = Join-Path $stage 'system.speech.zip'
    Invoke-WebRequest -UseBasicParsing -OutFile $nupkg https://api.nuget.org/v3-flatcontainer/system.speech/8.0.0/system.speech.8.0.0.nupkg
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($nupkg)
    try {
        $entry = $zip.Entries | Where-Object { $_.FullName -eq 'runtimes/win/lib/net8.0/System.Speech.dll' }
        if (-not $entry) { throw 'no runtimes/win/lib/net8.0/System.Speech.dll in the System.Speech package' }
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $dir 'System.Speech.dll'), $true)
    } finally { $zip.Dispose() }

    $readme = Get-Content (Join-Path $PSScriptRoot 'dist\windows\README.txt') -Raw
    $readme = $readme.Replace('@DATE@', (Get-Date -Format 'yyyy-MM-dd')).Replace('@COMMIT@', $commit)
    [IO.File]::WriteAllText((Join-Path $dir 'README.txt'), ($readme -replace "`r?`n", "`r`n"))
    Copy-Item (Join-Path $PSScriptRoot 'dist\windows\check.rex'),
              (Join-Path $repo 'docs\guide.md'),
              (Join-Path $repo 'notes\clr-compat.md'),
              (Join-Path $repo 'samples\powershell\hello.ps1') $dir -ErrorAction Stop

    # the samples: Rexx (every platform), Windows ones, and Office (the
    # Rosetta stone: each program with .OLEObject and through the bridge)
    foreach ($d in 'rexx', 'windows', 'office') {
        $to = Join-Path $dir "samples\$d"
        New-Item -ItemType Directory -Force $to | Out-Null
        Copy-Item (Join-Path $repo "samples\$d\*.rex") $to -ErrorAction Stop
    }
    Copy-Item (Join-Path $repo 'samples\README.md') (Join-Path $dir 'samples') -ErrorAction Stop
    Copy-Item (Join-Path $repo 'samples\office\README.md') (Join-Path $dir 'samples\office') -ErrorAction Stop

    # The check, as a user would run it: from elsewhere, through the variables
    # (a copy of check.rex outside the folder, so that net.cls is not found
    # next to the program)
    Copy-Item (Join-Path $dir 'check.rex') $stage
    $env:PATH = "$dir;$env:PATH"; $env:REXX_PATH = $dir
    Push-Location $stage
    try { $out = & rexx.exe check.rex nogui 2>&1 | Out-String; $rc = $LASTEXITCODE } finally { Pop-Location }
    Write-Host $out
    if ($rc -ne 0 -or $out -notmatch 'Windows Forms: ok') { throw "check.rex failed (rc $rc)" }

    New-Item -ItemType Directory -Force $Dest | Out-Null
    $zipFile = Join-Path (Resolve-Path $Dest) "$name.zip"
    if (Test-Path $zipFile) { Remove-Item $zipFile }
    [IO.Compression.ZipFile]::CreateFromDirectory($dir, $zipFile, [IO.Compression.CompressionLevel]::Optimal, $true)
    Write-Host "packaged: $zipFile"
} finally {
    Remove-Item -Recurse -Force $stage -ErrorAction SilentlyContinue
}
