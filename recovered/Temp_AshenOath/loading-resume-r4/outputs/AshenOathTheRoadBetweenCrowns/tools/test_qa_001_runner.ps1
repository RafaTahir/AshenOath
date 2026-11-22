param(
    [string]$Project = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
$runner = Join-Path $Project "tools\run_release_gate.ps1"
$python = "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
if (-not (Test-Path -LiteralPath $python)) { throw "Bundled Python is unavailable" }

$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($runner, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw "Release runner does not parse" }
$required = @(
    "Get-StringSha256", "Test-GateUsesArtifact", "Get-LogReference", "Get-CachedFileSha256",
    "Get-NormalizedGateValue", "Get-GateIdentity", "Add-Result", "ConvertTo-ArgumentLine",
    "Stop-IsolatedProcess", "Invoke-ManagedProcess", "Invoke-ExternalGate", "Invoke-CapturedProcess", "Invoke-GodotGate"
)
foreach ($name in $required) {
    $definition = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name }, $true) | Select-Object -First 1
    if ($null -eq $definition) { throw "Missing release runner function: $name" }
    . ([scriptblock]::Create($definition.Extent.Text))
}

$base = "D:\Temp\AshenOath"
New-Item -ItemType Directory -Force -Path $base | Out-Null
$tempRoot = Join-Path $base ("qa001-runner-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
$Logs = $tempRoot
$RunDirectory = $tempRoot
$QAWeb = Join-Path $tempRoot "qa-web"
$Web = Join-Path $tempRoot "web"
$RepoRoot = $Project
$FileHashCache = @{}
$CurrentRuntimeFingerprint = "fixture-runtime"
$CurrentHarnessFingerprint = "fixture-harness"
$CurrentRegistryFingerprint = "fixture-registry"
$CurrentArtifactFingerprint = "fixture-artifact"
$ExecutionFingerprint = "fixture-execution"
$CurrentGateIdentity = $null
$Results = [System.Collections.Generic.List[object]]::new()
$TimeoutSeconds = 5
$VerboseOutput = $false
$fixture = Join-Path $tempRoot "fixture.py"
@'
import json
import subprocess
import sys
import time

case = sys.argv[1]
report = sys.argv[3]
print("ARGS=" + repr(sys.argv), flush=True)
if case == "timeout":
    time.sleep(3)
if case == "inherited_stream":
    subprocess.Popen([sys.executable, "-c", "import time; time.sleep(5)"],
                     stdout=sys.stdout, stderr=sys.stderr,
                     creationflags=subprocess.CREATE_NO_WINDOW)
if case != "missing_report":
    status = "fail" if case == "reported_fail" else "pass"
    with open(report, "w", encoding="utf-8") as handle:
        if case == "malformed_report":
            handle.write("{broken")
        elif case == "statusless_report":
            json.dump({"detail": "pass marker only"}, handle)
        else:
            json.dump({"status": status}, handle)
if case != "missing_marker":
    print("VERIFIER: PASS", flush=True)
if case == "pass":
    print("ASSERTION: fixture reached the owned process boundary", flush=True)
    print("WARNING: fixture warning retained for review", flush=True)
if case == "fatal_after_pass":
    print('ERROR: Parameter "material" is null', flush=True)
if case == "rid_after_shutdown":
    print("VERIFIER_PHASE: SHUTDOWN", flush=True)
    print("RID allocations of type PhysicsServer3DShape are leaked at exit", flush=True)
sys.exit(7 if case == "nonzero" else 0)
'@ | Set-Content -LiteralPath $fixture -Encoding utf8

try {
    $cases = @(
        @{ Name = "pass"; Fails = $false },
        @{ Name = "fatal_after_pass"; Fails = $true },
        @{ Name = "rid_after_shutdown"; Fails = $true },
        @{ Name = "nonzero"; Fails = $true },
        @{ Name = "reported_fail"; Fails = $true },
        @{ Name = "missing_report"; Fails = $true },
        @{ Name = "malformed_report"; Fails = $true },
        @{ Name = "statusless_report"; Fails = $true },
        @{ Name = "inherited_stream"; Fails = $true },
        @{ Name = "timeout"; Fails = $true }
    )
    foreach ($case in $cases) {
        $Results.Clear()
        $report = Join-Path $tempRoot ("$($case.Name).json")
        $threw = $false
        $caughtError = ""
        try {
            Invoke-ExternalGate $case.Name $python @($fixture, $case.Name, "--report", $report) (1 + (4 * [int]($case.Name -ne "timeout")))
        } catch {
            $threw = $true
            $caughtError = $_.Exception.Message
        }
        if ($threw -ne $case.Fails) {
            $caseLog = Join-Path $Logs ("$($case.Name).log")
            $logText = if (Test-Path -LiteralPath $caseLog) { Get-Content -LiteralPath $caseLog -Raw } else { "missing" }
            throw "Incorrect process result for $($case.Name); error=$caughtError; log=$logText"
        }
        $expected = if ($case.Fails) { "fail" } else { "pass" }
        if ($Results.Count -ne 1 -or $Results[0].status -ne $expected) {
            throw "Incorrect structured gate result for $($case.Name)"
        }
        $result = $Results[0]
        $expectedExit = if ($case.Name -eq "nonzero") { 7 } elseif ($case.Name -in @("timeout", "inherited_stream")) { 124 } else { 0 }
        if ($result.process.owner -ne "release-runner" -or $result.process.exit_code -ne $expectedExit -or
                $result.process.timed_out -ne ($case.Name -in @("timeout", "inherited_stream"))) {
            throw "Incorrect process ownership metadata for $($case.Name)"
        }
        if ($case.Name -eq "rid_after_shutdown" -and $result.runtime_phase -ne "shutdown") {
            throw "Shutdown phase was not recorded"
        }
        if ($case.Name -eq "pass") {
            if (@($result.assertions).Count -ne 3 -or @($result.warnings).Count -ne 1 -or
                    $result.runtime_phase -ne "runner_completed") {
                throw "Runner/verifier assertions, warning, or completion phase were not recorded"
            }
        }
        Write-Output "QA-001 PROCESS $($case.Name): PASS"
    }
    $batch = Join-Path $tempRoot "failure.bat"
    "@echo off`r`nexit /b 9`r`n" | Set-Content -LiteralPath $batch -Encoding ascii
    $batchResult = Invoke-ManagedProcess $batch @() (Join-Path $tempRoot "batch.out") (Join-Path $tempRoot "batch.err") 5
    if ($batchResult.TimedOut -or $batchResult.ExitCode -ne 9) {
        throw "Batch gate exit status was masked: $($batchResult.ExitCode)"
    }
    Write-Output "QA-001 PROCESS batch_exit: PASS"
    $godotCases = @(
        @{ Name = "pass"; Fails = $false },
        @{ Name = "fatal_after_pass"; Fails = $true },
        @{ Name = "rid_after_shutdown"; Fails = $true },
        @{ Name = "nonzero"; Fails = $true },
        @{ Name = "missing_marker"; Fails = $true },
        @{ Name = "timeout"; Fails = $true }
    )
    foreach ($case in $godotCases) {
        $Results.Clear()
        $TimeoutSeconds = if ($case.Name -eq "timeout") { 1 } else { 5 }
        $name = "godot_$($case.Name)"
        $threw = $false
        $caughtError = ""
        try {
            Invoke-GodotGate $name @($fixture, $case.Name, "--report", (Join-Path $tempRoot "$name.json")) $python
        } catch {
            $threw = $true
            $caughtError = $_.Exception.Message
        }
        if ($threw -ne $case.Fails) {
            $caseLog = Join-Path $Logs "$name.log"
            $logText = if (Test-Path -LiteralPath $caseLog) { Get-Content -LiteralPath $caseLog -Raw } else { "missing" }
            throw "Incorrect Godot-style result for $name; error=$caughtError; log=$logText"
        }
        $expected = if ($case.Fails) { "fail" } else { "pass" }
        if ($Results.Count -ne 1 -or $Results[0].status -ne $expected) {
            throw "Incorrect Godot-style structured result for $name"
        }
        $result = $Results[0]
        $expectedExit = if ($case.Name -eq "nonzero") { 7 } elseif ($case.Name -eq "timeout") { 124 } else { 0 }
        if ($result.process.owner -ne "release-runner" -or $result.process.exit_code -ne $expectedExit -or
                $result.process.timed_out -ne ($case.Name -eq "timeout")) {
            throw "Incorrect Godot-style process metadata for $name"
        }
        Write-Output "QA-001 GODOT $($case.Name): PASS"
    }
    Write-Output "QA-001 PROCESS INJECTION: PASS"
} finally {
    $baseFull = [IO.Path]::GetFullPath($base).TrimEnd('\')
    $targetFull = [IO.Path]::GetFullPath($tempRoot)
    if ($targetFull.StartsWith($baseFull + '\', [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $targetFull)) {
        Remove-Item -LiteralPath $targetFull -Recurse -Force
    }
}
