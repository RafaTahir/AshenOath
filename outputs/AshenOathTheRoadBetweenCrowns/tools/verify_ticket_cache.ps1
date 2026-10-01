$ErrorActionPreference = 'Stop'
$Runner = Join-Path $PSScriptRoot 'run_ticket_gate.ps1'
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($Runner, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
$names = @('Normalize-Path', 'Matches-Pattern', 'Add-Unique', 'Get-GateInputs', 'Get-GateHash')
$script:CacheRunnerRoot = $PSScriptRoot
foreach ($function in $ast.FindAll({param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst]}, $true)) {
    # Dynamically compiled functions otherwise lose their originating script directory.
    if ($function.Name -in $names) { Invoke-Expression ($function.Extent.Text.Replace('$PSScriptRoot', '$script:CacheRunnerRoot')) }
}
$tempRoot = 'D:\Temp\AshenOath'
[IO.Directory]::CreateDirectory($tempRoot) | Out-Null
$RepoRoot = Join-Path $tempRoot ('cache-proof-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($RepoRoot) | Out-Null
$dependency = Join-Path $RepoRoot 'dependency.txt'
$unrelated = Join-Path $RepoRoot 'unrelated.txt'
$ProfilesPath = Join-Path $RepoRoot 'profiles.json'
$Configuration = '{"profiles":{"fixture":{"patterns":["dependency.txt"],"gates":["fixture"]}}}' | ConvertFrom-Json
try {
    [IO.File]::WriteAllText($dependency, 'before')
    [IO.File]::WriteAllText($unrelated, 'unrelated')
    $inputs = @(Get-GateInputs 'fixture' @('dependency.txt', 'unrelated.txt'))
    if ($inputs.Count -ne 1 -or $inputs[0] -ne 'dependency.txt') { throw 'Dependency selection includes unrelated files or omits dependency.' }
    $before = Get-GateHash 'fixture' $inputs
    [IO.File]::WriteAllText($dependency, 'after')
    $after = Get-GateHash 'fixture' $inputs
    if ($before -eq $after) { throw 'Dependency edit did not invalidate cache.' }
    Remove-Item -LiteralPath $dependency
    $missing = Get-GateHash 'fixture' $inputs
    if ($missing -eq $after) { throw 'Deleted dependency did not invalidate cache.' }
    if ($ast.Extent.Text -notmatch 'Get-GateInputs \$gate \$dependencyFiles') { throw 'Runner still hashes changed paths only.' }
    Write-Host 'TICKET CACHE: PASS - dependency selection, edit and deletion invalidation'
} finally {
    foreach ($file in @($dependency, $unrelated)) {
        if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file }
    }
    # Empty fixture directory only; never recursively remove the QA cache root.
    Remove-Item -LiteralPath $RepoRoot
}
