# Windows' counterpart of run.sh: builds the bridge (build.ps1) and the test
# assembly, runs phase1.rex, phase2.rex, phase3.rex (ooRexx -> .NET),
# bothways.rex (ooRexx as the host, .NET calling it back), clr.rex (the
# CLR.CLS compatibility package), then HostTests (.NET -> ooRexx).
#
#   powershell -ExecutionPolicy Bypass -File bridge\tests\run.ps1 [-Out DIR]
#
# Exit status 1 if any suite fails. Same prerequisites as build.ps1.
param([string]$Out = (Join-Path $env:USERPROFILE 'build\rexxnet'))
# 'Continue', every step checked explicitly: with 'Stop', Windows PowerShell
# 5.1 turns a native command's stderr into a terminating error when redirected
$ErrorActionPreference = 'Continue'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'; $env:DOTNET_NOLOGO = '1'
$here = $PSScriptRoot
& (Join-Path $here '..\build.ps1') -Out $Out
if (-not $?) { exit 1 }
$dotnet = Join-Path $(if ($env:DOTNET_ROOT) { $env:DOTNET_ROOT } else { Split-Path (Get-Command dotnet.exe).Source }) 'dotnet.exe'

$work = Join-Path ([IO.Path]::GetTempPath()) ('rexxnet-tests-' + [guid]::NewGuid())
New-Item -ItemType Directory -Force $work | Out-Null
$rc = 0
try {
    Copy-Item -Recurse (Join-Path $here 'TestLib') (Join-Path $work 'TestLib') -ErrorAction Stop
    & $dotnet build (Join-Path $work 'TestLib') -c Release -o (Join-Path $work 'out') "-p:RexxNetDir=$Out" -nologo -v q
    if ($LASTEXITCODE) { throw 'TestLib did not build' }
    $testlib = Join-Path $work 'out\TestLib.dll'

    # ooRexx finds rexxnet.dll by name (LoadLibrary: the PATH) and net.cls in
    # the current directory
    $env:PATH = "$Out;$env:PATH"
    Push-Location $Out
    try {
        foreach ($t in 'phase1', 'phase2', 'phase3', 'bothways', 'clr') {
            & rexx.exe (Join-Path $here "$t.rex") $testlib
            if ($LASTEXITCODE) { $rc = 1 }
        }
    } finally { Pop-Location }

    # .NET -> ooRexx: a .NET application hosting ooRexx (rexx.dll found by
    # Rexx.Net itself; for phase C, net.cls and rexxnet.dll through REXXNET_DIR)
    Copy-Item -Recurse (Join-Path $here 'HostTests') (Join-Path $work 'HostTests') -ErrorAction Stop
    & $dotnet build (Join-Path $work 'HostTests') -c Release -o (Join-Path $work 'host') "-p:RexxNetDir=$Out" -nologo -v q
    if ($LASTEXITCODE) { throw 'HostTests did not build' }
    $env:REXXNET_DIR = $Out
    & $dotnet (Join-Path $work 'host\HostTests.dll')
    if ($LASTEXITCODE) { $rc = 1 }
} finally {
    Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}
exit $rc
