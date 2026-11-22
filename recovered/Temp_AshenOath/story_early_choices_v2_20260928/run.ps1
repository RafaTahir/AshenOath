param(
    [Parameter(Mandatory)][ValidateSet('shrine','bog','names','ledger')][string]$Group,
    [Parameter(Mandatory)][string]$Choice,
    [switch]$Reload
)
$ErrorActionPreference = 'Stop'
$project = 'D:\Projects\AshenOath\outputs\AshenOathTheRoadBetweenCrowns'
$suffix = 'AppData\Roaming\Godot\app_userdata\Ashen Oath- The Road Between Crowns'
$contracts = @{
    shrine = @{source='chapel_pier_aligned';save='ashen_oath_autosave.json.bak';zone='greyfen';flag='crow_shrine_state';quest='main_bell_beneath_greyfen';prerequisite='open_chapel';next='main_teeth_in_rain';argument='--continue-cemetery';choices=@('disturbed','bound')}
    bog = @{source='bog_fixture';save='ashen_oath_autosave.json.bak';zone='deep_wood';flag='bog_core_fate';quest='main_teeth_in_rain';prerequisite='fight_bog_wretch';next='main_names_they_burned';argument='--continue-bog';choices=@('preserved','returned')}
    names = @{source='names_choice_fixture';save='ashen_oath_autosave.json.bak';zone='greyfen';flag='names_policy';quest='main_names_they_burned';prerequisite='reconstruct_register';next='main_ash_at_the_mill';argument='--continue-names-choice';choices=@('withheld')}
    ledger = @{source='record_ledger_v1_fixture';save='ashen_oath_save.json.bak';zone='record_hall';flag='vargan_ledger_choice_made';quest='main_blood_under_stone';prerequisite='locate_record_hall';next='main_blood_under_stone';argument='--continue-record-ledger';choices=@('hidden','copied')}
}
$contract = $contracts[$Group]
if ($Choice -notin $contract.choices) {throw 'Unknown visible dialogue choice'}
$origin = Join-Path "D:\Temp\AshenOath\$($contract.source)" $suffix
$case = "$Group-$Choice" + $(if ($Reload) {'-reload'} else {''})
$profile = Join-Path $PSScriptRoot $case
$user = Join-Path $profile $suffix
if (Test-Path -LiteralPath "$PSScriptRoot\$case.log") {throw 'Never overwrite completed/failed evidence'}
New-Item -ItemType Directory $user,"$profile\AppData\Local","$profile\Temp" -Force | Out-Null
$sourceSave = if ($Reload) {Join-Path (Join-Path "$PSScriptRoot\$Group-$Choice" $suffix) 'ashen_oath_save.json'} else {Join-Path $origin $contract.save}
$sourceHash = (Get-FileHash -LiteralPath $sourceSave).Hash
$before = Get-Content -LiteralPath $sourceSave -Raw | ConvertFrom-Json
if ($before.zone -ne $contract.zone) {throw 'Wrong genuine checkpoint zone'}
if ($Reload) {
    if ($Group -eq 'ledger') {
        $selectedFlag = if ($Choice -eq 'hidden') {'vargan_ledger_hidden'} else {'vargan_ledger_left_copied'}
        if (-not $before.story_state.flags.vargan_ledger_choice_made -or -not $before.story_state.flags.$selectedFlag -or -not $before.quests.active.($contract.quest)) {throw 'Reload requires the actual preceding exclusive ledger/manual save'}
    } elseif ($before.story_state.flags.($contract.flag) -ne $Choice -or -not $before.quests.completed.($contract.quest) -or -not $before.quests.active.($contract.next)) {throw 'Reload requires the actual preceding choice/manual save'}
} else {
    if ($before.story_state.flags.($contract.flag)) {throw 'Checkpoint choice already resolved'}
    if (-not ($before.quests.active.($contract.quest).objectives | Where-Object { $_.id -eq $contract.prerequisite -and $_.done })) {throw 'Genuine checkpoint prerequisite incomplete'}
}
foreach ($name in @('ashen_oath_save.json','ashen_oath_autosave.json')) {
    Copy-Item -LiteralPath $sourceSave -Destination (Join-Path $user $name)
    if ((Get-FileHash (Join-Path $user $name)).Hash -ne $sourceHash) {throw 'Fixture byte-copy mismatch'}
}
Copy-Item -LiteralPath (Join-Path $origin 'ashen_oath_settings.json') -Destination $user
$cacheOrigin = if ($Reload) {Join-Path "$PSScriptRoot\$Group-$Choice" $suffix} else {$origin}
$cache = Join-Path $cacheOrigin 'shader_cache'
if (Test-Path -LiteralPath $cache) {Copy-Item -LiteralPath $cache -Destination $user -Recurse -Force}
$env:APPDATA = "$profile\AppData\Roaming"
$env:LOCALAPPDATA = "$profile\AppData\Local"
$env:TEMP = "$profile\Temp"
$env:TMP = "$profile\Temp"
$p = $null
try {
    $sourceIdentity = @('tools/verify_opening_real_input_native.gd','tools/verify_story_alternative_native.gd','tools/verify_story_early_alternative_native.gd','scripts/game.gd','scripts/save_manager.gd','data/campaign_dialogue.json') | ForEach-Object { [pscustomobject]@{path=$_;sha256=(Get-FileHash (Join-Path $project $_)).Hash.ToLower()} }
    $sourceIdentity | ConvertTo-Json | Set-Content -LiteralPath "$PSScriptRoot\$case.sources.json" -Encoding utf8
    $reloadArgument = if ($Reload) {'--story-choice-reload'} else {''}
    $entryArgument = if ($Reload -and $Group -eq 'shrine') {'--continue-teeth'} else {$contract.argument}
    $arguments = "--path $project --rendering-method gl_compatibility --rendering-driver opengl3_angle --script res://tools/verify_story_early_alternative_native.gd -- $entryArgument --$Group-$Choice $reloadArgument"
    $p = Start-Process 'C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe' -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "$PSScriptRoot\$case.log" -RedirectStandardError "$PSScriptRoot\$case.err"
    $null = $p.Handle
    if (-not $p.WaitForExit(120000)) {throw "Owned $case timeout"}
    $p.Refresh()
    Get-Content "$PSScriptRoot\$case.log" -Tail 10
    Get-Content "$PSScriptRoot\$case.err" -Tail 14
    Write-Output "Owned $case exit=$($p.ExitCode); genuine source SHA256=$sourceHash; no state mutation; repeat cache, not cold/FPS acceptance."
    if ((Get-FileHash -LiteralPath $sourceSave).Hash -ne $sourceHash) {throw 'Original checkpoint changed'}
    foreach ($entry in $sourceIdentity) {if ((Get-FileHash (Join-Path $project $entry.path)).Hash.ToLower() -ne $entry.sha256) {throw 'Source changed during the frozen test'}}
    if ($p.ExitCode -ne 0 -or (Get-Content "$PSScriptRoot\$case.err" -Raw) -match '(?m)^ERROR:|^SCRIPT ERROR:|ObjectDB instances leaked') {exit 1}
} finally {
    if ($p -and -not $p.HasExited) {
        Get-CimInstance Win32_Process | Where-Object ParentProcessId -eq $p.Id | ForEach-Object {Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue}
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }
}
