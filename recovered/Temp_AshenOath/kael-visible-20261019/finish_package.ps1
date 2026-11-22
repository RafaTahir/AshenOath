param([switch]$ResumeRoot)
$ErrorActionPreference = 'Stop'
$repo = 'D:\Projects\AshenOath'
$project = Join-Path $repo 'outputs\AshenOathTheRoadBetweenCrowns'
$build = Join-Path $repo '.release-gate\kael-visible-20261019'
$packs = Join-Path $build 'runtime-packs'
$export = Join-Path $build 'export'
$logs = Join-Path $build 'logs'
$godot = 'C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe'
$python = 'C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$templateSource = Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'Godot\export_templates\4.6.3.stable'
$env:TEMP = 'D:\Temp\AshenOath'
$env:TMP = $env:TEMP
$env:APPDATA = Join-Path $env:TEMP 'kael-visible-20261019\build-profile\Roaming'
$env:LOCALAPPDATA = Join-Path $env:TEMP 'kael-visible-20261019\build-profile\Local'
New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
$templateTarget = Join-Path $env:APPDATA 'Godot\export_templates\4.6.3.stable'
New-Item -ItemType Directory -Force -Path $templateTarget | Out-Null
foreach ($name in @('web_nothreads_debug.zip','web_nothreads_release.zip')) {
    if (-not (Test-Path -LiteralPath (Join-Path $templateTarget $name))) {
        Copy-Item -LiteralPath (Join-Path $templateSource $name) -Destination (Join-Path $templateTarget $name)
    }
}

function Compile([string[]]$Arguments, [string]$Name) {
    Write-Output ('Packaging correction: ' + $Name)
    $quoted = @($Arguments | ForEach-Object { '"' + $_ + '"' })
    $stdout = Join-Path $logs ($Name + '.stdout.log')
    $stderr = Join-Path $logs ($Name + '.stderr.log')
    $process = Start-Process -FilePath $godot -ArgumentList ($quoted -join ' ') -WorkingDirectory $project -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    if ($process.ExitCode -ne 0 -or (Select-String -LiteralPath $stdout,$stderr -Pattern 'SCRIPT ERROR:|Failed to load script|Error parsing script')) {
        throw ('Compilation failed: ' + $Name)
    }
}

foreach ($id in $(if ($ResumeRoot) { @() } else { @('characters','monsters') })) {
    $preset = 'Runtime Pack ' + (Get-Culture).TextInfo.ToTitleCase($id)
    Compile @('--headless','--path',$project,'--export-pack',$preset,(Join-Path $packs ($id+'.pck'))) ('retry-pack-'+$id)
}
$candidatePath = Join-Path $packs 'runtime_pack_candidates.json'
$candidate = Get-Content -LiteralPath $candidatePath -Raw | ConvertFrom-Json
foreach ($record in $candidate.packs) {
    if ($record.id -notin @('characters','monsters')) { continue }
    $path = Join-Path $packs $record.artifact
    $record.bytes = (Get-Item -LiteralPath $path).Length
    $record.sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    $record.log = 'logs/retry-pack-'+$record.id+'.stdout.log'
}
$candidate.total_bytes = [int64](($candidate.packs | ForEach-Object { $_.bytes } | Measure-Object -Sum).Sum)
[IO.File]::WriteAllText($candidatePath, (($candidate | ConvertTo-Json -Depth 10)+[Environment]::NewLine), [Text.UTF8Encoding]::new($false))
$manifest = Join-Path $project 'runtime_pack_manifest.json'
& $python (Join-Path $project 'tools\sync_runtime_pack_manifest.py') $manifest $candidatePath --build-id 'kael-visible-20261019-40df567' --source-commit '40df5676dcdf4c04ecccf2215e47a0cdffc81916'
if ($LASTEXITCODE -ne 0) { throw 'Manifest generation failed' }
Compile @('--headless','--path',$project,'--export-release','Web Browser',(Join-Path $export 'index.html')) 'retry-web-production'
foreach ($id in @('characters','monsters')) {
    Copy-Item -LiteralPath (Join-Path $packs ($id+'.pck')) -Destination (Join-Path $export ('packs\'+$id+'.pck')) -Force
}
Copy-Item -LiteralPath $manifest -Destination (Join-Path $export 'runtime_pack_manifest.json') -Force
& $python (Join-Path $project 'tools\build_web_runtime_manifest.py') $export --runtime-pack-manifest $manifest --source-commit '40df5676dcdf4c04ecccf2215e47a0cdffc81916' --compress-wasm
if ($LASTEXITCODE -ne 0) { throw 'Package integrity/budget failed' }
$release = Get-Content -LiteralPath (Join-Path $export 'release_manifest.json') -Raw | ConvertFrom-Json
$candidate | Add-Member -Force NoteProperty selected_web_export ([ordered]@{
    build_id = $release.build_id
    artifact_directory = $export
    generated_from_commit = '40df5676dcdf4c04ecccf2215e47a0cdffc81916'
    artifacts_total_bytes = $release.artifacts_total_bytes
    root_pck_sha256 = $release.root_pck.sha256
    note = 'Packaging-budget correction reuses unchanged compiled packs; changed character/monster packs and root were rebuilt.'
})
[IO.File]::WriteAllText((Join-Path $project 'runtime_pack_candidates.json'), (($candidate | ConvertTo-Json -Depth 10)+[Environment]::NewLine), [Text.UTF8Encoding]::new($false))
$web = Join-Path $repo 'web'
$previous = Get-Content -LiteralPath (Join-Path $web 'release_manifest.json') -Raw | ConvertFrom-Json
$backup = Join-Path $build 'previous-web'
foreach ($relative in @($previous.artifacts.path)+@('release_manifest.json')) {
    if ($relative -notmatch '^(index\.[^/\\]+|runtime_pack_manifest\.json|release_manifest\.json|packs/[^/\\]+\.pck|engine/[a-f0-9]{24}/index\.[^/\\]+)$') { continue }
    $old = [IO.Path]::GetFullPath((Join-Path $web $relative))
    if (-not $old.StartsWith($web+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Path escapes web' }
    if (-not (Test-Path -LiteralPath $old -PathType Leaf)) { continue }
    $saved = Join-Path $backup $relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $saved) | Out-Null
    Copy-Item -LiteralPath $old -Destination $saved -Force
    if (-not (Test-Path -LiteralPath (Join-Path $export $relative) -PathType Leaf)) { Remove-Item -LiteralPath $old -Force }
}
foreach ($file in Get-ChildItem -LiteralPath $export -File -Recurse) {
    $relative = $file.FullName.Substring($export.Length).TrimStart('\','/')
    $destination = Join-Path $web $relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
}
Write-Output ('PACKAGED: '+$release.build_id+' bytes='+$release.artifacts_total_bytes)
