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
if ($Ticket -notmatch '^(LR|MOBILE)-\d{3}$') { throw 'Expected a Living Road or mobile repair ticket ID.' }
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
if ($LASTEXITCODE -ne 0) { throw 'Package identity or the 100 MiB budget failed; nothing was committed or pushed.' }
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
    deployment_log = (Join-Path $RunRoot 'vercel.log')
}
function Save-Receipt {
    [IO.File]::WriteAllText((Join-Path $RunRoot 'publication.json'), (($receipt | ConvertTo-Json -Depth 8) + [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
}
Save-Receipt

# Explicit paths include authored source; --only leaves unrelated staged work alone.
Invoke-Git (@('add', '--') + $CommitPaths)
Invoke-Git (@('commit', '--only', '-m', $Message, '--') + $CommitPaths)
$receipt.package_commit = (& git -C $RepositoryRoot rev-parse HEAD).Trim()
$receipt.phase = 'committed'
Save-Receipt
Invoke-Git @('push', '--atomic', 'origin', 'HEAD:codex/masterpiece-rebuild', 'HEAD:main')
$receipt.phase = 'pushed'
Save-Receipt

# Upload only the committed static site; source assets and diagnostics stay local.
$SiteRoot = Join-Path $RunRoot 'site'
New-Item -ItemType Directory -Path $SiteRoot | Out-Null
$archive = Join-Path $RunRoot 'site.zip'
Invoke-Git @('archive', '--format=zip', "--output=$archive", 'HEAD', 'web', 'vercel.json')
Expand-Archive -LiteralPath $archive -DestinationPath $SiteRoot
New-Item -ItemType Directory -Path (Join-Path $SiteRoot '.vercel') | Out-Null
Copy-Item -LiteralPath $LinkPath -Destination (Join-Path $SiteRoot '.vercel/project.json')

$PriorTemp = $env:TEMP
$PriorTmp = $env:TMP
$PriorNpmCache = $env:npm_config_cache
try {
    $env:TEMP = 'D:\Temp\AshenOath'
    $env:TMP = $env:TEMP
    $env:npm_config_cache = Join-Path $env:TEMP 'npm-cache'
    New-Item -ItemType Directory -Force -Path $env:npm_config_cache | Out-Null
    Push-Location $SiteRoot
    try {
        & npx.cmd --yes vercel --prod --yes 2>&1 | Tee-Object -FilePath $receipt.deployment_log
        if ($LASTEXITCODE -ne 0) { throw "Vercel failed; pushed commit and exact site are retained at $RunRoot. Resume deployment from site, without recommitting." }
    } finally { Pop-Location }
} finally {
    $env:TEMP = $PriorTemp
    $env:TMP = $PriorTmp
    $env:npm_config_cache = $PriorNpmCache
}
$receipt.phase = 'published_awaiting_user'
Save-Receipt
Write-Host "Published $Ticket : $($receipt.package_commit)"
Write-Host "Receipt: $RunRoot/publication.json"
Write-Host 'Runtime/gameplay/listening acceptance belongs to the user and was not executed.'
