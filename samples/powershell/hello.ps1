# PowerShell hosting ooRexx through Rexx.Net (PowerShell 7.4 or later: .NET 8+).
#
#   pwsh samples/powershell/hello.ps1 [DIR]
#
# DIR: where the bridge was built (bridge/build.sh or build.ps1: Rexx.Net.dll
# and rexxnet next to it), or the folder of the Windows binary package.
# Default: this script's folder if Rexx.Net.dll is there (the Windows binary
# package), else ~/build/rexxnet. ooRexx 5 must be installed. Not Windows
# PowerShell 5.1: it runs on .NET Framework.
param([string]$Dir = $(if (Test-Path (Join-Path $PSScriptRoot 'Rexx.Net.dll')) { $PSScriptRoot } else { Join-Path $HOME 'build/rexxnet' }))
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
