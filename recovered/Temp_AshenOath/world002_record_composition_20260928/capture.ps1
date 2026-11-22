$ErrorActionPreference = 'Stop'
$project = 'D:\Projects\AshenOath\outputs\AshenOathTheRoadBetweenCrowns'
$profile = Join-Path $PSScriptRoot 'capture'
$userSuffix = 'AppData\Roaming\Godot\app_userdata\Ashen Oath- The Road Between Crowns'
$user = Join-Path $profile $userSuffix
$origin = Join-Path 'D:\Temp\AshenOath\story_combined_20260928\combined-exile' $userSuffix
if (Test-Path -LiteralPath "$PSScriptRoot\capture.log") { throw 'Do not overwrite evidence' }
New-Item -ItemType Directory $user,"$profile\AppData\Local","$profile\Temp" -Force | Out-Null
Copy-Item -LiteralPath "$origin\ashen_oath_settings.json" -Destination $user
if (Test-Path -LiteralPath "$origin\shader_cache") { Copy-Item -LiteralPath "$origin\shader_cache" -Destination $user -Recurse }
$env:APPDATA = "$profile\AppData\Roaming"
$env:LOCALAPPDATA = "$profile\AppData\Local"
$env:TEMP = "$profile\Temp"
$env:TMP = "$profile\Temp"
$paths = @('scripts/game.gd','scripts/zones/castle_vargan_section.gd','scripts/visual_director.gd','tools/capture_pres_001.gd','tools/build_record_archive.gd','runtime_asset_manifest.json','assets_external/environment/props/RecordArchive_Authored.res')
$identity = $paths | ForEach-Object { [pscustomobject]@{path=$_;sha256=(Get-FileHash (Join-Path $project $_)).Hash.ToLower()} }
$identity | ConvertTo-Json | Set-Content "$PSScriptRoot\capture.sources.json" -Encoding utf8
$p = $null
try {
    $args = '--path . --rendering-method gl_compatibility --rendering-driver opengl3_angle --script res://tools/capture_pres_001.gd -- --views=RecordHall_Day,RecordHall_Night --output-dir=res://.release-gate/world002_record_scale_20260928 --reference-report=res://.release-gate/pres001_review_final_20260927/capture_report.json'
    $p = Start-Process 'C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe' -WorkingDirectory $project -ArgumentList $args -WindowStyle Hidden -PassThru -RedirectStandardOutput "$PSScriptRoot\capture.log" -RedirectStandardError "$PSScriptRoot\capture.err"
    $null = $p.Handle
    if (-not $p.WaitForExit(180000)) { throw 'Owned visual capture timeout; no readiness threshold relaxed' }
    $p.Refresh()
    foreach ($entry in $identity) { if ((Get-FileHash (Join-Path $project $entry.path)).Hash.ToLower() -ne $entry.sha256) { throw 'Source changed during capture' } }
    Get-Content "$PSScriptRoot\capture.log" -Tail 8
    Get-Content "$PSScriptRoot\capture.err" -Tail 8
    Write-Output "Owned capture exit=$($p.ExitCode). Staged images only, not player-route or FPS proof."
    if ($p.ExitCode -ne 0 -or (Get-Content "$PSScriptRoot\capture.err" -Raw) -match '(?m)^ERROR:|^SCRIPT ERROR:|ObjectDB instances leaked') { exit 1 }
} finally {
    if ($p -and -not $p.HasExited) {
        Get-CimInstance Win32_Process | Where-Object ParentProcessId -eq $p.Id | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }
}
