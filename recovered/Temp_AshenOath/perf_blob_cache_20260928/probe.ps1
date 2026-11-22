param([ValidateSet('baseline','disabled')][string[]]$Cases=@('baseline','disabled'))
$ErrorActionPreference='Stop'
foreach($case in $Cases) {
    $profile=Join-Path $PSScriptRoot "probe-$case"
    if(Test-Path -LiteralPath $profile) {throw 'Never overwrite completed probe'}
    New-Item -ItemType Directory "$profile\AppData\Roaming","$profile\AppData\Local","$profile\Temp" -Force | Out-Null
    $env:APPDATA="$profile\AppData\Roaming"
    $env:LOCALAPPDATA="$profile\AppData\Local"
    $env:TEMP="$profile\Temp"
    $env:TMP="$profile\Temp"
    if($case -eq 'disabled') {
        $env:ANGLE_FEATURE_OVERRIDES_ENABLED='disableProgramCaching'
        $env:ANGLE_FEATURE_OVERRIDES_DISABLED='cacheCompiledShader'
    } else {
        Remove-Item Env:\ANGLE_FEATURE_OVERRIDES_ENABLED,Env:\ANGLE_FEATURE_OVERRIDES_DISABLED -ErrorAction SilentlyContinue
    }
    $p=$null
    try {
        $p=Start-Process 'C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe' -ArgumentList "--path $PSScriptRoot\probe --rendering-method gl_compatibility --rendering-driver opengl3_angle --script $PSScriptRoot\probe\cache_probe.gd" -WindowStyle Hidden -PassThru -RedirectStandardOutput "$PSScriptRoot\probe-$case.log" -RedirectStandardError "$PSScriptRoot\probe-$case.err"
        $null=$p.Handle
        if(-not $p.WaitForExit(30000)) {throw 'Owned minimal cache probe timeout'}
        $p.Refresh()
        Get-Content "$PSScriptRoot\probe-$case.log" -Tail 4
        if($p.ExitCode -ne 0 -or (Get-Content "$PSScriptRoot\probe-$case.err" -Raw) -match '(?m)^ERROR:|^SCRIPT ERROR:|leaked') {Get-Content "$PSScriptRoot\probe-$case.err"; throw 'Minimal cache/render proof failed'}
        $files=@(Get-ChildItem -LiteralPath "$profile\AppData\Roaming" -Recurse -File | Where-Object FullName -Match 'shader_cache[\\/]EGL[\\/]')
        [pscustomobject]@{case=$case;exit=$p.ExitCode;egl_files=$files.Count;egl_bytes=($files|Measure-Object Length -Sum).Sum}|ConvertTo-Json -Compress
        if(($case -eq 'baseline' -and $files.Count -eq 0) -or ($case -eq 'disabled' -and $files.Count -ne 0)) {throw 'Cache control did not demonstrate expected callback behavior'}
    } finally {
        if($p -and -not $p.HasExited) {Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue}
    }
}
