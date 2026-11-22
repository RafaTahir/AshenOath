$ErrorActionPreference = 'Stop'
$base = $PSScriptRoot
$project = 'D:\Projects\AshenOath\outputs\AshenOathTheRoadBetweenCrowns'
New-Item -ItemType Directory "$base\AppData\Roaming", "$base\AppData\Local", "$base\compile" -Force | Out-Null
$env:APPDATA = "$base\AppData\Roaming"
$env:LOCALAPPDATA = "$base\AppData\Local"
$env:TEMP = "$base\compile"
$env:TMP = "$base\compile"
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class AshenWorkers {
  [StructLayout(LayoutKind.Sequential)] public struct FT { public uint lo, hi; public long ticks {get {return ((long)hi<<32)|lo;}} }
  [StructLayout(LayoutKind.Sequential)] public struct IO { public ulong readOps,writeOps,otherOps,readBytes,writeBytes,otherBytes; }
  [StructLayout(LayoutKind.Sequential)] public struct MEM { public uint cb,pageFaults; public UIntPtr peakWorking,working,peakPaged,paged,peakNonpaged,nonpaged,pagefile,peakPagefile; }
  [DllImport("kernel32.dll")] public static extern IntPtr OpenThread(uint rights, bool inherit, uint id);
  [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
  [DllImport("kernel32.dll")] public static extern bool GetThreadTimes(IntPtr h,out FT c,out FT e,out FT k,out FT u);
  [DllImport("kernel32.dll")] public static extern bool GetProcessTimes(IntPtr h,out FT c,out FT e,out FT k,out FT u);
  [DllImport("kernel32.dll")] public static extern bool GetProcessIoCounters(IntPtr h,out IO io);
  [DllImport("psapi.dll")] public static extern bool GetProcessMemoryInfo(IntPtr h,ref MEM mem,uint bytes);
  [DllImport("kernel32.dll")] public static extern int GetThreadDescription(IntPtr h,out IntPtr text);
  [DllImport("kernel32.dll")] public static extern IntPtr LocalFree(IntPtr h);
  public static string Name(IntPtr h) { IntPtr text; if(GetThreadDescription(h,out text) < 0) return "unavailable"; try { return Marshal.PtrToStringUni(text) ?? ""; } finally { if(text != IntPtr.Zero) LocalFree(text); } }
}
'@
$p = $null
$native = $null
$rows = [Collections.Generic.List[object]]::new()
$threadRows = [Collections.Generic.List[object]]::new()
$identities = @{}
$modules = @{}
try {
    if (Test-Path -LiteralPath "$base\header.json") { throw 'Refusing to overwrite an existing ownership trace' }
    $p = Start-Process 'C:\Temp\AshenOathGodot4.6.3\Godot_v4.6.3-stable_win64_console.exe' -WorkingDirectory $project -ArgumentList "--path . --rendering-method gl_compatibility --rendering-driver opengl3_angle --script $base\trace.gd -- --zone=greyfen" -WindowStyle Hidden -PassThru -RedirectStandardOutput "$base\native.log" -RedirectStandardError "$base\native.err"
    $null = $p.Handle
    $deadline = [DateTime]::UtcNow.AddSeconds(150)
    while (-not (Test-Path -LiteralPath "$base\header.json") -and -not $p.HasExited -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 20 }
    if (-not (Test-Path -LiteralPath "$base\header.json")) { throw 'Native trace header missing' }
    $header = Get-Content -LiteralPath "$base\header.json" -Raw | ConvertFrom-Json
    $native = Get-Process -Id $header.pid
    $null = $native.Handle
    if ($native.Id -ne $p.Id -and -not (Get-CimInstance Win32_Process -Filter "ProcessId=$($native.Id)").ParentProcessId.Equals([uint32]$p.Id)) { throw 'Trace does not identify the owned process' }
    while (-not $native.HasExited -and [DateTime]::UtcNow -lt $deadline) {
        $started = [Diagnostics.Stopwatch]::GetTimestamp()
        $epoch = [DateTime]::UtcNow.Ticks
        $native.Refresh()
        $c = [AshenWorkers+FT]::new(); $e = [AshenWorkers+FT]::new(); $k = [AshenWorkers+FT]::new(); $u = [AshenWorkers+FT]::new()
        if (-not [AshenWorkers]::GetProcessTimes($native.Handle,[ref]$c,[ref]$e,[ref]$k,[ref]$u)) { if($native.HasExited){break}; throw 'Process CPU read failed' }
        $processCpu = $k.ticks + $u.ticks
        $io = [AshenWorkers+IO]::new(); $mem = [AshenWorkers+MEM]::new(); $mem.cb = [Runtime.InteropServices.Marshal]::SizeOf($mem)
        if (-not [AshenWorkers]::GetProcessIoCounters($native.Handle,[ref]$io)) { if($native.HasExited){break}; throw 'IO read failed' }
        if (-not [AshenWorkers]::GetProcessMemoryInfo($native.Handle,[ref]$mem,$mem.cb)) { if($native.HasExited){break}; throw 'Memory read failed' }
        foreach ($thread in $native.Threads) {
            $h = [AshenWorkers]::OpenThread(0x0040,$false,[uint32]$thread.Id)
            if($h -eq [IntPtr]::Zero){continue}
            try {
                if(-not [AshenWorkers]::GetThreadTimes($h,[ref]$c,[ref]$e,[ref]$k,[ref]$u)){continue}
                $id = "$($thread.Id):$($c.ticks)"
                if(-not $identities.ContainsKey($id)) {
                    $address = $thread.StartAddress.ToInt64()
                    $identities[$id] = [pscustomobject]@{id=$thread.Id;created_ticks=$c.ticks;description=[AshenWorkers]::Name($h);start_address=$address}
                    foreach($module in $native.Modules) {
                        $key = $module.BaseAddress.ToInt64()
                        $modules[$key] = [pscustomobject]@{name=$module.ModuleName;path=$module.FileName;base=$key;bytes=$module.ModuleMemorySize}
                    }
                }
                $state = 'unavailable'; $reason = ''
                try { $state = $thread.ThreadState.ToString(); if($state -eq 'Wait'){$reason=$thread.WaitReason.ToString()} } catch {}
                $threadRows.Add([pscustomobject]@{utc_ticks=$epoch;identity=$id;cpu_ticks=($k.ticks+$u.ticks);state=$state;wait_reason=$reason})
            } finally { [void][AshenWorkers]::CloseHandle($h) }
        }
        $rows.Add([pscustomobject]@{utc_ticks=$epoch;process_cpu_ticks=$processCpu;read_bytes=$io.readBytes;write_bytes=$io.writeBytes;other_bytes=$io.otherBytes;page_faults=$mem.pageFaults;working_bytes=$mem.working.ToUInt64();private_bytes=$mem.pagefile.ToUInt64();query_ms=([Diagnostics.Stopwatch]::GetTimestamp()-$started)*1000.0/[Diagnostics.Stopwatch]::Frequency})
        Start-Sleep -Milliseconds 50
    }
    if(-not $native.HasExited){throw 'Owned worker trace timed out'}
    $p.WaitForExit(); $p.Refresh()
    $rows | Export-Csv -LiteralPath "$base\process.csv" -NoTypeInformation
    $threadRows | Export-Csv -LiteralPath "$base\threads.csv" -NoTypeInformation
    $identities.Values | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$base\identities.json"
    $modules.Values | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$base\modules.json"
    [pscustomobject]@{owned_pid=$native.Id;child_exit=$p.ExitCode;samples=$rows.Count;thread_samples=$threadRows.Count;scope='diagnostic_not_benchmark';no_thread_suspension=$true;no_gpu_timers=$true} | ConvertTo-Json | Set-Content -LiteralPath "$base\ownership.json"
    Get-Content "$base\native.log" -Tail 5
    Get-Content "$base\native.err" -Tail 8
    Write-Output "Worker diagnostic collected $($rows.Count) samples, $($identities.Count) thread identities; owned child exit=$($p.ExitCode). Not benchmark acceptance."
    if($p.ExitCode -ne 0){exit 1}
} finally {
    if($p -and -not $p.HasExited) {
        Get-CimInstance Win32_Process | Where-Object ParentProcessId -eq $p.Id | ForEach-Object {Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue}
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }
}
