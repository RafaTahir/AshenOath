$ErrorActionPreference = 'Stop'
$source = 'D:\Projects\AshenOath\outputs\AshenOathTheRoadBetweenCrowns'
$project = Join-Path $PSScriptRoot 'project'
$profile = Join-Path $PSScriptRoot 'profile'
if(Test-Path -LiteralPath "$PSScriptRoot\native_complete.log") {throw 'Never overwrite completed diagnostic'}
$identity=@('project.godot','tools/verify_perf_001.gd','scripts/game.gd','scripts/visual_director.gd','scripts/zones/greyfen_section.gd','scripts/asset_spawn_helper.gd','scripts/settings_manager.gd','character_role_manifest.json','runtime_pack_manifest.json') | ForEach-Object {[pscustomobject]@{path=$_;sha256=(Get-FileHash (Join-Path $source $_)).Hash.ToLower()}}
$identity | ConvertTo-Json | Set-Content -LiteralPath "$PSScriptRoot\source_identity.json" -Encoding utf8
foreach ($name in @('assets','assets_external','data','scenes','scripts','tools','.godot')) {
    $target = Join-Path $source $name
    $link = Join-Path $project $name
    if (Test-Path -LiteralPath $link) {
        $item = Get-Item -LiteralPath $link
        if ($item.LinkType -ne 'Junction' -or [string]$item.Target -ne $target) { throw "Fixture link differs from canonical source: $link" }
    } else { New-Item -ItemType Junction -Path $link -Target $target | Out-Null }
}
Copy-Item -LiteralPath "$source\project.godot", "$source\export_presets.cfg" -Destination $project
Get-ChildItem -LiteralPath $source -File -Filter '*.json' | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $project }
if (Test-Path -LiteralPath "$project\.release-gate\perf_001_greyfen_report.json") { Copy-Item -LiteralPath "$project\.release-gate\perf_001_greyfen_report.json" -Destination "$PSScriptRoot\invalid_missing_manifest_report.json" }
New-Item -ItemType Directory "$profile\AppData\Roaming", "$profile\AppData\Local" -Force | Out-Null
$env:APPDATA = "$profile\AppData\Roaming"
$env:LOCALAPPDATA = "$profile\AppData\Local"
New-Item -ItemType Directory "$profile\Temp" -Force | Out-Null
$env:TEMP="$profile\Temp"
$env:TMP="$profile\Temp"
$env:ANGLE_FEATURE_OVERRIDES_ENABLED='disableProgramCaching'
$env:ANGLE_FEATURE_OVERRIDES_DISABLED='cacheCompiledShader'
$p = $null
try {
    $p = Start-Process 'C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe' -WorkingDirectory $project -ArgumentList '--path . --rendering-method gl_compatibility --rendering-driver opengl3_angle --script res://tools/verify_perf_001.gd -- --zone=greyfen' -WindowStyle Hidden -PassThru -RedirectStandardOutput "$PSScriptRoot\native_complete.log" -RedirectStandardError "$PSScriptRoot\native_complete.err"
    $null = $p.Handle
    if (-not $p.WaitForExit(150000)) { throw 'Owned cache-disabled native timeout' }
    $p.Refresh()
    Get-Content "$PSScriptRoot\native_complete.log" -Tail 8
    Get-Content "$PSScriptRoot\native_complete.err" -Tail 14
    if (-not (Test-Path -LiteralPath "$project\.release-gate\perf_001_greyfen_report.json")) { throw 'Current targeted report missing' }
    $report = Get-Content "$project\.release-gate\perf_001_greyfen_report.json" -Raw | ConvertFrom-Json
    Write-Output "Diagnostic child exit=$($p.ExitCode); targeted status=$($report.status). Not retained or release accepted."
    Copy-Item -LiteralPath "$project\.release-gate\perf_001_greyfen_report.json" -Destination "$PSScriptRoot\report.json"
    foreach($entry in $identity) {if((Get-FileHash (Join-Path $source $entry.path)).Hash.ToLower() -ne $entry.sha256) {throw 'Source changed during isolated sample'}}
    foreach($owner in @('GodotEGL','IntelDriver')) {
        $files=@(Get-ChildItem -LiteralPath "$profile\AppData" -Recurse -File | Where-Object {if($owner -eq 'GodotEGL') {$_.FullName -match 'shader_cache[\\/]EGL[\\/]'} else {$_.FullName -match 'LocalLow[\\/]Intel[\\/]ShaderCache[\\/]'}})
        [pscustomobject]@{owner=$owner;files=$files.Count;bytes=($files|Measure-Object Length -Sum).Sum}|ConvertTo-Json -Compress
    }
    if ($p.ExitCode -ne 0 -or (Get-Content "$PSScriptRoot\native_complete.err" -Raw) -match '(?m)^ERROR:|^SCRIPT ERROR:|ObjectDB instances leaked') { exit 1 }
} finally {
    if ($p -and -not $p.HasExited) {
        Get-CimInstance Win32_Process | Where-Object ParentProcessId -eq $p.Id | ForEach-Object {Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue}
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }
}
