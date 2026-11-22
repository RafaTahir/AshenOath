$ErrorActionPreference = 'Stop'
$Repo = 'D:\Projects\AshenOath'
$Project = Join-Path $Repo 'outputs\AshenOathTheRoadBetweenCrowns'
$Previous = Join-Path $Repo '.release-gate\pack-closure-20261028'
$Run = Join-Path $Repo '.release-gate\pack-closure-20261028-r2'
$Godot = 'C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe'
$Python = 'C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$BuildId = 'pack-closure-20261028-r2'
$Commit = (& git -C $Repo rev-parse HEAD).Trim()
if (Test-Path -LiteralPath $Run) { throw 'Replacement candidate directory already exists; preserve it.' }
$Export = Join-Path $Run 'export'
$Packs = Join-Path $Run 'runtime-packs'
$Logs = Join-Path $Run 'logs'
New-Item -ItemType Directory -Path $Export,$Logs | Out-Null
Copy-Item -LiteralPath (Join-Path $Previous 'runtime-packs') -Destination $Packs -Recurse
function Build([string]$Executable, [string[]]$Arguments, [string]$Name) {
    Write-Host "Refreshing: $Name"
    $stdout = Join-Path $Logs ($Name + '.stdout.log')
    $stderr = Join-Path $Logs ($Name + '.stderr.log')
    $quoted = @($Arguments | ForEach-Object { '"' + $_.Replace('"','\"') + '"' })
    $process = Start-Process -FilePath $Executable -ArgumentList ($quoted -join ' ') -WorkingDirectory $Project -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    if ($process.ExitCode -ne 0) { throw "$Name failed; retained logs at $Logs" }
    if ($Executable -eq $Godot -and (Select-String -LiteralPath $stdout,$stderr -Pattern '^ERROR:|SCRIPT ERROR:|Failed to load script')) { throw "$Name reported an engine/compiler error" }
}
foreach ($id in @('opening','adjacent')) {
    $preset = 'Runtime Pack ' + (Get-Culture).TextInfo.ToTitleCase($id)
    Build $Godot @('--headless','--path',$Project,'--export-pack',$preset,(Join-Path $Packs ($id + '.pck'))) ('pack-' + $id)
}
$candidatePath = Join-Path $Packs 'runtime_pack_candidates.json'
$candidate = Get-Content -LiteralPath $candidatePath -Raw | ConvertFrom-Json
$candidate.build_id = $BuildId
$candidate.generated_at_utc = (Get-Date).ToUniversalTime().ToString('o')
$candidate.artifact_directory = $Packs
$candidate | Add-Member -NotePropertyName reused_unchanged_pack_inputs -NotePropertyValue 'base, campaign, characters, monsters, audio and quality_materials are byte-identical to pack-closure-20261028; only the three approved arrangements in opening/adjacent changed.' -Force
foreach ($record in $candidate.packs) {
    $file = Join-Path $Packs $record.artifact
    $record.version = $BuildId
    $record.bytes = [int64](Get-Item -LiteralPath $file).Length
    $record.sha256 = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
    $record.log = if ($record.id -in @('opening','adjacent')) { 'logs/pack-' + $record.id + '.stdout.log' } else { '../pack-closure-20261028/logs/pack-' + $record.id + '.stdout.log' }
}
$candidate.total_bytes = [int64](($candidate.packs | Measure-Object bytes -Sum).Sum)
[IO.File]::WriteAllText($candidatePath, (($candidate | ConvertTo-Json -Depth 12) + "`n"), [Text.UTF8Encoding]::new($false))
$Manifest = Join-Path $Project 'runtime_pack_manifest.json'
Build $Python @((Join-Path $Project 'tools/sync_runtime_pack_manifest.py'),$Manifest,$candidatePath,'--build-id',$BuildId,'--source-commit',$Commit) 'pack-manifest'
Build $Godot @('--headless','--path',$Project,'--export-release','Web Browser',(Join-Path $Export 'index.html')) 'web-production'
Copy-Item -LiteralPath (Join-Path $Project 'assets_external/ui/greyfen_menu_stylized.png') -Destination (Join-Path $Export 'menu-background.png')
New-Item -ItemType Directory -Path (Join-Path $Export 'packs') | Out-Null
foreach ($record in $candidate.packs) {
    if ($record.id -ne 'base') { Copy-Item -LiteralPath (Join-Path $Packs $record.artifact) -Destination (Join-Path $Export ('packs/' + $record.artifact)) }
}
Copy-Item -LiteralPath $Manifest -Destination (Join-Path $Export 'runtime_pack_manifest.json')
Build $Python @((Join-Path $Project 'tools/build_web_runtime_manifest.py'),$Export,'--runtime-pack-manifest',$Manifest,'--source-commit',$Commit,'--compress-wasm') 'web-manifest'
$release = Get-Content -LiteralPath (Join-Path $Export 'release_manifest.json') -Raw | ConvertFrom-Json
$candidate | Add-Member -NotePropertyName selected_web_export -NotePropertyValue ([ordered]@{build_id=$BuildId; artifact_directory=$Export; generated_from_commit=$Commit; artifacts_total_bytes=$release.artifacts_total_bytes; root_pck_sha256=$release.root_pck.sha256; note='Approved music restored; unchanged packs reused by full input identity.'}) -Force
[IO.File]::WriteAllText((Join-Path $Project 'runtime_pack_candidates.json'), (($candidate | ConvertTo-Json -Depth 12) + "`n"), [Text.UTF8Encoding]::new($false))
$Web = Join-Path $Repo 'web'
Copy-Item -LiteralPath $Web -Destination (Join-Path $Run 'previous-web') -Recurse
$expected = @($release.artifacts | ForEach-Object { $_.path }) + @('release_manifest.json')
$old = Get-Content -LiteralPath (Join-Path $Web 'release_manifest.json') -Raw | ConvertFrom-Json
foreach ($record in $old.artifacts) {
    if ($record.path -in $expected) { continue }
    $target = [IO.Path]::GetFullPath((Join-Path $Web $record.path))
    if (-not $target.StartsWith($Web + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Obsolete artifact escaped web root' }
    Remove-Item -LiteralPath $target -Force
}
foreach ($file in Get-ChildItem -LiteralPath $Export -File -Recurse) {
    $relative = $file.FullName.Substring($Export.Length).TrimStart('\','/')
    $target = [IO.Path]::GetFullPath((Join-Path $Web $relative))
    if (-not $target.StartsWith($Web + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Artifact escaped web root' }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $target -Force
}
Build $Python @((Join-Path $Project 'tools/build_web_runtime_manifest.py'),$Web,'--check-existing') 'package-check'
Write-Host "Replacement package complete: $BuildId. No gameplay run."
