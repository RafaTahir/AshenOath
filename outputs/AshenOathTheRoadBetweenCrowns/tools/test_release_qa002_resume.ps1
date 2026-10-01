$ErrorActionPreference = "Stop"
$scriptPath = Join-Path $PSScriptRoot "run_release_gate.ps1"
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw "Release runner does not parse" }
foreach ($name in @("Get-QA002RouteReport", "Invoke-QA002BranchMatrix", "Import-ResumeResults")) {
    $functionAst = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name
    }, $true)
    if ($null -eq $functionAst) { throw "Missing release helper: $name" }
    . ([ScriptBlock]::Create($functionAst.Extent.Text))
}

$tempRoot = "D:\Temp\AshenOath"
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
$fixture = Join-Path $tempRoot ("qa002_release_resume_" + [guid]::NewGuid().ToString("N"))
$oldRun = Join-Path $fixture "runs\prior"
$newRun = Join-Path $fixture "runs\current"
New-Item -ItemType Directory -Path $oldRun, $newRun -Force | Out-Null
try {
    $script:Logs = $fixture
    $script:RunDirectory = $newRun
    $script:Project = "D:\Projects\AshenOath\outputs\AshenOathTheRoadBetweenCrowns"
    $script:Web = "D:\Projects\AshenOath\outputs\AshenOath_Web"
    $script:Node = "node.exe"
    $script:BrowserRouteTimeoutSeconds = 3600
    $script:Qa002BranchRoutes = @(
        @{ slug = "opening_save_continue"; flag = "opening-save-continue" },
        @{ slug = "ending_matrix"; flag = "ending-matrix" }
    )
    $script:Results = [System.Collections.Generic.List[object]]::new()
    $script:Invoked = [System.Collections.Generic.List[string]]::new()
    foreach ($entry in @(
        @{ name = "verify_web_002_browser"; file = "web_002_browser.json" },
        @{ name = "qa_002_branch_opening_save_continue"; file = "qa_002_opening_save_continue.json" }
    )) {
        $log = Join-Path $oldRun ($entry.name + ".log")
        [IO.File]::WriteAllText($log, "pass")
        [IO.File]::WriteAllText((Join-Path $oldRun $entry.file), "{}")
        $script:Results.Add([ordered]@{
            name = $entry.name
            status = "pass"
            log = "runs/prior/$($entry.name).log"
        })
    }
    function Invoke-ExternalGate([string]$Name, [string]$Executable, [string[]]$Arguments, [int]$TimeoutOverride = 0) {
        $script:Invoked.Add($Name)
        $outputIndex = [Array]::IndexOf($Arguments, $(if ($Name -eq "qa_002_candidate") { "--output" } else { "--report" }))
        if ($outputIndex -lt 0) { throw "Gate $Name lacks its report path" }
        $report = $Arguments[$outputIndex + 1]
        [IO.File]::WriteAllText($report, "{}")
        $log = Join-Path $script:RunDirectory ($Name + ".log")
        [IO.File]::WriteAllText($log, "pass")
        $script:Results.Add([ordered]@{
            name = $Name
            status = "pass"
            log = "runs/current/$Name.log"
        })
        if ($Name -eq "qa_002_candidate") {
            $reports = for ($index = 0; $index -lt $Arguments.Count; $index++) {
                if ($Arguments[$index] -eq "--report") { $Arguments[$index + 1] }
            }
            if ($reports.Count -ne 3 -or $reports[0] -notlike "*runs\prior\web_002_browser.json" -or
                $reports[1] -notlike "*runs\prior\qa_002_opening_save_continue.json" -or
                $reports[2] -notlike "*runs\current\qa_002_ending_matrix.json") {
                throw "Candidate did not receive both resumed and fresh route reports"
            }
        }
    }
    Invoke-QA002BranchMatrix
    if (($script:Invoked -join ",") -ne "qa_002_branch_ending_matrix,qa_002_candidate") {
        throw "Release matrix reran an already accepted branch or skipped a required gate"
    }
    Write-Host "QA-002 release resume: PASS"
    $script:IsResume = $true
    $script:ResumeFrom = "verify_release_report"
    $script:ReleasePhase = "release"
    $script:CurrentRuntimeFingerprint = "runtime"
    $script:CurrentArtifactFingerprint = "artifact"
    $script:ExecutionFingerprint = "execution"
    $script:ReportPath = Join-Path $fixture "promotion.json"
    function Get-ReleaseWorktreeStatus { return $script:DirtyFixture }
    function Test-PreservedGateIdentity($Identity) { return [bool]$Identity.valid }
    foreach ($case in @("valid", "partial", "dirty", "stale-runtime", "stale-harness", "stale-artifact", "failed-process", "missing-gate")) {
        $script:Results = [System.Collections.Generic.List[object]]::new()
        $script:DirtyFixture = $(if ($case -eq "dirty") { @(" M scripts/game.gd") } else { @() })
        $prior = [ordered]@{
            release_phase = "candidate"
            status = $(if ($case -eq "partial") { "partial-pass" } else { "pass" })
            required_gates = @($(if ($case -eq "missing-gate") { "absent" } else { "native" }))
            results = @(
                [ordered]@{
                    name = "native"; status = "pass"; duration_seconds = 1.0; log = "prior.log"
                    warnings = @(); assertions = @(); runtime_phase = "active"
                    process = @{ owner = "release-runner"; exit_code = $(if ($case -eq "failed-process") { 1 } else { 0 }); timed_out = $false }
                    identities = @{
                        runtime_content = $(if ($case -eq "stale-runtime") { "different" } else { "runtime" })
                        gate = @{ valid = $case -ne "stale-harness" }
                        execution = "execution"
                        artifact = $(if ($case -eq "stale-artifact") { "different" } else { "artifact" })
                    }
                },
                @{ name = "verify_release_report"; status = "pass" }
            )
        }
        [IO.File]::WriteAllText($script:ReportPath, ($prior | ConvertTo-Json -Depth 10))
        $rejected = $false
        try { Import-ResumeResults } catch { $rejected = $true }
        if ($rejected -ne ($case -ne "valid")) { throw "Candidate promotion case failed: $case" }
        if ($case -eq "valid" -and ($script:Results.Count -ne 1 -or -not $script:Results[0].resumed)) {
            throw "Content-identical promotion did not preserve owned native evidence"
        }
    }
    Write-Host "Candidate promotion: PASS (clean complete evidence only; stale/dirty/missing/failed cases rejected)"
} finally {
    $resolvedFixture = [IO.Path]::GetFullPath($fixture)
    $resolvedRoot = [IO.Path]::GetFullPath($tempRoot).TrimEnd('\') + '\'
    if (-not $resolvedFixture.StartsWith($resolvedRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing cleanup outside D: QA temp root"
    }
    Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
}
