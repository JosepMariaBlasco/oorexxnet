# Builds the ooRexx/.NET bridge (prototype) on Windows, as build.sh does on
# Linux and macOS, into OUT (default %USERPROFILE%\build\rexxnet):
# Rexx.Net.dll + its runtimeconfig (managed), rexxnet.dll (native), net.cls,
# CLR.CLS.
#
#   powershell -ExecutionPolicy Bypass -File bridge\build.ps1 [-Out DIR]
#
# Needs: ooRexx 5, 64-bit, with its api\ folder (rexx.exe on the PATH, or
# REXX_HOME); a .NET 8 SDK or later (dotnet on the PATH, or DOTNET_ROOT);
# Visual Studio or its Build Tools with the C++ workload (cl.exe on the PATH,
# else found with vswhere). Windows PowerShell 5.1 or PowerShell 7.
# The managed project is built from a copy (no bin\ obj\ in the project).
param([string]$Out = (Join-Path $env:USERPROFILE 'build\rexxnet'))
# 'Continue', every step checked explicitly: with 'Stop', Windows PowerShell
# 5.1 turns a native command's stderr into a terminating error when redirected
$ErrorActionPreference = 'Continue'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'; $env:DOTNET_NOLOGO = '1'
$here = $PSScriptRoot

# ooRexx: REXX_HOME, else the installation of the rexx.exe on the PATH
$rexxHome = $env:REXX_HOME
if (-not $rexxHome) {
    $cmd = Get-Command rexx.exe -ErrorAction SilentlyContinue
    if (-not $cmd) { throw 'ooRexx not found: put rexx.exe on the PATH, or set REXX_HOME' }
    $rexxHome = Split-Path $cmd.Source
}
$api = Join-Path $rexxHome 'api'
if (-not (Test-Path (Join-Path $api 'oorexxapi.h'))) {
    throw "no oorexxapi.h in $api (ooRexx's api\ folder: set REXX_HOME to its installation)"
}

# .NET: DOTNET_ROOT, else the dotnet.exe on the PATH, else its usual place;
# nethost from the SDK's newest host pack
$dotnetRoot = $env:DOTNET_ROOT
if (-not $dotnetRoot) {
    $d = Get-Command dotnet.exe -ErrorAction SilentlyContinue
    if ($d) { $dotnetRoot = Split-Path $d.Source } else { $dotnetRoot = Join-Path $env:ProgramFiles 'dotnet' }
}
$dotnet = Join-Path $dotnetRoot 'dotnet.exe'
$packs = Join-Path $dotnetRoot 'packs\Microsoft.NETCore.App.Host.win-x64'
if (-not (Test-Path $packs)) { throw "no .NET host pack in $packs (a .NET 8 SDK or later is needed; set DOTNET_ROOT)" }
$hostpk = Get-ChildItem $packs -Directory |
    Sort-Object { try { [version]($_.Name -replace '-.*$', '') } catch { [version]'0.0' } } |
    Select-Object -Last 1
$native = Join-Path $hostpk.FullName 'runtimes\win-x64\native'

# The C++ compiler: cl.exe, or Visual Studio's developer environment (x64)
if (-not (Get-Command cl.exe -ErrorAction SilentlyContinue)) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path $vswhere)) { throw 'no C++ compiler: install Visual Studio or its Build Tools, with "Desktop development with C++"' }
    $vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (-not $vs) { throw 'Visual Studio has no C++ tools: add "Desktop development with C++"' }
    Import-Module (Join-Path $vs 'Common7\Tools\Microsoft.VisualStudio.DevShell.dll')
    Enter-VsDevShell -VsInstallPath $vs -SkipAutomaticLocation -DevCmdArguments '-arch=x64 -host_arch=x64' | Out-Null
}
if (-not (Get-Command cl.exe -ErrorAction SilentlyContinue)) { throw 'cl.exe not found, even in the Visual Studio developer environment' }

$work = Join-Path ([IO.Path]::GetTempPath()) ('rexxnet-' + [guid]::NewGuid())
New-Item -ItemType Directory -Force $work, $Out | Out-Null
try {
    $dll = Join-Path $Out 'Rexx.Net.dll'
    if (Test-Path $dll) { Remove-Item $dll }      # a failed build must not leave the old one passing
    Copy-Item -Recurse (Join-Path $here 'managed') (Join-Path $work 'managed') -ErrorAction Stop
    Copy-Item -Recurse (Join-Path $here 'rexx') (Join-Path $work 'rexx') -ErrorAction Stop   # (built into Rexx.Net)
    & $dotnet build (Join-Path $work 'managed') -c Release -o $Out -nologo -v q
    if ($LASTEXITCODE -or -not (Test-Path $dll)) { throw 'the managed build failed' }

    # The runtime also gets the Windows Desktop framework, when installed (as
    # with the .NET SDK): Windows Forms, System.Drawing, SystemSounds, the
    # event log, SystemEvents. Written without a BOM (hostfxr reads it).
    # REXXNET_NO_DESKTOP=1 leaves it out. The config as built stays as
    # Rexx.Net.core.runtimeconfig.json: rexxnet's fallback when .NET already
    # runs without that framework (a .NET application hosting ooRexx).
    $config = Join-Path $Out 'Rexx.Net.runtimeconfig.json'
    $coreConfig = Join-Path $Out 'Rexx.Net.core.runtimeconfig.json'
    if (Test-Path $coreConfig) { Remove-Item $coreConfig }
    if ((Test-Path (Join-Path $dotnetRoot 'shared\Microsoft.WindowsDesktop.App')) -and $env:REXXNET_NO_DESKTOP -ne '1') {
        Copy-Item $config $coreConfig -ErrorAction Stop
        $json = Get-Content $config -Raw | ConvertFrom-Json
        $core = $json.runtimeOptions.framework
        $desktop = [pscustomobject]@{ name = 'Microsoft.WindowsDesktop.App'; version = $core.version }
        $json.runtimeOptions.PSObject.Properties.Remove('framework')
        $json.runtimeOptions | Add-Member -NotePropertyName frameworks -NotePropertyValue @($core, $desktop)
        [IO.File]::WriteAllText($config, ($json | ConvertTo-Json -Depth 10))
    }

    # /MT: libnethost.lib is built against the static C runtime (and says so:
    # a /MD build fails to link); its registry lookups need advapi32; ole32:
    # CoInitializeEx (the starting thread an STA)
    Push-Location $work                             # (the .obj, .lib, .exp go here)
    try {
        & cl.exe /nologo /LD /EHsc /O2 /MT /std:c++17 /W3 /DNETHOST_USE_AS_STATIC "/I$api" "/I$native" `
            (Join-Path $here 'native\rexxnet.cpp') "/Fe$(Join-Path $Out 'rexxnet.dll')" `
            /link (Join-Path $native 'libnethost.lib') advapi32.lib ole32.lib /IMPLIB:rexxnet.lib
        if ($LASTEXITCODE) { throw 'the native build (cl) failed' }
    } finally { Pop-Location }
    Copy-Item (Join-Path $here 'rexx\net.cls'), (Join-Path $here 'rexx\CLR.CLS') $Out -ErrorAction Stop
    Write-Host "built: $Out"
} finally {
    Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}
