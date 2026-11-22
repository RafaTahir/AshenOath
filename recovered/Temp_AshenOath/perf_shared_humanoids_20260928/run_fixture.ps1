param([switch]$Graphical)
$ErrorActionPreference = 'Stop'
$project = Join-Path $PSScriptRoot 'project'
$name = if ($Graphical) { 'native_candidate' } else { 'complete_scene_unit' }
if ((Test-Path -LiteralPath "$PSScriptRoot\$name.err") -and (Get-Content "$PSScriptRoot\$name.err" -Raw) -match 'Parse Error') {
    Copy-Item -LiteralPath "$PSScriptRoot\$name.err" -Destination "$PSScriptRoot\$name.invalid_parse.err"
}
$profile = Join-Path $PSScriptRoot "$name-profile"
New-Item -ItemType Directory "$profile\AppData\Roaming", "$profile\AppData\Local", "$profile\Temp" -Force | Out-Null
$env:APPDATA = "$profile\AppData\Roaming"
$env:LOCALAPPDATA = "$profile\AppData\Local"
$env:TEMP = "$profile\Temp"
$env:TMP = "$profile\Temp"
$args = if ($Graphical) { '--path . --rendering-method gl_compatibility --rendering-driver opengl3_angle --script res://tools/verify_perf_001.gd -- --zone=greyfen' } else { "--headless --path . --script $PSScriptRoot\unit.gd" }
$p = $null
try {
    $p = Start-Process 'C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe' -WorkingDirectory $project -ArgumentList $args -WindowStyle Hidden -PassThru -RedirectStandardOutput "$PSScriptRoot\$name.log" -RedirectStandardError "$PSScriptRoot\$name.err"
    $null = $p.Handle
    if (-not $p.WaitForExit(150000)) { throw "Owned $name timed out" }
    $p.Refresh()
    Get-Content "$PSScriptRoot\$name.log" -Tail 7
    Get-Content "$PSScriptRoot\$name.err" -Tail 14
    Write-Output "Owned $name exit=$($p.ExitCode)"
    if ($p.ExitCode -ne 0 -or (Get-Content "$PSScriptRoot\$name.err" -Raw) -match '(?m)^ERROR:|^SCRIPT ERROR:|ObjectDB instances leaked') { exit 1 }
} finally {
    if ($p -and -not $p.HasExited) {
        Get-CimInstance Win32_Process | Where-Object ParentProcessId -eq $p.Id | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }
}
