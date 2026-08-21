param(
    [switch]$SkipExport,
    [switch]$SkipPerformance,
    [switch]$SkipScreenshots,
    [switch]$VerboseOutput,
    [string]$Only = "",
    [string]$ResumeFrom = ""
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false
$Project = Split-Path -Parent $PSScriptRoot
$RepoRoot = Resolve-Path (Join-Path $Project "..\..")
$GodotCandidates = [System.Collections.Generic.List[string]]::new()
if ($env:GODOT_BIN) { $GodotCandidates.Add($env:GODOT_BIN) }
$GodotCandidates.Add((Join-Path $RepoRoot "tools\godot\Godot_v4.6.3-stable_win64_console.exe"))
$GodotCandidates.Add("C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe")
$Godot = $GodotCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if ([string]::IsNullOrWhiteSpace($Godot)) {
    $Godot = Get-ChildItem -LiteralPath $env:USERPROFILE -Recurse -Filter "Godot_v4.6.3-stable_win64_console.exe" -File -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
}
$GraphicalGodotCandidates = [System.Collections.Generic.List[string]]::new()
if ($env:GODOT_GRAPHICAL_BIN) { $GraphicalGodotCandidates.Add($env:GODOT_GRAPHICAL_BIN) }
$GraphicalGodotCandidates.Add((Join-Path $RepoRoot "tools\godot\Godot_v4.6.3-stable_win64.exe"))
$GraphicalGodotCandidates.Add("C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64.exe")
$GraphicalGodotCandidates.Add("C:\Users\User\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe")
$GodotGraphical = $GraphicalGodotCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if ([string]::IsNullOrWhiteSpace($GodotGraphical)) {
    $GodotGraphical = Get-ChildItem -LiteralPath $env:USERPROFILE -Recurse -Filter "Godot_v4.6.3-stable_win64.exe" -File -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
}
$Python = "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
$Node = "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe"
$Web = Join-Path (Split-Path -Parent $Project) "AshenOath_Web"
$QAWeb = Join-Path (Split-Path -Parent $Project) ".release-gate\AshenOath_QA"
$Logs = Join-Path $Project ".release-gate"
$ReportDirectory = Join-Path $Project "release_reports"
$ReportPath = Join-Path $ReportDirectory "latest.json"
$ContentReportPath = Join-Path $Logs "content_integrity.json"
$StartedAt = Get-Date
$Results = [System.Collections.Generic.List[object]]::new()
New-Item -ItemType Directory -Force -Path $Logs | Out-Null
New-Item -ItemType Directory -Force -Path $ReportDirectory | Out-Null
New-Item -ItemType Directory -Force -Path $QAWeb | Out-Null
$IsResume = -not [string]::IsNullOrWhiteSpace($ResumeFrom)
$webTailResume = $IsResume -and $ResumeFrom -eq "verify_web_002_browser"
$mobileTailResume = $IsResume -and $ResumeFrom -eq "verify_mobile_browser"

if ($IsResume) {
    if (-not (Test-Path -LiteralPath $ReportPath)) {
        throw "Cannot resume without an existing release report: $ReportPath"
    }
    $previousReport = Get-Content -LiteralPath $ReportPath -Raw | ConvertFrom-Json
	$currentHead = (git -C $RepoRoot rev-parse HEAD).Trim()
    if ($previousReport.source_commit -ne $currentHead) {
        $changedSinceReport = @(git -C $repoRoot diff --name-only "$($previousReport.source_commit)..$currentHead")
        $unsafeResumeChanges = @($changedSinceReport | Where-Object {
            $_ -notmatch '^outputs/AshenOathTheRoadBetweenCrowns/tools/' -and
            $_ -notmatch '^outputs/AshenOathTheRoadBetweenCrowns/.*\.md$' -and
            -not (
                $ResumeFrom -in @("verify_web_001", "web_export") -and
                $_ -eq 'outputs/AshenOathTheRoadBetweenCrowns/export_presets.cfg'
            )
        })
        if ($unsafeResumeChanges.Count -gt 0) {
            throw "Cannot resume release after runtime/source changes: $($unsafeResumeChanges -join ', ')"
        }
        Write-Host "RELEASE RESUME: verifier/document-only changes accepted: $($changedSinceReport -join ', ')"
    }
    $resumeFound = $false
    foreach ($result in $previousReport.results) {
        if ($result.name -eq $ResumeFrom) {
            $resumeFound = $true
            break
        }
        if ($result.status -ne "pass") {
            throw "Cannot preserve non-passing gate before resume point: $($result.name)"
        }
        $Results.Add([ordered]@{
            name = [string]$result.name
            status = "pass"
            duration_seconds = [double]$result.duration_seconds
            log = [string]$result.log
            warnings = @($result.warnings)
            failure = ""
        })
    }
    if (-not $resumeFound) {
        throw "Resume gate was not found in the previous release report: $ResumeFrom"
    }
}

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
	try { $head = (git -C $RepoRoot rev-parse HEAD).Trim() } catch {}
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
        if ($VerboseOutput) {
            & $Executable @Arguments 2>&1 | Tee-Object -FilePath $log
        } else {
            & $Executable @Arguments *> $log
        }
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorPreference
    }
    $timer.Stop()
    if ($exitCode -ne 0) {
        $failure = "$Name failed with exit code $exitCode"
        Add-Result $Name "fail" $timer.Elapsed.TotalSeconds $log @() $failure
        if (-not $VerboseOutput) { Get-Content -LiteralPath $log -Tail 40 }
        throw $failure
    }
    Add-Result $Name "pass" $timer.Elapsed.TotalSeconds $log
    Write-Host ("RELEASE GATE {0}: PASS ({1:n1}s)" -f $Name, $timer.Elapsed.TotalSeconds)
}

function Invoke-CapturedProcess(
    [string]$Executable,
    [string[]]$Arguments,
    [string]$Log
) {
    # The graphical Godot binary is a GUI subsystem process on Windows. The
    # PowerShell call operator can return as soon as that process hands off to
    # its window process, which makes a performance gate look like a 0-second
    # pass and leaves the real test outside release ownership. Start it with
    # an awaited process handle and capture both streams explicitly.
    $stdoutPath = "$Log.stdout.tmp"
    $stderrPath = "$Log.stderr.tmp"
    Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
    $argumentLine = (($Arguments | ForEach-Object {
        $value = [string]$_
        if ($value -match '[\s"]') {
            '"' + $value.Replace('"', '\\"') + '"'
        } else {
            $value
        }
    }) -join ' ')
    # Keep the Compatibility window foregroundable. On Intel/ANGLE, hiding a
    # graphical Godot window changes compositor pacing and produces a lower
    # frame-time profile than the browser-facing desktop path we are measuring.
    $process = Start-Process -FilePath $Executable -ArgumentList $argumentLine `
        -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath `
        -PassThru -Wait
    $stdout = if (Test-Path -LiteralPath $stdoutPath) { Get-Content -LiteralPath $stdoutPath -Raw } else { "" }
    $stderr = if (Test-Path -LiteralPath $stderrPath) { Get-Content -LiteralPath $stderrPath -Raw } else { "" }
    if ($stdout.Length -gt 0) { [IO.File]::WriteAllText($Log, $stdout) } else { [IO.File]::WriteAllText($Log, "") }
    if ($stderr.Length -gt 0) { Add-Content -LiteralPath $Log -Value $stderr -NoNewline }
    Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
    return [int]$process.ExitCode
}

function Invoke-GodotGate([string]$Name, [string[]]$Arguments, [string]$Executable = "") {
	$Runner = $Godot
	if (-not [string]::IsNullOrWhiteSpace($Executable)) { $Runner = $Executable }
	$log = Join-Path $Logs "$Name.log"
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    $previousErrorPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        if (-not [string]::IsNullOrWhiteSpace($Executable)) {
            $exitCode = Invoke-CapturedProcess $Runner $Arguments $log
            if ($VerboseOutput -and (Test-Path -LiteralPath $log)) { Get-Content -LiteralPath $log }
        } elseif ($VerboseOutput) {
			& $Runner @Arguments 2>&1 | Tee-Object -FilePath $log
			$exitCode = $LASTEXITCODE
		} else {
			& $Runner @Arguments *> $log
			$exitCode = $LASTEXITCODE
		}
    } finally {
        $ErrorActionPreference = $previousErrorPreference
    }
    $timer.Stop()
    if ($exitCode -ne 0) {
        $failure = "$Name failed with exit code $exitCode"
        Add-Result $Name "fail" $timer.Elapsed.TotalSeconds $log @() $failure
        if (-not $VerboseOutput) { Get-Content -LiteralPath $log -Tail 40 }
        throw $failure
    }

    $lines = @(Get-Content -LiteralPath $log)
    $passIndex = -1
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -match '\bPASS\b|Screenshot capture complete') {
            $passIndex = $index
        }
    }
    if ($passIndex -lt 0) {
        $failure = "$Name produced no verifier pass marker"
        Add-Result $Name "fail" $timer.Elapsed.TotalSeconds $log @() $failure
        if (-not $VerboseOutput -and (Test-Path -LiteralPath $log)) { Get-Content -LiteralPath $log -Tail 40 }
        throw $failure
    }
    $warnings = [System.Collections.Generic.List[string]]::new()
    $fatal = [System.Collections.Generic.List[string]]::new()
    $isHeadless = $Arguments -contains "--headless"
	$teardownPattern = 'Parameter "material" is null|RID allocations .* leaked at exit|Pages in use exist at exit|resources still in use at exit|Buffer with GL ID .* leaked|shaders of type .* never freed|ObjectDB instances leaked at exit|Leaked instance dependency|did not call instance_notify_deleted'
    $fatalPattern = 'SCRIPT ERROR|Parse Error|Compile Error|Failed to load|Cannot open|ERROR:|VERIFIER:\s*FAIL|ASSERTION FAILED|Assertion failed'
    for ($index = 0; $index -lt $lines.Count; $index++) {
        $line = $lines[$index]
        if ($line -notmatch $fatalPattern) { continue }
        # PowerShell wraps native stderr as an ErrorRecord and abbreviates the
        # original line inside CategoryInfo. The complete stderr line is also
        # present in the log and is classified independently below.
        if ($line -match '^\s*\+\s+CategoryInfo|FullyQualifiedErrorId.*NativeCommandError') {
            continue
        }
        if ($line -match $teardownPattern -and $passIndex -ge 0 -and $index -gt $passIndex) {
            $warnings.Add($line.Trim())
        } else {
            $fatal.Add($line.Trim())
        }
    }
    if ($fatal.Count -gt 0) {
        $failure = "$Name emitted a release-blocking error: $($fatal[0])"
        Add-Result $Name "fail" $timer.Elapsed.TotalSeconds $log @($warnings) $failure
        if (-not $VerboseOutput) { Get-Content -LiteralPath $log -Tail 40 }
        throw $failure
    }
    Add-Result $Name "pass" $timer.Elapsed.TotalSeconds $log @($warnings)
    Write-Host ("RELEASE GATE {0}: PASS ({1:n1}s)" -f $Name, $timer.Elapsed.TotalSeconds)
}

try {
    if (!(Test-Path -LiteralPath $Godot)) { throw "Godot 4.6.3 console binary not found: $Godot" }
    if (!(Test-Path -LiteralPath $Python)) { throw "Bundled Python not found: $Python" }
    if (!(Test-Path -LiteralPath $Node)) { throw "Bundled Node.js not found: $Node" }

    if (-not $IsResume) {
        Invoke-ExternalGate "verify_security_001" $Python @(
            (Join-Path $Project "tools\verify_security_001.py"),
            $Project
        )
        Invoke-ExternalGate "verify_recovery_004" $Python @(
            (Join-Path $Project "tools\verify_recovery_004.py"),
            $Project
        )
        Invoke-ExternalGate "verify_content_integrity" $Python @(
            (Join-Path $Project "tools\verify_content_integrity.py"),
            $Project,
            "--json-report",
            $ContentReportPath
        )
        Invoke-ExternalGate "verify_asset_001_files" $Python @(
            (Join-Path $Project "tools\verify_asset_001.py")
        )
        Invoke-ExternalGate "verify_prod_002" $Python @(
            (Join-Path $Project "tools\verify_prod_002.py"),
            "--registry", (Join-Path $Project "PROD_002_ISSUE_REGISTRY.json"),
            "--dashboard", (Join-Path $Project "PROD_002_MILESTONE_DASHBOARD.md")
        )
        Invoke-ExternalGate "verify_prod_003" $Python @(
            (Join-Path $Project "tools\verify_prod_003.py"),
            $Project
        )
    }

    $verifiers = @(
		"verify_runtime.gd", "verify_runtime_regressions.gd", "verify_zone_builder_integrity.gd", "verify_gate_transitions.gd", "verify_engine_001.gd", "verify_engine_003.gd", "verify_story_campaign.gd", "verify_quest_001.gd", "verify_quest_002.gd", "verify_save_001.gd", "verify_qa_002.gd", "verify_art_001.gd", "verify_asset_001.gd", "verify_character_real_001.gd", "verify_face_river_sun_001.gd",
        "verify_motion_quality.gd", "verify_river_swimming.gd", "verify_greyfen_life.gd",
		"verify_castle_vargan.gd", "verify_audio_runtime.gd", "verify_audio_001.gd", "verify_visible_quality.gd",
		"verify_recovery_002_foundation.gd", "verify_navigation_001.gd", "verify_char_001.gd", "verify_anim_001.gd", "verify_combat_001.gd", "verify_ai_001.gd", "verify_oath_001.gd", "verify_ui_001.gd", "verify_input_001.gd", "verify_mobile_001.gd", "verify_world_001.gd", "verify_world_002.gd", "verify_world_003.gd", "verify_zone_budgets.gd",
        "verify_visual_003.gd", "verify_visual_100.gd", "verify_master_002.gd", "verify_master_003.gd",
        "verify_mat_001.gd", "verify_char_002.gd", "verify_mon_001.gd", "verify_vfx_001.gd", "verify_water_001.gd",
        "verify_gameplay_001.gd", "verify_combat_002.gd", "verify_ai_002.gd", "verify_inv_001.gd", "verify_dialogue_001.gd", "verify_narr_001.gd",
        "verify_world_004.gd", "verify_quest_003.gd", "verify_world_005.gd", "verify_quest_004.gd",
        "verify_world_006.gd", "verify_quest_005.gd", "verify_boss_001.gd", "verify_side_001.gd", "verify_quest_006.gd", "verify_qa_004.gd",
        "verify_perf_003.gd"
    )
    $verifierNames = @($verifiers | ForEach-Object { [IO.Path]::GetFileNameWithoutExtension($_) })
    $resumeFromVerifier = $IsResume -and ($verifierNames -contains $ResumeFrom)
    $resumeFromPerformance = $IsResume -and $ResumeFrom -eq "verify_perf_001"
    $screenshotGates = @(
        "capture_slice_screenshots",
        "capture_anim_001",
        "capture_world_001",
        "capture_world_002",
        "capture_world_003",
        "capture_world_004",
        "capture_world_005",
        "capture_world_006",
        "capture_boss_001"
    )
    $resumeFromScreenshot = $IsResume -and ($screenshotGates -contains $ResumeFrom)
    if (-not $IsResume -or $resumeFromVerifier) {
        $resumeVerifierReached = -not $IsResume
        foreach ($verifier in $verifiers) {
            $name = [IO.Path]::GetFileNameWithoutExtension($verifier)
            if (-not $resumeVerifierReached) {
                if ($name -ne $ResumeFrom) { continue }
                $resumeVerifierReached = $true
            }
            if (-not [string]::IsNullOrWhiteSpace($Only) -and $name -ne $Only) { continue }
            Invoke-GodotGate $name @("--headless", "--path", $Project, "--script", "tools/$verifier")
        }
    }

    if ((-not $IsResume -or $resumeFromVerifier -or $resumeFromPerformance) -and [string]::IsNullOrWhiteSpace($Only) -and -not $SkipPerformance) {
		if ([string]::IsNullOrWhiteSpace($GodotGraphical) -or -not (Test-Path -LiteralPath $GodotGraphical)) {
			throw "Graphical Godot 4.6.3 binary not found for verify_perf_001: $GodotGraphical"
		}
        Invoke-GodotGate "verify_perf_001" @(
            "--path", $Project, "--rendering-method", "gl_compatibility",
            "--script", "tools/verify_perf_001.gd"
        ) $GodotGraphical
    }
    if (-not $IsResume -and [string]::IsNullOrWhiteSpace($Only)) {
        $qaLogArguments = @()
        foreach ($verifierName in $verifierNames) {
            $qaLogArguments += "--log"
            $qaLogArguments += (Join-Path $Logs "$verifierName.log")
        }
        $qaLogArguments += "--log"
        $qaLogArguments += (Join-Path $Logs "verify_perf_001.log")
        # Flatten the log switches into the argument array. Passing the
        # collection as one nested element makes argparse see the entire list
        # as a single malformed --log value and masks the real QA result.
        $qaArguments = @(
            (Join-Path $Project "tools\verify_qa_005.py"),
            $Project
        ) + $qaLogArguments + @(
            "--report", (Join-Path $Logs "qa_005_report.json")
        )
        Invoke-ExternalGate "verify_qa_005" $Python $qaArguments
    }
    if ((-not $IsResume -or $resumeFromVerifier -or $resumeFromPerformance -or $resumeFromScreenshot) -and [string]::IsNullOrWhiteSpace($Only) -and -not $SkipScreenshots) {
        $captureReached = -not $resumeFromScreenshot
        foreach ($captureName in $screenshotGates) {
            if (-not $captureReached) {
                if ($captureName -ne $ResumeFrom) { continue }
                $captureReached = $true
            }
            Invoke-GodotGate $captureName @(
                "--path", $Project, "--rendering-method", "gl_compatibility",
                "--script", "tools/$captureName.gd"
            )
        }
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
        Invoke-ExternalGate "verify_screenshot_qa_003" $Python @(
            (Join-Path $Project "tools\verify_screenshot_qa_003.py"),
            $Project,
            "--mode", "milestone",
            "--report", (Join-Path $Logs "qa_003_milestone_report.json")
        )
        Invoke-ExternalGate "verify_qa_006" $Python @(
            (Join-Path $Project "tools\verify_qa_006.py"),
            $Project,
            "--report", (Join-Path $Logs "qa_006_report.json")
        )
    }

    if ([string]::IsNullOrWhiteSpace($Only) -and -not $SkipExport -and -not $webTailResume -and -not $mobileTailResume) {
        Invoke-ExternalGate "verify_web_001" $Python @(
            (Join-Path $Project "tools\verify_web_001.py"),
            $Project,
            (Resolve-Path (Join-Path $Project "..\.."))
        )
        Invoke-ExternalGate "verify_web_002" $Python @(
            (Join-Path $Project "tools\verify_web_002.py"),
            $Project
        )
        Invoke-ExternalGate "web_export" (Join-Path $Project "Export_Web_Build.bat") @()
        Invoke-ExternalGate "verify_web_export" $Python @(
            (Join-Path $Project "tools\verify_web_export.py"), $Web,
            "--json-report", (Join-Path $Logs "web_export.json")
        )
        $pack = Join-Path $Web "index.pck"
        Invoke-GodotGate "packed_startup" @(
            # The exported folder is an artifact, not a Godot project. Start the
            # packed game with the source project context so remapped resources
            # and the PCK are resolved consistently in CI and locally.
            "--headless", "--path", $Project, "--main-pack", $pack,
            "--script", "tools/verify_packed_startup.gd"
        )
        Invoke-ExternalGate "verify_web_browser" $Node @(
            (Join-Path $Project "tools\verify_web_browser.mjs"),
            "--export", $Web,
            "--report", (Join-Path $Logs "web_browser.json")
        )
        Invoke-ExternalGate "qa_web_export" $Godot @(
            "--headless", "--path", $Project, "--export-release", "Web QA Browser"
        )
        Invoke-ExternalGate "verify_qa_002" $Godot @(
            "--headless", "--path", $Project, "--script", "tools/verify_qa_002.gd"
        )
        Invoke-ExternalGate "verify_mobile_browser" $Node @(
            (Join-Path $Project "tools\verify_web_browser.mjs"),
            "--export", $Web,
            "--report", (Join-Path $Logs "mobile_browser.json"),
            "--mobile", "true"
        )
        Invoke-ExternalGate "verify_web_002_browser" $Node @(
            (Join-Path $Project "tools\verify_qa_002_browser.mjs"),
            "--export", $QAWeb,
            "--browser", "all",
            "--full-campaign", "true",
            "--report", (Join-Path $Logs "web_002_browser.json")
        )
        Invoke-ExternalGate "verify_web_002_mobile" $Node @(
            (Join-Path $Project "tools\verify_qa_002_browser.mjs"),
            "--export", $QAWeb,
            "--browser", "all",
            "--full-campaign", "true",
            "--mobile", "true",
            "--report", (Join-Path $Logs "web_002_mobile.json")
        )
    }
	if ([string]::IsNullOrWhiteSpace($Only) -and -not $SkipExport -and $webTailResume) {
		# The package and all preceding browser gates are already recorded in the
		# release report. Resume only the failed full-campaign browser gate and
		# its mobile companion against the verified QA export.
		Invoke-ExternalGate "verify_web_002_browser" $Node @(
			(Join-Path $Project "tools\verify_qa_002_browser.mjs"),
			"--export", $QAWeb,
			"--browser", "all",
			"--full-campaign", "true",
			"--report", (Join-Path $Logs "web_002_browser.json")
		)
		Invoke-ExternalGate "verify_web_002_mobile" $Node @(
			(Join-Path $Project "tools\verify_qa_002_browser.mjs"),
			"--export", $QAWeb,
			"--browser", "all",
			"--full-campaign", "true",
			"--mobile", "true",
			"--report", (Join-Path $Logs "web_002_mobile.json")
		)
	}
	if ([string]::IsNullOrWhiteSpace($Only) -and -not $SkipExport -and $mobileTailResume) {
		# Desktop Web and export gates already passed in the prior report. Resume
		# at the corrected mobile smoke gate, then continue through the campaign
		# browser checks against the existing verified QA export.
		Invoke-ExternalGate "verify_mobile_browser" $Node @(
			(Join-Path $Project "tools\verify_web_browser.mjs"),
			"--export", $Web,
			"--report", (Join-Path $Logs "mobile_browser.json"),
			"--mobile", "true"
		)
		Invoke-ExternalGate "verify_web_002_browser" $Node @(
			(Join-Path $Project "tools\verify_qa_002_browser.mjs"),
			"--export", $QAWeb,
			"--browser", "all",
			"--full-campaign", "true",
			"--report", (Join-Path $Logs "web_002_browser.json")
		)
		Invoke-ExternalGate "verify_web_002_mobile" $Node @(
			(Join-Path $Project "tools\verify_qa_002_browser.mjs"),
			"--export", $QAWeb,
			"--browser", "all",
			"--full-campaign", "true",
			"--mobile", "true",
			"--report", (Join-Path $Logs "web_002_mobile.json")
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
