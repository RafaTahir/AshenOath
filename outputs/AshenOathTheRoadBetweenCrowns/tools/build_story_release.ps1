param(
    [string]$OutputDirectory = "",
    [string]$BuildId = "",
    [string]$GodotPath = "C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe",
    [string]$PythonPath = "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe",
    [switch]$SkipWebCopy,
    [switch]$BuildVoices,
    [switch]$FinalizeExistingVoices,
    [switch]$DialogueVoicesOnly,
    [switch]$Publish,
    [string]$PublishMessage = "",
    [string]$Ticket = "",
    [string[]]$PublishPaths = @()
)

# Production packaging by default. The explicit -Publish option also commits
# explicitly selected source/artifacts, pushes development/main and deploys to Vercel.
# Neither mode invokes tests, QA, review tools, browsers or post-deploy requests.
$ErrorActionPreference = "Stop"
$ProjectRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$RepositoryRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent (Split-Path -Parent $ProjectRoot)))
$GeneratedRoot = Join-Path $RepositoryRoot ".release-gate"
$WebRoot = Join-Path $RepositoryRoot "web"
if ($Publish -and $SkipWebCopy) { throw "-Publish requires the generated web transport to be copied." }
if ($Publish -and (-not $PublishPaths.Count -or $Ticket -notmatch '^LR-\d{3}$')) { throw "-Publish requires -Ticket LR-NNN and explicit -PublishPaths for authored source." }

function Assert-Within([string]$Path, [string]$Root) {
    $resolved = [System.IO.Path]::GetFullPath($Path)
    $boundary = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($boundary, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Build output must stay within $boundary : $resolved"
    }
    return $resolved
}

function Invoke-BuildProcess([string]$Executable, [string[]]$Arguments, [string]$LogName) {
    $quoted = @($Arguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' })
    $stdout = Join-Path $LogRoot ($LogName + ".stdout.log")
    $stderr = Join-Path $LogRoot ($LogName + ".stderr.log")
    Write-Host ("Building: {0}" -f $LogName)
    $process = Start-Process -FilePath $Executable -ArgumentList ($quoted -join ' ') -WorkingDirectory $ProjectRoot -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    if ($Executable -eq $GodotPath) {
        # Godot may return zero after reporting an unsuccessful script import.
        # These are compiler diagnostics from this build process, not a QA run.
        $compilerDiagnostics = @(Select-String -LiteralPath @($stdout, $stderr) -Pattern '(?i)SCRIPT ERROR:\s*(?:Parse|Compile) Error|Failed to load script|Error parsing script')
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
Invoke-BuildProcess $PythonPath @((Join-Path $PSScriptRoot "build_source_catalog.py")) "source-catalog"
Invoke-BuildProcess $PythonPath @((Join-Path $PSScriptRoot "build_story_score.py")) "story-score"
if ($BuildVoices) {
    $VoiceArguments = @((Join-Path $PSScriptRoot "build_story_voices.py"), "--all-scenes")
    if ($FinalizeExistingVoices) { $VoiceArguments += "--finalize-existing" }
    if ($DialogueVoicesOnly) { $VoiceArguments += "--dialogue-only" }
    Invoke-BuildProcess $PythonPath $VoiceArguments "story-voices"
}
Invoke-BuildProcess $GodotPath @("--headless", "--path", $ProjectRoot, "--editor", "--import") "import"
Invoke-BuildProcess $GodotPath @("--headless", "--path", $ProjectRoot, "--script", (Join-Path $PSScriptRoot "build_directional_gaits.gd")) "directional-gaits"
Invoke-BuildProcess $GodotPath @("--headless", "--path", $ProjectRoot, "--script", (Join-Path $PSScriptRoot "build_bracken_asset.gd")) "bracken-asset"

# Opening and campaign packs carry zone scripts and base carries scripts/data.
# They must never be reused from an earlier release: load_resource_pack can
# otherwise override freshly exported core code. This build intentionally
# exports all asset packs too, avoiding unproven cross-build cache assumptions.
$packs = @(
    @{ id = "base"; preset = "Runtime Pack Base" },
    @{ id = "opening"; preset = "Runtime Pack Opening" },
    @{ id = "campaign"; preset = "Runtime Pack Campaign" },
    @{ id = "characters"; preset = "Runtime Pack Characters" },
    @{ id = "monsters"; preset = "Runtime Pack Monsters" },
    @{ id = "audio"; preset = "Runtime Pack Audio" },
    @{ id = "quality_materials"; preset = "Runtime Pack Quality Materials" }
)
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
    max_deployment_bytes = 104857600
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
Copy-Item -LiteralPath (Join-Path $ProjectRoot "assets_external/ui/greyfen_menu_runtime.jpg") -Destination (Join-Path $ExportRoot "menu-background.jpg") -Force

$externalRoot = Join-Path $ExportRoot "packs"
New-Item -ItemType Directory -Force -Path $externalRoot | Out-Null
foreach ($pack in $packs) {
    if ($pack.id -ne "base") {
        Copy-Item -LiteralPath (Join-Path $PackRoot ($pack.id + ".pck")) -Destination (Join-Path $externalRoot ($pack.id + ".pck")) -Force
    }
}
Copy-Item -LiteralPath $runtimeManifest -Destination (Join-Path $ExportRoot "runtime_pack_manifest.json") -Force
# Existing hosting serves index.wasm with Content-Encoding: gzip. The builder
# preserves that format, injects the shell build/cache identity and writes hashes.
Invoke-BuildProcess $PythonPath @((Join-Path $PSScriptRoot "build_web_runtime_manifest.py"), $ExportRoot, "--runtime-pack-manifest", $runtimeManifest, "--source-commit", $SourceCommit, "--compress-wasm") "web-manifest"

$releaseManifest = Get-Content -LiteralPath (Join-Path $ExportRoot "release_manifest.json") -Raw | ConvertFrom-Json
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
        if ($relative -notmatch '^(index\.[^/\\]+|runtime_pack_manifest\.json|release_manifest\.json|packs/[^/\\]+\.pck)$') { continue }
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
    & (Join-Path $PSScriptRoot "publish_living_road.ps1") -Ticket $Ticket -Message $PublishMessage -CommitPaths (@($GeneratedPaths + $PublishPaths | Select-Object -Unique)) -PythonPath $PythonPath
} else {
    Write-Host "Packaging completed; publication was not requested."
}
Write-Host "This command did not run tests, QA, review tools, browsers or post-deployment requests."
} finally {
    [AshenOathBuildPower]::SetThreadExecutionState([uint32]2147483648) | Out-Null
}
