$ErrorActionPreference = "Stop"
$Project = Split-Path -Parent $PSScriptRoot
$RepoRoot = Resolve-Path (Join-Path $Project "..\..")
$Runner = Join-Path $PSScriptRoot "run_ticket_gate.ps1"

function Get-DryRun([string]$ChangedFile) {
    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $Runner `
        -DryRun -ChangedFiles $ChangedFile 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Dry run failed for $ChangedFile`n$output" }
    return ($output -join "`n")
}

function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

$combat = Get-DryRun "outputs/AshenOathTheRoadBetweenCrowns/scripts/player_controller.gd"
Require ($combat -match "verify_combat_001") "Combat profile omitted combat verification."
Require ($combat -match "verify_oath_001") "Combat profile omitted Oathfire verification."
Require ($combat -notmatch "verify_castle_vargan|verify_story_campaign|web_export") "Combat profile selected unrelated gates."

$navigation = Get-DryRun "outputs/AshenOathTheRoadBetweenCrowns/scripts/zone_spatial_service.gd"
Require ($navigation -match "verify_zone_builder_integrity") "Navigation profile omitted builder integrity."
Require ($navigation -match "verify_gate_transitions") "Navigation profile omitted gate traversal."
Require ($navigation -match "verify_navigation_001") "Navigation profile omitted navigation verification."
Require ($navigation -match "verify_river_swimming") "Navigation profile omitted river safety."

$web = Get-DryRun "outputs/AshenOathTheRoadBetweenCrowns/export_presets.cfg"
Require ($web -match "web_export") "Export-filter changes did not force Web verification."

$browserAudio = Get-DryRun "outputs/AshenOathTheRoadBetweenCrowns/scripts/audio_manager.gd"
Require ($browserAudio -match "verify_audio_runtime") "Audio change omitted audio verification."
Require ($browserAudio -match "web_export") "Browser-audio change did not force Web verification."

$production = Get-DryRun "outputs/AshenOathTheRoadBetweenCrowns/PROD_002_ISSUE_REGISTRY.json"
Require ($production -match "verify_prod_002") "Production/QA registry changes omitted PROD-002 verification."
Require ($production -notmatch "web_export|verify_web_browser") "Production/QA registry changes selected unrelated Web gates."

$deploy = Get-Content -LiteralPath (Join-Path $RepoRoot "scripts\deploy_web_update.ps1") -Raw
Require ($deploy -match "Production.*RoadmapMilestone") "Production milestone guard is missing."
Require ($deploy -match "branch -eq `"main`"") "Ordinary-ticket main-branch guard is missing."

$release = Get-Content -LiteralPath (Join-Path $PSScriptRoot "run_release_gate.ps1") -Raw
Require ($release -match "verify_perf_001") "Milestone performance gate was removed."
Require ($release -match "capture_slice_screenshots") "Milestone screenshot gate was removed."
Require ($release -match "packed_startup") "Milestone packed startup gate was removed."

$ignore = Get-Content -LiteralPath (Join-Path $RepoRoot ".gitignore") -Raw
Require ($ignore -match "\.verification-cache") "Verification cache is not ignored."

Write-Host "WORKFLOW-002 VERIFIER: PASS"
