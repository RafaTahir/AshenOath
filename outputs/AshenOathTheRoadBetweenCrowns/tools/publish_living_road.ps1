param(
    [Parameter(Mandatory = $true)][string]$Ticket,
    [Parameter(Mandatory = $true)][string]$Message,
    [Parameter(Mandatory = $true)][string[]]$CommitPaths,
    [string]$PythonPath = "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$RepositoryRoot = [IO.Path]::GetFullPath((Split-Path -Parent (Split-Path -Parent $ProjectRoot)))
if ($RepositoryRoot -ne 'D:\Projects\AshenOath') { throw 'Publish from the canonical D: repository.' }
if ($Ticket -notmatch '^(LR|MOBILE|BOOT|XP|OPT|WORLD-SAGA|FINISH|CAST)-\d{3}$') { throw 'Expected a supported project ticket ID.' }
if (-not $CommitPaths.Count) { throw 'Explicit authored and generated commit paths are required.' }
$WebRoot = Join-Path $RepositoryRoot 'web'
$LinkPath = Join-Path $RepositoryRoot '.vercel/project.json'
if (-not (Test-Path -LiteralPath $LinkPath)) { throw 'Link this D: checkout to the existing ashenoath Vercel project first.' }
$link = Get-Content -LiteralPath $LinkPath -Raw | ConvertFrom-Json
if ($link.projectId -ne 'prj_hJ4rsZ7wOpK7XKVpbqGlMx3VjMSQ') { throw 'Refusing to deploy to a different Vercel project.' }

$RunRoot = Join-Path $RepositoryRoot ('.release-gate/living-road/' + $Ticket + '-' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'))
New-Item -ItemType Directory -Path $RunRoot | Out-Null
$NoHooks = Join-Path $RunRoot 'no-hooks'
New-Item -ItemType Directory -Path $NoHooks | Out-Null
$GitArguments = @('-C', $RepositoryRoot, '-c', "core.hooksPath=$NoHooks")
function Invoke-Git([string[]]$GitArgs) {
    & git @GitArguments @GitArgs
    if ($LASTEXITCODE -ne 0) { throw "Git failed: $($GitArgs[0]); retained checkpoint: $RunRoot" }
}

$branch = (& git -C $RepositoryRoot branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $branch -ne 'codex/masterpiece-rebuild') { throw 'Expected codex/masterpiece-rebuild.' }
foreach ($relative in $CommitPaths) {
    if ($relative -match '[*?]' -or $relative.StartsWith(':') -or [IO.Path]::IsPathRooted($relative)) { throw "Use explicit repository-relative paths: $relative" }
    $absolute = [IO.Path]::GetFullPath((Join-Path $RepositoryRoot $relative))
    if (-not $absolute.StartsWith($RepositoryRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw "Path escapes repository: $relative" }
}
Invoke-Git @('fetch', 'origin')
foreach ($remoteBranch in @('origin/main', 'origin/codex/masterpiece-rebuild')) {
    & git -C $RepositoryRoot merge-base --is-ancestor $remoteBranch HEAD
    if ($LASTEXITCODE -ne 0) { throw "$remoteBranch contains changes that must be integrated before publication." }
}

# Static byte/manifest inspection is part of packaging, not gameplay acceptance.
& $PythonPath (Join-Path $PSScriptRoot 'build_web_runtime_manifest.py') $WebRoot --check-existing
if ($LASTEXITCODE -ne 0) { throw 'Package identity or the shared deployment budget failed; nothing was committed or pushed.' }
$manifest = Get-Content -LiteralPath (Join-Path $WebRoot 'release_manifest.json') -Raw | ConvertFrom-Json
$receipt = [ordered]@{
    ticket = $Ticket
    phase = 'prepared'
    build_id = $manifest.build_id
    artifact_source = $manifest.source
    package_commit = ''
    user_acceptance = 'pending'
    runtime_testing = 'not_run_user_owned'
    production_url = 'https://ashenoath.vercel.app'
    deployment_method = 'git_staged_production'
}
function Save-Receipt {
    [IO.File]::WriteAllText((Join-Path $RunRoot 'publication.json'), (($receipt | ConvertTo-Json -Depth 8) + [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
}
Save-Receipt

function Invoke-PublicationStep([string]$Action) {
    & $PythonPath (Join-Path $PSScriptRoot 'vercel_git_release.py') $Action --receipt (Join-Path $RunRoot 'publication.json')
    if ($LASTEXITCODE -ne 0) { throw "Publication stopped at $Action. Preserve and resume the receipt in $RunRoot; do not rebuild or recommit unchanged bytes." }
}

# Staging is enabled before either Git push. Protected previews remain protected.
Invoke-PublicationStep 'setup'

# Explicit paths include authored source; --only leaves unrelated staged work alone.
Invoke-Git (@('add', '--') + $CommitPaths)
Invoke-Git (@('commit', '--only', '-m', $Message, '--') + $CommitPaths)
Invoke-PublicationStep 'bind'
Invoke-Git @('push', 'origin', 'HEAD:codex/masterpiece-rebuild')
Invoke-PublicationStep 'preview'

# Recheck main after the preview wait; a concurrent change must not be overwritten.
Invoke-Git @('fetch', 'origin', 'main')
& git -C $RepositoryRoot merge-base --is-ancestor origin/main HEAD
if ($LASTEXITCODE -ne 0) { throw 'Main changed during the preview. Preserve this candidate and integrate before continuing.' }
Invoke-Git @('push', 'origin', 'HEAD:main')
Invoke-PublicationStep 'production'
Invoke-PublicationStep 'promote'
$receipt = Get-Content -LiteralPath (Join-Path $RunRoot 'publication.json') -Raw | ConvertFrom-Json
Write-Host "Published $Ticket : $($receipt.package_commit)"
Write-Host "Receipt: $RunRoot/publication.json"
Write-Host 'Runtime/gameplay/listening acceptance belongs to the user and was not executed.'
