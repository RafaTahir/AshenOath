$ErrorActionPreference = 'Stop'
$Repo = 'D:\Projects\AshenOath'
$Project = Join-Path $Repo 'outputs\AshenOathTheRoadBetweenCrowns'
$BuildId = 'startup-speed-20261107'
$Build = Join-Path $Repo ".release-gate\$BuildId"
$Previous = Join-Path $Repo '.release-gate\startup-verified-r2-20261106\runtime-packs'
$Packs = Join-Path $Build 'runtime-packs'
$Export = Join-Path $Build 'export'
$Logs = Join-Path $Build 'logs'
$Godot = 'C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe'
$Python = 'C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
foreach ($Directory in @($Packs,$Export,$Logs)) { New-Item -ItemType Directory -Force -Path $Directory | Out-Null }
if (Test-Path -LiteralPath (Join-Path $Export 'index.pck')) { throw 'Candidate already exported; preserve it.' }
function Build-Step([string]$Exe,[string[]]$Arguments,[string]$Name) {
    Write-Host "Building: $Name"
    $Out = Join-Path $Logs "$Name.stdout.log"
    $Err = Join-Path $Logs "$Name.stderr.log"
    if ($Exe -eq $Godot) { $Arguments = @('--log-file',(Join-Path $Logs "$Name.engine.log")) + $Arguments }
    $Quoted = @($Arguments | ForEach-Object { '"' + $_.Replace('"','\"') + '"' })
    $Process = Start-Process -FilePath $Exe -ArgumentList ($Quoted -join ' ') -WorkingDirectory $Project -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $Out -RedirectStandardError $Err
    $Errors = @(Select-String -LiteralPath @($Out,$Err) -Pattern '(?i)^ERROR:|SCRIPT ERROR:|Failed to load script|Error parsing script')
    if ($Process.ExitCode -ne 0 -or $Errors.Count) { throw "$Name failed: $Out ; $Err" }
}
Build-Step $Godot @('--headless','--path',$Project,'--script','res://tools/compile_runtime_services.gd') 'required-services-compile'
foreach ($Script in @('systems/session_service','systems/opening_startup_service','journey_load_runtime')) {
    Build-Step $Godot @('--headless','--path',$Project,'--check-only','--script',"res://scripts/$Script.gd") ('compile-' + $Script.Replace('/','-'))
}
Build-Step $Python @((Join-Path $Project 'tools/prepare_runtime_pack_layout.py')) 'pack-layout'
$Source = (& git -C $Repo rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Cannot identify source revision.' }
$Candidate = Get-Content -LiteralPath (Join-Path $Previous 'runtime_pack_candidates.json') -Raw | ConvertFrom-Json
$Candidate.build_id = $BuildId
$Candidate.generated_from_commit = $Source
$Candidate.generated_at_utc = (Get-Date).ToUniversalTime().ToString('o')
$Candidate.artifact_directory = $Packs
$Candidate.source_dirty = $true
foreach ($Pack in $Candidate.packs) {
    $Destination = Join-Path $Packs $Pack.artifact
    if ($Pack.id -in @('base','opening','adjacent','campaign')) {
        # Rebuild every script-carrying world pack as well as the changed art owner.
        Build-Step $Godot @('--headless','--path',$Project,'--export-pack',$Pack.preset,$Destination) "pack-$($Pack.id)"
        $Pack.bytes = (Get-Item -LiteralPath $Destination).Length
        $Pack.sha256 = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash.ToLowerInvariant()
        $Pack.version = $BuildId
        $Pack.log = "logs/pack-$($Pack.id).stdout.log"
    } else {
        # No actor, audio, material, geometry or leisure asset inputs were changed.
        $Original = Join-Path $Previous $Pack.artifact
        if ((Get-Item -LiteralPath $Original).Length -ne $Pack.bytes -or (Get-FileHash -LiteralPath $Original -Algorithm SHA256).Hash.ToLowerInvariant() -ne $Pack.sha256) { throw "Retained pack mismatch: $($Pack.id)" }
        Copy-Item -LiteralPath $Original -Destination $Destination
        $Pack | Add-Member -NotePropertyName reused_from -NotePropertyValue 'startup-verified-r2-20261106; unchanged asset inputs' -Force
    }
}
$Candidate.total_bytes = [long](($Candidate.packs | Measure-Object -Property bytes -Sum).Sum)
$CandidatePath = Join-Path $Packs 'runtime_pack_candidates.json'
[IO.File]::WriteAllText($CandidatePath,($Candidate | ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
$Manifest = Join-Path $Project 'runtime_pack_manifest.json'
Build-Step $Python @((Join-Path $Project 'tools/sync_runtime_pack_manifest.py'),$Manifest,$CandidatePath,'--build-id',$BuildId,'--source-commit',$Source) 'pack-manifest'
Build-Step $Godot @('--headless','--path',$Project,'--export-release','Web Browser',(Join-Path $Export 'index.html')) 'web-export'
Copy-Item -LiteralPath $Manifest -Destination (Join-Path $Export 'runtime_pack_manifest.json')
Build-Step $Python @((Join-Path $Project 'tools/build_web_runtime_manifest.py'),$Export,'--runtime-pack-manifest',$Manifest,'--pack-dir',$Packs,'--source-commit',$Source,'--compress-wasm') 'web-manifest'
$Release = Get-Content -LiteralPath (Join-Path $Export 'release_manifest.json') -Raw | ConvertFrom-Json
$Total = [long]((Get-ChildItem -LiteralPath $Export -File -Recurse | Measure-Object -Property Length -Sum).Sum)
$Policy = Get-Content -LiteralPath (Join-Path $Project 'data/deployment_policy.json') -Raw | ConvertFrom-Json
if ($Total -ge $Policy.max_deployment_bytes) { throw "Package exceeds budget: $Total" }
$Selected = [pscustomobject]@{ build_id=$BuildId; artifact_directory=$Export; generated_from_commit=$Source; artifacts_total_bytes=$Release.artifacts_total_bytes; root_pck_sha256=$Release.root_pck.sha256; note='Startup repair; unchanged asset packs retain their exact bytes. Native records describe decoded artifacts.' }
$Candidate | Add-Member -NotePropertyName selected_web_export -NotePropertyValue $Selected -Force
[IO.File]::WriteAllText((Join-Path $Project 'runtime_pack_candidates.json'),($Candidate | ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
$Web = Join-Path $Repo 'web'
foreach ($File in Get-ChildItem -LiteralPath $Export -File -Recurse) {
    $Relative = $File.FullName.Substring($Export.Length).TrimStart('\','/')
    $Destination = [IO.Path]::GetFullPath((Join-Path $Web $Relative))
    if (-not $Destination.StartsWith($Web+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid publication path' }
    if (Test-Path -LiteralPath $Destination) {
        $Backup = Join-Path (Join-Path $Build 'previous-web') $Relative
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Backup) | Out-Null
        Copy-Item -LiteralPath $Destination -Destination $Backup
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null
    Copy-Item -LiteralPath $File.FullName -Destination $Destination -Force
}
Build-Step $Python @((Join-Path $Project 'tools/build_web_runtime_manifest.py'),$Web,'--check-existing') 'package-integrity'
Write-Host "Package complete: $BuildId, $Total deployed bytes. No game or browser execution."
