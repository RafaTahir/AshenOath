$ErrorActionPreference = 'Stop'
$powershell = 'C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
$cases = @(@('shrine','disturbed',$false),@('shrine','bound',$false),@('shrine','disturbed',$true),@('shrine','bound',$true),@('bog','preserved',$false),@('bog','returned',$false),@('bog','preserved',$true),@('bog','returned',$true),@('names','withheld',$false),@('names','withheld',$true),@('ledger','hidden',$false),@('ledger','copied',$false),@('ledger','hidden',$true),@('ledger','copied',$true))
foreach ($case in $cases) {
    $id = "$($case[0])-$($case[1])" + $(if ($case[2]) {'-reload'} else {''})
    $stdout = "$PSScriptRoot\$id.wrapper.log"
    $stderr = "$PSScriptRoot\$id.wrapper.err"
    if (Test-Path -LiteralPath $stdout) {throw 'Never overwrite evidence'}
    $p = $null
    try {
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File $PSScriptRoot\run.ps1 -Group $($case[0]) -Choice $($case[1])" + $(if ($case[2]) {' -Reload'} else {''})
        $p = Start-Process $powershell -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        $null = $p.Handle
        if (-not $p.WaitForExit(135000)) {throw "Owned $id wrapper timeout"}
        $p.Refresh()
        if ($p.ExitCode -ne 0) {
            Get-Content $stdout -Tail 18
            Get-Content $stderr -Tail 18
            throw "$id FAILED exit=$($p.ExitCode); downstream cases not run"
        }
        Write-Output "$id PASS exit=0; source frozen, genuine save/real input, logs on D:"
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
