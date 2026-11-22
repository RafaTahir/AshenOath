param([ValidateSet('contract','candidate','candidate4')][string]$Mode = 'contract')
$ErrorActionPreference = 'Stop'
$source = 'D:\Projects\AshenOath\outputs\AshenOathTheRoadBetweenCrowns'
$project = Join-Path $PSScriptRoot 'project'
foreach ($name in @('assets','assets_external','data','scenes','scripts','tools','.godot')) {
    $target = Join-Path $source $name
    $link = Join-Path $project $name
    if (Test-Path -LiteralPath $link) {
        $item = Get-Item -LiteralPath $link
        if ($item.LinkType -ne 'Junction' -or [string]$item.Target -ne $target) { throw "Unexpected fixture link: $link" }
    } else { New-Item -ItemType Junction -Path $link -Target $target | Out-Null }
}
Copy-Item -LiteralPath "$source\project.godot", "$source\export_presets.cfg" -Destination $project
Get-ChildItem -LiteralPath $source -File -Filter '*.json' | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $project }
$profile = Join-Path $PSScriptRoot "profile-$Mode"
New-Item -ItemType Directory "$profile\AppData\Roaming", "$profile\AppData\Local", "$profile\Temp" -Force | Out-Null
$env:APPDATA = "$profile\AppData\Roaming"
$env:LOCALAPPDATA = "$profile\AppData\Local"
$env:TEMP = "$profile\Temp"
$env:TMP = "$profile\Temp"
if (Test-Path -LiteralPath "$PSScriptRoot\$Mode.log") { throw 'Do not overwrite existing experiment evidence' }
$arguments = if ($Mode -eq 'contract') { "--headless --path . --script $PSScriptRoot\light_contract.gd" } else { '--path . --rendering-method gl_compatibility --rendering-driver opengl3_angle --script res://tools/verify_perf_001.gd -- --zone=greyfen' }
$p = $null
try {
    $p = Start-Process 'C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe' -WorkingDirectory $project -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "$PSScriptRoot\$Mode.log" -RedirectStandardError "$PSScriptRoot\$Mode.err"
    $null = $p.Handle
    if (-not $p.WaitForExit(150000)) { throw "Owned $Mode timed out" }
    $p.Refresh()
    Get-Content "$PSScriptRoot\$Mode.log" -Tail 8
    Get-Content "$PSScriptRoot\$Mode.err" -Tail 14
    Write-Output "Owned $Mode exit=$($p.ExitCode)"
    if ($p.ExitCode -ne 0 -or (Get-Content "$PSScriptRoot\$Mode.err" -Raw) -match '(?m)^ERROR:|^SCRIPT ERROR:|ObjectDB instances leaked') { exit 1 }
} finally {
    if ($p -and -not $p.HasExited) {
        Get-CimInstance Win32_Process | Where-Object ParentProcessId -eq $p.Id | ForEach-Object {Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue}
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }
}
