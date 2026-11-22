$ErrorActionPreference = 'Stop'
$powershell = 'C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
foreach ($case in @(@('kael',$false),@('edric',$false),@('kael',$true),@('edric',$true))) {
    $id = "assembly-$($case[0])" + $(if ($case[1]) {'-reload'} else {''})
    $stdout = "$PSScriptRoot\$id.wrapper.log"
    $stderr = "$PSScriptRoot\$id.wrapper.err"
    if (Test-Path -LiteralPath $stdout) {throw 'Do not overwrite evidence'}
    $p = $null
    try {
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File $PSScriptRoot\run.ps1 -Group assembly -Choice $($case[0])" + $(if ($case[1]) {' -Reload'} else {''})
        $p = Start-Process $powershell -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        $null = $p.Handle
        if (-not $p.WaitForExit(135000)) {throw 'Owned assembly wrapper timeout'}
        $p.Refresh()
        if ($p.ExitCode -ne 0) {
            Get-Content $stdout -Tail 18
            Get-Content $stderr -Tail 18
            throw "$id FAILED exit=$($p.ExitCode); downstream not run"
        }
        Write-Output "$id PASS exit=0; clear-aisle real input, complete logs on D:"
    } finally {
        if ($p -and -not $p.HasExited) {
            foreach ($child in @(Get-CimInstance Win32_Process | Where-Object ParentProcessId -eq $p.Id)) {
                Get-CimInstance Win32_Process | Where-Object ParentProcessId -eq $child.ProcessId | ForEach-Object {Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue}
                Stop-Process -Id $child.ProcessId -Force -ErrorAction SilentlyContinue
            }
            Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
        }
    }
}
