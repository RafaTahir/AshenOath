param([ValidateSet('exposed','compelled')][string]$Choice = 'exposed',[switch]$Reload)
$ErrorActionPreference = 'Stop'
$project = 'D:\Projects\AshenOath\outputs\AshenOathTheRoadBetweenCrowns'
$origin = 'D:\Temp\AshenOath\edric_exposed_v2_fixture\AppData\Roaming\Godot\app_userdata\Ashen Oath- The Road Between Crowns'
$case = $Choice + $(if ($Reload) {'-reload'} else {''})
$profile = Join-Path $PSScriptRoot $case
$user = "$profile\AppData\Roaming\Godot\app_userdata\Ashen Oath- The Road Between Crowns"
if (Test-Path -LiteralPath "$PSScriptRoot\$case.log") {throw 'Do not overwrite completed or failed evidence'}
New-Item -ItemType Directory $user,"$profile\AppData\Local","$profile\Temp" -Force | Out-Null
$saveOrigin = if ($Reload) { "$PSScriptRoot\$Choice\AppData\Roaming\Godot\app_userdata\Ashen Oath- The Road Between Crowns" } else {$origin}
foreach ($name in @('ashen_oath_save.json','ashen_oath_autosave.json','ashen_oath_settings.json')) {
    Copy-Item -LiteralPath (Join-Path $saveOrigin $name) -Destination $user
}
$cache = Join-Path $saveOrigin 'shader_cache'
if (Test-Path -LiteralPath $cache) {Copy-Item -LiteralPath $cache -Destination $user -Recurse -Force}
$before = Get-Content "$user\ashen_oath_save.json" -Raw | ConvertFrom-Json
if ($before.zone -ne 'record_hall' -or -not $before.story_state.flags.castle_haunting_cleared) {throw 'Fixture is not the preserved genuine Record Hall checkpoint'}
if ($Reload) {
    if ($before.story_state.flags.edric_stance -ne $Choice) {throw 'Reload requires the actual preceding choice save'}
} elseif ($before.story_state.flags.edric_stance) {throw 'Pre-choice fixture was already resolved'}
$env:APPDATA = "$profile\AppData\Roaming"
$env:LOCALAPPDATA = "$profile\AppData\Local"
$env:TEMP = "$profile\Temp"
$env:TMP = "$profile\Temp"
$script = if ($Reload) { "$PSScriptRoot\reload.gd" } else {'res://tools/verify_opening_real_input_native.gd'}
$p = $null
try {
    $arguments = "--path $project --rendering-method gl_compatibility --rendering-driver opengl3_angle --script $script -- --continue-edric --edric-$Choice"
    $p = Start-Process 'C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "$PSScriptRoot\$case.log" -RedirectStandardError "$PSScriptRoot\$case.err"
    $null = $p.Handle
    if (-not $p.WaitForExit(120000)) {throw "Owned $case timeout"}
    $p.Refresh()
    Get-Content "$PSScriptRoot\$case.log" -Tail 10
    Get-Content "$PSScriptRoot\$case.err" -Tail 14
    Write-Output "Owned $case exit=$($p.ExitCode); preserved source fixture; genuine save copied, not edited. Repeat cache, not cold/FPS acceptance."
    if ($p.ExitCode -ne 0 -or (Get-Content "$PSScriptRoot\$case.err" -Raw) -match '(?m)^ERROR:|^SCRIPT ERROR:|ObjectDB instances leaked') {exit 1}
} finally {
    if ($p -and -not $p.HasExited) {
        Get-CimInstance Win32_Process | Where-Object ParentProcessId -eq $p.Id | ForEach-Object {Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue}
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }
}
