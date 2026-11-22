$ErrorActionPreference = 'Stop'
$run = $PSScriptRoot
$project = 'D:\Projects\AshenOath\outputs\AshenOathTheRoadBetweenCrowns'
if (Test-Path -LiteralPath "$run\header.json") { throw 'Existing evidence: refusing overwrite' }
foreach ($folder in @('AppData\Roaming','AppData\Local','compile')) {
    New-Item -ItemType Directory -Path (Join-Path $run $folder) -Force | Out-Null
}
$env:APPDATA = "$run\AppData\Roaming"
$env:LOCALAPPDATA = "$run\AppData\Local"
$env:TEMP = "$run\compile"
$env:TMP = $env:TEMP
Add-Type -Path "$run\StackSampler.cs"
$console = $null
$native = $null
try {
    $console = Start-Process 'C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe' -WorkingDirectory $project -ArgumentList "--path . --rendering-method gl_compatibility --rendering-driver opengl3_angle --script $run\trace.gd -- --zone=greyfen" -WindowStyle Hidden -PassThru -RedirectStandardOutput "$run\native.log" -RedirectStandardError "$run\native.err"
    $null = $console.Handle
    $deadline = [DateTime]::UtcNow.AddSeconds(45)
    while (-not (Test-Path -LiteralPath "$run\header.json") -and -not $console.HasExited -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 30 }
    if (-not (Test-Path -LiteralPath "$run\header.json")) { throw 'Missing owned native header' }
    $header = Get-Content -Raw -LiteralPath "$run\header.json" | ConvertFrom-Json
    $native = Get-Process -Id $header.pid
    $null = $native.Handle
    if ($native.Id -ne $console.Id -and (Get-CimInstance Win32_Process -Filter "ProcessId=$($native.Id)").ParentProcessId -ne $console.Id) { throw 'PID is not the owned child' }
    $summary = [AshenStackSampler]::Sample($native.Id, $run, 90)
    $summary | Set-Content -LiteralPath "$run\sampler.txt"
    $deadline = [DateTime]::UtcNow.AddSeconds(60)
    while (-not $console.HasExited -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 200 }
    if (-not $console.HasExited) { throw 'Owned verifier exceeded diagnostic bound' }
    $console.WaitForExit()
    [pscustomobject]@{wrapper_pid=$console.Id; native_pid=$native.Id; wrapper_exit=$console.ExitCode; native_exit=$native.ExitCode; diagnostic_only=$true; sampler=$summary} | ConvertTo-Json | Set-Content -LiteralPath "$run\ownership.json"
    $summary
    Get-Content -LiteralPath "$run\native.err" -Tail 6
} finally {
    if ($native -and -not $native.HasExited) { Stop-Process -Id $native.Id -Force }
    if ($console -and -not $console.HasExited) { Stop-Process -Id $console.Id -Force }
}
