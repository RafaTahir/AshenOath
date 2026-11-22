param([Parameter(Mandatory)][string]$BuildId)
$ErrorActionPreference = 'Stop'
$Repo = 'D:/Projects/AshenOath'
$Project = Join-Path $Repo 'outputs/AshenOathTheRoadBetweenCrowns'
$Web = Join-Path $Repo 'web'
if ($BuildId -notmatch '^proximity-streaming-[a-z0-9-]+$') {
    throw 'Supply the exact prepared build ID.'
}
$Run = Join-Path $Repo ('.release-gate/' + $BuildId)
$Export = Join-Path $Run 'export'
$SourceManifest = Join-Path $Export 'release_manifest.json'
$OldManifest = Join-Path $Web 'release_manifest.json'
$Backup = Join-Path $Run 'previous-web'
$webStatus = @(git -C $Repo status --porcelain --untracked-files=all -- web)
if ($LASTEXITCODE -ne 0 -or $webStatus.Count -gt 0) { throw 'Existing Web work must be preserved; this copy requires a clean web/.' }
if (Test-Path -LiteralPath $Backup) { throw 'Previous Web backup already exists. Preserve it and inspect the current checkpoint.' }

function Assert-ArtifactPath([string]$Relative,[string]$Root) {
    if ($Relative -notmatch '^(index\.[^/\\]+|menu-background\.png|favicon\.ico|runtime_pack_manifest\.json|release_manifest\.json|packs/[a-z0-9_]+\.pck|engine/[a-f0-9]{24}/index\.[^/\\]+)$') {
        throw "Unexpected transport path: $Relative"
    }
    $Absolute = [IO.Path]::GetFullPath((Join-Path $Root $Relative))
    if (-not $Absolute.StartsWith([IO.Path]::GetFullPath($Root).TrimEnd('\','/') + '\',[StringComparison]::OrdinalIgnoreCase)) {
        throw "Artifact escapes output root: $Relative"
    }
    return $Absolute
}

$old = Get-Content -LiteralPath $OldManifest -Raw | ConvertFrom-Json
$new = Get-Content -LiteralPath $SourceManifest -Raw | ConvertFrom-Json
if ($new.build_id -ne $BuildId) { throw 'Candidate manifest has a different build ID.' }
$rawCandidate = Join-Path $Run 'runtime-packs/runtime_pack_candidates.json'
$candidate = Get-Content -LiteralPath $rawCandidate -Raw | ConvertFrom-Json -AsHashtable
if ($candidate.build_id -ne $new.build_id -or $candidate.generated_from_commit -ne $new.source.git_commit) { throw 'Native and Web receipt provenance disagree.' }
$oldPaths = @($old.artifacts.path) + @('release_manifest.json')
$newPaths = @($new.artifacts.path) + @('release_manifest.json')
foreach ($relative in $oldPaths + $newPaths) { [void](Assert-ArtifactPath $relative $Web) }
foreach ($relative in $oldPaths) {
    $source = Assert-ArtifactPath $relative $Web
    $target = Assert-ArtifactPath $relative $Backup
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    Copy-Item -LiteralPath $source -Destination $target
}
foreach ($relative in $oldPaths) {
    if ($relative -notin $newPaths) { Remove-Item -LiteralPath (Assert-ArtifactPath $relative $Web) }
}
foreach ($relative in $newPaths) {
    $target = Assert-ArtifactPath $relative $Web
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    Copy-Item -LiteralPath (Assert-ArtifactPath $relative $Export) -Destination $target -Force
}
$candidate.selected_web_export = [ordered]@{
    build_id = $BuildId
    artifact_directory = $Export
    generated_from_commit = $new.source.git_commit
    artifacts_total_bytes = $new.artifacts_total_bytes
    root_pck_sha256 = $new.root_pck.sha256
    note = 'Selected export uses gzip transport; native records retain exact decoded pack provenance.'
}
[IO.File]::WriteAllText((Join-Path $Project 'runtime_pack_candidates.json'), (($candidate | ConvertTo-Json -Depth 12) + [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
Write-Host "Prepared bytes copied to $Web; preceding package retained in $Backup. Nothing pushed."
