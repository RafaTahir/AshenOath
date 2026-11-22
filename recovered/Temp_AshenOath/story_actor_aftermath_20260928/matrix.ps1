$ErrorActionPreference = 'Stop'
foreach ($case in @(@('senn','exile',$false),@('senn','punished',$false),@('halvern','released',$false),@('halvern','destroyed',$false),@('senn','exile',$true),@('senn','punished',$true),@('halvern','released',$true),@('halvern','destroyed',$true))) {
    $id = "$($case[0])-$($case[1])" + $(if ($case[2]) {'-reload'} else {''})
    $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',"$PSScriptRoot\run.ps1",'-Group',$case[0],'-Choice',$case[1])
    if ($case[2]) {$args += '-Reload'}
    & 'C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe' @args *> "$PSScriptRoot\$id.wrapper.log"
    if ($LASTEXITCODE -ne 0) {Get-Content "$PSScriptRoot\$id.wrapper.log" -Tail 20; throw "$id failed; downstream not run"}
    Write-Output "$id PASS source-frozen real decision/Continue, ordinary Save/resume and gameplay capture"
}
