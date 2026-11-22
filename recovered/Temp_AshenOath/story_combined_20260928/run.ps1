param(
    [Parameter(Mandatory)][ValidateSet('senn','halvern')][string]$Group,
    [Parameter(Mandatory)][string]$Choice,
    [Parameter(Mandatory)][string]$LegacyProfile,
    [switch]$ExpectPresent
)
$ErrorActionPreference = 'Stop'
$project = 'D:\Projects\AshenOath\outputs\AshenOathTheRoadBetweenCrowns'
$suffix = 'AppData\Roaming\Godot\app_userdata\Ashen Oath- The Road Between Crowns'
$contracts = @{
    mill = @{source='ashwing_v5_fixture';save='ashen_oath_autosave.json.bak';zone='old_mill';flag='mill_fate';quest='main_ash_at_the_mill';prerequisite='mill_encounter';next='main_soldier_without_banner';argument='--continue-soldier-road';choices=@('burned','exposed')}
    senn = @{source='senn_fight_v3_fixture';save='ashen_oath_autosave.json.bak';zone='bandit_road';flag='senn_fate';quest='main_soldier_without_banner';prerequisite='senn_confrontation';next='main_blood_under_stone';argument='--continue-senn';choices=@('exile','punished')}
    halvern = @{source='halvern_choice_v1_fixture';save='ashen_oath_save.json.bak';zone='undercroft';flag='halvern_fate';quest='main_last_witness';prerequisite='break_halvern_guard';next='main_crowns_without_mercy';argument='--continue-halvern-choice';choices=@('released','destroyed')}
    assembly = @{source='assembly_choice_v4_fixture';save='ashen_oath_save.json.bak';zone='assembly';flag='confession_method';quest='main_crowns_without_mercy';prerequisite='greyfen_assembly';next='main_hart_remembers';argument='--continue-assembly-choice';choices=@('kael','edric')}
}
$contract = $contracts[$Group]
if ($Choice -notin @('exile','punished','testimony','released','destroyed','witness')) {throw 'Unknown authored fate'}
$Reload = $true
$origin = Join-Path "D:\Temp\AshenOath\$LegacyProfile" $suffix
$case = "combined-$Choice"
$profile = Join-Path $PSScriptRoot $case
$user = Join-Path $profile $suffix
if (Test-Path -LiteralPath "$PSScriptRoot\$case.log") {throw 'Never overwrite completed/failed evidence'}
New-Item -ItemType Directory $user,"$profile\AppData\Local","$profile\Temp" -Force | Out-Null
$sourceSave = Join-Path $origin 'ashen_oath_save.json'
$sourceHash = (Get-FileHash -LiteralPath $sourceSave).Hash
$before = Get-Content -LiteralPath $sourceSave -Raw | ConvertFrom-Json
if ($before.zone -ne $contract.zone) {throw 'Wrong genuine checkpoint zone'}
if ($Reload) {
    if ($before.story_state.flags.($contract.flag) -ne $Choice -or -not $before.quests.completed.($contract.quest) -or -not $before.quests.active.($contract.next)) {throw 'Reload requires the actual preceding choice/manual save'}
} else {
    if ($before.story_state.flags.($contract.flag)) {throw 'Checkpoint choice already resolved'}
    if (-not ($before.quests.active.($contract.quest).objectives | Where-Object { $_.id -eq $contract.prerequisite -and $_.done })) {throw 'Genuine checkpoint prerequisite incomplete'}
}
foreach ($name in @('ashen_oath_save.json','ashen_oath_autosave.json')) {
    Copy-Item -LiteralPath $sourceSave -Destination (Join-Path $user $name)
    if ((Get-FileHash (Join-Path $user $name)).Hash -ne $sourceHash) {throw 'Fixture byte-copy mismatch'}
}
Copy-Item -LiteralPath (Join-Path $origin 'ashen_oath_settings.json') -Destination $user
$cacheOrigin = $origin
$cache = Join-Path $cacheOrigin 'shader_cache'
if (Test-Path -LiteralPath $cache) {Copy-Item -LiteralPath $cache -Destination $user -Recurse -Force}
$env:APPDATA = "$profile\AppData\Roaming"
$env:LOCALAPPDATA = "$profile\AppData\Local"
$env:TEMP = "$profile\Temp"
$env:TMP = "$profile\Temp"
$p = $null
try {
    $sourceIdentity = @('tools/verify_opening_real_input_native.gd','tools/verify_story_combined_native.gd','scripts/story_actor_presence.gd','scripts/game.gd','scripts/zones/bandit_road_section.gd','scripts/zones/campaign_finale_section.gd','scripts/zones/castle_vargan_section.gd','data/campaign_dialogue.json','scripts/save_manager.gd') | ForEach-Object {[pscustomobject]@{path=$_;sha256=(Get-FileHash (Join-Path $project $_)).Hash.ToLower()}}
    $sourceIdentity | ConvertTo-Json | Set-Content -LiteralPath "$PSScriptRoot\$case.sources.json" -Encoding utf8
    $branchArguments = if($Choice -eq 'exile') {'--ledger-hidden --edric-compelled --halvern-released --assembly-edric'} else {'--ledger-copied --edric-exposed --halvern-destroyed --assembly-kael --ending-ash'}
    $arguments = "--path $project --rendering-method gl_compatibility --rendering-driver opengl3_angle --script res://tools/verify_story_combined_native.gd -- --continue-castle-road --senn-$Choice $branchArguments"
    $p = Start-Process 'C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "$PSScriptRoot\$case.log" -RedirectStandardError "$PSScriptRoot\$case.err"
    $null = $p.Handle
    if (-not $p.WaitForExit(480000)) {throw "Owned combined campaign timeout; individual movement/combat deadlines unchanged"}
    $p.Refresh()
    Get-Content "$PSScriptRoot\$case.log" -Tail 10
    Get-Content "$PSScriptRoot\$case.err" -Tail 14
    Write-Output "Owned $case exit=$($p.ExitCode); genuine source SHA256=$sourceHash; no state mutation; repeat cache, not cold/FPS acceptance."
    if ((Get-FileHash -LiteralPath $sourceSave).Hash -ne $sourceHash) {throw 'Original checkpoint changed'}
    foreach ($entry in $sourceIdentity) {if ((Get-FileHash (Join-Path $project $entry.path)).Hash.ToLower() -ne $entry.sha256) {throw 'Source changed during frozen test'}}
    if ($p.ExitCode -ne 0 -or (Get-Content "$PSScriptRoot\$case.err" -Raw) -match '(?m)^ERROR:|^SCRIPT ERROR:|ObjectDB instances leaked') {exit 1}
} finally {
    if ($p -and -not $p.HasExited) {
        Get-CimInstance Win32_Process | Where-Object ParentProcessId -eq $p.Id | ForEach-Object {Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue}
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }
}
