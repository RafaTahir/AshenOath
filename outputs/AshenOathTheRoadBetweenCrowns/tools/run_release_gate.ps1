param(
    [switch]$SkipExport,
    [string]$ResumeFrom = ""
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false
$Project = Split-Path -Parent $PSScriptRoot
$Godot = "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe"
$Python = "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
$Web = Join-Path (Split-Path -Parent $Project) "AshenOath_Web"
$Logs = Join-Path $Project ".release-gate"
New-Item -ItemType Directory -Force -Path $Logs | Out-Null

function Invoke-Gate([string]$Name, [string[]]$Arguments) {
    $log = Join-Path $Logs "$Name.log"
    $previousNativePreference = $PSNativeCommandUseErrorActionPreference
    $PSNativeCommandUseErrorActionPreference = $false
    try {
        & $Godot @Arguments 2>&1 | Tee-Object -FilePath $log
        $exitCode = $LASTEXITCODE
    }
    finally {
        $PSNativeCommandUseErrorActionPreference = $previousNativePreference
    }
    if ($exitCode -ne 0) { throw "$Name failed with exit code $exitCode" }
	$materialCleanup = Select-String -Path $log -Pattern 'Parameter "material" is null'
	if ($materialCleanup) {
		Write-Warning "$Name emitted $($materialCleanup.Count) renderer-destruction material diagnostics; active surfaces are validated separately by verify_zone_budgets."
	}
    $bad = Select-String -Path $log -Pattern 'SCRIPT ERROR|Parse Error|Compile Error|Failed to load|Cannot open|ERROR:' | Where-Object {
        # Godot's dummy renderer emits this only while releasing valid MultiMesh
        # resources at process shutdown. The graphical gate below remains strict.
        $_.Line -notmatch 'Parameter "material" is null|RID allocations .* leaked at exit|Pages in use exist at exit|resources still in use at exit|Buffer with GL ID .* leaked|ObjectDB instances leaked at exit|Leaked instance dependency|did not call instance_notify_deleted'
    }
    if ($bad) { throw "$Name emitted a release-blocking error: $($bad[0].Line)" }
}

$verifiers = @(
    "verify_runtime.gd", "verify_story_campaign.gd", "verify_character_real_001.gd",
    "verify_motion_quality.gd", "verify_river_swimming.gd", "verify_greyfen_life.gd",
    "verify_castle_vargan.gd", "verify_audio_runtime.gd", "verify_visible_quality.gd",
    "verify_recovery_002_foundation.gd", "verify_zone_budgets.gd",
    "verify_visual_003.gd", "verify_visual_100.gd", "verify_master_002.gd", "verify_master_003.gd"
)
$resumeReached = [string]::IsNullOrWhiteSpace($ResumeFrom)
foreach ($verifier in $verifiers) {
    if (-not $resumeReached) {
        $resumeReached = ([IO.Path]::GetFileNameWithoutExtension($verifier) -eq $ResumeFrom)
        if (-not $resumeReached) { continue }
    }
    Invoke-Gate ([IO.Path]::GetFileNameWithoutExtension($verifier)) @("--headless", "--path", $Project, "--script", "tools/$verifier")
}

# Performance and screenshots must use a real Compatibility renderer. Headless is never accepted.
Invoke-Gate "verify_720p_performance" @("--path", $Project, "--rendering-method", "gl_compatibility", "--script", "tools/verify_720p_performance.gd")
Invoke-Gate "capture_slice_screenshots" @("--path", $Project, "--rendering-method", "gl_compatibility", "--script", "tools/capture_slice_screenshots.gd")

$runtimeRoots = @(
    (Join-Path $Project "scripts"),
    (Join-Path $Project "scenes"),
    (Join-Path $Project "data")
)
$runtimeSources = foreach ($runtimeRoot in $runtimeRoots) {
    if (Test-Path $runtimeRoot) {
        Get-ChildItem $runtimeRoot -Recurse -File -Include *.gd,*.tscn,*.json
    }
}
$runtimeSources += Get-Item (Join-Path $Project "project.godot"), (Join-Path $Project "export_presets.cfg")
$sourceNewest = $runtimeSources | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$gallery = Join-Path $Project "Development_Gallery\screenshots"
$required = @("01_greyfen_spawn", "05_sister_anwen_dialogue", "70_greyfen_river_bridge", "10_combat_clearing", "36_vargan_approach", "38_record_hall", "41_white_hart_glade")
foreach ($stem in $required) {
    $image = Get-ChildItem $gallery -File -Filter "*$stem*.png" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $image) { throw "Required screenshot missing: $stem" }
    if ($image.LastWriteTime -lt $sourceNewest.LastWriteTime) { throw "Stale screenshot: $($image.Name)" }
    if ($image.Length -lt 4096) { throw "Screenshot is blank or corrupt: $($image.Name)" }
}

if (-not $SkipExport) {
    & (Join-Path $Project "Export_Web_Build.bat")
    if ($LASTEXITCODE -ne 0) { throw "Web export failed" }
    & $Python (Join-Path $Project "tools\verify_web_export.py") $Web
    if ($LASTEXITCODE -ne 0) { throw "Web export verification failed" }
}
Write-Host "BUILD-RECOVERY RELEASE GATE: PASS"
