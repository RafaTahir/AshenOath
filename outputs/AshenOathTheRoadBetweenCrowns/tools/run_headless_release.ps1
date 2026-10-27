param([string[]]$Only = @(), [string]$Run = "", [string]$Godot = $env:GODOT_BIN)
# Uses the canonical verifier inventory and owned-process implementation.
# This is headless source evidence, not browser or performance certification.
$Suffix = ""
$ErrorActionPreference = 'Stop'
$Project = Split-Path -Parent $PSScriptRoot
if (-not $Run) { $Run = Join-Path 'D:\Temp\AshenOath' ('headless-release-' + [guid]::NewGuid().ToString('N')) }
if (-not $Godot) { $Godot = 'D:\Temp\AshenOath\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' }
$Python = 'C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$env:APPDATA = Join-Path $Run ('profile' + $Suffix)
$env:TEMP = 'D:\Temp\AshenOath'
$env:TMP = $env:TEMP
$TimeoutSeconds = 240
New-Item -ItemType Directory -Force -Path "$Run\headless",$env:APPDATA | Out-Null
Set-Location -LiteralPath $Project
$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile("$Project\tools\run_release_gate.ps1",[ref]$tokens,[ref]$parseErrors)
if ($parseErrors.Count) { throw 'Existing release runner does not parse.' }
foreach ($name in @('ConvertTo-ArgumentLine','Stop-IsolatedProcess','Invoke-ManagedProcess')) {
    $function = $ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name},$true)
    if ($null -eq $function) { throw "Existing process owner missing: $name" }
    $source = $function.Extent.Text
    if ($name -eq 'Invoke-ManagedProcess') {
        $source = $source.Replace('$completed = $process.WaitForExit($effectiveTimeoutSeconds * 1000)', @'
$completed = $false
        $deadline = [DateTime]::UtcNow.AddSeconds($effectiveTimeoutSeconds)
        while ([DateTime]::UtcNow -lt $deadline) {
            if ($process.WaitForExit(350)) { $completed = $true; break }
            if ($script:CurrentEngineLog -and (Test-Path -LiteralPath $script:CurrentEngineLog)) {
                if (Select-String -LiteralPath $script:CurrentEngineLog -Pattern 'SCRIPT ERROR|Parse Error|Compile Error|ERROR:|ASSERTION FAILED|Assertion failed' -Quiet -ErrorAction SilentlyContinue) {
                    $script:GateFatalOutput = $true
                    break
                }
            }
        }
'@)
    }
    . ([scriptblock]::Create($source))
}
$assignment = $ast.Find({param($node) $node -is [Management.Automation.Language.AssignmentStatementAst] -and $node.Left.Extent.Text -eq '$verifiers'},$true)
$verifiers = @($assignment.Right.FindAll({param($node) $node -is [Management.Automation.Language.StringConstantExpressionAst]},$true) | ForEach-Object Value | Select-Object -Unique)
if ($verifiers.Count -lt 80) { throw 'Canonical integration list extraction failed.' }
$graphical = @('verify_paused_player_real_input.gd','verify_access_context_real_input.gd','verify_world_013.gd','verify_qa_012.gd','verify_perf_003.gd')
$results = [System.Collections.Generic.List[object]]::new()
$skipped = @($verifiers | Where-Object { $_ -in $graphical })
$verifiers = @('verify_runtime_smoke.gd') + @($verifiers | Where-Object { $_ -notin $graphical -and $_ -ne 'verify_runtime_smoke.gd' })
if ($Only.Count) {
    $known = @('content-integrity','python-unit-suite') + @($verifiers | ForEach-Object { [IO.Path]::GetFileNameWithoutExtension($_) })
    foreach ($name in $Only) { if ($name -notin $known) { throw "Unknown/inapplicable headless gate: $name" } }
}
if ($Only.Count) { $verifiers = @($verifiers | Where-Object { [IO.Path]::GetFileNameWithoutExtension($_) -in $Only }) }
function Save-Summary {
    [ordered]@{acceptance_profile='headless_release_with_disclosures';scope='Canonical source checks only; not browser, rendered, phone, listening or strict performance acceptance';complete_source_run=($Only.Count -eq 0);isolated_profile=$env:APPDATA;skipped_graphical=$skipped;results=@($results.ToArray())} | ConvertTo-Json -Depth 9 | Set-Content -LiteralPath "$Run\headless-results$Suffix.json" -Encoding utf8
}
function Run-Check([string]$Name,[string]$Executable,[string[]]$Arguments,[bool]$GodotCheck) {
	$env:APPDATA = Join-Path $Run ("profiles$Suffix\$Name")
	New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
    Write-Output "RUN $Name"
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $output = "$Run\headless\$Name$Suffix.stdout.log"
    $errorOutput = "$Run\headless\$Name$Suffix.stderr.log"
    $script:GateFatalOutput = $false
    $script:CurrentEngineLog = if ($GodotCheck) { "$Run\headless\$Name$Suffix.engine.log" } else { '' }
    if ($GodotCheck) { $Arguments = @('--log-file',$script:CurrentEngineLog) + $Arguments }
	$ownedTimeout = if ($Name -eq 'verify_gate_transitions') { 900 } else { 240 }
    $process = Invoke-ManagedProcess $Executable $Arguments $output $errorOutput $ownedTimeout
    $watch.Stop()
    $content = (Get-Content -LiteralPath $output,$errorOutput -Raw -ErrorAction SilentlyContinue) -join "`n"
    $failure = ''
    if ($script:GateFatalOutput) { $failure = 'Fatal engine output; owned fixture cancelled without waiting for the timeout.' }
    elseif ($process.TimedOut) { $failure = "Owned process timed out at $ownedTimeout seconds." }
    elseif ($process.ExitCode -ne 0) { $failure = "Owned process exit $($process.ExitCode)." }
    elseif ($GodotCheck) {
        $line = @($content -split "`n" | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error|Compile Error|Failed to load|Cannot open|ERROR:|VERIFIER:\s*FAIL|ASSERTION FAILED|Assertion failed|RID allocations .* leaked at exit|ObjectDB instances leaked at exit' } | Select-Object -First 1)
        if ($line.Count) { $failure = $line[0].Trim() }
        elseif ($content -notmatch '\bPASS\b') { $failure = 'No verifier PASS marker.' }
    }
    $status = if ($failure) {'fail'} else {'pass'}
    $results.Add([ordered]@{name=$Name;status=$status;exit_code=$process.ExitCode;timed_out=($process.TimedOut -and -not $script:GateFatalOutput);fatal_output_abort=$script:GateFatalOutput;seconds=[Math]::Round($watch.Elapsed.TotalSeconds,2);failure=$failure;stdout=$output;stderr=$errorOutput;limitations=@($content -split "`n" | Where-Object { $_ -match '^PERFORMANCE LIMITATION:' })})
    Save-Summary
    Write-Output "$Name : $status ($([Math]::Round($watch.Elapsed.TotalSeconds,1))s) $failure"
}
if (-not $Only.Count -or 'content-integrity' -in $Only) { Run-Check 'content-integrity' $Python @("$Project/tools/verify_content_integrity.py",$Project,'--json-report',"$Run\content-integrity$Suffix.json") $false }
if (-not $Only.Count -or 'python-unit-suite' -in $Only) { Run-Check 'python-unit-suite' $Python @('-m','unittest','discover','-s',"$Project/tools",'-p','test_*.py') $false }
foreach ($verifier in $verifiers) {
    Run-Check ([IO.Path]::GetFileNameWithoutExtension($verifier)) $Godot @('--headless','--path',$Project,'--script',"tools/$verifier",'--','--acceptance-profile=headless_release_with_disclosures') $true
}
$failed = @($results | Where-Object { $_.status -eq 'fail' })
Write-Output "Evidence directory: $Run"
Write-Output "HEADLESS COMPLETE: $($results.Count-$failed.Count) pass, $($failed.Count) fail, $($skipped.Count) graphical-only not run."
exit ([int]($failed.Count -gt 0))

