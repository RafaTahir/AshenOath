$ErrorActionPreference = 'Stop'
$project = 'D:\Projects\AshenOath\outputs\AshenOathTheRoadBetweenCrowns'
if ((Test-Path -LiteralPath "$PSScriptRoot\census.json") -and -not (Test-Path -LiteralPath "$PSScriptRoot\invalid_primitive_api_census.json")) {
    foreach ($name in @('census.json', 'native.log', 'native.err')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $PSScriptRoot "invalid_primitive_api_$name")
    }
}
if ((Test-Path -LiteralPath "$PSScriptRoot\native.err") -and (Get-Content "$PSScriptRoot\native.err" -Raw) -match 'Parse Error') {
    Copy-Item -LiteralPath "$PSScriptRoot\native.err" -Destination "$PSScriptRoot\invalid_inferred_blend_type.err"
}
if ((Test-Path -LiteralPath "$PSScriptRoot\native.err") -and (Get-Content "$PSScriptRoot\native.err" -Raw) -match 'surface_get_primitive_type') {
    foreach ($name in @('census.json', 'native.log', 'native.err')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $PSScriptRoot "invalid_primitive_surface_api_$name")
    }
}
$profile = Join-Path $PSScriptRoot 'profile'
New-Item -ItemType Directory "$profile\AppData\Roaming", "$profile\AppData\Local", "$profile\Temp" -Force | Out-Null
$env:APPDATA = "$profile\AppData\Roaming"
$env:LOCALAPPDATA = "$profile\AppData\Local"
$env:TEMP = "$profile\Temp"
$env:TMP = "$profile\Temp"
$p = $null
try {
    $p = Start-Process 'C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe' -WorkingDirectory $project -ArgumentList "--headless --path . --script $PSScriptRoot\census.gd" -WindowStyle Hidden -PassThru -RedirectStandardOutput "$PSScriptRoot\native.log" -RedirectStandardError "$PSScriptRoot\native.err"
    $null = $p.Handle
    if (-not $p.WaitForExit(90000)) { throw 'Owned geometry census timed out' }
    $p.Refresh()
    Get-Content "$PSScriptRoot\native.log" -Tail 5
    Get-Content "$PSScriptRoot\native.err" -Tail 12
    Write-Output "Owned geometry census exit=$($p.ExitCode)"
    if ($p.ExitCode -ne 0 -or (Get-Content "$PSScriptRoot\native.err" -Raw) -match '(?m)^ERROR:|^SCRIPT ERROR:|ObjectDB instances leaked') { exit 1 }
} finally {
    if ($p -and -not $p.HasExited) {
        Get-CimInstance Win32_Process | Where-Object ParentProcessId -eq $p.Id | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }
}
