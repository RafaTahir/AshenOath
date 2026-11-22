$ErrorActionPreference = 'Stop'
$base = Join-Path $PSScriptRoot 'v2'
$project = 'D:\Projects\AshenOath\outputs\AshenOathTheRoadBetweenCrowns'
New-Item -ItemType Directory "$base\AppData\Roaming", "$base\AppData\Local", "$base\compile" -Force | Out-Null
$env:APPDATA = "$base\AppData\Roaming"
$env:LOCALAPPDATA = "$base\AppData\Local"
$env:TEMP = "$base\compile"
$env:TMP = "$base\compile"
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class AshenCpuTrace {
  [StructLayout(LayoutKind.Sequential)] public struct FT { public uint lo, hi; public long ticks {get {return ((long)hi<<32)|lo;}} }
  [StructLayout(LayoutKind.Sequential)] public struct IO { public ulong readOps,writeOps,otherOps,readBytes,writeBytes,otherBytes; }
  [StructLayout(LayoutKind.Sequential)] public struct MEM { public uint cb,pageFaults; public UIntPtr peakWorking,working,peakPaged,paged,peakNonpaged,nonpaged,pagefile,peakPagefile; }
  [DllImport("kernel32.dll")] public static extern IntPtr OpenThread(uint rights, bool inherit, uint id);
  [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
  [DllImport("kernel32.dll")] public static extern bool GetThreadTimes(IntPtr h,out FT c,out FT e,out FT k,out FT u);
  [DllImport("kernel32.dll")] public static extern bool GetProcessTimes(IntPtr h,out FT c,out FT e,out FT k,out FT u);
  [DllImport("kernel32.dll")] public static extern bool GetProcessIoCounters(IntPtr h,out IO io);
  [DllImport("psapi.dll")] public static extern bool GetProcessMemoryInfo(IntPtr h,ref MEM mem,uint bytes);
}
'@
$p = $null
$threadHandle = [IntPtr]::Zero
$rows = [Collections.Generic.List[object]]::new()
try {
    $p = Start-Process 'C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe' -WorkingDirectory $project -ArgumentList "--path . --rendering-method gl_compatibility --rendering-driver opengl3_angle --script $PSScriptRoot\trace.gd -- --zone=greyfen" -WindowStyle Hidden -PassThru -RedirectStandardOutput "$base\native.log" -RedirectStandardError "$base\native.err"
    $deadline = [DateTime]::UtcNow.AddSeconds(150)
    while (-not (Test-Path -LiteralPath "$base\header.json") -and -not $p.HasExited -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 20 }
    if (-not (Test-Path -LiteralPath "$base\header.json")) { throw 'Native trace header missing' }
    $header = Get-Content -LiteralPath "$base\header.json" -Raw | ConvertFrom-Json
    $native = Get-Process -Id $header.pid
    if ($native.Id -ne $p.Id -and -not (Get-CimInstance Win32_Process -Filter "ProcessId=$($native.Id)").ParentProcessId.Equals([uint32]$p.Id)) { throw 'Native header does not identify the owned test process' }
    $threadStarts = @()
    foreach ($thread in $native.Threads) {
        $h = [AshenCpuTrace]::OpenThread(0x0040,$false,[uint32]$thread.Id)
        if ($h -eq [IntPtr]::Zero) { continue }
        try {
            $c = [AshenCpuTrace+FT]::new(); $e = [AshenCpuTrace+FT]::new(); $k = [AshenCpuTrace+FT]::new(); $u = [AshenCpuTrace+FT]::new()
            if ([AshenCpuTrace]::GetThreadTimes($h,[ref]$c,[ref]$e,[ref]$k,[ref]$u)) { $threadStarts += [pscustomobject]@{id=$thread.Id;created_ticks=$c.ticks} }
        } finally { [void][AshenCpuTrace]::CloseHandle($h) }
    }
    $ordered = @($threadStarts | Sort-Object created_ticks)
    if ($ordered.Count -lt 1 -or ($ordered.Count -gt 1 -and $ordered[0].created_ticks -eq $ordered[1].created_ticks)) { throw 'Initial native main thread cannot be identified unambiguously' }
    $ordered | Export-Csv -LiteralPath "$base\thread_identity.csv" -NoTypeInformation
    $threadHandle = [AshenCpuTrace]::OpenThread(0x0040,$false,[uint32]$ordered[0].id)
    if ($threadHandle -eq [IntPtr]::Zero) { throw 'Main thread timing access failed' }
    while (-not $native.HasExited -and [DateTime]::UtcNow -lt $deadline) {
        $started = [Diagnostics.Stopwatch]::GetTimestamp()
        $c = [AshenCpuTrace+FT]::new(); $e = [AshenCpuTrace+FT]::new(); $k = [AshenCpuTrace+FT]::new(); $u = [AshenCpuTrace+FT]::new()
        if (-not [AshenCpuTrace]::GetThreadTimes($threadHandle,[ref]$c,[ref]$e,[ref]$k,[ref]$u)) { throw 'Main thread timing failed' }
        $mainTicks = $k.ticks + $u.ticks
        if (-not [AshenCpuTrace]::GetProcessTimes($native.Handle,[ref]$c,[ref]$e,[ref]$k,[ref]$u)) { throw 'Process timing failed' }
        $io = [AshenCpuTrace+IO]::new(); $mem = [AshenCpuTrace+MEM]::new(); $mem.cb = [Runtime.InteropServices.Marshal]::SizeOf($mem)
        if (-not [AshenCpuTrace]::GetProcessIoCounters($native.Handle,[ref]$io)) { throw 'IO timing failed' }
        if (-not [AshenCpuTrace]::GetProcessMemoryInfo($native.Handle,[ref]$mem,$mem.cb)) { throw 'Memory timing failed' }
        $rows.Add([pscustomobject]@{utc_ticks=[DateTime]::UtcNow.Ticks;main_cpu_ticks=$mainTicks;process_cpu_ticks=($k.ticks+$u.ticks);read_bytes=$io.readBytes;other_bytes=$io.otherBytes;page_faults=$mem.pageFaults;working_bytes=$mem.working.ToUInt64();query_ms=([Diagnostics.Stopwatch]::GetTimestamp()-$started)*1000.0/[Diagnostics.Stopwatch]::Frequency})
        Start-Sleep -Milliseconds 20
    }
    if (-not $native.HasExited) { throw 'Owned native trace timed out' }
    $p.WaitForExit(); $p.Refresh()
    $rows | Export-Csv -LiteralPath "$base\cpu.csv" -NoTypeInformation
    Get-Content "$base\native.log" -Tail 7
    Get-Content "$base\native.err" -Tail 12
    Write-Output "Diagnostic captured $($rows.Count) OS samples; child exit $($p.ExitCode). FPS failures remain failures."
} finally {
    if ($threadHandle -ne [IntPtr]::Zero) { [void][AshenCpuTrace]::CloseHandle($threadHandle) }
    if ($p -and -not $p.HasExited) {
        Get-CimInstance Win32_Process | Where-Object ParentProcessId -eq $p.Id | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }
}
