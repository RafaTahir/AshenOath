param([ValidateSet('Import', 'Prepared')][string]$Phase)
$ErrorActionPreference = 'Stop'
$faceProject = 'D:/Temp/af/outputs/AshenOathTheRoadBetweenCrowns'
$faceGodot = 'C:/Users/User/.cache/codex-runtimes/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe'
$faceLogs = 'D:/Temp/af/.release-gate/lower-face-repair-20261111/compilation'
New-Item -ItemType Directory -Path $faceLogs -Force | Out-Null
$faceArguments = @('--headless', '--path', $faceProject)
if ($Phase -eq 'Import') {
    $faceArguments += @('--editor', '--import', '--quit')
} else {
    $faceArguments += @('--script', 'res://tools/build_prepared_actors.gd', '--', '--face-repair-only')
}
$faceStdout = Join-Path $faceLogs ($Phase + '.stdout.log')
$faceStderr = Join-Path $faceLogs ($Phase + '.stderr.log')
$faceProcess = Start-Process -FilePath $faceGodot -ArgumentList $faceArguments -WorkingDirectory $faceProject -WindowStyle Hidden -PassThru -RedirectStandardOutput $faceStdout -RedirectStandardError $faceStderr
Write-Output ('Compiling asset phase {0}; owned PID {1}' -f $Phase, $faceProcess.Id)
$faceProcess.WaitForExit()
$faceProcess.Refresh()
$faceErrors = @(Select-String -LiteralPath @($faceStdout, $faceStderr) -Pattern '(?i)^ERROR:|SCRIPT ERROR:|Failed to load script|Error parsing script')
if ($faceProcess.ExitCode -ne 0 -or $faceErrors.Count -gt 0) {
    Get-Content -LiteralPath $faceStdout -Tail 15
    Get-Content -LiteralPath $faceStderr -Tail 30
    throw ('Asset compilation failed: {0}, exit {1}' -f $Phase, $faceProcess.ExitCode)
}
Write-Output ('Completed asset compilation: ' + $Phase)
