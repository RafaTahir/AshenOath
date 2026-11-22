$ErrorActionPreference = 'Stop'
$powershell = 'C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
$cases = @(
    @('mill','exposed',$false), @('mill','burned',$true), @('mill','exposed',$true),
    @('senn','exile',$false), @('senn','punished',$false), @('senn','exile',$true), @('senn','punished',$true),
    @('halvern','released',$false), @('halvern','destroyed',$false), @('halvern','released',$true), @('halvern','destroyed',$true),
    @('assembly','kael',$false), @('assembly','edric',$false), @('assembly','kael',$true), @('assembly','edric',$true)
)
foreach ($case in $cases) {
    $id = "$($case[0])-$($case[1])" + $(if ($case[2]) {'-reload'} else {''})
    $stdout = "$PSScriptRoot\$id.wrapper.log"
    $stderr = "$PSScriptRoot\$id.wrapper.err"
    if (Test-Path -LiteralPath $stdout) {throw 'Matrix must not overwrite evidence'}
    $p = $null
    try {
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File $PSScriptRoot\run.ps1 -Group $($case[0]) -Choice $($case[1])" + $(if ($case[2]) {' -Reload'} else {''})
        $p = Start-Process $powershell -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        $null = $p.Handle
        if (-not $p.WaitForExit(135000)) {throw "Owned wrapper timeout: $id"}
        $p.Refresh()
        if ($p.ExitCode -ne 0) {
            Get-Content $stdout -Tail 18
            Get-Content $stderr -Tail 18
            throw "$id FAILED, exit=$($p.ExitCode); matrix stopped without running downstream cases"
        }
        Write-Output "$id PASS, exit=0; full native/ownership logs retained on D:"
    } finally {
        if ($p -and -not $p.HasExited) {
            $children = @(Get-CimInstance Win32_Process | Where-Object ParentProcessId -eq $p.Id)
            foreach ($child in $children) {
                Get-CimInstance Win32_Process | Where-Object ParentProcessId -eq $child.ProcessId | ForEach-Object {Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue}
                Stop-Process -Id $child.ProcessId -Force -ErrorAction SilentlyContinue
            }
            Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
        }
    }
}
