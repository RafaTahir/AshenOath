import assert from "node:assert/strict";
import test from "node:test";
import { summarizeFirefoxProcesses } from "./firefox_content_memory.mjs";

const MB = 1048576;
const profile = "D:\\Temp\\AshenOath\\qa002-firefox-unique";
const rows = [
  { pid: 100, parent_pid: 1, command_line: `firefox.exe -profile ${profile}`, private_bytes: 90 * MB },
  { pid: 101, parent_pid: 100, command_line: "firefox.exe -contentproc", private_bytes: 180 * MB },
  { pid: 102, parent_pid: 100, command_line: "firefox.exe -gpu", private_bytes: 70 * MB },
  { pid: 200, parent_pid: 1, command_line: "firefox.exe -profile C:\\unrelated", private_bytes: 80 * MB },
  { pid: 201, parent_pid: 200, command_line: "firefox.exe -contentproc", private_bytes: 300 * MB },
];

test("Firefox memory bounds only isolated content processes and records the full owned tree separately", () => {
  const result = summarizeFirefoxProcesses(rows, 100, profile);
  assert.equal(result.method, "isolated_content_process_private_upper_bound");
  assert.equal(result.content_private_mb, 180);
  assert.equal(result.owned_process_private_mb, 340);
  assert.equal(result.owned_process_count, 3);
});

test("Firefox memory fails closed when profile, content process or private bytes are absent", () => {
  assert.throws(() => summarizeFirefoxProcesses(rows, 100, "D:\\Temp\\AshenOath\\missing"), /isolated-profile/);
  assert.throws(() => summarizeFirefoxProcesses(rows.filter((row) => row.pid !== 101), 100, profile), /no owned content process/);
  const zero = rows.map((row) => row.pid === 101 ? { ...row, private_bytes: 0 } : row);
  assert.throws(() => summarizeFirefoxProcesses(zero, 100, profile), /private memory is unavailable/);
});
