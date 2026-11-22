$ErrorActionPreference='Stop'
foreach($case in @(@('terms',$false),@('report',$false),@('terms',$true),@('report',$true))) {
    $id="anwen-$($case[0])" + $(if($case[1]){'-reload'}else{''})
    $args=@('-NoProfile','-ExecutionPolicy','Bypass','-File',"$PSScriptRoot\run.ps1",'-Choice',$case[0])
    if($case[1]) {$args+='-Reload'}
    & 'C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe' @args *> "$PSScriptRoot\$id.wrapper.log"
    if($LASTEXITCODE -ne 0) {Get-Content "$PSScriptRoot\$id.wrapper.log" -Tail 20; throw "$id failed; downstream not run"}
    Write-Output "$id PASS normal Continue, real focus/E/choice and exact manual-save consequences"
}
