$ErrorActionPreference = 'Stop'
$project = 'D:\Projects\AshenOath\outputs\AshenOathTheRoadBetweenCrowns'
if ((Test-Path -LiteralPath "$PSScriptRoot\bake.err") -and (Get-Content "$PSScriptRoot\bake.err" -Raw) -match 'res://geometry_') {
    Copy-Item -LiteralPath "$PSScriptRoot\bake.err" -Destination "$PSScriptRoot\invalid_relative_paths.err"
    Copy-Item -LiteralPath "$PSScriptRoot\assets" -Destination "$PSScriptRoot\invalid_relative_paths_assets" -Recurse
}
if ((Test-Path -LiteralPath "$PSScriptRoot\bake.err") -and (Get-Content "$PSScriptRoot\bake.err" -Raw) -match 'Parse Error') {
    Copy-Item -LiteralPath "$PSScriptRoot\bake.err" -Destination "$PSScriptRoot\invalid_inferred_type.err"
}
$profile = Join-Path $PSScriptRoot 'bake_profile'
New-Item -ItemType Directory "$profile\AppData\Roaming", "$profile\AppData\Local", "$profile\Temp" -Force | Out-Null
$env:APPDATA = "$profile\AppData\Roaming"
$env:LOCALAPPDATA = "$profile\AppData\Local"
$env:TEMP = "$profile\Temp"
$env:TMP = "$profile\Temp"
$p = $null
try {
    $p = Start-Process 'C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe' -WorkingDirectory $project -ArgumentList "--headless --path . --script $PSScriptRoot\bake.gd" -WindowStyle Hidden -PassThru -RedirectStandardOutput "$PSScriptRoot\bake.log" -RedirectStandardError "$PSScriptRoot\bake.err"
    $null = $p.Handle
    if (-not $p.WaitForExit(90000)) { throw 'Owned shared-geometry bake timed out' }
    $p.Refresh()
    Get-Content "$PSScriptRoot\bake.log" -Tail 6
    Get-Content "$PSScriptRoot\bake.err" -Tail 14
    Write-Output "Owned shared-geometry bake exit=$($p.ExitCode)"
    if ($p.ExitCode -ne 0 -or (Get-Content "$PSScriptRoot\bake.err" -Raw) -match '(?m)^ERROR:|^SCRIPT ERROR:|ObjectDB instances leaked') { exit 1 }
} finally {
    if ($p -and -not $p.HasExited) {
        Get-CimInstance Win32_Process | Where-Object ParentProcessId -eq $p.Id | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }
}
