param([switch]$Resume, [switch]$SkipAssetBuild, [string[]]$RebuildPacks = @())
$ErrorActionPreference = 'Stop'
$Project = 'D:\Projects\AshenOath\outputs\AshenOathTheRoadBetweenCrowns'
$Build = 'D:\Projects\AshenOath\.release-gate\finish-implementation-20261026'
$Previous = 'D:\Projects\AshenOath\.release-gate\cohesive-foundation-r14-20261025'
$Godot = 'D:\Temp\AshenOath\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe'
$Python = 'C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$env:APPDATA = 'D:\Temp\AshenOath\cohesive-build-profile'
$env:TEMP = 'D:\Temp\AshenOath'
$env:TMP = $env:TEMP
Set-Location -LiteralPath $Project
New-Item -ItemType Directory -Path "$Build\logs","$Build\runtime-packs","$Build\export\packs" -Force | Out-Null
function Invoke-Compile([string]$Id, [string]$Arguments) {
    $stdout = "$Build\logs\$Id.stdout.log"
    $stderr = "$Build\logs\$Id.stderr.log"
    Write-Output "Compiling $Id"
    $process = Start-Process -FilePath $Godot -ArgumentList "--headless --path `"$Project`" $Arguments" -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    if ($process.ExitCode -ne 0 -or (Select-String -LiteralPath $stdout,$stderr -Pattern 'SCRIPT ERROR|Parse Error|ERROR:' -Quiet)) {
        throw "Compilation failed: $Id; see $stdout and $stderr"
    }
}
if (-not $SkipAssetBuild) {
    Invoke-Compile 'approved-arrangements' '--script tools/build_prepared_audio.gd -- --approved-arrangements'
    & $Python tools/prepare_runtime_pack_layout.py
    if ($LASTEXITCODE -ne 0) { throw 'Pack ownership generation failed.' }
}
$records = @()
$presets = [ordered]@{base='Base';opening='Opening';adjacent='Adjacent';campaign='Campaign';characters='Characters';monsters='Monsters';audio='Audio';quality_materials='Quality Materials'}
foreach ($id in $presets.Keys) {
    $target = "$Build\runtime-packs\$id.pck"
    $stamp = "$Build\logs\$id.complete"
    if (-not $Resume -or $id -in $RebuildPacks -or -not (Test-Path -LiteralPath $stamp)) {
        Invoke-Compile "pack-$id" "--export-pack `"Runtime Pack $($presets[$id])`" `"$target`""
        [IO.File]::WriteAllText($stamp, 'compiled')
    }
    $records += [ordered]@{id=$id;version='finish-implementation-20261026';preset="Runtime Pack $($presets[$id])";artifact="$id.pck";bytes=[int64](Get-Item -LiteralPath $target).Length;sha256=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant();status='candidate_external';log="logs/pack-$id.stdout.log"}
    if ($id -ne 'base') { Copy-Item -LiteralPath $target -Destination "$Build\export\packs\$id.pck" }
}
if ('base' -notin $RebuildPacks -and (Test-Path -LiteralPath "$Build\logs\rebuild-base")) {
    Invoke-Compile 'pack-base' "--export-pack `"Runtime Pack Base`" `"$Build\runtime-packs\base.pck`""
    $base = $records | Where-Object { $_.id -eq 'base' }
    $base.bytes = [int64](Get-Item -LiteralPath "$Build\runtime-packs\base.pck").Length
    $base.sha256 = (Get-FileHash -LiteralPath "$Build\runtime-packs\base.pck" -Algorithm SHA256).Hash.ToLowerInvariant()
}
$policy = Get-Content -LiteralPath 'data/deployment_policy.json' -Raw | ConvertFrom-Json
$ledger = [ordered]@{schema_version=2;ticket='FINISH-016';generated_at_utc=(Get-Date).ToUniversalTime().ToString('o');build_id='finish-implementation-20261026';generated_from_commit=(& git -C 'D:\Projects\AshenOath' rev-parse HEAD).Trim();source_dirty=$true;artifact_directory="$Build\runtime-packs";artifacts_are_external=$true;max_deployment_bytes=[int64]$policy.max_deployment_bytes;deployment_policy_id=$policy.id;total_bytes=[int64](($records | Measure-Object -Property bytes -Sum).Sum);packs=$records;errors=@()}
[IO.File]::WriteAllText("$Build\runtime-packs\runtime_pack_candidates.json", ($ledger | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
& $Python tools/sync_runtime_pack_manifest.py runtime_pack_manifest.json "$Build\runtime-packs\runtime_pack_candidates.json" --build-id 'finish-implementation-20261026'
if ($LASTEXITCODE -ne 0) { throw 'Pack identity synchronization failed.' }
Invoke-Compile 'web-production' "--export-release `"Web Browser`" `"$Build\export\index.html`""
Copy-Item -LiteralPath runtime_pack_manifest.json -Destination "$Build\export\runtime_pack_manifest.json"
Copy-Item -LiteralPath "$Previous\export\menu-background.png" -Destination "$Build\export\menu-background.png"
& $Python tools/build_web_runtime_manifest.py "$Build\export" --runtime-pack-manifest runtime_pack_manifest.json --compress-wasm
if ($LASTEXITCODE -ne 0) { throw 'Transport packaging failed.' }
Write-Output "Production candidate complete: $Build\export"
