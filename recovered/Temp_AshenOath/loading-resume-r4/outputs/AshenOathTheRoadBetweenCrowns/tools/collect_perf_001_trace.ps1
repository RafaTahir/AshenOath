#requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'

$project = Split-Path -Parent $PSScriptRoot
$godot = 'D:\Temp\AshenOath\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe'
$run = Join-Path 'D:\Temp\AshenOath' ('perf_wpr_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
$etl = Join-Path $run 'greyfen_cpu_gpu_disk.etl'
$stdout = Join-Path $run 'greyfen_stdout.log'
$stderr = Join-Path $run 'greyfen_stderr.log'

if (-not (Test-Path -LiteralPath $godot -PathType Leaf)) {
    throw "Godot executable missing: $godot"
}
foreach ($path in @($run, (Join-Path $run 'profile\Roaming'), (Join-Path $run 'profile\Local'), (Join-Path $run 'temp'))) {
    New-Item -ItemType Directory -Path $path -Force | Out-Null
}

$old = @{
    APPDATA = $env:APPDATA
    LOCALAPPDATA = $env:LOCALAPPDATA
    TEMP = $env:TEMP
    TMP = $env:TMP
}
$env:APPDATA = Join-Path $run 'profile\Roaming'
$env:LOCALAPPDATA = Join-Path $run 'profile\Local'
$env:TEMP = Join-Path $run 'temp'
$env:TMP = $env:TEMP

$started = $false
$gameExit = $null
$traceExit = $null
$process = $null

function Wait-ForVerifierMarker([string]$marker, [int]$seconds) {
    $deadline = (Get-Date).AddSeconds($seconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-Path -LiteralPath $stdout -PathType Leaf) {
            $tail = Get-Content -LiteralPath $stdout -Tail 120 -ErrorAction SilentlyContinue
            if ($tail | Select-String -SimpleMatch $marker -Quiet) { return $true }
        }
        if ($process.HasExited) { return $false }
        Start-Sleep -Milliseconds 250
    }
    return $false
}

try {
    $process = Start-Process -FilePath $godot `
        -ArgumentList @('--path', $project, '--rendering-driver', 'opengl3_angle', '--script', 'res://tools/verify_perf_001.gd', '--', '--zone=greyfen') `
        -WorkingDirectory $project -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
    & wpr.exe -start CPU.Light -start GPU.Light -start DiskIO.Light -filemode -recordtempto $run
    if ($LASTEXITCODE -ne 0) {
        throw "WPR start failed with exit code $LASTEXITCODE"
    }
    $started = $true
    if (-not (Wait-ForVerifierMarker 'PERF_001 greyfen_hydration ' 180)) {
        throw "Hydration marker was not observed before exit/timeout; inspect $stdout"
    }
}
finally {
    if ($started) {
        & wpr.exe -stop $etl
        $traceExit = $LASTEXITCODE
    }
    $gameTimedOut = $false
    if ($process -ne $null) {
        if (-not $process.WaitForExit(180000)) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            $gameTimedOut = $true
        } else {
            $gameExit = $process.ExitCode
        }
    }
    $env:APPDATA = $old.APPDATA
    $env:LOCALAPPDATA = $old.LOCALAPPDATA
    $env:TEMP = $old.TEMP
    $env:TMP = $old.TMP
    if ($gameTimedOut) {
        throw "Godot did not exit after the bounded trace; inspect $stdout"
    }
}

if ($traceExit -ne 0 -or -not (Test-Path -LiteralPath $etl -PathType Leaf)) {
    throw "WPR did not produce the ETL; inspect its output and $run"
}
Write-Host "PERF-001 attribution trace: $etl"
Write-Host "Native verifier exit: $gameExit (a red FPS gate is expected during diagnosis)"
Write-Host "Godot stdout: $stdout"
Write-Host "Godot stderr: $stderr"
Write-Host "ETL bytes: $((Get-Item -LiteralPath $etl).Length)"
