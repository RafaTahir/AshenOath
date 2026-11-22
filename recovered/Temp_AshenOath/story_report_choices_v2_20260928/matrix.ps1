$ErrorActionPreference = 'Stop'
$powershell = 'C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
foreach ($case in @(@('public',$false),@('retained',$false),@('public',$true),@('retained',$true))) {
    $id = "report-$($case[0])" + $(if ($case[1]) {'-reload'} else {''})
    $stdout = "$PSScriptRoot\$id.wrapper.log"
    $stderr = "$PSScriptRoot\$id.wrapper.err"
    if (Test-Path -LiteralPath $stdout) {throw 'Never overwrite evidence'}
    $p = $null
    try {
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File $PSScriptRoot\run.ps1 -Choice $($case[0])" + $(if ($case[1]) {' -Reload'} else {''})
        $p = Start-Process $powershell -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        $null = $p.Handle
        if (-not $p.WaitForExit(135000)) {throw "Owned $id wrapper timeout"}
        $p.Refresh()
        if ($p.ExitCode -ne 0) {
            Get-Content $stdout -Tail 16
            Get-Content $stderr -Tail 12
            throw "$id FAILED exit=$($p.ExitCode); downstream cases not run"
        }
        Write-Output "$id PASS exit=0; real input, frozen source and original genuine save retained"
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
