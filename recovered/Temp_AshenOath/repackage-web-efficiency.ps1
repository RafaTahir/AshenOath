param([switch]$Resume)
$ErrorActionPreference = 'Stop'
$Repo = 'D:\Projects\AshenOath'
$Project = Join-Path $Repo 'outputs\AshenOathTheRoadBetweenCrowns'
$Tools = Join-Path $Project 'tools'
$Run = Join-Path $Repo '.release-gate\web-efficiency-20261101-r2'
$Packs = Join-Path $Run 'runtime-packs'
$Export = Join-Path $Run 'export'
$Logs = Join-Path $Run 'logs'
$Godot = 'C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe'
$Python = 'C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$BuildId = 'web-efficiency-20261101-r2'
$Commit = (git -C $Repo rev-parse HEAD).Trim()

function Run-Checked([string]$Executable, [string[]]$Arguments, [string]$Name) {
    Write-Output "Building: $Name"
    if ($Executable -eq $Godot) { $Arguments = @('--log-file', (Join-Path $Logs "$Name.engine.log")) + $Arguments }
    $line = ($Arguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }) -join ' '
    $stdout = Join-Path $Logs "$Name.stdout.log"
    $stderr = Join-Path $Logs "$Name.stderr.log"
    $process = Start-Process -FilePath $Executable -ArgumentList $line -WorkingDirectory $Project -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    if ($process.ExitCode -ne 0) { throw "$Name failed: $($process.ExitCode). See $Logs" }
    if ($Executable -eq $Godot -and @(Select-String -LiteralPath $stdout,$stderr -Pattern '(?i)^ERROR:|SCRIPT ERROR:|Failed to load script|Error parsing script').Count) {
        throw "$Name emitted engine errors. See $Logs"
    }
}

$CandidatePath = Join-Path $Packs 'runtime_pack_candidates.json'
$RuntimeManifest = Join-Path $Project 'runtime_pack_manifest.json'
if (-not $Resume) {
foreach ($Pack in @(@{id='base';preset='Runtime Pack Base'}, @{id='adjacent';preset='Runtime Pack Adjacent'}, @{id='monsters';preset='Runtime Pack Monsters'})) {
    Run-Checked $Godot @('--headless','--path',$Project,'--export-pack',$Pack.preset,(Join-Path $Packs ($Pack.id + '.pck'))) ('pack-' + $Pack.id)
}
$CandidatePath = Join-Path $Packs 'runtime_pack_candidates.json'
$Candidate = Get-Content -LiteralPath $CandidatePath -Raw | ConvertFrom-Json
$Candidate.build_id = $BuildId
$Candidate.generated_at_utc = (Get-Date).ToUniversalTime().ToString('o')
$Candidate.generated_from_commit = $Commit
$Candidate.source_dirty = $true
$Candidate.artifact_directory = $Packs
foreach ($Pack in $Candidate.packs) {
    $Path = Join-Path $Packs $Pack.artifact
    $Pack.bytes = [long](Get-Item -LiteralPath $Path).Length
    $Pack.sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    $Pack.version = $BuildId
}
$Candidate.total_bytes = [long](($Candidate.packs | Measure-Object -Property bytes -Sum).Sum)
[IO.File]::WriteAllText($CandidatePath, (($Candidate | ConvertTo-Json -Depth 12) + [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
$RuntimeManifest = Join-Path $Project 'runtime_pack_manifest.json'
Run-Checked $Python @((Join-Path $Tools 'sync_runtime_pack_manifest.py'),$RuntimeManifest,$CandidatePath,'--build-id',$BuildId,'--source-commit',$Commit) 'pack-manifest'
Run-Checked $Godot @('--headless','--path',$Project,'--export-release','Web Browser',(Join-Path $Export 'index.html')) 'web-production'
} else {
    $Candidate = Get-Content -LiteralPath $CandidatePath -Raw | ConvertFrom-Json
}
$Isolated = Join-Path $Run $(if ($Resume) { 'isolated-resource-check-final' } else { 'isolated-resource-check' })
New-Item -ItemType Directory -Path $Isolated -ErrorAction Stop | Out-Null
Run-Checked $Godot @('--headless','--path',$Isolated,'--main-pack',(Join-Path $Export 'index.pck'),'--script',(Join-Path $Tools 'verify_prepared_actor_package.gd'),'--','--pack-dir',$Packs) 'prepared-actor-package-final'
foreach ($Id in @('adjacent','monsters')) {
    Copy-Item -LiteralPath (Join-Path $Packs ($Id + '.pck')) -Destination (Join-Path $Export ('packs\' + $Id + '.pck')) -Force
}
Copy-Item -LiteralPath $RuntimeManifest -Destination (Join-Path $Export 'runtime_pack_manifest.json') -Force
Run-Checked $Python @((Join-Path $Tools 'build_web_runtime_manifest.py'),$Export,'--runtime-pack-manifest',$RuntimeManifest,'--source-commit',$Commit,'--compress-wasm') 'web-manifest'
$Release = Get-Content -LiteralPath (Join-Path $Export 'release_manifest.json') -Raw | ConvertFrom-Json
$Candidate | Add-Member -NotePropertyName selected_web_export -NotePropertyValue ([ordered]@{build_id=$BuildId;artifact_directory=$Export;generated_from_commit=$Commit;artifacts_total_bytes=$Release.artifacts_total_bytes;root_pck_sha256=$Release.root_pck.sha256;note='Selected export uses gzip transport; native pack records describe decoded build artifacts.'}) -Force
[IO.File]::WriteAllText((Join-Path $Project 'runtime_pack_candidates.json'), (($Candidate | ConvertTo-Json -Depth 12) + [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
Write-Output "Validated candidate ready: $Export"
