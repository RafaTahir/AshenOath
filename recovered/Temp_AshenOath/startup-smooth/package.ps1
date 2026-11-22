param([switch]$RootOnly)
$ErrorActionPreference = 'Stop'
$Repository = 'D:\Projects\AshenOath'
$Project = Join-Path $Repository 'outputs\AshenOathTheRoadBetweenCrowns'
$OutputRoot = Join-Path $Repository '.release-gate\startup-smooth-20261013'
$Export = Join-Path $OutputRoot 'export'
$PackRoot = Join-Path $OutputRoot 'runtime-packs'
$Logs = Join-Path $OutputRoot 'logs'
$Godot = 'C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe'
$Python = 'C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$BuildId = if ($RootOnly) { 'startup-smooth-20261013-final-10371b9' } else { 'startup-smooth-20261013-10371b9' }
$Commit = (git -C $Repository rev-parse HEAD).Trim()
$env:TEMP = 'D:\Temp\AshenOath'
$env:TMP = $env:TEMP
New-Item -ItemType Directory -Force -Path $Export, (Join-Path $Export 'packs'), $PackRoot, $Logs | Out-Null

$Previous = Get-Content (Join-Path $Repository 'web\release_manifest.json') -Raw | ConvertFrom-Json
$Ledger = Get-Content (Join-Path $Project 'runtime_pack_candidates.json') -Raw | ConvertFrom-Json
$Ledger.build_id = $BuildId
$Ledger.generated_from_commit = $Commit
$Ledger.source_dirty = $true
$Ledger.artifact_directory = $PackRoot
$Ledger.generated_at_utc = (Get-Date).ToUniversalTime().ToString('o')
foreach ($Record in $Ledger.packs) {
    $Record.version = $BuildId
    if ($Record.id -in @('opening','characters') -and $RootOnly) {
        Copy-Item -LiteralPath (Join-Path $PackRoot $Record.artifact) -Destination (Join-Path $Export ('packs/' + $Record.id + '.pck'))
        continue
    }
    if ($Record.id -in @('base','opening','characters')) { continue }
    $Artifact = $Previous.artifacts | Where-Object { $_.path -eq ('packs/' + $Record.id + '.pck') }
    if (-not $Artifact) { throw "Missing retained pack: $($Record.id)" }
    $Record.bytes = $Artifact.decoded_bytes
    $Record.sha256 = $Artifact.decoded_sha256
    Copy-Item -LiteralPath (Join-Path $Repository ('web/' + $Artifact.path)) -Destination (Join-Path $Export $Artifact.path)
}
$LedgerPath = Join-Path $PackRoot 'runtime_pack_candidates.json'
$Ledger | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $LedgerPath -Encoding utf8
& $Python (Join-Path $Project 'tools\sync_runtime_pack_manifest.py') (Join-Path $Project 'runtime_pack_manifest.json') $LedgerPath --build-id $BuildId --source-commit $Commit
if ($LASTEXITCODE) { throw 'Initial pack identity update failed.' }

function Export-Godot([string]$Preset, [string]$Target, [string]$Tag, [switch]$Web) {
    $Mode = if ($Web) { '--export-release' } else { '--export-pack' }
    $Stdout = Join-Path $Logs ($Tag + '.stdout.log')
    $Stderr = Join-Path $Logs ($Tag + '.stderr.log')
    $Arguments = "--headless --path `"$Project`" $Mode `"$Preset`" `"$Target`""
    $Process = Start-Process -FilePath $Godot -ArgumentList $Arguments -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $Stdout -RedirectStandardError $Stderr
    if ($Process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $Target)) { throw "Export failed: $Tag" }
    if (Select-String -LiteralPath $Stderr -Pattern 'SCRIPT ERROR:|Parse Error:|Failed to load script|ERROR:' -Quiet) { throw "Export diagnostics failed: $Stderr" }
}
foreach ($Record in $Ledger.packs) {
    if ($Record.id -notin @('base','opening','characters')) { continue }
    if ($RootOnly -and $Record.id -ne 'base') { continue }
    $Target = Join-Path $PackRoot $Record.artifact
    Write-Host "Packaging changed pack: $($Record.id)"
    Export-Godot $Record.preset $Target $Record.id
    $Record.bytes = (Get-Item -LiteralPath $Target).Length
    $Record.sha256 = (Get-FileHash -LiteralPath $Target -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($Record.id -ne 'base') { Copy-Item -LiteralPath $Target -Destination (Join-Path $Export ('packs/' + $Record.id + '.pck')) }
}
$Ledger.total_bytes = [int64](($Ledger.packs | Measure-Object -Property bytes -Sum).Sum)
$Ledger | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $LedgerPath -Encoding utf8
& $Python (Join-Path $Project 'tools\sync_runtime_pack_manifest.py') (Join-Path $Project 'runtime_pack_manifest.json') $LedgerPath --build-id $BuildId --source-commit $Commit
if ($LASTEXITCODE) { throw 'Final pack identity update failed.' }
Write-Host 'Packaging production Web preset'
Export-Godot 'Web Browser' (Join-Path $Export 'index.html') 'web' -Web
Copy-Item -LiteralPath (Join-Path $Project 'runtime_pack_manifest.json') -Destination (Join-Path $Export 'runtime_pack_manifest.json')
Copy-Item -LiteralPath (Join-Path $Repository 'web\menu-background.png') -Destination (Join-Path $Export 'menu-background.png')
& $Python (Join-Path $Project 'tools\build_web_runtime_manifest.py') $Export --compress-wasm --source-commit $Commit
if ($LASTEXITCODE) { throw 'Web package identity or budget failed.' }
Write-Host "Candidate: $Export"
