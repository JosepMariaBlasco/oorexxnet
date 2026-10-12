# PowerShell hosting ooRexx through Rexx.Net (PowerShell 7.4 or later: .NET 8+).
#
#   pwsh samples/powershell/hello.ps1 [DIR]
#
# DIR: the folder of Rexx.Net.dll (with rexxnet next to it): a build of the
# bridge (bridge/build.sh or build.ps1), or where the binary zip's installer
# put it. Default: this script's folder if Rexx.Net.dll is there; else the
# installed bridge of the rexx on the PATH (Windows: its folder; Linux and
# macOS: its lib/oorexxnet); else ~/build/rexxnet. ooRexx 5 must be
# installed. Not Windows PowerShell 5.1: it runs on .NET Framework.
param([string]$Dir = '')
function Find-RexxNet {
    if (Test-Path (Join-Path $PSScriptRoot 'Rexx.Net.dll')) { return $PSScriptRoot }
    $rexx = Get-Command rexx -ErrorAction SilentlyContinue
    if ($rexx) {
        $bin = Split-Path (Get-Item $rexx.Source).ResolvedTarget
        if (-not $bin) { $bin = Split-Path $rexx.Source }
        $installed = if ($IsWindows) { $bin } else { Join-Path (Split-Path $bin) 'lib/oorexxnet' }
        if (Test-Path (Join-Path $installed 'Rexx.Net.dll')) { return $installed }
    }
    return (Join-Path $HOME 'build/rexxnet')
}
if (-not $Dir) { $Dir = Find-RexxNet }
Add-Type -Path (Join-Path $Dir 'Rexx.Net.dll')

$rexx = [Rexx.Net.RexxInterpreter]::Create()
try {
    # Rexx code, its result as a PowerShell value
    $rexx.Run('return 6 * 7').ToString()

    # Rexx's output into PowerShell (a TextWriter)
    $out = [System.IO.StringWriter]::new()
    $rexx.Output = $out
    $rexx.Run('do i = 1 to 3; say "line" i; end') | Out-Null
    $rexx.Output = $null
    $out.ToString().TrimEnd() -split "`r?`n" | ForEach-Object { "from Rexx: $_" }

    # A PowerShell (.NET) object to Rexx, which uses it through .net
    $list = [System.Collections.Generic.List[string]]::new()
    $rexx.Run(@'
use arg list
do w over "one two three"~makeArray(" ")
  list~Add(w~upper)
end
return list~Count
::requires "net.cls"
'@, $list).ToString()
    $list -join ', '

    # A Rexx object in PowerShell: messages through Send (Rexx strings as
    # strings with ToString)
    $d = $rexx.Run('d = .directory~new; d~name = "Rexx"; d~version = 5; return d')
    $d.Send('name').ToString() + ' ' + $d.Send('version').ToString() + ', ' + $d.Send('items').ToString() + ' items'
}
finally { $rexx.Dispose() }
