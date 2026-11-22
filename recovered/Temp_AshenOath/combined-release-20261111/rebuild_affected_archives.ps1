param(
    [Parameter(Mandatory)][string]$BuildId,
    [Parameter(Mandatory)][string]$SourceCommit,
    [string]$PreviousBuild = 'combined-loading-cast-20261111-945101e-r2',
    [AllowEmptyCollection()][ValidateSet('base','campaign','community')][string[]]$AffectedPacks = @('community'),
    [switch]$CompileOnlyDelivery
)
$ErrorActionPreference = 'Stop'
$Repo = 'D:/Projects/AshenOath'
$Project = Join-Path $Repo 'outputs/AshenOathTheRoadBetweenCrowns'
$ToolRoot = Join-Path $Project 'tools'
$Godot = 'C:/Users/User/.cache/codex-runtimes/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe'
$Python = 'C:/Users/User/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
$Initial = Join-Path $Repo '.release-gate/combined-loading-cast-20261111-945101e-r2'
if ($PreviousBuild -notmatch '^combined-loading-cast-20261111-[a-z0-9-]+$') { throw 'Invalid previous combined release build ID.' }
$Previous = Join-Path $Repo ('.release-gate/' + $PreviousBuild)
$PreviousExport = Join-Path $Previous 'export'
if ($BuildId -notmatch '^combined-loading-cast-20261111-[a-z0-9-]+$') { throw 'Invalid combined release build ID.' }
if ((git -C $Repo rev-parse HEAD).Trim() -ne $SourceCommit) { throw 'Candidate source commit is not HEAD.' }
$Out = Join-Path $Repo ('.release-gate/' + $BuildId)
if (Test-Path -LiteralPath $Out) { throw 'Candidate output directory must be fresh.' }
$RuntimeManifest = Join-Path $Project 'runtime_pack_manifest.json'
$PreviousManifest = Join-Path $PreviousExport 'runtime_pack_manifest.json'
if (-not $CompileOnlyDelivery -and (Get-FileHash -LiteralPath $RuntimeManifest).Hash -ne (Get-FileHash -LiteralPath $PreviousManifest).Hash) {
    throw 'Current manifest differs from the exact prior build; reconsider archive reuse.'
}
$Export = Join-Path $Out 'export'
$Raw = Join-Path $Out 'runtime-packs'
$Changed = Join-Path $Out 'changed-packs'
$Transport = Join-Path $Out 'transport-inputs'
$Logs = Join-Path $Out 'logs'
$ResourceCheck = Join-Path $Out 'isolated-resource-check'
New-Item -ItemType Directory -Path $Export,$Raw,$Changed,$Transport,$Logs,$ResourceCheck | Out-Null

function Invoke-Checked([string]$Exe,[string[]]$Arguments,[string]$Name) {
    Write-Host "Building/checking: $Name"
    $stdout = Join-Path $Logs ($Name + '.stdout.log')
    $stderr = Join-Path $Logs ($Name + '.stderr.log')
    if ($Exe -eq $Godot) { $Arguments = @('--log-file',(Join-Path $Logs ($Name + '.engine.log'))) + $Arguments }
    $quoted = @($Arguments | ForEach-Object { '"' + $_.Replace('"','\"') + '"' })
    $proc = Start-Process -FilePath $Exe -ArgumentList ($quoted -join ' ') -WorkingDirectory $Project -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    if ($proc.ExitCode -ne 0 -or ($Exe -eq $Godot -and (Select-String -LiteralPath @($stdout,$stderr) -Pattern '(?i)^ERROR:|SCRIPT ERROR:|Failed to load script|Error parsing script|ObjectDB instances leaked|resources still in use'))) {
        Get-Content -LiteralPath @($stdout,$stderr) -Tail 25
        throw "$Name failed ($($proc.ExitCode)); see $Logs"
    }
    Get-Content -LiteralPath $stdout -Tail 3
}

if ($CompileOnlyDelivery) {
    foreach ($Name in @('stationary_work_grip','character_life_modifier','greyfen_life_controller','saga_activities')) {
        Invoke-Checked $Godot @('--headless','--path',$Project,'--check-only','--script',"res://scripts/$Name.gd") "compile-$Name"
    }
} else {
    Invoke-Checked $Godot @('--headless','--path',$Project,'--script',(Join-Path $ToolRoot 'verify_community_routes.gd'),'--','--require-expansion') 'community-routes'
    if ($PreviousBuild -eq 'combined-loading-cast-20261111-945101e-r2') {
        Invoke-Checked $Godot @('--headless','--path',$Project,'--script',(Join-Path $ToolRoot 'verify_ambient_morph_ownership.gd')) 'ambient-morph-ownership'
    }
}
$PackLayout = Get-Content -LiteralPath $PreviousManifest -Raw | ConvertFrom-Json
$OldRaw = Join-Path $Previous 'runtime-packs'
$Compaction = Join-Path $Out 'changed-pack-compaction.json'
$Compactor = Join-Path $ToolRoot 'compact_runtime_packs.py'
foreach ($Id in $AffectedPacks) {
    $PackPreset = [string]$PackLayout.pack_presets.$Id
    if (-not $PackPreset) { throw "Missing preset for $Id" }
    Invoke-Checked $Godot @('--headless','--path',$Project,'--export-pack',$PackPreset,(Join-Path $Changed ($Id + '.pck'))) "pack-$Id"
}
$Authority = if ($AffectedPacks -contains 'base') { Join-Path $Changed 'base.pck' } else { Join-Path $OldRaw 'base.pck' }
if ($AffectedPacks.Count -gt 0) {
    Invoke-Checked $Python @($Compactor,'--root-pack',$Authority,'--pack-dir',$Changed,'--report',$Compaction) 'compact-affected-packs'
}

Get-ChildItem -LiteralPath $OldRaw -Filter '*.pck' -File | Copy-Item -Destination $Raw
Get-ChildItem -LiteralPath (Join-Path $PreviousExport 'packs') -Filter '*.pck' -File | Copy-Item -Destination $Transport
$Candidate = Get-Content -LiteralPath (Join-Path $OldRaw 'runtime_pack_candidates.json') -Raw | ConvertFrom-Json -AsHashtable
foreach ($Id in $AffectedPacks) {
    $Name = $Id + '.pck'
    $PackFile = Join-Path $Changed $Name
    Copy-Item -LiteralPath $PackFile -Destination (Join-Path $Raw $Name) -Force
    if ($Id -ne 'base') { Copy-Item -LiteralPath $PackFile -Destination (Join-Path $Transport $Name) -Force }
    $Rows = @($Candidate.packs | Where-Object { $_.id -eq $Id })
    if ($Rows.Count -ne 1) { throw "Prior candidates must have one authoritative record for $Id." }
    $Rows[0].bytes = (Get-Item -LiteralPath $PackFile).Length
    $Rows[0].sha256 = (Get-FileHash -LiteralPath $PackFile).Hash.ToLowerInvariant()
    $Rows[0].version = $BuildId
    $Rows[0].log = "logs/pack-$Id.stdout.log"
}
$Candidate.generated_at_utc = [datetime]::UtcNow.ToString('o')
$Candidate.build_id = $BuildId
$Candidate.generated_from_commit = $SourceCommit
$Candidate.artifact_directory = $Raw
$Candidate.total_bytes = [int64](($Candidate.packs | ForEach-Object { $_.bytes } | Measure-Object -Sum).Sum)
if (-not $CompileOnlyDelivery) {
    foreach ($Record in $Candidate.packs) {
        $File = Get-Item -LiteralPath (Join-Path $Raw $Record.artifact)
        if ($File.Length -ne $Record.bytes -or (Get-FileHash -LiteralPath $File.FullName).Hash.ToLowerInvariant() -ne $Record.sha256) {
            throw "Reused raw pack does not match verified input: $($Record.id)"
        }
    }
}
$CandidatePath = Join-Path $Raw 'runtime_pack_candidates.json'
[IO.File]::WriteAllText($CandidatePath, (($Candidate | ConvertTo-Json -Depth 12) + [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
Invoke-Checked $Python @((Join-Path $ToolRoot 'sync_runtime_pack_manifest.py'),$RuntimeManifest,$CandidatePath,'--build-id',$BuildId,'--source-commit',$SourceCommit) 'pack-manifest'
Invoke-Checked $Godot @('--headless','--path',$Project,'--export-release','Web Browser',(Join-Path $Export 'index.html')) 'web-production'
$RootPack = Join-Path $Export 'index.pck'
if (-not $CompileOnlyDelivery) {
    Invoke-Checked $Python @($Compactor,'--root-pack',$RootPack,'--verify-authority',(Join-Path $Initial 'pack-metadata-compaction.json')) 'prior-pack-metadata-authority'
    if (Test-Path -LiteralPath $Compaction) {
        Invoke-Checked $Python @($Compactor,'--root-pack',$RootPack,'--verify-authority',$Compaction) 'affected-pack-metadata-authority'
    }
    Invoke-Checked $Godot @('--headless','--path',$ResourceCheck,'--main-pack',$RootPack,'--script',(Join-Path $ToolRoot 'verify_prepared_actor_package.gd'),'--','--pack-dir',$Raw) 'prepared-actor-package'
}
Copy-Item -LiteralPath $RuntimeManifest -Destination (Join-Path $Export 'runtime_pack_manifest.json')
Invoke-Checked $Python @((Join-Path $ToolRoot 'build_web_runtime_manifest.py'),$Export,'--runtime-pack-manifest',$RuntimeManifest,'--pack-dir',$Transport,'--source-commit',$SourceCommit,'--compress-wasm') 'web-manifest'
if (-not $CompileOnlyDelivery) {
    Invoke-Checked $Python @((Join-Path $ToolRoot 'community_acceptance_packs.py'),'--export',$Export) 'community-web-residency'
}
Write-Host "Candidate is isolated at $Export; no bytes copied to web/."
