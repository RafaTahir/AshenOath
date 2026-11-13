param([Parameter(Mandatory)][string]$BuildId)
$ErrorActionPreference = 'Stop'
$Project = Split-Path -Parent $PSScriptRoot
$Repo = Split-Path -Parent (Split-Path -Parent $Project)
$Godot = 'C:/Users/User/.cache/codex-runtimes/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe'
$Python = 'C:/Users/User/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
if ($BuildId -notmatch '^proximity-streaming-[a-z0-9-]+$') { throw 'Invalid build ID.' }
$Out = Join-Path $Repo ('.release-gate/' + $BuildId)
if (Test-Path -LiteralPath $Out) { throw 'Use a fresh output directory; previous builds are preserved.' }
$Source = (& git -C $Repo rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Unable to identify source commit.' }
$Runtime = Join-Path $Project 'runtime_pack_manifest.json'
$PriorRuntime = Join-Path $Repo 'web/runtime_pack_manifest.json'
if ((Get-FileHash -LiteralPath $Runtime).Hash -ne (Get-FileHash -LiteralPath $PriorRuntime).Hash) {
    throw 'Runtime manifest does not match the preceding published candidate.'
}
$Candidate = Get-Content -LiteralPath (Join-Path $Project 'runtime_pack_candidates.json') -Raw | ConvertFrom-Json -AsHashtable
$PriorRaw = [string]$Candidate.artifact_directory
$Raw = Join-Path $Out 'runtime-packs'
$Changed = Join-Path $Out 'changed-packs'
$Transport = Join-Path $Out 'transport-inputs'
$Export = Join-Path $Out 'export'
$Logs = Join-Path $Out 'logs'
foreach ($Directory in @($Raw,$Changed,$Transport,$Export,$Logs)) { New-Item -ItemType Directory -Path $Directory -Force | Out-Null }
function Invoke-Compiler([string]$Exe,[string[]]$Arguments,[string]$Name) {
    $stdout = Join-Path $Logs ($Name + '.stdout.log')
    $stderr = Join-Path $Logs ($Name + '.stderr.log')
    if ($Exe -eq $Godot) { $Arguments = @('--log-file',(Join-Path $Logs ($Name + '.engine.log'))) + $Arguments }
    $quoted = @($Arguments | ForEach-Object { '"' + $_.Replace('"','\"') + '"' })
    Write-Host "Compiling/packaging: $Name"
    $process = Start-Process -FilePath $Exe -ArgumentList ($quoted -join ' ') -WorkingDirectory $Project -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    if ($process.ExitCode -ne 0 -or ($Exe -eq $Godot -and (Select-String -LiteralPath @($stdout,$stderr) -Pattern '(?i)^ERROR:|SCRIPT ERROR:|Failed to load script|Error parsing script'))) {
        Get-Content -LiteralPath @($stdout,$stderr) -Tail 24
        throw "$Name failed; candidate and logs preserved at $Out"
    }
}
# Source-only change: every reused asset archive must retain its exact identity.
foreach ($Record in $Candidate.packs) {
    $InputFile = Join-Path $PriorRaw $Record.artifact
    if ((Get-Item -LiteralPath $InputFile).Length -ne $Record.bytes -or (Get-FileHash -LiteralPath $InputFile).Hash.ToLowerInvariant() -ne $Record.sha256) {
        throw "Previous raw artifact identity mismatch: $($Record.id)"
    }
    Copy-Item -LiteralPath $InputFile -Destination (Join-Path $Raw $Record.artifact)
}
Get-ChildItem -LiteralPath (Join-Path $Repo 'web/packs') -File -Filter '*.pck' | Copy-Item -Destination $Transport
$Layout = Get-Content -LiteralPath $Runtime -Raw | ConvertFrom-Json
$Base = Join-Path $Changed 'base.pck'
Invoke-Compiler $Godot @('--headless','--path',$Project,'--export-pack',[string]$Layout.pack_presets.base,$Base) 'pack-base'
$Metadata = Join-Path $Repo '.release-gate/combined-loading-cast-20261111-945101e-r2/pack-metadata-compaction.json'
if (-not (Test-Path -LiteralPath $Metadata)) { throw 'The original complete asset-pack metadata authority receipt is required.' }
# Base is the metadata authority, not a supplemental pack. All asset packs are
# unchanged; the new Web root must still supply their original removed metadata.
Copy-Item -LiteralPath $Base -Destination (Join-Path $Raw 'base.pck') -Force
$Record = @($Candidate.packs | Where-Object id -eq 'base')
if ($Record.Count -ne 1) { throw 'Expected one base-pack record.' }
$Record[0].version = $BuildId
$Record[0].bytes = (Get-Item -LiteralPath $Base).Length
$Record[0].sha256 = (Get-FileHash -LiteralPath $Base).Hash.ToLowerInvariant()
$Record[0].log = 'logs/pack-base.stdout.log'
$Candidate.build_id = $BuildId
$Candidate.generated_at_utc = [datetime]::UtcNow.ToString('o')
$Candidate.generated_from_commit = $Source
$Candidate.source_dirty = $true
$Candidate.artifact_directory = $Raw
$Candidate.total_bytes = [int64](($Candidate.packs | ForEach-Object { $_.bytes } | Measure-Object -Sum).Sum)
$CandidatePath = Join-Path $Raw 'runtime_pack_candidates.json'
[IO.File]::WriteAllText($CandidatePath,(($Candidate | ConvertTo-Json -Depth 15)+[Environment]::NewLine),[Text.UTF8Encoding]::new($false))
Invoke-Compiler $Python @((Join-Path $PSScriptRoot 'sync_runtime_pack_manifest.py'),$Runtime,$CandidatePath,'--build-id',$BuildId,'--source-commit',$Source) 'runtime-manifest'
Invoke-Compiler $Godot @('--headless','--path',$Project,'--export-release','Web Browser',(Join-Path $Export 'index.html')) 'web-production'
Invoke-Compiler $Python @((Join-Path $PSScriptRoot 'compact_runtime_packs.py'),'--root-pack',(Join-Path $Export 'index.pck'),'--verify-authority',$Metadata) 'metadata-authority'
Copy-Item -LiteralPath $Runtime -Destination (Join-Path $Export 'runtime_pack_manifest.json')
Invoke-Compiler $Python @((Join-Path $PSScriptRoot 'build_web_runtime_manifest.py'),$Export,'--runtime-pack-manifest',$Runtime,'--pack-dir',$Transport,'--source-commit',$Source,'--compress-wasm') 'web-manifest'
Invoke-Compiler $Python @((Join-Path $PSScriptRoot 'verify_web_export.py'),$Export,'--json-report',(Join-Path $Out 'package-integrity.json')) 'package-integrity'
Write-Host "Build-only candidate ready at $Export. No gameplay, browser, benchmark, push or deployment was run."
