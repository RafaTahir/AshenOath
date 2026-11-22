$ErrorActionPreference = 'Stop'
$project = 'D:\Projects\AshenOath\outputs\AshenOathTheRoadBetweenCrowns'
$profile = Join-Path $PSScriptRoot 'route'
$suffix = 'AppData\Roaming\Godot\app_userdata\Ashen Oath- The Road Between Crowns'
$user = Join-Path $profile $suffix
$origin = Join-Path 'D:\Temp\AshenOath\castle_evidence_v2_fixture' $suffix
$save = Join-Path $origin 'ashen_oath_save.json'
if (Test-Path -LiteralPath "$PSScriptRoot\route.log") { throw 'Never overwrite evidence' }
$sourceHash = (Get-FileHash -LiteralPath $save).Hash
$data = Get-Content -LiteralPath $save -Raw | ConvertFrom-Json
if ($data.zone -ne 'vargan_court') { throw 'Expected genuine courtyard save' }
New-Item -ItemType Directory $user,"$profile\AppData\Local","$profile\Temp" -Force | Out-Null
foreach ($name in @('ashen_oath_save.json','ashen_oath_autosave.json')) {
    Copy-Item -LiteralPath $save -Destination (Join-Path $user $name)
    if ((Get-FileHash (Join-Path $user $name)).Hash -ne $sourceHash) { throw 'Save copy differs' }
}
Copy-Item -LiteralPath "$origin\ashen_oath_settings.json" -Destination $user
if (Test-Path -LiteralPath "$origin\shader_cache") { Copy-Item -LiteralPath "$origin\shader_cache" -Destination $user -Recurse }
$env:APPDATA="$profile\AppData\Roaming"
$env:LOCALAPPDATA="$profile\AppData\Local"
$env:TEMP="$profile\Temp"
$env:TMP="$profile\Temp"
$paths=@('scripts/game.gd','scripts/zones/castle_vargan_section.gd','tools/verify_opening_real_input_native.gd','assets_external/environment/props/RecordArchive_Authored.res','runtime_asset_manifest.json')
$identity=$paths | ForEach-Object {[pscustomobject]@{path=$_;sha256=(Get-FileHash (Join-Path $project $_)).Hash.ToLower()}}
$identity | ConvertTo-Json | Set-Content "$PSScriptRoot\route.sources.json" -Encoding utf8
$p=$null
try {
    $args='--path . --rendering-method gl_compatibility --rendering-driver opengl3_angle --script res://tools/verify_opening_real_input_native.gd -- --continue-record-hall --castle-return-proof'
    $p=Start-Process 'C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe' -WorkingDirectory $project -ArgumentList $args -WindowStyle Hidden -PassThru -RedirectStandardOutput "$PSScriptRoot\route.log" -RedirectStandardError "$PSScriptRoot\route.err"
    $null=$p.Handle
    if (-not $p.WaitForExit(150000)) {throw 'Owned route timeout; movement deadlines unchanged'}
    $p.Refresh()
    if ((Get-FileHash -LiteralPath $save).Hash -ne $sourceHash) {throw 'Original save changed'}
    foreach($entry in $identity) {if((Get-FileHash (Join-Path $project $entry.path)).Hash.ToLower() -ne $entry.sha256) {throw 'Source changed during route'}}
    Get-Content "$PSScriptRoot\route.log" -Tail 12
    Get-Content "$PSScriptRoot\route.err" -Tail 10
    Write-Output "Owned physical-route exit=$($p.ExitCode); no FPS acceptance."
    if($p.ExitCode -ne 0 -or (Get-Content "$PSScriptRoot\route.err" -Raw) -match '(?m)^ERROR:|^SCRIPT ERROR:|ObjectDB instances leaked') {exit 1}
} finally {
    if($p -and -not $p.HasExited) {
        Get-CimInstance Win32_Process | Where-Object ParentProcessId -eq $p.Id | ForEach-Object {Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue}
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }
}
