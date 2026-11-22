$ErrorActionPreference = 'Stop'
$runner = Join-Path $PSScriptRoot 'run_ticket_gate.ps1'
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($runner, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'Ticket runner does not parse' }
foreach ($name in @('Invoke-Compact', 'Write-Cache')) {
    $function = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name }, $true)
    if ($null -eq $function) { throw "Runner function missing: $name" }
    . ([scriptblock]::Create($function.Extent.Text))
}
function Get-GateHash { param($Name, $Files) return "controlled-$Name" }
$base = [IO.Path]::GetFullPath('D:\Temp\AshenOath')
$owned = Join-Path $base ('ashen-oath-qa003-cache-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $owned -Force | Out-Null
$resolved = (Resolve-Path -LiteralPath $owned).Path
if (-not $resolved.StartsWith($base + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe fixture directory' }
$Logs = $owned
$CacheDirectory = Join-Path $owned 'cache'
$CachePath = Join-Path $CacheDirectory 'ticket-gates.json'
$NoCache = $false
$TimeoutSeconds = 5
$Python = 'C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$cache = @{ unaffected = @{ hash = 'previous-valid-inputs'; status = 'pass' } }
try {
    Write-Cache $cache
    $before = [IO.File]::ReadAllBytes($CachePath)
    Invoke-Compact 'capture_fixture.provenance_begin' $Python @('-c', "print('controlled begin')") @() $cache -Transient
    if ([Convert]::ToBase64String($before) -ne [Convert]::ToBase64String([IO.File]::ReadAllBytes($CachePath))) { throw 'Transient success rewrote passing cache' }
    if ($cache.Count -ne 1) { throw 'Transient success inserted a reusable capture session' }
    $failed = $false
    try {
        Invoke-Compact 'capture_fixture.provenance_finish' $Python @('-c', "import sys; print('controlled rejection'); sys.exit(1)") @() $cache -Transient
    } catch { $failed = $true }
    if (-not $failed) { throw 'Rejected capture session did not propagate failure' }
    if ([Convert]::ToBase64String($before) -ne [Convert]::ToBase64String([IO.File]::ReadAllBytes($CachePath))) { throw 'Transient failure rewrote passing cache' }
    if ($cache.Count -ne 1) { throw 'Transient failure inserted a reusable capture session' }
    'VISUAL CAPTURE CACHE: PASS - transient sessions preserve unrelated green gates on success/failure'
} finally {
    $resolved = (Resolve-Path -LiteralPath $owned).Path
    if (-not $resolved.StartsWith($base + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe cleanup target' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
