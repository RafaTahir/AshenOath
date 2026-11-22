param(
    [Parameter(Mandatory=$true)][string]$BuildId,
    [Parameter(Mandatory=$true)][string]$PriorCandidate
)
$ErrorActionPreference = 'Stop'
$repo = 'D:\Projects\AshenOath'
$project = Join-Path $repo 'outputs\AshenOathTheRoadBetweenCrowns'
$prior = [IO.Path]::GetFullPath($PriorCandidate)
$output = Join-Path $repo ('.release-gate\' + $BuildId)
if ($BuildId -notmatch '^finish-line-[a-z0-9-]+$' -or -not $prior.StartsWith($repo + '\.release-gate\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Use canonical D: candidate paths.' }
$packRoot = Join-Path $output 'runtime-packs'
$export = Join-Path $output 'export'
$logs = Join-Path $output 'logs'
if (Test-Path -LiteralPath (Join-Path $export 'index.pck')) { throw 'Candidate exists; preserve it.' }
New-Item -ItemType Directory -Force -Path $packRoot,$export,$logs | Out-Null
$env:TEMP = 'D:\Temp\AshenOath'
$env:TMP = $env:TEMP
$env:APPDATA = 'D:\Temp\AshenOath\kael-visible-20261019\build-profile\Roaming'
$env:LOCALAPPDATA = 'D:\Temp\AshenOath\kael-visible-20261019\build-profile\Local'
$godot = 'D:\Temp\AshenOath\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe'
$python = 'C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$source = (& git -C $repo rev-parse HEAD).Trim()
function Build([string]$exe, [string[]]$arguments, [string]$label) {
    $stdout = Join-Path $logs ($label + '.stdout.log')
    $stderr = Join-Path $logs ($label + '.stderr.log')
    $quoted = @($arguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' })
    Write-Output ('Building: ' + $label)
    $p = Start-Process -FilePath $exe -ArgumentList ($quoted -join ' ') -WorkingDirectory $project -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    if ($p.ExitCode -ne 0) { throw "$label exit $($p.ExitCode); logs at $logs" }
    if ($exe -eq $godot -and @(Select-String -LiteralPath @($stdout,$stderr) -Pattern '(?i)SCRIPT ERROR:|Failed to load script|Error parsing script').Count) { throw "$label compiler error; logs at $logs" }
}
Build $godot @('--headless','--path',$project,'--editor','--import') 'import'
Build $godot @('--headless','--path',$project,'--check-only','--script','res://scripts/hud.gd') 'compile-hud'
$records = @()
$old = Get-Content -LiteralPath (Join-Path $prior 'runtime-packs\runtime_pack_candidates.json') -Raw | ConvertFrom-Json
foreach ($record in $old.packs) {
    $target = Join-Path $packRoot $record.artifact
    if ($record.id -in @('base','opening','adjacent','campaign')) {
        Build $godot @('--headless','--path',$project,'--export-pack',$record.preset,$target) ('pack-' + $record.id)
    } else {
        $oldFile = Join-Path $prior ('runtime-packs\' + $record.artifact)
        if ((Get-FileHash -LiteralPath $oldFile -Algorithm SHA256).Hash.ToLowerInvariant() -ne $record.sha256) { throw ('Invalid reused asset pack: ' + $record.id) }
        Copy-Item -LiteralPath $oldFile -Destination $target
        $record | Add-Member -NotePropertyName reused_from -NotePropertyValue $oldFile -Force
    }
    $record.version = $BuildId
    $record.bytes = [int64](Get-Item -LiteralPath $target).Length
    $record.sha256 = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
    $records += $record
}
$old.build_id = $BuildId
$old.generated_at_utc = (Get-Date).ToUniversalTime().ToString('o')
$old.generated_from_commit = $source
$old.source_dirty = $true
$old.artifact_directory = $packRoot
$old.packs = $records
$old.total_bytes = [int64](($records | Measure-Object -Property bytes -Sum).Sum)
$candidatePath = Join-Path $packRoot 'runtime_pack_candidates.json'
[IO.File]::WriteAllText($candidatePath, (($old | ConvertTo-Json -Depth 12) + [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
$runtime = Join-Path $project 'runtime_pack_manifest.json'
Build $python @((Join-Path $project 'tools\sync_runtime_pack_manifest.py'),$runtime,$candidatePath,'--build-id',$BuildId,'--source-commit',$source) 'pack-manifest'
Build $godot @('--headless','--path',$project,'--export-release','Web Browser',(Join-Path $export 'index.html')) 'web-production'
Copy-Item -LiteralPath (Join-Path $project 'assets_external\ui\greyfen_menu_stylized.png') -Destination (Join-Path $export 'menu-background.png')
$external = Join-Path $export 'packs'
New-Item -ItemType Directory -Path $external | Out-Null
foreach ($record in $records) {
    if ($record.id -ne 'base') { Copy-Item -LiteralPath (Join-Path $packRoot $record.artifact) -Destination (Join-Path $external $record.artifact) }
}
Copy-Item -LiteralPath $runtime -Destination (Join-Path $export 'runtime_pack_manifest.json')
Build $python @((Join-Path $project 'tools\build_web_runtime_manifest.py'),$export,'--runtime-pack-manifest',$runtime,'--source-commit',$source,'--compress-wasm') 'web-manifest'
$release = Get-Content -LiteralPath (Join-Path $export 'release_manifest.json') -Raw | ConvertFrom-Json
$old | Add-Member -NotePropertyName selected_web_export -NotePropertyValue ([ordered]@{build_id=$BuildId;artifact_directory=$export;generated_from_commit=$source;artifacts_total_bytes=$release.artifacts_total_bytes;root_pck_sha256=$release.root_pck.sha256;note='Gzip delivery; native pack records describe decoded artifacts.'}) -Force
[IO.File]::WriteAllText((Join-Path $project 'runtime_pack_candidates.json'), (($old | ConvertTo-Json -Depth 12) + [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
Write-Output ($release | Select-Object build_id,artifacts_total_bytes,root_pck | ConvertTo-Json -Depth 4)
Write-Output ('Complete Web bytes: ' + ((Get-ChildItem -LiteralPath $export -File -Recurse | Measure-Object -Property Length -Sum).Sum))
