param(
    [switch]$SkipExport,
    [switch]$SkipPerformance,
    [switch]$SkipScreenshots,
    [string]$Only = "",
    [string]$ResumeFrom = ""
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false
$Project = Split-Path -Parent $PSScriptRoot
$Godot = "C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe"
$Python = "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
$Web = Join-Path (Split-Path -Parent $Project) "AshenOath_Web"
$Logs = Join-Path $Project ".release-gate"
$ReportDirectory = Join-Path $Project "release_reports"
$ReportPath = Join-Path $ReportDirectory "latest.json"
$ContentReportPath = Join-Path $Logs "content_integrity.json"
$StartedAt = Get-Date
$Results = [System.Collections.Generic.List[object]]::new()
New-Item -ItemType Directory -Force -Path $Logs | Out-Null
New-Item -ItemType Directory -Force -Path $ReportDirectory | Out-Null

function Add-Result(
    [string]$Name,
    [string]$Status,
    [double]$Seconds,
    [string]$Log,
    [string[]]$Warnings = @(),
    [string]$Failure = ""
) {
    $Results.Add([ordered]@{
        name = $Name
        status = $Status
        duration_seconds = [math]::Round($Seconds, 2)
        log = [IO.Path]::GetFileName($Log)
        warnings = @($Warnings)
        failure = $Failure
    })
}

function Write-ReleaseReport([string]$Status, [string]$Failure = "") {
    $head = ""
    try { $head = (git -C (Split-Path -Parent (Split-Path -Parent $Project)) rev-parse HEAD).Trim() } catch {}
    $report = [ordered]@{
        schema_version = 1
        status = $Status
        started_at = $StartedAt.ToUniversalTime().ToString("o")
        finished_at = (Get-Date).ToUniversalTime().ToString("o")
        source_commit = $head
        mode = $(if ([string]::IsNullOrWhiteSpace($Only)) { "full" } else { "targeted" })
        requested_gate = $Only
        project = "outputs/AshenOathTheRoadBetweenCrowns"
        failure = $Failure
        results = @($Results)
    }
    $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ReportPath -Encoding utf8
}

function Invoke-ExternalGate(
    [string]$Name,
    [string]$Executable,
    [string[]]$Arguments
) {
    $log = Join-Path $Logs "$Name.log"
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    $previousErrorPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $Executable @Arguments 2>&1 | Tee-Object -FilePath $log
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorPreference
    }
    $timer.Stop()
    if ($exitCode -ne 0) {
        $failure = "$Name failed with exit code $exitCode"
        Add-Result $Name "fail" $timer.Elapsed.TotalSeconds $log @() $failure
        throw $failure
    }
    Add-Result $Name "pass" $timer.Elapsed.TotalSeconds $log
}

function Invoke-GodotGate([string]$Name, [string[]]$Arguments) {
    $log = Join-Path $Logs "$Name.log"
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    $previousErrorPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $Godot @Arguments 2>&1 | Tee-Object -FilePath $log
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorPreference
    }
    $timer.Stop()
    if ($exitCode -ne 0) {
        $failure = "$Name failed with exit code $exitCode"
        Add-Result $Name "fail" $timer.Elapsed.TotalSeconds $log @() $failure
        throw $failure
    }

    $lines = @(Get-Content -LiteralPath $log)
    $passIndex = -1
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -match '\bPASS\b|Screenshot capture complete') {
            $passIndex = $index
        }
    }
    $warnings = [System.Collections.Generic.List[string]]::new()
    $fatal = [System.Collections.Generic.List[string]]::new()
    $isHeadless = $Arguments -contains "--headless"
    $teardownPattern = 'RID allocations .* leaked at exit|Pages in use exist at exit|resources still in use at exit|Buffer with GL ID .* leaked|ObjectDB instances leaked at exit|Leaked instance dependency|did not call instance_notify_deleted|Parameter "material" is null'
    $fatalPattern = 'SCRIPT ERROR|Parse Error|Compile Error|Failed to load|Cannot open|ERROR:|VERIFIER:\s*FAIL|ASSERTION FAILED|Assertion failed'
    for ($index = 0; $index -lt $lines.Count; $index++) {
        $line = $lines[$index]
        if ($line -notmatch $fatalPattern) { continue }
        $headlessDummyMaterial = $isHeadless -and $line -match 'Parameter "material" is null'
        if ($headlessDummyMaterial -or ($line -match $teardownPattern -and $passIndex -ge 0 -and $index -gt $passIndex)) {
            $warnings.Add($line.Trim())
        } else {
            $fatal.Add($line.Trim())
        }
    }
    if ($fatal.Count -gt 0) {
        $failure = "$Name emitted a release-blocking error: $($fatal[0])"
        Add-Result $Name "fail" $timer.Elapsed.TotalSeconds $log @($warnings) $failure
        throw $failure
    }
    Add-Result $Name "pass" $timer.Elapsed.TotalSeconds $log @($warnings)
}

try {
    if (!(Test-Path -LiteralPath $Godot)) { throw "Godot 4.6.3 not found: $Godot" }
    if (!(Test-Path -LiteralPath $Python)) { throw "Bundled Python not found: $Python" }

    Invoke-ExternalGate "verify_content_integrity" $Python @(
        (Join-Path $Project "tools\verify_content_integrity.py"),
        $Project,
        "--json-report",
        $ContentReportPath
    )
	Invoke-ExternalGate "verify_asset_001_files" $Python @(
		(Join-Path $Project "tools\verify_asset_001.py")
	)

    $verifiers = @(
		"verify_runtime.gd", "verify_runtime_regressions.gd", "verify_engine_001.gd", "verify_story_campaign.gd", "verify_quest_001.gd", "verify_quest_002.gd", "verify_art_001.gd", "verify_asset_001.gd", "verify_character_real_001.gd",
        "verify_motion_quality.gd", "verify_river_swimming.gd", "verify_greyfen_life.gd",
		"verify_castle_vargan.gd", "verify_audio_runtime.gd", "verify_audio_001.gd", "verify_visible_quality.gd",
		"verify_recovery_002_foundation.gd", "verify_navigation_001.gd", "verify_char_001.gd", "verify_anim_001.gd", "verify_combat_001.gd", "verify_ai_001.gd", "verify_oath_001.gd", "verify_ui_001.gd", "verify_world_001.gd", "verify_world_002.gd", "verify_world_003.gd", "verify_zone_budgets.gd",
        "verify_visual_003.gd", "verify_visual_100.gd", "verify_master_002.gd", "verify_master_003.gd"
    )
    $resumeReached = [string]::IsNullOrWhiteSpace($ResumeFrom)
    foreach ($verifier in $verifiers) {
        $name = [IO.Path]::GetFileNameWithoutExtension($verifier)
        if (-not [string]::IsNullOrWhiteSpace($Only) -and $name -ne $Only) { continue }
        if (-not $resumeReached) {
            $resumeReached = ($name -eq $ResumeFrom)
            if (-not $resumeReached) { continue }
        }
        Invoke-GodotGate $name @("--headless", "--path", $Project, "--script", "tools/$verifier")
    }

    if ([string]::IsNullOrWhiteSpace($Only) -and -not $SkipPerformance) {
        Invoke-GodotGate "verify_720p_performance" @(
            "--path", $Project, "--rendering-method", "gl_compatibility",
            "--script", "tools/verify_720p_performance.gd"
        )
    }
    if ([string]::IsNullOrWhiteSpace($Only) -and -not $SkipScreenshots) {
        Invoke-GodotGate "capture_slice_screenshots" @(
            "--path", $Project, "--rendering-method", "gl_compatibility",
            "--script", "tools/capture_slice_screenshots.gd"
        )
		Invoke-GodotGate "capture_anim_001" @(
			"--path", $Project, "--rendering-method", "gl_compatibility",
			"--script", "tools/capture_anim_001.gd"
		)
		Invoke-GodotGate "capture_world_001" @(
			"--path", $Project, "--rendering-method", "gl_compatibility",
			"--script", "tools/capture_world_001.gd"
		)
		Invoke-GodotGate "capture_world_002" @(
			"--path", $Project, "--rendering-method", "gl_compatibility",
			"--script", "tools/capture_world_002.gd"
		)
		Invoke-GodotGate "capture_world_003" @(
			"--path", $Project, "--rendering-method", "gl_compatibility",
			"--script", "tools/capture_world_003.gd"
		)
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
        $runtimeSources += Get-Item (Join-Path $Project "project.godot")
        $sourceNewest = $runtimeSources | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        $gallery = Join-Path $Project "Development_Gallery\screenshots"
		$required = @("01_greyfen_spawn", "05_sister_anwen_dialogue", "70_greyfen_river_bridge", "10_combat_clearing", "15_player_sword_ready", "13_player_light_attack_arc", "14_player_heavy_attack_arc", "73_combat_001_blade_contact", "36_vargan_approach", "38_record_hall", "41_white_hart_glade")
        foreach ($stem in $required) {
            $image = Get-ChildItem $gallery -File -Filter "*$stem*.png" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if (-not $image) { throw "Required screenshot missing: $stem" }
            if ($image.LastWriteTime -lt $sourceNewest.LastWriteTime) { throw "Stale screenshot: $($image.Name)" }
            if ($image.Length -lt 4096) { throw "Screenshot is blank or corrupt: $($image.Name)" }
        }
    }

    if ([string]::IsNullOrWhiteSpace($Only) -and -not $SkipExport) {
        Invoke-ExternalGate "web_export" (Join-Path $Project "Export_Web_Build.bat") @()
        Invoke-ExternalGate "verify_web_export" $Python @(
            (Join-Path $Project "tools\verify_web_export.py"), $Web
        )
        $pack = Join-Path $Web "index.pck"
        Invoke-GodotGate "packed_startup" @(
            "--headless", "--path", $Web, "--main-pack", $pack, "--quit-after", "5"
        )
    }
    $finalStatus = $(if ([string]::IsNullOrWhiteSpace($Only)) { "pass" } else { "partial-pass" })
    Write-ReleaseReport $finalStatus
    Write-Host "AUTHORITATIVE RELEASE GATE: $($finalStatus.ToUpper())"
    Write-Host "Release report: $ReportPath"
}
catch {
    $failure = $_.Exception.Message
    Write-ReleaseReport "fail" $failure
    Write-Error "AUTHORITATIVE RELEASE GATE: FAIL - $failure"
    exit 1
}
