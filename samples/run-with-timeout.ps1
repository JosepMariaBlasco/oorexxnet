# run-with-timeout.ps1 FILE ARG SECONDS: runs "rexx FILE ARG" in this console;
# kills it if it has not ended after SECONDS (for check-samples.rex, on Windows).
param([string]$File, [string]$Arg, [int]$Seconds = 90)
$p = Start-Process -FilePath "rexx" -ArgumentList "`"$File`" $Arg" -NoNewWindow -PassThru
if (-not $p.WaitForExit($Seconds * 1000)) {
    Write-Host "TIMEOUT: still running after $Seconds seconds; killed"
    $p.Kill($true)
    exit 124
}
exit $p.ExitCode
