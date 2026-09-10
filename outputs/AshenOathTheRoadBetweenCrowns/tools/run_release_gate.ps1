param(
    [switch]$SkipExport,
    [switch]$SkipPerformance,
    [switch]$SkipScreenshots,
    [switch]$Strict,
[switch]$VerboseOutput,
[string]$Only = "",
[string]$ResumeFrom = "",
[int]$TimeoutSeconds = 240
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
# The full-campaign browser gate runs clean Chrome and Edge sessions
# sequentially. Each session has its own bounded route timeout; this outer
# budget must cover both sessions without treating a valid run as a hang.
$BrowserRouteTimeoutSeconds = 1800
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

function Get-ArtifactSnapshot {
    $records = [System.Collections.Generic.List[object]]::new()
    $totalBytes = [int64]0
    if (Test-Path -LiteralPath $Web -PathType Container) {
        $artifactRoot = (Resolve-Path -LiteralPath $Web).Path.TrimEnd('\')
        foreach ($item in Get-ChildItem -LiteralPath $Web -Recurse -File | Sort-Object FullName) {
            $relativePath = $item.FullName.Substring($artifactRoot.Length + 1).Replace('\', '/')
            $hash = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            $totalBytes += [int64]$item.Length
            $records.Add([ordered]@{
                path = $relativePath
                bytes = [int64]$item.Length
                sha256 = $hash
            })
        }
    }
    $pck = $records | Where-Object { $_.path -eq "index.pck" } | Select-Object -First 1
    return [ordered]@{
        directory = $Web
        total_bytes = $totalBytes
        files = @($records)
        pck_sha256 = if ($null -ne $pck) { [string]$pck.sha256 } else { "" }
        max_bytes = 104857600
    }
}

function Get-SourceFingerprint {
    # Keep this contract byte-for-byte aligned with verify_release_report.py:
    # relative path, NUL, and the lowercase hexadecimal SHA-256 of each runtime
    # input. Hex is used because Windows PowerShell 5 lacks FromHexString.
    $entries = [System.Collections.Generic.List[object]]::new()
    foreach ($root in @((Join-Path $Project "scripts"), (Join-Path $Project "scenes"), (Join-Path $Project "data"))) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object { $_.Extension.ToLowerInvariant() -in @('.gd','.tscn','.json') } | Sort-Object FullName) {
            $relative = $file.FullName.Substring($Project.Length + 1).Replace('\','/')
            $digest = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            $entries.Add([pscustomobject]@{ Path = $relative; Digest = $digest })
        }
    }
    foreach ($relative in @(
        "project.godot",
        "export_presets.cfg",
        "runtime_asset_manifest.json",
        "curated_runtime_assets.json",
        "character_role_manifest.json",
        "soul_character_role_manifest.json",
        "runtime_pack_manifest.json",
        "runtime_pack_candidates.json",
        "web_boot_shell.html"
    )) {
        $candidate = Join-Path $Project $relative
        if (Test-Path -LiteralPath $candidate) {
            $entries.Add([pscustomobject]@{ Path = $relative; Digest = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash.ToLowerInvariant() })
        }
    }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $stream = [System.IO.MemoryStream]::new()
    $encoding = [System.Text.Encoding]::UTF8
    try {
        foreach ($entry in ($entries | Sort-Object Path)) {
            $pathBytes = $encoding.GetBytes([string]$entry.Path)
            $digestBytes = $encoding.GetBytes([string]$entry.Digest)
            $stream.Write($pathBytes, 0, $pathBytes.Length)
            $stream.WriteByte(0)
            $stream.Write($digestBytes, 0, $digestBytes.Length)
        }
        return ([BitConverter]::ToString($sha.ComputeHash($stream.ToArray()))).Replace('-','').ToLowerInvariant()
    } finally {
        $stream.Dispose()
        $sha.Dispose()
    }
}

function Get-ReleaseWorktreeStatus {
    # A strict release is allowed to create the evidence and report it is
    # validating. Runtime source changes remain visible and still block. This
    # keeps the report honest without requiring a commit in the middle of a
    # release run.
    $status = @(git -C $RepoRoot status --short)
    return @($status | Where-Object {
        $_ -notmatch '^.. outputs/AshenOathTheRoadBetweenCrowns/release_reports/latest\.json$' -and
        $_ -notmatch '^.. outputs/AshenOathTheRoadBetweenCrowns/Development_Gallery/screenshots/' -and
        $_ -notmatch '^\?\? outputs/AshenOathTheRoadBetweenCrowns/tools/_inspect_milestone_c_assets\.gd$'
    })
}

function Get-BlockingIssueSnapshot {
    $registryPath = Join-Path $Project "RECOVERY_004_ISSUE_REGISTRY.json"
    if (-not (Test-Path -LiteralPath $registryPath -PathType Leaf)) {
        return @()
    }
    try {
        $registry = Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json
        return @($registry.categories | Where-Object {
            $_.status -ne "verified" -and $_.status -ne "deferred"
        } | ForEach-Object {
            [ordered]@{
                id = [string]$_.id
                severity = [string]$_.severity
                status = [string]$_.status
            }
        })
    } catch {
        return @([ordered]@{ id = "RECOVERY-004-REGISTRY"; severity = "blocker"; status = "unreadable" })
    }
}

function Get-ScreenshotEvidence {
    $capturePath = Join-Path $Logs "qa_003_milestone_report.json"
    $evidence = [ordered]@{}
    if (-not (Test-Path -LiteralPath $capturePath -PathType Leaf)) {
        return $evidence
    }
    try {
        $captureReport = Get-Content -LiteralPath $capturePath -Raw | ConvertFrom-Json
        foreach ($entry in @($captureReport.results)) {
            $viewId = [string]$entry.view_id
            if ([string]::IsNullOrWhiteSpace($viewId)) { continue }
            $status = if ([string]$entry.status -eq "pass") { "approved" } else { "pending" }
            $evidence[$viewId] = [ordered]@{
                status = $status
                image = [string]$entry.image
                message = [string]$entry.message
                metrics = $entry.metrics
            }
        }
    } catch {
        # Leave the evidence empty so the strict report verifier blocks the
        # release instead of accepting malformed or partial screenshot data.
        return [ordered]@{}
    }
    return $evidence
}

function Write-ReleaseReport([string]$Status, [string]$Failure = "") {
    $head = ""
	try { $head = (git -C $RepoRoot rev-parse HEAD).Trim() } catch {}
    $branch = ""
    try { $branch = (git -C $RepoRoot branch --show-current).Trim() } catch {}
    $gitStatus = @()
    try { $gitStatus = @(Get-ReleaseWorktreeStatus) } catch {}
    $screenshotEvidence = Get-ScreenshotEvidence
    $report = [ordered]@{
        schema_version = 2
        release_id = if ($env:ASHENOATH_RELEASE_ID) { $env:ASHENOATH_RELEASE_ID } else { "recovery-004" }
        status = $Status
        started_at = $StartedAt.ToUniversalTime().ToString("o")
        finished_at = (Get-Date).ToUniversalTime().ToString("o")
        source_commit = $head
        source_branch = $branch
        source_fingerprint = Get-SourceFingerprint
        git_status = $gitStatus
        mode = $(if ([string]::IsNullOrWhiteSpace($Only)) { "full" } else { "targeted" })
        requested_gate = $Only
        project = "outputs/AshenOathTheRoadBetweenCrowns"
        artifact = Get-ArtifactSnapshot
        release_blockers = Get-BlockingIssueSnapshot
        failure = $Failure
        results = @($Results)
        screenshots = $screenshotEvidence
    }
    $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ReportPath -Encoding utf8
}

function ConvertTo-ArgumentLine([string[]]$Arguments) {
    return (($Arguments | ForEach-Object {
        $value = [string]$_
        if ($value -match '[\s"]') {
            '"' + $value.Replace('"', '\\"') + '"'
        } else {
            $value
        }
    }) -join ' ')
}

function Stop-IsolatedProcess([Diagnostics.Process]$Process) {
    if ($null -eq $Process -or $Process.HasExited) { return }
    # Browser and export helpers may create children. Kill only the process
    # tree started by this gate, never a user-owned process by name.
    try {
        & taskkill.exe /PID $Process.Id /T /F 2>$null | Out-Null
    } catch {
        try { Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue } catch {}
    }
    try { $Process.WaitForExit(5000) } catch {}
}

function Invoke-ManagedProcess(
    [string]$Executable,
    [string[]]$Arguments,
    [string]$StdoutPath,
    [string]$StderrPath,
    [int]$TimeoutOverride = 0
) {
    Remove-Item -LiteralPath $StdoutPath, $StderrPath -Force -ErrorAction SilentlyContinue
    $effectiveTimeoutSeconds = if ($TimeoutOverride -gt 0) { $TimeoutOverride } else { $TimeoutSeconds }
    if ([IO.Path]::GetFileName($Executable) -match '^Godot_.*_console\.exe$') {
        # Capture the console build through an owned Process handle. Invoking
        # it with PowerShell's call operator can surface Godot's shutdown
        # diagnostics as a terminating native-command error after the verifier
        # has already passed. An explicit redirected handle keeps stdout and
        # stderr in the gate log so shutdown classification remains reliable.
        $startInfo = [Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = $Executable
        $startInfo.Arguments = ConvertTo-ArgumentLine $Arguments
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $process = [Diagnostics.Process]::new()
        $process.StartInfo = $startInfo
        try {
            [void]$process.Start()
            $stdoutTask = $process.StandardOutput.ReadToEndAsync()
            $stderrTask = $process.StandardError.ReadToEndAsync()
            $completed = $process.WaitForExit($effectiveTimeoutSeconds * 1000)
            if (-not $completed) {
                Stop-IsolatedProcess $process
            }
            $stdout = $stdoutTask.GetAwaiter().GetResult()
            $stderr = $stderrTask.GetAwaiter().GetResult()
            [IO.File]::WriteAllText($StdoutPath, $stdout)
            [IO.File]::WriteAllText($StderrPath, $stderr)
            $exitCode = if ($completed) { [int]$process.ExitCode } else { 124 }
        } finally {
            $process.Dispose()
        }
        return [pscustomobject]@{
            ExitCode = $exitCode
            TimedOut = -not $completed
        }
    }
    $launchExecutable = $Executable
    $argumentLine = ConvertTo-ArgumentLine $Arguments
    if ([IO.Path]::GetExtension($Executable).ToLowerInvariant() -eq ".bat") {
        $launchExecutable = $env:ComSpec
        $argumentLine = '/d /s /c "' + $Executable + '" ' + $argumentLine
    }
    $process = Start-Process -FilePath $launchExecutable -ArgumentList $argumentLine `
        -RedirectStandardOutput $StdoutPath -RedirectStandardError $StderrPath -PassThru
    $completed = $process.WaitForExit($effectiveTimeoutSeconds * 1000)
    $timedOut = -not $completed
    if ($timedOut) {
        Stop-IsolatedProcess $process
        $exitCode = 124
    } else {
        $exitCode = [int]$process.ExitCode
    }
    return [pscustomobject]@{
        ExitCode = $exitCode
        TimedOut = $timedOut
    }
}

function Invoke-ExternalGate(
    [string]$Name,
    [string]$Executable,
    [string[]]$Arguments,
    [int]$TimeoutOverride = 0
) {
    $log = Join-Path $Logs "$Name.log"
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    $stdoutPath = "$log.stdout.tmp"
    $stderrPath = "$log.stderr.tmp"
    $managed = Invoke-ManagedProcess $Executable $Arguments $stdoutPath $stderrPath $TimeoutOverride
    $stdout = if (Test-Path -LiteralPath $stdoutPath) { Get-Content -LiteralPath $stdoutPath -Raw } else { "" }
    $stderr = if (Test-Path -LiteralPath $stderrPath) { Get-Content -LiteralPath $stderrPath -Raw } else { "" }
    [IO.File]::WriteAllText($log, $stdout + $stderr)
    if ($VerboseOutput -and ($stdout.Length -gt 0 -or $stderr.Length -gt 0)) { Write-Host ($stdout + $stderr) -NoNewline }
    Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
    $exitCode = $managed.ExitCode
    $timer.Stop()
    if ($managed.TimedOut) {
        $timeoutLabel = if ($TimeoutOverride -gt 0) { $TimeoutOverride } else { $TimeoutSeconds }
        $failure = "$Name timed out after $timeoutLabel seconds"
        Add-Result $Name "fail" $timer.Elapsed.TotalSeconds $log @() $failure
        if (-not $VerboseOutput) { Get-Content -LiteralPath $log -Tail 40 }
        throw "$failure. Full log: $log"
    }
    if ($exitCode -ne 0) {
        $failure = "$Name failed with exit code $exitCode"
        Add-Result $Name "fail" $timer.Elapsed.TotalSeconds $log @() $failure
        if (-not $VerboseOutput) { Get-Content -LiteralPath $log -Tail 40 }
        throw $failure
    }
	# Browser gates write structured reports in addition to their process exit
	# code. Treat a non-pass report as a failure even if a wrapper or native
	# process masks the child's exit status.
	$reportArgIndex = [Array]::IndexOf($Arguments, "--report")
	if ($reportArgIndex -ge 0 -and $reportArgIndex + 1 -lt $Arguments.Count) {
		$reportFile = [string]$Arguments[$reportArgIndex + 1]
		if (-not (Test-Path -LiteralPath $reportFile)) {
			$failure = "$Name completed without its structured report: $reportFile"
			Add-Result $Name "fail" $timer.Elapsed.TotalSeconds $log @() $failure
			if (-not $VerboseOutput) { Get-Content -LiteralPath $log -Tail 40 }
			throw $failure
		}
		$reportStatus = $null
		$reportParseError = $null
		try {
			$structuredReport = Get-Content -LiteralPath $reportFile -Raw | ConvertFrom-Json
			if ($structuredReport.PSObject.Properties.Name -contains "status") {
				$reportStatus = [string]$structuredReport.status
			}
		} catch {
			$reportParseError = $_.Exception.Message
		}
		if ($null -ne $reportParseError) {
			$failure = "$Name produced an unreadable structured report: $reportParseError"
			Add-Result $Name "fail" $timer.Elapsed.TotalSeconds $log @() $failure
			if (-not $VerboseOutput) { Get-Content -LiteralPath $log -Tail 40 }
			throw $failure
		}
		if ($null -ne $reportStatus -and $reportStatus -ne "pass") {
			$failure = "$Name reported status '$reportStatus' despite exit code 0"
			Add-Result $Name "fail" $timer.Elapsed.TotalSeconds $log @() $failure
			if (-not $VerboseOutput) { Get-Content -LiteralPath $log -Tail 40 }
			throw $failure
		}
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
    $managed = Invoke-ManagedProcess $Executable $Arguments $stdoutPath $stderrPath
    $stdout = if (Test-Path -LiteralPath $stdoutPath) { Get-Content -LiteralPath $stdoutPath -Raw } else { "" }
    $stderr = if (Test-Path -LiteralPath $stderrPath) { Get-Content -LiteralPath $stderrPath -Raw } else { "" }
    if ($stdout.Length -gt 0) { [IO.File]::WriteAllText($Log, $stdout) } else { [IO.File]::WriteAllText($Log, "") }
    if ($stderr.Length -gt 0) { Add-Content -LiteralPath $Log -Value $stderr -NoNewline }
    Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
    if ($managed.TimedOut) { return 124 }
    return [int]$managed.ExitCode
}

function Invoke-GodotGate([string]$Name, [string[]]$Arguments, [string]$Executable = "") {
	$Runner = $Godot
	if (-not [string]::IsNullOrWhiteSpace($Executable)) { $Runner = $Executable }
    $log = Join-Path $Logs "$Name.log"
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    if (-not [string]::IsNullOrWhiteSpace($Executable)) {
        $exitCode = Invoke-CapturedProcess $Runner $Arguments $log
    } else {
        $stdoutPath = "$log.stdout.tmp"
        $stderrPath = "$log.stderr.tmp"
        $managed = Invoke-ManagedProcess $Runner $Arguments $stdoutPath $stderrPath
        $stdout = if (Test-Path -LiteralPath $stdoutPath) { Get-Content -LiteralPath $stdoutPath -Raw } else { "" }
        $stderr = if (Test-Path -LiteralPath $stderrPath) { Get-Content -LiteralPath $stderrPath -Raw } else { "" }
        [IO.File]::WriteAllText($log, $stdout + $stderr)
        if ($VerboseOutput -and ($stdout.Length -gt 0 -or $stderr.Length -gt 0)) { Write-Host ($stdout + $stderr) -NoNewline }
        Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
        $exitCode = $managed.ExitCode
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
	# Runtime diagnostics are fatal until a verifier explicitly enters its
	# shutdown phase. This prevents a test from printing PASS early and hiding a
	# real active-render failure, while allowing the known Godot 4.6.3
	# Compatibility allocator messages emitted after all owned nodes have been
	# retired. Verifiers that use this classification must print the phase
	# marker immediately before cleanup and print their final PASS afterwards.
	$shutdownIndex = -1
	for ($index = 0; $index -lt $lines.Count; $index++) {
		if ($lines[$index] -match 'VERIFIER_PHASE:\s*SHUTDOWN') {
			$shutdownIndex = $index
			break
		}
	}
	$shutdownResourcePattern = 'Parameter "material" is null|RID allocations .* leaked at exit|Pages in use exist at exit|resources still in use at exit|Buffer with GL ID .* leaked|shaders of type .* never freed|ObjectDB instances leaked at exit|Leaked instance dependency|did not call instance_notify_deleted|Orphan .* at exit'
	$activeResourcePattern = 'Parameter "material" is null|RID allocations .* leaked at exit|Pages in use exist at exit|resources still in use at exit|Buffer with GL ID .* leaked|shaders of type .* never freed|ObjectDB instances leaked at exit|Leaked instance dependency|did not call instance_notify_deleted|Orphan .* at exit|Condition .* is true'
    $fatalPattern = 'SCRIPT ERROR|Parse Error|Compile Error|Failed to load|Cannot open|ERROR:|VERIFIER:\s*FAIL|ASSERTION FAILED|Assertion failed'
    for ($index = 0; $index -lt $lines.Count; $index++) {
        $line = $lines[$index]
		if ($line -match $shutdownResourcePattern) {
			if ($shutdownIndex -ge 0 -and $index -gt $shutdownIndex) {
				$warnings.Add($line.Trim())
			} else {
				$fatal.Add($line.Trim())
			}
			continue
		}
		if ($line -notmatch $fatalPattern) { continue }
        # PowerShell wraps native stderr as an ErrorRecord and abbreviates the
        # original line inside CategoryInfo. The complete stderr line is also
        # present in the log and is classified independently below.
        if ($line -match '^\s*\+\s+CategoryInfo|FullyQualifiedErrorId.*NativeCommandError') {
            continue
        }
		$fatal.Add($line.Trim())
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

function Sync-QAWebPacks {
    $sourcePackDirectory = Join-Path $Web "packs"
    if (-not (Test-Path -LiteralPath $sourcePackDirectory)) {
        throw "Verified Web export is missing runtime packs: $sourcePackDirectory"
    }
    $qaPackDirectory = Join-Path $QAWeb "packs"
    New-Item -ItemType Directory -Force -Path $qaPackDirectory | Out-Null
    foreach ($packName in @("opening", "campaign", "characters", "monsters", "audio")) {
        $sourcePack = Join-Path $sourcePackDirectory "$packName.pck"
        if (-not (Test-Path -LiteralPath $sourcePack)) {
            throw "Verified Web export is missing runtime pack: $sourcePack"
        }
        Copy-Item -LiteralPath $sourcePack -Destination (Join-Path $qaPackDirectory "$packName.pck") -Force
    }
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
        Invoke-ExternalGate "verify_runtime_required_components" $Python @(
            (Join-Path $Project "tools\verify_runtime_required_components.py"),
            $Project,
            "--json-report",
            (Join-Path $Logs "runtime_required_components.json")
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
        "verify_runtime_smoke.gd", "verify_runtime.gd", "verify_runtime_regressions.gd", "verify_zone_builder_integrity.gd", "verify_gate_transitions.gd", "verify_engine_001.gd", "verify_engine_003.gd", "verify_engine_004.gd", "verify_story_campaign.gd", "verify_quest_002.gd", "verify_objective_view_model.gd", "verify_save_001.gd", "verify_qa_002.gd", "verify_art_001.gd", "verify_asset_001.gd", "verify_character_real_001.gd", "verify_face_river_sun_001.gd",
        "verify_motion_quality.gd", "verify_river_swimming.gd", "verify_greyfen_life.gd",
		"verify_castle_vargan.gd", "verify_audio_runtime.gd", "verify_audio_001.gd", "verify_visible_quality.gd",
		"verify_recovery_002_foundation.gd", "verify_navigation_001.gd", "verify_char_001.gd", "verify_anim_001.gd", "verify_combat_001.gd", "verify_ai_001.gd", "verify_oath_001.gd", "verify_ui_001.gd", "verify_input_001.gd", "verify_mobile_001.gd", "verify_world_001.gd", "verify_world_002.gd", "verify_world_003.gd", "verify_world_014.gd", "verify_zone_budgets.gd",
        "verify_visual_003.gd", "verify_visual_100.gd", "verify_master_002.gd", "verify_master_003.gd",
        "verify_mat_001.gd", "verify_char_002.gd", "verify_mon_001.gd", "verify_vfx_001.gd", "verify_water_001.gd",
        "verify_gameplay_001.gd", "verify_combat_002.gd", "verify_ai_002.gd", "verify_inv_001.gd", "verify_dialogue_001.gd", "verify_narr_001.gd",
        "verify_world_004.gd", "verify_quest_003.gd", "verify_world_005.gd", "verify_quest_004.gd",
        "verify_world_006.gd", "verify_quest_005.gd", "verify_boss_001.gd", "verify_side_001.gd", "verify_quest_006.gd", "verify_qa_004.gd",
        "verify_perf_003.gd"
    )
    $verifierNames = @($verifiers | ForEach-Object { [IO.Path]::GetFileNameWithoutExtension($_) })
    $qa005ManifestPath = Join-Path $Logs "qa_005_inputs.json"
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
        $qa005Logs = @($verifierNames + "verify_perf_001" | ForEach-Object { "$_.log" })
        $qa005Manifest = [ordered]@{
            schema_version = 1
            run_id = [guid]::NewGuid().ToString("N")
            started_at = $StartedAt.ToUniversalTime().ToString("o")
            logs = @($qa005Logs)
        }
        # Windows PowerShell's `-Encoding utf8` writes a BOM, while the
        # verifier manifest is a UTF-8 interchange file consumed by Python.
        # Write it explicitly without a BOM so a fresh run cannot fail before
        # it classifies the current gate logs.
        $manifestJson = $qa005Manifest | ConvertTo-Json -Depth 4
        [IO.File]::WriteAllText($qa005ManifestPath, $manifestJson + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
        $qaArguments = @(
            (Join-Path $Project "tools\verify_qa_005.py"),
            $Project,
            "--run-manifest", $qa005ManifestPath,
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
        Sync-QAWebPacks
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
        ) -TimeoutOverride $BrowserRouteTimeoutSeconds
        Invoke-ExternalGate "verify_web_002_mobile" $Node @(
            (Join-Path $Project "tools\verify_qa_002_browser.mjs"),
            "--export", $QAWeb,
            "--browser", "all",
            "--full-campaign", "true",
            "--mobile", "true",
            "--report", (Join-Path $Logs "web_002_mobile.json")
        ) -TimeoutOverride $BrowserRouteTimeoutSeconds
    }
	if ([string]::IsNullOrWhiteSpace($Only) -and -not $SkipExport -and $webTailResume) {
		# The package and all preceding browser gates are already recorded in the
		# release report. Resume only the failed full-campaign browser gate and
		# its mobile companion against the verified QA export.
		Sync-QAWebPacks
		Invoke-ExternalGate "verify_web_002_browser" $Node @(
			(Join-Path $Project "tools\verify_qa_002_browser.mjs"),
			"--export", $QAWeb,
			"--browser", "all",
			"--full-campaign", "true",
			"--report", (Join-Path $Logs "web_002_browser.json")
		) -TimeoutOverride $BrowserRouteTimeoutSeconds
		Invoke-ExternalGate "verify_web_002_mobile" $Node @(
			(Join-Path $Project "tools\verify_qa_002_browser.mjs"),
			"--export", $QAWeb,
			"--browser", "all",
			"--full-campaign", "true",
			"--mobile", "true",
			"--report", (Join-Path $Logs "web_002_mobile.json")
		) -TimeoutOverride $BrowserRouteTimeoutSeconds
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
		) -TimeoutOverride $BrowserRouteTimeoutSeconds
		Invoke-ExternalGate "verify_web_002_mobile" $Node @(
			(Join-Path $Project "tools\verify_qa_002_browser.mjs"),
			"--export", $QAWeb,
			"--browser", "all",
			"--full-campaign", "true",
			"--mobile", "true",
			"--report", (Join-Path $Logs "web_002_mobile.json")
		) -TimeoutOverride $BrowserRouteTimeoutSeconds
	}
    # A skipped or resumed run is evidence for the requested slice only.
    # Never label it as a complete release pass when mandatory stages did not run.
    $hasSkippedStages = $SkipExport -or $SkipPerformance -or $SkipScreenshots -or $IsResume
    $isCompleteReleaseRun = [string]::IsNullOrWhiteSpace($Only) -and -not $hasSkippedStages
    $blockingIssues = @(Get-BlockingIssueSnapshot)
    if ($isCompleteReleaseRun -and $blockingIssues.Count -gt 0) {
        $blockerSummary = ($blockingIssues | ForEach-Object {
            "%s=%s" -f [string]$_.id, [string]$_.status
        }) -join ", "
        $failure = "Release blocked by unresolved issue registry entries: $blockerSummary"
        Write-ReleaseReport "fail" $failure
        Write-Error "AUTHORITATIVE RELEASE GATE: FAIL - $failure"
        exit 1
    }
    $finalStatus = $(if ($isCompleteReleaseRun) { "pass" } else { "partial-pass" })
    Write-ReleaseReport $finalStatus
    if ($Strict -and [string]::IsNullOrWhiteSpace($Only)) {
        Invoke-ExternalGate "verify_release_report" $Python @(
            (Join-Path $Project "tools\verify_release_report.py"),
            $Project,
            "--report", $ReportPath,
            "--strict"
        )
        Write-ReleaseReport "pass"
    }
    Write-Host "AUTHORITATIVE RELEASE GATE: $($finalStatus.ToUpper())"
    Write-Host "Release report: $ReportPath"
}
catch {
    $failure = $_.Exception.Message
    Write-ReleaseReport "fail" $failure
    Write-Error "AUTHORITATIVE RELEASE GATE: FAIL - $failure"
    exit 1
}
