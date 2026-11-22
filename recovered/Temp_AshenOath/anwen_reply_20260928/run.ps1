param([Parameter(Mandatory)][ValidateSet('terms','report')][string]$Choice, [switch]$Reload)
$ErrorActionPreference = 'Stop'
$project = 'D:\Projects\AshenOath\outputs\AshenOathTheRoadBetweenCrowns'
$suffix = 'AppData\Roaming\Godot\app_userdata\Ashen Oath- The Road Between Crowns'
$origin = Join-Path 'D:\Temp\AshenOath\world001_wychwood_real_input_20260927' $suffix
$case = "anwen-$Choice" + $(if ($Reload) {'-reload'} else {''})
$profile = Join-Path $PSScriptRoot $case
$user = Join-Path $profile $suffix
if (Test-Path -LiteralPath $profile) {throw 'Never overwrite completed or failed evidence'}
$null = New-Item -ItemType Directory $user,"$profile\AppData\Local","$profile\Temp" -Force
$sourceSave = if ($Reload) {Join-Path (Join-Path "$PSScriptRoot\anwen-$Choice" $suffix) 'ashen_oath_save.json'} else {Join-Path $origin 'ashen_oath_checkpoint.json.bak'}
$sourceHash = (Get-FileHash -LiteralPath $sourceSave).Hash
$before = Get-Content -LiteralPath $sourceSave -Raw | ConvertFrom-Json
if ($before.zone -ne 'greyfen') {throw 'Wrong genuine checkpoint zone'}
if ($Reload) {
    if ($before.story_state.flags.anwen_response -ne $Choice) {throw 'Reload requires the real preceding reply save'}
} elseif ($before.story_state.flags.anwen_response -or -not ($before.quests.active.main_road_of_crows.objectives | Where-Object {$_.id -eq 'speak_anwen' -and $_.done}) -or ($before.quests.active.main_road_of_crows.objectives | Where-Object {$_.id -eq 'evidence_ready' -and $_.done})) {throw 'Not a genuine unresolved first-conversation checkpoint'}
foreach ($name in @('ashen_oath_save.json','ashen_oath_autosave.json')) {
    Copy-Item -LiteralPath $sourceSave -Destination (Join-Path $user $name)
    if ((Get-FileHash (Join-Path $user $name)).Hash -ne $sourceHash) {throw 'Fixture byte-copy mismatch'}
}
Copy-Item -LiteralPath (Join-Path $origin 'ashen_oath_settings.json') -Destination $user
$cacheOrigin = if ($Reload) {Join-Path "$PSScriptRoot\anwen-$Choice" $suffix} else {$origin}
$cache = Join-Path $cacheOrigin 'shader_cache'
if (Test-Path -LiteralPath $cache) {Copy-Item -LiteralPath $cache -Destination $user -Recurse -Force}
$env:APPDATA = "$profile\AppData\Roaming"
$env:LOCALAPPDATA = "$profile\AppData\Local"
$env:TEMP = "$profile\Temp"
$env:TMP = "$profile\Temp"
$sourceIdentity = @('tools/verify_opening_real_input_native.gd','tools/verify_anwen_reply_native.gd','scripts/game.gd','scripts/save_manager.gd','scripts/story_state.gd','data/dialogue.json') | ForEach-Object {[pscustomobject]@{path=$_;sha256=(Get-FileHash (Join-Path $project $_)).Hash.ToLower()}}
$sourceIdentity | ConvertTo-Json | Set-Content -LiteralPath "$PSScriptRoot\$case.sources.json" -Encoding utf8
$p = $null
try {
    $reloadArgument = if ($Reload) {'--anwen-reload'} else {''}
    $arguments = "--path $project --rendering-method gl_compatibility --rendering-driver opengl3_angle --script res://tools/verify_anwen_reply_native.gd -- --anwen-$Choice $reloadArgument"
    $p = Start-Process 'C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "$PSScriptRoot\$case.log" -RedirectStandardError "$PSScriptRoot\$case.err"
    $null = $p.Handle
    if (-not $p.WaitForExit(120000)) {throw "Owned $case timeout"}
    $p.Refresh()
    Get-Content "$PSScriptRoot\$case.log" -Tail 12
    Get-Content "$PSScriptRoot\$case.err" -Tail 10
    Write-Output "Owned $case exit=$($p.ExitCode); source SHA256=$sourceHash; real input; repeat cache, not FPS acceptance."
    if ((Get-FileHash -LiteralPath $sourceSave).Hash -ne $sourceHash) {throw 'Original checkpoint changed'}
    foreach ($entry in $sourceIdentity) {if ((Get-FileHash (Join-Path $project $entry.path)).Hash.ToLower() -ne $entry.sha256) {throw 'Source changed during frozen test'}}
    if ($p.ExitCode -ne 0 -or (Get-Content "$PSScriptRoot\$case.err" -Raw) -match '(?m)^ERROR:|^SCRIPT ERROR:|ObjectDB instances leaked' -or -not (Select-String -Path "$PSScriptRoot\$case.log" -SimpleMatch 'OPENING REAL INPUT NATIVE: PASS')) {exit 1}
} finally {
    if ($p -and -not $p.HasExited) {
        Get-CimInstance Win32_Process | Where-Object ParentProcessId -eq $p.Id | ForEach-Object {Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue}
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }
}
