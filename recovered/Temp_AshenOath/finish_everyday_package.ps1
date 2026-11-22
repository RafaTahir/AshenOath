param([switch]$FinalizeOnly)
$ErrorActionPreference = 'Stop'
$Repo = 'D:\Projects\AshenOath'
$Project = Join-Path $Repo 'outputs\AshenOathTheRoadBetweenCrowns'
$Build = Join-Path $Repo '.release-gate\everyday-life-20261106'
$Packs = Join-Path $Build 'runtime-packs'
$Export = Join-Path $Build 'export'
$Logs = Join-Path $Build 'logs'
$Godot = 'C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe'
$Python = 'C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
function Build-Step([string]$Exe, [string[]]$Arguments, [string]$Name) {
    $Out = Join-Path $Logs "$Name.stdout.log"
    $Err = Join-Path $Logs "$Name.stderr.log"
    if ($Exe -eq $Godot) { $Arguments = @('--log-file',(Join-Path $Logs "$Name.engine.log")) + $Arguments }
    $Quoted = @($Arguments | ForEach-Object { '"' + $_.Replace('"','\"') + '"' })
    Write-Host "Packaging: $Name"
    $Process = Start-Process -FilePath $Exe -ArgumentList ($Quoted -join ' ') -WorkingDirectory $Project -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $Out -RedirectStandardError $Err
    $Errors = @(Select-String -LiteralPath @($Out,$Err) -Pattern '(?i)^ERROR:|SCRIPT ERROR:|Failed to load script|Error parsing script')
    if ($Process.ExitCode -ne 0 -or $Errors.Count) { throw "$Name failed: $Out ; $Err" }
}
if (-not $FinalizeOnly) {
foreach ($Name in @('everyday_life','fishing_activity')) {
    Build-Step $Godot @('--headless','--path',$Project,'--check-only','--script',"res://scripts/$Name.gd") "final-compile-$Name"
}
# Only these two scripts changed after base export; actor and environment inputs
# have not changed. Re-export their base owner and the root that embeds its hash.
Build-Step $Godot @('--headless','--path',$Project,'--export-pack','Runtime Pack Base',(Join-Path $Packs 'base.pck')) 'final-pack-base'
$CandidatePath = Join-Path $Packs 'runtime_pack_candidates.json'
$Candidate = Get-Content -LiteralPath $CandidatePath -Raw | ConvertFrom-Json
$Base = @($Candidate.packs | Where-Object id -eq 'base')[0]
$Base.bytes = (Get-Item -LiteralPath (Join-Path $Packs 'base.pck')).Length
$Base.sha256 = (Get-FileHash -LiteralPath (Join-Path $Packs 'base.pck') -Algorithm SHA256).Hash.ToLowerInvariant()
$Base.log = 'logs/final-pack-base.stdout.log'
$Candidate.total_bytes = [long](($Candidate.packs | Measure-Object -Property bytes -Sum).Sum)
foreach ($Pack in $Candidate.packs) {
    $File = Join-Path $Packs $Pack.artifact
    if ((Get-Item -LiteralPath $File).Length -ne $Pack.bytes -or (Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash.ToLowerInvariant() -ne $Pack.sha256) { throw "Pack identity mismatch: $($Pack.id)" }
}
[IO.File]::WriteAllText($CandidatePath,($Candidate | ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
$Manifest = Join-Path $Project 'runtime_pack_manifest.json'
Build-Step $Python @((Join-Path $Project 'tools/sync_runtime_pack_manifest.py'),$Manifest,$CandidatePath,'--build-id',$Candidate.build_id,'--source-commit',$Candidate.generated_from_commit) 'final-pack-manifest'
Build-Step $Godot @('--headless','--path',$Project,'--export-release','Web Browser',(Join-Path $Export 'index.html')) 'final-web'
Copy-Item -LiteralPath $Manifest -Destination (Join-Path $Export 'runtime_pack_manifest.json') -Force
Build-Step $Python @((Join-Path $Project 'tools/build_web_runtime_manifest.py'),$Export,'--runtime-pack-manifest',$Manifest,'--pack-dir',$Packs,'--source-commit',$Candidate.generated_from_commit,'--compress-wasm') 'final-web-manifest'
}
$Candidate = Get-Content -LiteralPath (Join-Path $Packs 'runtime_pack_candidates.json') -Raw | ConvertFrom-Json
$Release = Get-Content -LiteralPath (Join-Path $Export 'release_manifest.json') -Raw | ConvertFrom-Json
$ProjectCandidatePath = Join-Path $Project 'runtime_pack_candidates.json'
$Selected = [pscustomobject]@{ build_id=$Candidate.build_id; artifact_directory=$Export; generated_from_commit=$Candidate.generated_from_commit; artifacts_total_bytes=$Release.artifacts_total_bytes; root_pck_sha256=$Release.root_pck.sha256; note='Final script-aligned gzip transport. Native pack records describe decoded artifacts.' }
$Candidate | Add-Member -NotePropertyName selected_web_export -NotePropertyValue $Selected -Force
[IO.File]::WriteAllText($ProjectCandidatePath,($Candidate | ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
$Web = Join-Path $Repo 'web'
foreach ($File in Get-ChildItem -LiteralPath $Export -File -Recurse) {
    $Relative = $File.FullName.Substring($Export.Length).TrimStart('\','/')
    $Destination = [IO.Path]::GetFullPath((Join-Path $Web $Relative))
    if (-not $Destination.StartsWith($Web+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid publication path' }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null
    Copy-Item -LiteralPath $File.FullName -Destination $Destination -Force
}
Build-Step $Python @((Join-Path $Project 'tools/build_web_runtime_manifest.py'),$Web,'--check-existing') 'final-package-integrity'
Write-Host "Final script-aligned package: $($Candidate.build_id), $($Release.artifacts_total_bytes) artifact bytes."
