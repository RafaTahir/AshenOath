import { spawnSync } from "node:child_process";

export function summarizeFirefoxProcesses(rows, rootPid, profile) {
  const byPid = new Map(rows.map((row) => [Number(row.pid), row]));
  const profileKey = String(profile).toLowerCase();
  const owned = new Set();
  const profileRows = rows.filter((row) => String(row.command_line || "").toLowerCase().includes(profileKey));
  if (!profileRows.length) throw new Error("Firefox memory measurement found no isolated-profile process");
  if (byPid.has(Number(rootPid))) owned.add(Number(rootPid));
  for (const row of profileRows) owned.add(Number(row.pid));
  for (let changed = true; changed;) {
    changed = false;
    for (const row of rows) {
      if (!owned.has(Number(row.pid)) && owned.has(Number(row.parent_pid))) {
        owned.add(Number(row.pid));
        changed = true;
      }
    }
  }
  const processes = rows.filter((row) => owned.has(Number(row.pid)));
  const content = processes.filter((row) => /(?:^|\s)-contentproc(?:\s|$)/i.test(String(row.command_line || "")));
  if (!content.length) throw new Error("Firefox memory measurement found no owned content process");
  if (content.some((row) => !Number.isFinite(Number(row.private_bytes)) || Number(row.private_bytes) <= 0)) {
    throw new Error("Firefox content-process private memory is unavailable");
  }
  const contentPrivateBytes = content.reduce((sum, row) => sum + Number(row.private_bytes), 0);
  return {
    method: "isolated_content_process_private_upper_bound",
    content_private_mb: Number((contentPrivateBytes / 1048576).toFixed(1)),
    content_process_count: content.length,
    owned_process_private_mb: Number((processes.reduce((sum, row) => sum + Number(row.private_bytes || 0), 0) / 1048576).toFixed(1)),
    owned_process_count: processes.length,
  };
}

export function measureFirefoxContentMemory(rootPid, profile) {
  if (!Number.isInteger(Number(rootPid)) || Number(rootPid) <= 0 || !profile) {
    throw new Error("Firefox memory measurement requires an owned PID and isolated profile");
  }
  const script = [
    "$rows = @(Get-CimInstance Win32_Process -Filter \"Name='firefox.exe'\" | ForEach-Object {",
    "  $process = Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue",
    "  if ($null -ne $process) {",
    "    [pscustomobject]@{ pid = $_.ProcessId; parent_pid = $_.ParentProcessId; command_line = $_.CommandLine; private_bytes = $process.PrivateMemorySize64 }",
    "  }",
    "})",
    "ConvertTo-Json -InputObject $rows -Compress -Depth 3",
  ].join("\n");
  const result = spawnSync("powershell.exe", ["-NoProfile", "-Command", script], {
    encoding: "utf8", windowsHide: true, timeout: 15000, maxBuffer: 1024 * 1024,
  });
  if (result.error || result.status !== 0) {
    throw new Error(`Firefox memory measurement failed: ${result.error?.message || result.stderr?.trim() || result.status}`);
  }
  const rows = JSON.parse(result.stdout);
  return summarizeFirefoxProcesses(Array.isArray(rows) ? rows : [rows], rootPid, profile);
}
