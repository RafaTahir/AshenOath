param(
    [switch]$SkipExport,
    [switch]$SkipPerformance,
    [switch]$SkipScreenshots,
    [switch]$Strict,
    [switch]$VerboseOutput,
    [string]$Only = "",
    [string]$ResumeFrom = "",
    [string]$FunctionalEvidence = "",
    [ValidateSet("candidate", "release", "final")]
    [string]$ReleasePhase = "candidate",
    [ValidateSet("strict", "functional_candidate")]
    [string]$AcceptanceProfile = "strict",
    [int]$TimeoutSeconds = 240
)

$ErrorActionPreference = "Stop"
$FunctionalCandidate = $AcceptanceProfile -eq "functional_candidate"
$CampaignBrowser = if ($FunctionalCandidate) { "chrome" } else { "all" }
$EnforceBrowserPerformance = if ($FunctionalCandidate) { "false" } else { "true" }
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
if ($FunctionalEvidence) {
    if (-not $FunctionalCandidate -or -not $SkipExport -or -not $SkipPerformance -or -not $SkipScreenshots) {
        throw "Preserved evidence aggregation requires functional_candidate and all three Skip switches"
    }
    $EvidenceBundle = Get-Content -LiteralPath $FunctionalEvidence -Raw | ConvertFrom-Json
    $Web = [string]$EvidenceBundle.artifact_directory
}
$Logs = Join-Path $Project ".release-gate"
# The full campaign can take 45 minutes per browser. Keep the owned-process
# timeout longer than one route; the driver retains its own per-browser bound.
$BrowserRouteTimeoutSeconds = 3600
$ReportDirectory = Join-Path $Project "release_reports"
$ReportPath = Join-Path $ReportDirectory "latest.json"
if ($FunctionalEvidence) { $ReportPath = Join-Path $ReportDirectory "functional_candidate_v10.json" }
$StartedAt = Get-Date
$Results = [System.Collections.Generic.List[object]]::new()
$ReportId = [guid]::NewGuid().ToString("N")
$RunDirectory = Join-Path $Logs ("runs\{0}" -f $ReportId)
$ContentReportPath = Join-Path $RunDirectory "content_integrity.json"
New-Item -ItemType Directory -Force -Path $Logs | Out-Null
New-Item -ItemType Directory -Force -Path $ReportDirectory | Out-Null
New-Item -ItemType Directory -Force -Path $RunDirectory | Out-Null
$IsResume = -not [string]::IsNullOrWhiteSpace($ResumeFrom)
$webTailResume = $IsResume -and $ResumeFrom -eq "verify_web_002_browser"
$mobileTailResume = $IsResume -and $ResumeFrom -eq "verify_mobile_browser"
$previousReport = $null
$CurrentRuntimeFingerprint = ""
$CurrentHarnessFingerprint = ""
$CurrentRegistryFingerprint = ""
$CurrentArtifactFingerprint = ""
$ExecutionFingerprint = ""
$RequiredGateNames = @()
$FileHashCache = @{}
$CurrentGateIdentity = $null
$Qa002BranchRoutes = @(
    @{ slug = "opening_save_continue"; flag = "opening-save-continue" },
    @{ slug = "ending_matrix"; flag = "ending-matrix" },
    @{ slug = "shrine_matrix"; flag = "shrine-matrix" },
    @{ slug = "report_matrix"; flag = "report-matrix" },
    @{ slug = "ledger_matrix"; flag = "ledger-matrix" },
    @{ slug = "edric_matrix"; flag = "edric-matrix" },
    @{ slug = "mill_matrix"; flag = "mill-matrix" },
    @{ slug = "senn_matrix"; flag = "senn-matrix" },
    @{ slug = "widow_matrix"; flag = "widow-matrix" },
    @{ slug = "iron_matrix"; flag = "iron-matrix" },
    @{ slug = "returned_soldier_matrix"; flag = "returned-soldier-matrix" },
    @{ slug = "bitter_roots_matrix"; flag = "bitter-roots-matrix" },
    @{ slug = "black_dog_matrix"; flag = "black-dog-matrix" },
    @{ slug = "named_dead_route"; flag = "named-dead-matrix" },
    @{ slug = "rooks_map_matrix"; flag = "rooks-map-matrix" },
    @{ slug = "millers_measure_matrix"; flag = "millers-measure-matrix" },
    @{ slug = "bannerless_matrix"; flag = "bannerless-matrix" }
)

function Get-StringSha256([string]$Value) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

function Test-GateUsesArtifact([string]$Name) {
    return $Name -in @("web_export", "verify_web_export", "packed_startup", "verify_web_browser", "verify_mobile_browser", "verify_web_002_browser", "verify_web_002_mobile", "qa_002_candidate") -or
        $Name.StartsWith("qa_002_branch_", [StringComparison]::Ordinal)
}

function Get-LogReference([string]$Log) {
    $fullLog = [IO.Path]::GetFullPath($Log)
    $fullRoot = [IO.Path]::GetFullPath($Logs).TrimEnd('\')
    if ($fullLog.StartsWith($fullRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
        return $fullLog.Substring($fullRoot.Length + 1).Replace('\', '/')
    }
    return $fullLog
}

function Get-CachedFileSha256([string]$Path) {
    $resolved = (Resolve-Path -LiteralPath $Path).Path
    if (-not $FileHashCache.ContainsKey($resolved)) {
        $stream = [IO.File]::OpenRead($resolved)
        $sha = [Security.Cryptography.SHA256]::Create()
        try {
            $FileHashCache[$resolved] = ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace("-", "").ToLowerInvariant()
        } finally {
            $stream.Dispose()
            $sha.Dispose()
        }
    }
    return [string]$FileHashCache[$resolved]
}

function Get-NormalizedGateValue([string]$Value) {
    foreach ($mapping in @(
        @($RunDirectory, "<run>"),
        @($Web, "<web>"),
        @($Project, "<project>"),
        @($RepoRoot, "<repo>")
    )) {
        if (-not [string]::IsNullOrWhiteSpace([string]$mapping[0])) {
            $Value = $Value.Replace([string]$mapping[0], [string]$mapping[1])
        }
    }
    return $Value.Replace('\', '/')
}

function Get-GateIdentity([string]$Name, [string]$Executable, [string[]]$Arguments) {
    $dependencies = [System.Collections.Generic.List[object]]::new()
    $candidates = [System.Collections.Generic.List[string]]::new()
    if (Test-Path -LiteralPath $Executable -PathType Leaf) { $candidates.Add((Resolve-Path -LiteralPath $Executable).Path) }
    foreach ($argument in $Arguments) {
        $candidate = [string]$argument
        if ($candidate -match '^tools[/\\]') { $candidate = Join-Path $Project $candidate }
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $resolved = (Resolve-Path -LiteralPath $candidate).Path
            if (-not $resolved.StartsWith($RunDirectory, [StringComparison]::OrdinalIgnoreCase)) {
                $candidates.Add($resolved)
            }
        }
    }
    foreach ($candidate in @($candidates | Sort-Object -Unique)) {
        $dependencies.Add([ordered]@{
            path = $candidate
            sha256 = Get-CachedFileSha256 $candidate
        })
    }
    $contract = [ordered]@{
        protocol = "release-gate-v4"
        name = $Name
        executable = Get-NormalizedGateValue $Executable
        arguments = @($Arguments | ForEach-Object { Get-NormalizedGateValue ([string]$_) })
        dependencies = @($dependencies)
    }
    return [ordered]@{
        protocol = "release-gate-v4"
        fingerprint = Get-StringSha256 ($contract | ConvertTo-Json -Depth 6 -Compress)
        contract = $contract
    }
}

function Test-PreservedGateIdentity($GateIdentity) {
    if ($null -eq $GateIdentity -or [string]$GateIdentity.protocol -ne "release-gate-v4") { return $false }
    if ($null -eq $GateIdentity.contract -or @($GateIdentity.contract.dependencies).Count -eq 0) { return $false }
    foreach ($dependency in @($GateIdentity.contract.dependencies)) {
        $path = [string]$dependency.path
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
        if ((Get-CachedFileSha256 $path) -ne [string]$dependency.sha256) { return $false }
    }
    return $true
}

function Add-Result(
    [string]$Name,
    [string]$Status,
    [double]$Seconds,
    [string]$Log,
    [string[]]$Warnings = @(),
    [string]$Failure = "",
    [int]$ExitCode = 0,
    [bool]$TimedOut = $false
) {
    $lines = if (Test-Path -LiteralPath $Log) { @(Get-Content -LiteralPath $Log) } else { @() }
    $phase = if ($Status -eq "pass") { "runner_completed" } else { "runner_failed" }
    $assertions = [System.Collections.Generic.List[string]]::new()
    if ($Status -eq "pass") {
        $assertions.Add("runner: owned child exited with code 0")
        $assertions.Add("runner: no release-blocking diagnostic remained in the gate log")
    } elseif (-not [string]::IsNullOrWhiteSpace($Failure)) {
        $assertions.Add("runner: failed - $Failure")
    }
    $allWarnings = [System.Collections.Generic.List[string]]::new()
    foreach ($warning in $Warnings) { $allWarnings.Add($warning) }
    foreach ($line in $lines) {
        if ($line -match 'VERIFIER_PHASE:\s*([A-Za-z_]+)') {
            $phase = $Matches[1].ToLowerInvariant()
        }
        if ($line -match '^(?:ASSERTION|CHECK):\s*(.+)$') {
            $assertions.Add("verifier: " + $Matches[1].Trim())
        }
        if ($line -match '^\s*WARN(?:ING)?:\s*(.+)$') {
            $allWarnings.Add($Matches[1].Trim())
        }
    }
    $Results.Add([ordered]@{
        name = $Name
        status = $Status
        duration_seconds = [math]::Round($Seconds, 2)
        log = Get-LogReference $Log
        warnings = @($allWarnings)
        failure = $Failure
        assertions = @($assertions)
        runtime_phase = $phase
        process = [ordered]@{
            owner = "release-runner"
            exit_code = $ExitCode
            timed_out = $TimedOut
        }
        identities = [ordered]@{
            runtime_content = $CurrentRuntimeFingerprint
            test_harness = $CurrentHarnessFingerprint
            registry = $CurrentRegistryFingerprint
            execution = $ExecutionFingerprint
            artifact = $(if (Test-GateUsesArtifact $Name) { $CurrentArtifactFingerprint } else { "" })
            gate = $CurrentGateIdentity
        }
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
    $provenance = $null
    $provenancePath = Join-Path $RunDirectory "web_export_source.json"
    if (Test-Path -LiteralPath $provenancePath) {
        try { $provenance = Get-Content -LiteralPath $provenancePath -Raw | ConvertFrom-Json } catch {}
    } elseif ($null -ne $previousReport -and $null -ne $previousReport.artifact.export_provenance) {
        $provenance = $previousReport.artifact.export_provenance
    } else {
        $legacyProvenancePath = Join-Path $Logs "web_export_source.json"
        if (Test-Path -LiteralPath $legacyProvenancePath) {
            try { $provenance = Get-Content -LiteralPath $legacyProvenancePath -Raw | ConvertFrom-Json } catch {}
        }
    }
    $artifactIdentityInput = [Text.StringBuilder]::new()
    foreach ($record in $records) {
        [void]$artifactIdentityInput.Append([string]$record.path).Append([char]0)
        [void]$artifactIdentityInput.Append([string]$record.bytes).Append([char]0)
        [void]$artifactIdentityInput.Append([string]$record.sha256).Append([char]0)
    }
    $artifactIdentity = Get-StringSha256 $artifactIdentityInput.ToString()
    return [ordered]@{
        directory = $Web
        fingerprint = $artifactIdentity
        total_bytes = $totalBytes
        files = @($records)
        pck_sha256 = if ($null -ne $pck) { [string]$pck.sha256 } else { "" }
        export_provenance = $provenance
        max_bytes = 104857600
    }
}

function Write-WebExportProvenance {
    $artifact = Get-ArtifactSnapshot
    if (-not $artifact.pck_sha256) { throw "Cannot bind Web export without index.pck" }
    $script:CurrentArtifactFingerprint = [string]$artifact.fingerprint
    [ordered]@{
        runtime_content_fingerprint = $CurrentRuntimeFingerprint
        source_fingerprint = $CurrentRuntimeFingerprint
        pck_sha256 = $artifact.pck_sha256
        files = @($artifact.files)
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $RunDirectory "web_export_source.json") -Encoding utf8
}

function Get-SourceFingerprint {
    # Use the verifier's implementation so release creation and validation
    # cannot diverge on path ordering or runtime asset inclusion.
    $value = & $Python (Join-Path $Project "tools\verify_release_report.py") $Project --print-source-fingerprint
    if ($LASTEXITCODE -ne 0 -or $value -notmatch '^[a-f0-9]{64}$') {
        throw "Could not calculate the release source fingerprint"
    }
    return [string]$value
}

function Initialize-ReleaseIdentities {
    $identityJson = & $Python (Join-Path $Project "tools\release_identity.py") $Project --runtime --harness --registry --artifact $Web --json
    if ($LASTEXITCODE -ne 0) { throw "Could not calculate independent release identities" }
    try { $identity = $identityJson | ConvertFrom-Json } catch { throw "Release identity output was malformed: $($_.Exception.Message)" }
    foreach ($property in @("runtime_content", "test_harness", "registry")) {
        if ([string]$identity.$property -notmatch '^[a-f0-9]{64}$') { throw "Release identity '$property' is invalid" }
    }
    $script:CurrentRuntimeFingerprint = [string]$identity.runtime_content
    $script:CurrentHarnessFingerprint = [string]$identity.test_harness
    $script:CurrentRegistryFingerprint = [string]$identity.registry
    $script:CurrentArtifactFingerprint = [string]$identity.artifact.fingerprint
    $executionRecord = [ordered]@{
        protocol = "release-gate-v4"
        release_phase = $ReleasePhase
        acceptance_profile = $AcceptanceProfile
        strict = [bool]$Strict
        skip_export = [bool]$SkipExport
        skip_performance = [bool]$SkipPerformance
        skip_screenshots = [bool]$SkipScreenshots
        only = $Only
        evidence_bundle = $FunctionalEvidence
        timeout_seconds = $TimeoutSeconds
        browser_timeout_seconds = $BrowserRouteTimeoutSeconds
    }
    $script:ExecutionFingerprint = Get-StringSha256 ($executionRecord | ConvertTo-Json -Compress)
}

function Refresh-ArtifactIdentity {
    $artifact = Get-ArtifactSnapshot
    $script:CurrentArtifactFingerprint = [string]$artifact.fingerprint
    foreach ($result in $Results) {
        if ([string]$result.name -eq "web_export" -and $null -ne $result.identities) {
            $result.identities.artifact = $CurrentArtifactFingerprint
        }
    }
}

function Import-ResumeResults {
    if (-not $IsResume) { return }
    if (-not (Test-Path -LiteralPath $ReportPath)) {
        throw "Cannot resume without an existing release report: $ReportPath"
    }
    $script:previousReport = Get-Content -LiteralPath $ReportPath -Raw | ConvertFrom-Json
    if ([string]$previousReport.release_phase -ne $ReleasePhase) {
        $candidatePromotion = [string]$previousReport.release_phase -eq "candidate" -and
            $ReleasePhase -eq "release" -and [string]$previousReport.status -eq "pass" -and
            $ResumeFrom -eq "verify_release_report"
        if (-not $candidatePromotion) {
            throw "Cannot resume a '$($previousReport.release_phase)' report as '$ReleasePhase'"
        }
        if (@(Get-ReleaseWorktreeStatus).Count -ne 0) {
            throw "Cannot promote candidate evidence from a dirty worktree"
        }
        $priorNames = @($previousReport.results | ForEach-Object { [string]$_.name })
        if ($null -eq $previousReport.required_gates -or @($previousReport.required_gates).Count -eq 0 -or
            @($priorNames | Group-Object | Where-Object { $_.Count -gt 1 }).Count -ne 0) {
            throw "Cannot promote candidate evidence without a complete unique gate set"
        }
        foreach ($required in @($previousReport.required_gates)) {
            if ([string]$required -notin $priorNames) {
                throw "Cannot promote candidate evidence missing gate: $required"
            }
        }
    }
    $resumeFound = $false
    foreach ($result in @($previousReport.results)) {
        if ([string]$result.name -eq $ResumeFrom) {
            $resumeFound = $true
            break
        }
        if ([string]$result.status -ne "pass") {
            throw "Cannot preserve non-passing gate before resume point: $($result.name)"
        }
        if ($null -eq $result.process -or [string]$result.process.owner -ne "release-runner" -or [int]$result.process.exit_code -ne 0 -or [bool]$result.process.timed_out) {
            throw "Cannot preserve gate without a successful owned-process result: $($result.name)"
        }
        if ($null -eq $result.identities) {
            throw "Cannot preserve legacy gate without input identities: $($result.name)"
        }
        if ([string]$result.identities.runtime_content -ne $CurrentRuntimeFingerprint) {
            throw "Cannot preserve stale runtime evidence: $($result.name)"
        }
        if (-not (Test-PreservedGateIdentity $result.identities.gate)) {
            throw "Cannot preserve stale or incomplete gate-harness evidence: $($result.name)"
        }
        if ([string]$result.identities.execution -ne $ExecutionFingerprint) {
            throw "Cannot preserve evidence from a different execution configuration: $($result.name)"
        }
        $recordedArtifact = [string]$result.identities.artifact
        if (-not [string]::IsNullOrWhiteSpace($recordedArtifact) -and $recordedArtifact -ne $CurrentArtifactFingerprint) {
            throw "Cannot preserve stale artifact evidence: $($result.name)"
        }
        $Results.Add([ordered]@{
            name = [string]$result.name
            status = "pass"
            duration_seconds = [double]$result.duration_seconds
            log = [string]$result.log
            warnings = @($result.warnings)
            failure = ""
            assertions = @($result.assertions)
            runtime_phase = [string]$result.runtime_phase
            process = $result.process
            identities = $result.identities
            resumed = $true
        })
    }
    if (-not $resumeFound) {
        throw "Resume gate was not found in the previous release report: $ResumeFrom"
    }
    Write-Host "RELEASE RESUME: preserved $($Results.Count) input-identical owned gate result(s)"
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

function Get-CurrentTicketStatuses($Registry) {
    $acceptance = $Registry.current_program.acceptance
    if ($null -eq $acceptance -or @($acceptance.PSObject.Properties).Count -eq 0) {
        throw "Current recovery ticket acceptance map is missing"
    }
    foreach ($entry in $acceptance.PSObject.Properties) {
        if ($entry.Value -isnot [string] -or [string]::IsNullOrWhiteSpace($entry.Name)) {
            throw "Current recovery ticket acceptance map is malformed"
        }
        [ordered]@{ id = $entry.Name; severity = "blocker"; status = $entry.Value }
    }
}

function Get-BlockingIssueSnapshot([string]$Phase = $ReleasePhase) {
    $registryPath = Join-Path $Project "RECOVERY_004_ISSUE_REGISTRY.json"
    if (-not (Test-Path -LiteralPath $registryPath -PathType Leaf)) {
        return @([ordered]@{ id = "RECOVERY-004-REGISTRY"; severity = "blocker"; status = "missing" })
    }
    try {
        $registry = Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json
        $tickets = @(Get-CurrentTicketStatuses $registry)
        $excluded = switch ($Phase) {
            "candidate" { @("CERT-001", "RELEASE-001") }
            "release" { @("RELEASE-001") }
            "final" { @() }
            default { throw "Unknown release phase: $Phase" }
        }
        # Historical category health remains in the report for context. The
        # canonical 37-ticket acceptance map alone owns current release blocks.
        return @($tickets | Where-Object {
            $_.status -ne "accepted" -and $_.id -notin $excluded
        } | Sort-Object id)
    } catch {
        return @([ordered]@{ id = "RECOVERY-004-REGISTRY"; severity = "blocker"; status = "unreadable" })
    }
}

function Get-IssueRegistrySnapshot {
    $registryPath = Join-Path $Project "RECOVERY_004_ISSUE_REGISTRY.json"
    if (-not (Test-Path -LiteralPath $registryPath -PathType Leaf)) {
        return [ordered]@{
            path = "RECOVERY_004_ISSUE_REGISTRY.json"
            exists = $false
            sha256 = ""
            schema_version = 0
            registry_id = ""
            category_statuses = @()
        }
    }
    try {
        $registry = Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json
        $categoryStatuses = @($registry.categories | ForEach-Object {
            [ordered]@{
                id = [string]$_.id
                severity = [string]$_.severity
                status = [string]$_.status
            }
        } | Sort-Object id)
        return [ordered]@{
            path = "RECOVERY_004_ISSUE_REGISTRY.json"
            exists = $true
            sha256 = (Get-FileHash -LiteralPath $registryPath -Algorithm SHA256).Hash.ToLowerInvariant()
            schema_version = [int]$registry.schema_version
            registry_id = [string]$registry.registry_id
            category_statuses = @($categoryStatuses)
            ticket_statuses = @(Get-CurrentTicketStatuses $registry | Sort-Object id)
        }
    } catch {
        return [ordered]@{
            path = "RECOVERY_004_ISSUE_REGISTRY.json"
            exists = $true
            sha256 = ""
            schema_version = 0
            registry_id = ""
            category_statuses = @()
            error = $_.Exception.Message
        }
    }
}

function Get-ScreenshotEvidence {
    $capturePath = Join-Path $RunDirectory "qa_003_milestone_report.json"
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
    $artifact = Get-ArtifactSnapshot
    $registry = Get-IssueRegistrySnapshot
    $report = [ordered]@{
        schema_version = 4
        report_id = $ReportId
        release_id = if ($env:ASHENOATH_RELEASE_ID) { $env:ASHENOATH_RELEASE_ID } else { "recovery-004" }
        release_phase = $ReleasePhase
        acceptance_profile = $AcceptanceProfile
        release_basis = if ($FunctionalCandidate) { "functionality-certified candidate" } else { "strict" }
        performance_certified = -not $FunctionalCandidate
        listening_reviewed = $false
        status = $Status
        started_at = $StartedAt.ToUniversalTime().ToString("o")
        finished_at = (Get-Date).ToUniversalTime().ToString("o")
        source_commit = $head
        source_branch = $branch
        source_fingerprint = $CurrentRuntimeFingerprint
        runtime_content_fingerprint = $CurrentRuntimeFingerprint
        test_harness_fingerprint = $CurrentHarnessFingerprint
        registry_fingerprint = $CurrentRegistryFingerprint
        execution_fingerprint = $ExecutionFingerprint
        verification_revision = [ordered]@{
            source_commit = $head
            runtime_content_fingerprint = $CurrentRuntimeFingerprint
            test_harness_fingerprint = $CurrentHarnessFingerprint
            registry_sha256 = [string]$registry.sha256
            execution_fingerprint = $ExecutionFingerprint
        }
        git_status = $gitStatus
        mode = $(if ([string]::IsNullOrWhiteSpace($Only)) { "full" } else { "targeted" })
        requested_gate = $Only
        project = "outputs/AshenOathTheRoadBetweenCrowns"
        evidence_project = $Project
        artifact = $artifact
        issue_registry = $registry
        release_blockers = @(Get-BlockingIssueSnapshot $ReleasePhase)
        failure = $Failure
        required_gates = @($RequiredGateNames)
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
    $launchExecutable = $Executable
    $argumentLine = ConvertTo-ArgumentLine $Arguments
    if ([IO.Path]::GetExtension($Executable).ToLowerInvariant() -eq ".bat") {
        $launchExecutable = $env:ComSpec
        $argumentLine = '/d /s /c "' + $Executable + '" ' + $argumentLine
    }
    # Own the process handle for every gate. Start-Process -PassThru can expose
    # a blank ExitCode on Windows even after WaitForExit, masking failures.
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $launchExecutable
    $startInfo.Arguments = $argumentLine
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
        # A child can inherit stdout/stderr after its parent exits. Never let
        # such a helper hold the release runner past the bounded capture wait.
        $stdoutReady = $stdoutTask.Wait(3000)
        $stderrReady = $stderrTask.Wait(3000)
        $streamsReady = $stdoutReady -and $stderrReady
        $stdout = if ($stdoutReady) { $stdoutTask.GetAwaiter().GetResult() } else { "ERROR: owned process stdout remained open after exit`r`n" }
        $stderr = if ($stderrReady) { $stderrTask.GetAwaiter().GetResult() } else { "ERROR: owned process stderr remained open after exit`r`n" }
        [IO.File]::WriteAllText($StdoutPath, $stdout)
        [IO.File]::WriteAllText($StderrPath, $stderr)
        $exitCode = if ($completed -and $streamsReady) { [int]$process.ExitCode } else { 124 }
    } finally {
        $process.Dispose()
    }
    return [pscustomobject]@{
        ExitCode = $exitCode
        TimedOut = -not ($completed -and $streamsReady)
    }
}

function Invoke-ExternalGate(
    [string]$Name,
    [string]$Executable,
    [string[]]$Arguments,
    [int]$TimeoutOverride = 0
) {
    $script:CurrentGateIdentity = Get-GateIdentity $Name $Executable $Arguments
    $log = Join-Path $RunDirectory "$Name.log"
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
        Add-Result $Name "fail" $timer.Elapsed.TotalSeconds $log @() $failure $exitCode $true
        if (-not $VerboseOutput) { Get-Content -LiteralPath $log -Tail 40 }
        throw "$failure. Full log: $log"
    }
    if ($exitCode -ne 0) {
        $failure = "$Name failed with exit code $exitCode"
        Add-Result $Name "fail" $timer.Elapsed.TotalSeconds $log @() $failure $exitCode
        if (-not $VerboseOutput) { Get-Content -LiteralPath $log -Tail 40 }
        throw $failure
    }
	$blockingLine = @(Get-Content -LiteralPath $log | Where-Object {
		$_ -match 'SCRIPT ERROR|Parse Error|Compile Error|Failed to load|Cannot open|ERROR:|VERIFIER:\s*FAIL|ASSERTION FAILED|Assertion failed|Parameter "material" is null|RID allocations .* leaked at exit|ObjectDB instances leaked at exit|Condition .* is true' -and
		$_ -notmatch '^\s*\+\s+CategoryInfo|FullyQualifiedErrorId.*NativeCommandError'
	} | Select-Object -First 1)
	if ($blockingLine.Count -gt 0) {
		$failure = "$Name emitted a release-blocking error: $($blockingLine[0])"
		Add-Result $Name "fail" $timer.Elapsed.TotalSeconds $log @() $failure $exitCode
		if (-not $VerboseOutput) { Get-Content -LiteralPath $log -Tail 40 }
		throw $failure
	}
	# Gates write structured reports in addition to their process exit code.
	# Treat a missing, malformed, or non-pass report as a failure even if a
	# wrapper or native process masks the child's exit status. Both spellings
	# are used by the existing Python gates and must share one contract.
	$reportFlag = @("--report", "--json-report") | Where-Object {
		[Array]::IndexOf($Arguments, $_) -ge 0
	} | Select-Object -First 1
	$reportArgIndex = if ($null -ne $reportFlag) { [Array]::IndexOf($Arguments, $reportFlag) } else { -1 }
	if ($reportArgIndex -ge 0 -and $reportArgIndex + 1 -lt $Arguments.Count) {
		$reportFile = [string]$Arguments[$reportArgIndex + 1]
		if (-not (Test-Path -LiteralPath $reportFile)) {
			$failure = "$Name completed without its structured report: $reportFile"
			Add-Result $Name "fail" $timer.Elapsed.TotalSeconds $log @() $failure $exitCode
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
			Add-Result $Name "fail" $timer.Elapsed.TotalSeconds $log @() $failure $exitCode
			if (-not $VerboseOutput) { Get-Content -LiteralPath $log -Tail 40 }
			throw $failure
		}
		if ($null -eq $reportStatus -or [string]::IsNullOrWhiteSpace($reportStatus)) {
			$failure = "$Name produced a structured report without a status: $reportFile"
			Add-Result $Name "fail" $timer.Elapsed.TotalSeconds $log @() $failure $exitCode
			if (-not $VerboseOutput) { Get-Content -LiteralPath $log -Tail 40 }
			throw $failure
		}
		if ($reportStatus -ne "pass") {
			$failure = "$Name reported status '$reportStatus' despite exit code 0"
			Add-Result $Name "fail" $timer.Elapsed.TotalSeconds $log @() $failure $exitCode
			if (-not $VerboseOutput) { Get-Content -LiteralPath $log -Tail 40 }
			throw $failure
		}
	}
    Add-Result $Name "pass" $timer.Elapsed.TotalSeconds $log @() "" $exitCode
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
    $script:CurrentGateIdentity = Get-GateIdentity $Name $Runner $Arguments
    $log = Join-Path $RunDirectory "$Name.log"
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
        Add-Result $Name "fail" $timer.Elapsed.TotalSeconds $log @() $failure $exitCode ($exitCode -eq 124)
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
        Add-Result $Name "fail" $timer.Elapsed.TotalSeconds $log @() $failure $exitCode
        if (-not $VerboseOutput -and (Test-Path -LiteralPath $log)) { Get-Content -LiteralPath $log -Tail 40 }
        throw $failure
    }
    $warnings = [System.Collections.Generic.List[string]]::new()
    $fatal = [System.Collections.Generic.List[string]]::new()
	# The phase marker is retained for diagnostics, but it never turns a
	# resource or renderer error into a passing result. A teardown allowlist
	# requires an exact, separately reviewed engine signature; none is approved.
	$shutdownIndex = -1
	for ($index = 0; $index -lt $lines.Count; $index++) {
		if ($lines[$index] -match 'VERIFIER_PHASE:\s*SHUTDOWN') {
			$shutdownIndex = $index
			break
		}
	}
	$activeResourcePattern = 'Parameter "material" is null|RID allocations .* leaked at exit|Pages in use exist at exit|resources still in use at exit|Buffer with GL ID .* leaked|shaders of type .* never freed|ObjectDB instances leaked at exit|Leaked instance dependency|did not call instance_notify_deleted|Orphan .* at exit|Condition .* is true'
    $fatalPattern = 'SCRIPT ERROR|Parse Error|Compile Error|Failed to load|Cannot open|ERROR:|VERIFIER:\s*FAIL|ASSERTION FAILED|Assertion failed'
    for ($index = 0; $index -lt $lines.Count; $index++) {
        $line = $lines[$index]
		if ($line -match $activeResourcePattern) {
			$fatal.Add($line.Trim())
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
        Add-Result $Name "fail" $timer.Elapsed.TotalSeconds $log @($warnings) $failure $exitCode
        if (-not $VerboseOutput) { Get-Content -LiteralPath $log -Tail 40 }
        throw $failure
    }
    Add-Result $Name "pass" $timer.Elapsed.TotalSeconds $log @($warnings) "" $exitCode
    Write-Host ("RELEASE GATE {0}: PASS ({1:n1}s)" -f $Name, $timer.Elapsed.TotalSeconds)
}

function Get-QA002RouteReport([string]$GateName, [string]$FileName) {
    $result = @($Results | Where-Object { [string]$_.name -eq $GateName } | Select-Object -Last 1)
    if ($result.Count -ne 1 -or [string]$result[0].status -ne "pass") {
        throw "Missing passing QA-002 route gate: $GateName"
    }
    $log = [string]$result[0].log
    $logPath = if ([IO.Path]::IsPathRooted($log)) { $log } else { Join-Path $Logs $log }
    $routeReport = Join-Path (Split-Path -Parent $logPath) $FileName
    if (-not (Test-Path -LiteralPath $routeReport -PathType Leaf)) {
        throw "Missing QA-002 route report for $GateName`: $routeReport"
    }
    return $routeReport
}

function Invoke-QA002BranchMatrix {
    $routeReports = [System.Collections.Generic.List[string]]::new()
    $routeReports.Add((Get-QA002RouteReport "verify_web_002_browser" "web_002_browser.json"))
    foreach ($route in $(if ($FunctionalCandidate) { @() } else { $Qa002BranchRoutes })) {
        $gateName = "qa_002_branch_$($route.slug)"
        if (-not @($Results | Where-Object { [string]$_.name -eq $gateName }).Count) {
            $reportFile = Join-Path $RunDirectory "qa_002_$($route.slug).json"
            Invoke-ExternalGate $gateName $Node @(
                (Join-Path $Project "tools\verify_qa_002_browser.mjs"),
                "--export", $Web,
                "--browser", "chrome",
                "--renderer", "hardware",
                "--acceptance-profile", $AcceptanceProfile,
                "--production-observer", "true",
                "--$($route.flag)", "true",
                "--report", $reportFile
            ) -TimeoutOverride $BrowserRouteTimeoutSeconds
        }
        $routeReports.Add((Get-QA002RouteReport $gateName "qa_002_$($route.slug).json"))
    }
    if ($FunctionalCandidate) {
        foreach ($compatibilityBrowser in @("edge", "firefox")) {
            $gateName = "qa_002_branch_$($compatibilityBrowser)_smoke"
            $reportFileName = "qa_002_$($compatibilityBrowser)_smoke.json"
            if (-not @($Results | Where-Object { [string]$_.name -eq $gateName }).Count) {
                Invoke-ExternalGate $gateName $Node @(
                    (Join-Path $Project "tools\verify_qa_002_browser.mjs"),
                    "--export", $Web, "--browser", $compatibilityBrowser,
                    "--renderer", "hardware", "--acceptance-profile", $AcceptanceProfile,
                    "--production-observer", "true", "--browser-smoke", "true",
                    "--report", (Join-Path $RunDirectory $reportFileName)
                ) -TimeoutOverride $BrowserRouteTimeoutSeconds
            }
            $routeReports.Add((Get-QA002RouteReport $gateName $reportFileName))
        }
    }
    $candidateArguments = [System.Collections.Generic.List[string]]::new()
    $candidateArguments.Add((Join-Path $Project "tools\verify_qa_002_candidate.mjs"))
    $candidateArguments.Add("--export")
    $candidateArguments.Add($Web)
    $candidateArguments.Add("--acceptance-profile")
    $candidateArguments.Add($AcceptanceProfile)
    $candidateArguments.Add("--output")
    $candidateArguments.Add((Join-Path $RunDirectory "qa_002_candidate.json"))
    foreach ($routeReport in $routeReports) {
        $candidateArguments.Add("--report")
        $candidateArguments.Add($routeReport)
    }
    Invoke-ExternalGate "qa_002_candidate" $Node $candidateArguments.ToArray()
}

try {
    if (!(Test-Path -LiteralPath $Godot)) { throw "Godot 4.6.3 console binary not found: $Godot" }
    if (!(Test-Path -LiteralPath $Python)) { throw "Bundled Python not found: $Python" }
    if (!(Test-Path -LiteralPath $Node)) { throw "Bundled Node.js not found: $Node" }
    Initialize-ReleaseIdentities
    Import-ResumeResults

    if ($FunctionalEvidence) {
        $script:RequiredGateNames = @("functional_evidence", "qa_002_candidate", "verify_security_001", "verify_web_export", "verify_recovery_004")
        Invoke-ExternalGate "functional_evidence" $Python @(
            (Join-Path $Project "tools\verify_release_report.py"), $Project,
            "--check-functional-evidence", $FunctionalEvidence
        )
        $candidateArguments = @((Join-Path $Project "tools\verify_qa_002_candidate.mjs"),
            "--export", $Web, "--output", (Join-Path $RunDirectory "qa_002_candidate.json"),
            "--acceptance-profile", $AcceptanceProfile)
        foreach ($browserReport in @($EvidenceBundle.browser_reports)) { $candidateArguments += @("--report", [string]$browserReport) }
        Invoke-ExternalGate "qa_002_candidate" $Node $candidateArguments
        Invoke-ExternalGate "verify_security_001" $Python @((Join-Path $Project "tools\verify_security_001.py"), $Project)
        Invoke-ExternalGate "verify_web_export" $Python @((Join-Path $Project "tools\verify_web_export.py"), $Web)
        Invoke-ExternalGate "verify_recovery_004" $Python @((Join-Path $Project "tools\verify_recovery_004.py"), $Project)
        Copy-Item -LiteralPath ([string]$EvidenceBundle.visual_report) -Destination (Join-Path $RunDirectory "qa_003_milestone_report.json")
        $artifact = Get-ArtifactSnapshot
        # This binds a preserved export; it does not invent an export-time snapshot.
        [ordered]@{
            binding_origin = "preserved_v10_export_and_capture"
            rendering_inputs_sha256 = [string]$EvidenceBundle.rendering_inputs_sha256
            export_log = [string]$EvidenceBundle.export_log
            export_log_sha256 = Get-CachedFileSha256 ([string]$EvidenceBundle.export_log)
            runtime_content_fingerprint = $CurrentRuntimeFingerprint
            pck_sha256 = $artifact.pck_sha256
            files = @($artifact.files)
        } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $RunDirectory "web_export_source.json") -Encoding utf8
        Write-ReleaseReport "pass"
        $certificationInput = Join-Path $RunDirectory "certification_input.json"
        Copy-Item -LiteralPath $ReportPath -Destination $certificationInput
        Invoke-ExternalGate "verify_release_report" $Python @(
            (Join-Path $Project "tools\verify_release_report.py"), $Project,
            "--report", $certificationInput, "--strict", "--acceptance-profile", $AcceptanceProfile
        )
        Write-ReleaseReport "pass"
        Write-Host "CERT-001: PASS - preserved V10 evidence aggregated; no campaign replay or export"
        exit 0
    }

    if (-not $IsResume) {
        Invoke-ExternalGate "verify_security_001" $Python @(
            (Join-Path $Project "tools\verify_security_001.py"),
            $Project
        )
        Invoke-ExternalGate "verify_recovery_004" $Python @(
            (Join-Path $Project "tools\verify_recovery_004.py"),
            $Project
        )
        Invoke-ExternalGate "verify_pack_http" $Python @(
            (Join-Path $Project "tools\verify_pack_http.py"),
            "--godot", $Godot, "--project", $Project,
            "--report", (Join-Path $RunDirectory "pack_http.json")
        )
        Invoke-ExternalGate "verify_qa_001" $Python @(
            (Join-Path $Project "tools\verify_qa_001.py"),
            $Project
        )
        Invoke-ExternalGate "verify_current_ticket_release" $Python @(
            (Join-Path $Project "tools\verify_current_ticket_release.py")
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
            "--production",
            "--json-report",
            (Join-Path $RunDirectory "runtime_required_components.json")
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
        "verify_enemy_dormancy.gd",
        "verify_hart_stag.gd",
        "verify_hart_pending_reload.gd",
        "verify_boss_resolution.gd",
        "verify_health_boundaries.gd",
        "verify_deferred_player_restore.gd",
        "verify_world_snapshot_isolation.gd",
        "verify_quest_snapshot_isolation.gd",
        "verify_progression_restore.gd",
        "verify_pack_wait_ownership.gd",
        "verify_save_version_boundary.gd",
        "verify_settings_roundtrip.gd",
        "verify_inventory_restore.gd",
        "verify_runtime_smoke.gd", "verify_runtime.gd", "verify_runtime_regressions.gd", "verify_zone_builder_integrity.gd", "verify_gate_transitions.gd", "verify_engine_001.gd", "verify_engine_003.gd", "verify_engine_004.gd", "verify_story_campaign.gd", "verify_quest_002.gd", "verify_objective_view_model.gd", "verify_save_001.gd", "verify_qa_002.gd", "verify_art_001.gd", "verify_asset_001.gd", "verify_character_real_001.gd", "verify_face_river_sun_001.gd",
        "verify_motion_quality.gd", "verify_river_swimming.gd", "verify_river_bank_faces.gd", "verify_greyfen_life.gd",
        "verify_event_driven_touch.gd", "verify_event_driven_life.gd",
        "verify_dialogue_runtime_coordinator.gd", "verify_combat_vfx_coordinator.gd",
        "verify_interaction_visibility.gd", "verify_quest_hud_coordinator.gd", "verify_zone_residency.gd",
        "verify_record_archive.gd", "verify_greyfen_social.gd", "verify_greyfen_horizon.gd", "verify_cemetery_architecture.gd", "verify_minigame_presentation.gd",
        "verify_vargan_architecture.gd",
        "verify_ash_mill.gd",
        "verify_undercroft_vault.gd",
        "verify_finale_composition.gd",
        "verify_campaign_wilds_composition.gd",
        "verify_paused_player_real_input.gd",
        "verify_zone_pause_ownership.gd",
        "verify_access_weapon_context.gd",
        "verify_access_binding_restore.gd",
        "verify_access_context_real_input.gd",
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
    $qa005ManifestPath = Join-Path $RunDirectory "qa_005_inputs.json"
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
    $requiredGateNames = @(
        "verify_security_001", "verify_recovery_004", "verify_pack_http", "verify_qa_001",
        "verify_current_ticket_release", "verify_content_integrity", "verify_runtime_required_components",
        "verify_asset_001_files", "verify_prod_002", "verify_prod_003"
    )
    $requiredGateNames += $verifierNames
    $requiredGateNames += @("verify_perf_001", "verify_qa_005")
    foreach ($captureName in $screenshotGates) {
        $requiredGateNames += @("$captureName.provenance_begin", $captureName, "$captureName.provenance_finish")
    }
    $requiredGateNames += @(
        "verify_screenshot_qa_003", "verify_qa_006", "verify_web_001", "verify_web_002",
        "web_export", "verify_web_export", "packed_startup", "verify_web_browser",
        "verify_mobile_browser", "verify_web_002_browser", "verify_web_002_mobile"
    )
    if (-not $FunctionalCandidate) {
        $requiredGateNames += @($Qa002BranchRoutes | ForEach-Object { "qa_002_branch_$($_.slug)" })
    }
    $requiredGateNames += "qa_002_candidate"
    if ($FunctionalCandidate) {
        $requiredGateNames = @($requiredGateNames | Where-Object { $_ -ne "verify_web_002_mobile" })
        $requiredGateNames += @("qa_002_branch_edge_smoke", "qa_002_branch_firefox_smoke")
    }
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
            if ($name -in @("verify_paused_player_real_input", "verify_access_context_real_input", "verify_world_013")) {
                Invoke-GodotGate $name @("--path", $Project, "--rendering-method", "gl_compatibility", "--script", "tools/$verifier")
            } else {
                Invoke-GodotGate $name @("--headless", "--path", $Project, "--script", "tools/$verifier")
            }
        }
    }

    if ((-not $IsResume -or $resumeFromVerifier -or $resumeFromPerformance) -and [string]::IsNullOrWhiteSpace($Only) -and -not $SkipPerformance) {
		if ([string]::IsNullOrWhiteSpace($GodotGraphical) -or -not (Test-Path -LiteralPath $GodotGraphical)) {
			throw "Graphical Godot 4.6.3 binary not found for verify_perf_001: $GodotGraphical"
		}
        Invoke-GodotGate "verify_perf_001" @(
            "--path", $Project, "--rendering-method", "gl_compatibility",
            "--script", "tools/verify_perf_001.gd", "--", "--acceptance-profile=$AcceptanceProfile"
        ) $GodotGraphical
    }
    if ((-not $IsResume -or $resumeFromVerifier -or $resumeFromPerformance) -and [string]::IsNullOrWhiteSpace($Only)) {
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
            "--report", (Join-Path $RunDirectory "qa_005_report.json")
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
            $captureSession = Join-Path $RunDirectory "$captureName.capture-session.json"
            Invoke-ExternalGate "$captureName.provenance_begin" $Python @(
                (Join-Path $Project "tools\capture_visual_provenance.py"),
                "begin", $Project, "--session", $captureSession, "--gate", $captureName
            )
            Invoke-GodotGate $captureName @(
                "--path", $Project, "--rendering-method", "gl_compatibility",
                "--script", "tools/$captureName.gd"
            )
            # This is unreachable after a failed/timeout capture. Never bind an
            # old gallery file merely because a renderer command was attempted.
            Invoke-ExternalGate "$captureName.provenance_finish" $Python @(
                (Join-Path $Project "tools\capture_visual_provenance.py"),
                "finish", $Project, "--session", $captureSession
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
            "--report", (Join-Path $RunDirectory "qa_003_milestone_report.json")
        )
        Invoke-ExternalGate "verify_qa_006" $Python @(
            (Join-Path $Project "tools\verify_qa_006.py"),
            $Project,
            "--report", (Join-Path $RunDirectory "qa_006_report.json")
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
        Refresh-ArtifactIdentity
        Invoke-ExternalGate "verify_web_export" $Python @(
            (Join-Path $Project "tools\verify_web_export.py"), $Web,
            "--json-report", (Join-Path $RunDirectory "web_export.json")
        )
        Write-WebExportProvenance
        $pack = Join-Path $Web "index.pck"
        Invoke-GodotGate "packed_startup" @(
            # Isolate the artifact: source files must not rescue missing exports.
            "--headless", "--path", $Web, "--main-pack", $pack,
            "--script", (Join-Path $Project "tools\verify_packed_startup.gd")
        )
        Invoke-ExternalGate "verify_web_browser" $Node @(
            (Join-Path $Project "tools\verify_web_browser.mjs"),
            "--export", $Web,
            "--report", (Join-Path $RunDirectory "web_browser.json")
        )
        Invoke-ExternalGate "verify_mobile_browser" $Node @(
            (Join-Path $Project "tools\verify_web_browser.mjs"),
            "--export", $Web,
            "--report", (Join-Path $RunDirectory "mobile_browser.json"),
            "--mobile", "true"
        )
        Invoke-ExternalGate "verify_web_002_browser" $Node @(
            (Join-Path $Project "tools\verify_qa_002_browser.mjs"),
			"--export", $Web,
            "--browser", $CampaignBrowser,
            "--renderer", "hardware",
            $(if ($FunctionalCandidate) { "--opening-save-continue" } else { "--full-campaign" }), "true",
			"--enforce-performance", $EnforceBrowserPerformance,
			"--acceptance-profile", $AcceptanceProfile,
			"--production-observer", "true",
            "--report", (Join-Path $RunDirectory "web_002_browser.json")
        ) -TimeoutOverride $BrowserRouteTimeoutSeconds
        if (-not $FunctionalCandidate) { Invoke-ExternalGate "verify_web_002_mobile" $Node @(
            (Join-Path $Project "tools\verify_qa_002_browser.mjs"),
			"--export", $Web,
            "--browser", "chromium",
            "--renderer", "hardware",
            "--full-campaign", "true",
			"--production-observer", "true",
            "--mobile", "true",
            "--report", (Join-Path $RunDirectory "web_002_mobile.json")
        ) -TimeoutOverride $BrowserRouteTimeoutSeconds }
    }
	if ([string]::IsNullOrWhiteSpace($Only) -and -not $SkipExport -and $webTailResume) {
		# Preserve input-identical gates and use the verified production export.
		Invoke-ExternalGate "verify_web_002_browser" $Node @(
			(Join-Path $Project "tools\verify_qa_002_browser.mjs"),
			"--export", $Web,
			"--browser", $CampaignBrowser,
			"--renderer", "hardware",
			$(if ($FunctionalCandidate) { "--opening-save-continue" } else { "--full-campaign" }), "true",
			"--enforce-performance", $EnforceBrowserPerformance,
			"--acceptance-profile", $AcceptanceProfile,
			"--production-observer", "true",
			"--report", (Join-Path $RunDirectory "web_002_browser.json")
		) -TimeoutOverride $BrowserRouteTimeoutSeconds
		if (-not $FunctionalCandidate) { Invoke-ExternalGate "verify_web_002_mobile" $Node @(
			(Join-Path $Project "tools\verify_qa_002_browser.mjs"),
			"--export", $Web,
			"--browser", "chromium",
			"--renderer", "hardware",
			$(if ($FunctionalCandidate) { "--opening-save-continue" } else { "--full-campaign" }), "true",
			"--production-observer", "true",
			"--mobile", "true",
			"--report", (Join-Path $RunDirectory "web_002_mobile.json")
		) -TimeoutOverride $BrowserRouteTimeoutSeconds }
	}
	if ([string]::IsNullOrWhiteSpace($Only) -and -not $SkipExport -and $mobileTailResume) {
		# Desktop Web and export gates already passed in the prior report. Resume
		# browser checks against those same production bytes.
		Invoke-ExternalGate "verify_mobile_browser" $Node @(
			(Join-Path $Project "tools\verify_web_browser.mjs"),
			"--export", $Web,
			"--report", (Join-Path $RunDirectory "mobile_browser.json"),
			"--mobile", "true"
		)
		Invoke-ExternalGate "verify_web_002_browser" $Node @(
			(Join-Path $Project "tools\verify_qa_002_browser.mjs"),
			"--export", $Web,
			"--browser", $CampaignBrowser,
			"--renderer", "hardware",
			"--full-campaign", "true",
			"--enforce-performance", $EnforceBrowserPerformance,
			"--acceptance-profile", $AcceptanceProfile,
			"--production-observer", "true",
			"--report", (Join-Path $RunDirectory "web_002_browser.json")
		) -TimeoutOverride $BrowserRouteTimeoutSeconds
		if (-not $FunctionalCandidate) { Invoke-ExternalGate "verify_web_002_mobile" $Node @(
			(Join-Path $Project "tools\verify_qa_002_browser.mjs"),
			"--export", $Web,
			"--browser", "chromium",
			"--renderer", "hardware",
			"--full-campaign", "true",
			"--production-observer", "true",
			"--mobile", "true",
			"--report", (Join-Path $RunDirectory "web_002_mobile.json")
		) -TimeoutOverride $BrowserRouteTimeoutSeconds }
	}
    $resumeFromQa002Matrix = $IsResume -and ($ResumeFrom -eq "qa_002_candidate" -or $ResumeFrom.StartsWith("qa_002_branch_", [StringComparison]::Ordinal))
    if ([string]::IsNullOrWhiteSpace($Only) -and -not $SkipExport -and
        (-not $IsResume -or $webTailResume -or $mobileTailResume -or $resumeFromQa002Matrix)) {
        Invoke-QA002BranchMatrix
    }
    $hasSkippedStages = $SkipExport -or $SkipPerformance -or $SkipScreenshots
    $resultNames = @($Results | ForEach-Object { [string]$_.name })
    $missingGates = @($requiredGateNames | Where-Object { $_ -notin $resultNames })
    $duplicateGates = @($resultNames | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
    $isCompleteReleaseRun = [string]::IsNullOrWhiteSpace($Only) -and -not $hasSkippedStages -and $missingGates.Count -eq 0 -and $duplicateGates.Count -eq 0
    if ([string]::IsNullOrWhiteSpace($Only) -and -not $hasSkippedStages -and ($missingGates.Count -gt 0 -or $duplicateGates.Count -gt 0)) {
        $failure = "Release evidence set is incomplete"
        if ($missingGates.Count -gt 0) { $failure += "; missing: $($missingGates -join ', ')" }
        if ($duplicateGates.Count -gt 0) { $failure += "; duplicate: $($duplicateGates -join ', ')" }
        Write-ReleaseReport "fail" $failure
        throw $failure
    }
    $blockingIssues = @(Get-BlockingIssueSnapshot $ReleasePhase)
    if ($isCompleteReleaseRun -and $blockingIssues.Count -gt 0) {
        $blockerSummary = ($blockingIssues | ForEach-Object {
            "{0}={1}" -f [string]$_.id, [string]$_.status
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
            "--strict", "--acceptance-profile", $AcceptanceProfile
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
