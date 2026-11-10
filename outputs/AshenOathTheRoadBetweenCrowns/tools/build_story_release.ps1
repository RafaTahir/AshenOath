param(
    [string]$OutputDirectory = "",
    [string]$BuildId = "",
    [string]$GodotPath = "C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe",
    [string]$PythonPath = "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe",
    [switch]$SkipWebCopy,
    [switch]$BuildVoices,
    [switch]$FinalizeExistingVoices,
    [switch]$DialogueVoicesOnly,
    [switch]$CharacterAssetsOnly,
    [switch]$Publish,
    [string]$PublishMessage = "",
    [string]$Ticket = "",
    [ValidateSet('codex/masterpiece-rebuild', 'codex/art-recovery-anwen')]
    [string]$DevelopmentBranch = 'codex/masterpiece-rebuild',
    [string[]]$PublishPaths = @()
)

# Production packaging by default. The explicit -Publish option also commits
# explicitly selected source/artifacts, pushes development/main and deploys to Vercel.
# Neither mode invokes gameplay tests or browsers. Publication checks HTTP artifact identity.
$ErrorActionPreference = "Stop"
$ProjectRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$RepositoryRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent (Split-Path -Parent $ProjectRoot)))
$GeneratedRoot = Join-Path $RepositoryRoot ".release-gate"
$WebRoot = Join-Path $RepositoryRoot "web"
$ArtGatePath = Join-Path $RepositoryRoot 'art_source/art_recovery_v2/quality_gate.json'
if (Test-Path -LiteralPath $ArtGatePath) {
    $ArtGate = Get-Content -LiteralPath $ArtGatePath -Raw | ConvertFrom-Json
    $CandidateAuthorization = $ArtGate.status -eq 'user_authorized_candidate_publication' -and $ArtGate.publication_authorized -eq $true
    if ($ArtGate.status -ne 'user_accepted_for_publication' -and -not $CandidateAuthorization) {
        throw "Art-quality production hold: $($ArtGate.reason) Review slices locally; do not package/publish rejected assets. Gate: $ArtGatePath"
    }
    if (-not $CandidateAuthorization) { foreach ($AssetId in $ArtGate.required_asset_ids) {
        $Review = $ArtGate.$AssetId
        if (-not $Review -or -not $Review.user_accepted) { throw "Missing user art acceptance: $AssetId" }
        foreach ($Category in $ArtGate.required_categories) {
            if ([int]$Review.scores.$Category -lt [int]$ArtGate.minimum_visual_score) {
                throw "Art gate failed: $AssetId / $Category"
            }
        }
        foreach ($View in $ArtGate.required_evidence) {
            $Evidence = $Review.evidence_paths.$View
            if (-not $Evidence -or -not (Test-Path -LiteralPath $Evidence -PathType Leaf)) {
                throw "Missing art evidence: $AssetId / $View"
            }
        }
    } }
}
$DeploymentPolicy = Get-Content -LiteralPath (Join-Path $ProjectRoot 'data/deployment_policy.json') -Raw | ConvertFrom-Json
if ($Publish -and $SkipWebCopy) { throw "-Publish requires the generated web transport to be copied." }
if ($Publish -and (-not $PublishPaths.Count -or $Ticket -notmatch '^(LR|OPT)-\d{3}$')) { throw "-Publish requires a supported ticket ID and explicit -PublishPaths for authored source." }

function Assert-Within([string]$Path, [string]$Root) {
    $resolved = [System.IO.Path]::GetFullPath($Path)
    $boundary = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($boundary, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Build output must stay within $boundary : $resolved"
    }
    return $resolved
}

function Invoke-BuildProcess([string]$Executable, [string[]]$Arguments, [string]$LogName) {
    if ($Executable -eq $GodotPath) { $Arguments = @('--log-file', (Join-Path $LogRoot ($LogName + '.engine.log'))) + $Arguments }
    $quoted = @($Arguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' })
    $stdout = Join-Path $LogRoot ($LogName + ".stdout.log")
    $stderr = Join-Path $LogRoot ($LogName + ".stderr.log")
    Write-Host ("Building: {0}" -f $LogName)
    $process = Start-Process -FilePath $Executable -ArgumentList ($quoted -join ' ') -WorkingDirectory $ProjectRoot -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    if ($Executable -eq $GodotPath) {
        # Godot may return zero after reporting an unsuccessful script import.
        # These are compiler diagnostics from this build process, not a QA run.
        $compilerDiagnostics = @(Select-String -LiteralPath @($stdout, $stderr) -Pattern '(?i)^ERROR:|SCRIPT ERROR:|Failed to load script|Error parsing script')
        if ($compilerDiagnostics.Count -gt 0) {
            foreach ($diagnostic in $compilerDiagnostics) { Write-Host $diagnostic.Line -ForegroundColor Red }
            throw "$LogName compilation failed. Build logs: $stdout ; $stderr"
        }
    }
    if ($process.ExitCode -ne 0) {
        throw "$LogName build failed with exit $($process.ExitCode). Build logs: $stdout ; $stderr"
    }
}

if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw "Pinned Godot executable is unavailable: $GodotPath" }
if (-not (Test-Path -LiteralPath $PythonPath -PathType Leaf)) { throw "Pinned Python executable is unavailable: $PythonPath" }
$SourceCommit = (& git -C $RepositoryRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or -not $SourceCommit) { throw "A source revision is needed for release packaging." }
if (-not $BuildId) { $BuildId = "story-$((Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'))-$($SourceCommit.Substring(0,12))" }

if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $GeneratedRoot "story-release"
} elseif (-not [System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $OutputDirectory = Join-Path $RepositoryRoot $OutputDirectory
}
$OutputDirectory = Assert-Within $OutputDirectory $GeneratedRoot
$ExportRoot = Join-Path $OutputDirectory "export"
$PackRoot = Join-Path $OutputDirectory "runtime-packs"
$LogRoot = Join-Path $OutputDirectory "logs"
if (Test-Path -LiteralPath (Join-Path $ExportRoot "index.pck")) {
    throw "A prior packaged candidate exists here. Use a fresh -OutputDirectory under .release-gate; the prior candidate is preserved."
}
foreach ($directory in @($ExportRoot, $PackRoot, $LogRoot)) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

# Keep the system awake only while this build process is active. Closing the
# laptop lid or a manual sleep request remains under the user's control.
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class AshenOathBuildPower {
    [DllImport("kernel32.dll")]
    public static extern uint SetThreadExecutionState(uint flags);
}
'@
[AshenOathBuildPower]::SetThreadExecutionState([uint32]2147483649) | Out-Null
try {
Invoke-BuildProcess $PythonPath @((Join-Path $PSScriptRoot "verify_native_attack_profiles.py"), "--project", $ProjectRoot) "native-attack-profiles"
if (-not $CharacterAssetsOnly) {
Invoke-BuildProcess $PythonPath @((Join-Path $PSScriptRoot "build_source_catalog.py")) "source-catalog"
Invoke-BuildProcess $PythonPath @((Join-Path $PSScriptRoot "prepare_runtime_dialogue.py")) "runtime-dialogue"
}
Invoke-BuildProcess $PythonPath @((Join-Path $PSScriptRoot "prepare_runtime_pack_layout.py"), "--defer-environment") "pack-layout"
if (-not $CharacterAssetsOnly) {
Invoke-BuildProcess $PythonPath @((Join-Path $PSScriptRoot "build_story_score.py")) "story-score"
$DesignPackCast = Test-Path (Join-Path $ProjectRoot "data/design_pack_assets.json")
if (-not $DesignPackCast) {
    Invoke-BuildProcess $PythonPath @((Join-Path $PSScriptRoot "build_living_faces.py")) "living-faces"
}
if ($BuildVoices) {
    $VoiceArguments = @((Join-Path $PSScriptRoot "build_story_voices.py"), "--all-scenes")
    if ($FinalizeExistingVoices) { $VoiceArguments += "--finalize-existing" }
    if ($DialogueVoicesOnly) { $VoiceArguments += "--dialogue-only" }
    Invoke-BuildProcess $PythonPath $VoiceArguments "story-voices"
}
}
Invoke-BuildProcess $GodotPath @("--headless", "--path", $ProjectRoot, "--editor", "--import", "--quit") "import"
Invoke-BuildProcess $GodotPath @("--headless", "--path", $ProjectRoot, "--script", (Join-Path $PSScriptRoot "compile_runtime_services.gd")) "runtime-services-compile"
# EnemyAI is demand-loaded after the menu, so editor import alone can miss a
# parser failure that disables every encounter. Compile it without running it.
Invoke-BuildProcess $GodotPath @("--headless", "--path", $ProjectRoot, "--check-only", "--script", "res://scripts/enemy_ai.gd") "enemy-runtime-compile"
foreach ($script in @("greyfen_life_controller", "story_state", "hud")) {
    Invoke-BuildProcess $GodotPath @("--headless", "--path", $ProjectRoot, "--check-only", "--script", "res://scripts/$script.gd") ("compile-" + $script)
}
if (-not $CharacterAssetsOnly) {
Invoke-BuildProcess $GodotPath @("--headless", "--path", $ProjectRoot, "--script", (Join-Path $PSScriptRoot "split_prepared_audio.gd")) "prepared-audio-split"
Invoke-BuildProcess $GodotPath @("--headless", "--path", $ProjectRoot, "--script", (Join-Path $PSScriptRoot "build_prepared_audio.gd"), "--", "--approved-arrangements") "approved-arrangements"
Invoke-BuildProcess $GodotPath @("--headless", "--path", $ProjectRoot, "--script", (Join-Path $PSScriptRoot "build_living_cast_station_props.gd")) "living-cast-station-props"
Invoke-BuildProcess $GodotPath @("--headless", "--path", $ProjectRoot, "--script", (Join-Path $PSScriptRoot "build_prepared_zone_geometry.gd")) "prepared-zone-geometry"
Invoke-BuildProcess $GodotPath @("--headless", "--path", $ProjectRoot, "--script", (Join-Path $PSScriptRoot "build_directional_gaits.gd")) "directional-gaits"
if (-not $DesignPackCast) {
    Invoke-BuildProcess $GodotPath @("--headless", "--path", $ProjectRoot, "--script", (Join-Path $PSScriptRoot "build_bracken_asset.gd")) "bracken-asset"
}
}
Invoke-BuildProcess $GodotPath @("--headless", "--path", $ProjectRoot, "--script", (Join-Path $PSScriptRoot "build_prepared_actors.gd")) "prepared-actors"
Invoke-BuildProcess $GodotPath @("--headless", "--path", $ProjectRoot, "--script", (Join-Path $PSScriptRoot "build_living_cast_libraries.gd"), "--", "--require-activity-grips") "living-cast-libraries"
Invoke-BuildProcess $GodotPath @("--headless", "--path", $ProjectRoot, "--script", (Join-Path $PSScriptRoot "build_living_cast_stage2_libraries.gd"), "--", "--require-activity-grips") "living-cast-stage2-libraries"
Invoke-BuildProcess $GodotPath @("--headless", "--path", $ProjectRoot, "--script", (Join-Path $PSScriptRoot "build_prepared_actors.gd"), "--", "--refresh-library-ownership") "prepared-actor-library-ownership"
Invoke-BuildProcess $GodotPath @("--headless", "--path", $ProjectRoot, "--script", (Join-Path $PSScriptRoot "build_environment_dependencies.gd")) "environment-material-dependencies"
Invoke-BuildProcess $PythonPath @((Join-Path $PSScriptRoot "prepare_runtime_pack_layout.py")) "prepared-actor-pack-layout"
Invoke-BuildProcess $PythonPath @((Join-Path $PSScriptRoot "runtime_pack_validation.py"), (Join-Path $ProjectRoot "runtime_pack_manifest.json")) "runtime-pack-graph"

# Opening and campaign packs carry zone scripts and base carries scripts/data.
# They must never be reused from an earlier release: load_resource_pack can
# otherwise override freshly exported core code. This build intentionally
# exports all asset packs too, avoiding unproven cross-build cache assumptions.
$PackLayout = Get-Content -LiteralPath (Join-Path $ProjectRoot 'runtime_pack_manifest.json') -Raw | ConvertFrom-Json
$packs = @($PackLayout.pack_presets.psobject.Properties | ForEach-Object { @{ id = $_.Name; preset = [string]$_.Value } })
$records = @()
foreach ($pack in $packs) {
    $artifactName = $pack.id + ".pck"
    $target = Join-Path $PackRoot $artifactName
    Invoke-BuildProcess $GodotPath @("--headless", "--path", $ProjectRoot, "--export-pack", $pack.preset, $target) ("pack-" + $pack.id)
    $info = Get-Item -LiteralPath $target
    $records += [ordered]@{
        id = $pack.id
        version = $BuildId
        preset = $pack.preset
        artifact = $artifactName
        bytes = [int64]$info.Length
        sha256 = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
        status = "candidate_external"
        log = "logs/pack-$($pack.id).stdout.log"
    }
}
$MetadataReceipt = Join-Path $OutputDirectory "pack-metadata-compaction.json"
Invoke-BuildProcess $PythonPath @((Join-Path $PSScriptRoot "compact_runtime_packs.py"), "--root-pack", (Join-Path $PackRoot "base.pck"), "--pack-dir", $PackRoot, "--report", $MetadataReceipt) "pack-metadata-compaction"
# Compaction preserves resource payloads but changes container identities.
# Bind the exact final bytes before the manifest is embedded in the Web root.
foreach ($record in $records) {
    $target = Join-Path $PackRoot $record["artifact"]
    $record["bytes"] = [int64](Get-Item -LiteralPath $target).Length
    $record["sha256"] = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
}
$candidatePath = Join-Path $PackRoot "runtime_pack_candidates.json"
$candidate = [ordered]@{
    schema_version = 2
    generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    build_id = $BuildId
    generated_from_commit = $SourceCommit
    # Builds can include uncommitted generated manifests or implementation work.
    # Do not imply a clean/verified source snapshot from HEAD alone.
    source_dirty = $true
    artifact_directory = $PackRoot
    artifacts_are_external = $true
    max_deployment_bytes = [int64]$DeploymentPolicy.max_deployment_bytes
    deployment_policy_id = [string]$DeploymentPolicy.id
    total_bytes = [int64](($records | ForEach-Object { $_.bytes } | Measure-Object -Sum).Sum)
    packs = $records
    errors = @()
}
$candidateJson = ($candidate | ConvertTo-Json -Depth 8) + [System.Environment]::NewLine
[System.IO.File]::WriteAllText($candidatePath, $candidateJson, [System.Text.UTF8Encoding]::new($false))

# Embed the current external-pack identities before exporting index.pck.
$runtimeManifest = Join-Path $ProjectRoot "runtime_pack_manifest.json"
Invoke-BuildProcess $PythonPath @((Join-Path $PSScriptRoot "sync_runtime_pack_manifest.py"), $runtimeManifest, $candidatePath, "--build-id", $BuildId, "--source-commit", $SourceCommit) "pack-manifest"
Invoke-BuildProcess $GodotPath @("--headless", "--path", $ProjectRoot, "--export-release", "Web Browser", (Join-Path $ExportRoot "index.html")) "web-production"
Invoke-BuildProcess $PythonPath @((Join-Path $PSScriptRoot "compact_runtime_packs.py"), "--root-pack", (Join-Path $ExportRoot "index.pck"), "--verify-authority", $MetadataReceipt) "pack-metadata-authority"
$ResourceCheckRoot = Assert-Within (Join-Path $OutputDirectory "isolated-resource-check") $OutputDirectory
New-Item -ItemType Directory -Force -Path $ResourceCheckRoot | Out-Null
if (@(Get-ChildItem -LiteralPath $ResourceCheckRoot -Force).Count -gt 0) {
    throw "Packed resource check requires an empty isolated directory: $ResourceCheckRoot"
}
# The Web root exports the full script dependency graph, unlike standalone base.
# Mount only exported files so authored resources cannot hide missing content.
# This instantiates resources without running a world, before gzip transport.
Invoke-BuildProcess $GodotPath @("--headless", "--path", $ResourceCheckRoot, "--main-pack", (Join-Path $ExportRoot "index.pck"), "--script", (Join-Path $PSScriptRoot "verify_prepared_actor_package.gd"), "--", "--pack-dir", $PackRoot) "prepared-actor-package"
Copy-Item -LiteralPath $runtimeManifest -Destination (Join-Path $ExportRoot "runtime_pack_manifest.json") -Force
# Existing hosting serves index.wasm with Content-Encoding: gzip. The builder
# preserves that format, injects the shell build/cache identity and writes hashes.
Invoke-BuildProcess $PythonPath @((Join-Path $PSScriptRoot "build_web_runtime_manifest.py"), $ExportRoot, "--runtime-pack-manifest", $runtimeManifest, "--pack-dir", $PackRoot, "--source-commit", $SourceCommit, "--compress-wasm") "web-manifest"

$releaseManifest = Get-Content -LiteralPath (Join-Path $ExportRoot "release_manifest.json") -Raw | ConvertFrom-Json
if ($ArtGate -and $ArtGate.full_release_max_bytes) {
    $RecoveryBytes = [int64]((Get-ChildItem -LiteralPath $ExportRoot -File -Recurse | Measure-Object -Property Length -Sum).Sum)
    if ($RecoveryBytes -ge [int64]$ArtGate.full_release_max_bytes) {
        throw "Art-recovery package is $RecoveryBytes bytes; it must be strictly below $($ArtGate.full_release_max_bytes) bytes. Preserve content and report the deficit; do not publish."
    }
}
$candidate.selected_web_export = [ordered]@{
    build_id = $BuildId
    artifact_directory = $ExportRoot
    generated_from_commit = $SourceCommit
    artifacts_total_bytes = $releaseManifest.artifacts_total_bytes
    root_pck_sha256 = $releaseManifest.root_pck.sha256
    note = "Selected export uses gzip transport; native pack records describe decoded build artifacts."
}
[IO.File]::WriteAllText((Join-Path $ProjectRoot "runtime_pack_candidates.json"), (($candidate | ConvertTo-Json -Depth 10) + [Environment]::NewLine), [Text.UTF8Encoding]::new($false))

if (-not $SkipWebCopy) {
    New-Item -ItemType Directory -Force -Path $WebRoot | Out-Null
    $oldManifestPath = Join-Path $WebRoot "release_manifest.json"
    $previousFiles = @()
    if (Test-Path -LiteralPath $oldManifestPath) {
        $oldManifest = Get-Content -LiteralPath $oldManifestPath -Raw | ConvertFrom-Json
        $previousFiles = @($oldManifest.artifacts | ForEach-Object { [string]$_.path }) + @("release_manifest.json")
    }
    $backupRoot = Join-Path $OutputDirectory "previous-web"
    foreach ($relative in $previousFiles) {
        # Only known generated transport files are eligible for cleanup. Hosting
        # configuration and any other user-owned web files are retained.
        if ($relative -notmatch '^(index\.[^/\\]+|runtime_pack_manifest\.json|release_manifest\.json|packs/[^/\\]+\.pck|engine/[a-f0-9]{24}/index\.[^/\\]+)$') { continue }
        $oldFile = Assert-Within (Join-Path $WebRoot $relative) $WebRoot
        if (-not (Test-Path -LiteralPath $oldFile -PathType Leaf)) { continue }
        $backup = Assert-Within (Join-Path $backupRoot $relative) $backupRoot
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backup) | Out-Null
        Copy-Item -LiteralPath $oldFile -Destination $backup -Force
        if (-not (Test-Path -LiteralPath (Join-Path $ExportRoot $relative) -PathType Leaf)) {
            Remove-Item -LiteralPath $oldFile -Force
        }
    }
    foreach ($file in Get-ChildItem -LiteralPath $ExportRoot -File -Recurse) {
        $relative = $file.FullName.Substring($ExportRoot.Length).TrimStart('\', '/')
        $destination = Assert-Within (Join-Path $WebRoot $relative) $WebRoot
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
    }
    Write-Host "Packaged production files copied to $WebRoot. Prior generated files are retained in $backupRoot."
}
Write-Host "Story build packaged: $ExportRoot"
Write-Host "Build identity: $BuildId ; source revision: $SourceCommit"
if ($Publish) {
    if (-not $PublishMessage) { $PublishMessage = $Ticket + ": publish " + $BuildId }
    $GeneratedPaths = @(
        "web",
        "outputs/AshenOathTheRoadBetweenCrowns/runtime_pack_manifest.json",
        "outputs/AshenOathTheRoadBetweenCrowns/runtime_pack_candidates.json",
        "outputs/AshenOathTheRoadBetweenCrowns/data/localization/en.json",
        "outputs/AshenOathTheRoadBetweenCrowns/story_score_manifest.json",
        "outputs/AshenOathTheRoadBetweenCrowns/assets_external/animations/AnimationLibrary_Godot_Opening.tres",
        "outputs/AshenOathTheRoadBetweenCrowns/assets_external/audio/story_score"
    )
    if ($BuildVoices) {
        $GeneratedPaths += @(
            "outputs/AshenOathTheRoadBetweenCrowns/voice_production_manifest.json",
            "outputs/AshenOathTheRoadBetweenCrowns/assets_external/audio/voices/story",
            "outputs/AshenOathTheRoadBetweenCrowns/docs/audio"
        )
    }
    & (Join-Path $PSScriptRoot "publish_living_road.ps1") -Ticket $Ticket -Message $PublishMessage -CommitPaths (@($GeneratedPaths + $PublishPaths | Select-Object -Unique)) -PythonPath $PythonPath -DevelopmentBranch $DevelopmentBranch
} else {
    Write-Host "Packaging completed; publication was not requested."
}
Write-Host "No gameplay, browser QA or benchmark was run. Publication, when requested, checks HTTP artifact identity."
} finally {
    [AshenOathBuildPower]::SetThreadExecutionState([uint32]2147483648) | Out-Null
}
