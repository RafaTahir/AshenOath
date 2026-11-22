param([string]$Suffix = '')
$ErrorActionPreference = 'Stop'
$base = $PSScriptRoot
$project = 'D:\Projects\AshenOath\outputs\AshenOathTheRoadBetweenCrowns'
$original = 'D:\Temp\AshenOath\bandit_identity_candidate_v3\profile\AppData\Roaming\Godot\app_userdata\Ashen Oath- The Road Between Crowns'
$profile = Join-Path $base ('profile' + $Suffix)
$destination = Join-Path $profile 'AppData\Roaming\Godot\app_userdata\Ashen Oath- The Road Between Crowns'
$null = New-Item -ItemType Directory -Path $destination -Force
foreach ($name in @('ashen_oath_save.json', 'ashen_oath_settings.json')) {
    Copy-Item -LiteralPath (Join-Path $original $name) -Destination (Join-Path $destination $name)
}
$originalHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $original 'ashen_oath_save.json')).Hash
$env:APPDATA = Join-Path $profile 'AppData\Roaming'
$env:LOCALAPPDATA = Join-Path $profile 'AppData\Local'
$env:TEMP = Join-Path $base 'temp'
$env:TMP = $env:TEMP
$null = New-Item -ItemType Directory -Path $env:TEMP -Force
$env:ASHEN_PERF_PRESET = 'balanced'
$exe = 'D:\Temp\AshenOath\godot-4.6.3\Godot_v4.6.3-stable_win64.exe'
$arguments = '--path "' + $project + '" --rendering-method gl_compatibility --rendering-driver opengl3_angle --script res://tools/capture_bandit_road_recovery.gd -- --output-dir="' + (Join-Path $base ('captures' + $Suffix)) + '" --night-combat'
$process = Start-Process -FilePath $exe -ArgumentList $arguments -WorkingDirectory $project -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $base ('capture_stdout' + $Suffix + '.log')) -RedirectStandardError (Join-Path $base ('capture_stderr' + $Suffix + '.log'))
$null = $process.Handle
try {
    if (-not $process.WaitForExit(180000)) { throw 'Owned candidate capture timed out' }
    $process.WaitForExit()
    if ($originalHash -ne (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $original 'ashen_oath_save.json')).Hash) { throw 'Original genuine fixture changed' }
    Write-Output "Native capture exit: $($process.ExitCode)"
    Write-Output "Genuine fixture hash: $($originalHash.ToLower())"
    Get-Content -LiteralPath (Join-Path $base ('capture_stdout' + $Suffix + '.log')) -Tail 15
    Get-Content -LiteralPath (Join-Path $base ('capture_stderr' + $Suffix + '.log'))
    exit $process.ExitCode
} finally {
    if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force }
    $process.Dispose()
}
