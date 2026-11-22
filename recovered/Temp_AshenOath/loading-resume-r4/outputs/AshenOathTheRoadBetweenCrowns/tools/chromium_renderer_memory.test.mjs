import assert from 'node:assert/strict';
import test from 'node:test';
import { summarizeChromiumProcesses } from './chromium_renderer_memory.mjs';

const mb = 1048576;
const profile = 'D:\\Temp\\AshenOath\\qa-owned-profile';
const rows = [
  { pid: 10, parent_pid: 1, command_line: `chrome.exe --user-data-dir=${profile}`, private_bytes: 50 * mb },
  { pid: 11, parent_pid: 10, command_line: 'chrome.exe --type=renderer', private_bytes: 210 * mb },
  { pid: 12, parent_pid: 10, command_line: 'chrome.exe --type=gpu-process', private_bytes: 30 * mb },
  { pid: 20, parent_pid: 1, command_line: 'chrome.exe --user-data-dir=D:\\Temp\\elsewhere', private_bytes: 50 * mb },
  { pid: 21, parent_pid: 20, command_line: 'chrome.exe --type=renderer', private_bytes: 400 * mb },
];

test('isolated Chromium renderer memory includes WASM-capable renderer but not unrelated profiles', () => {
  const result = summarizeChromiumProcesses(rows, 10, profile);
  assert.equal(result.method, 'isolated_renderer_process_private_upper_bound');
  assert.equal(result.renderer_private_mb, 210);
  assert.equal(result.renderer_process_count, 1);
  assert.equal(result.owned_process_private_mb, 290);
});

test('missing or unmeasurable renderer cannot pass the memory gate', () => {
  assert.throws(() => summarizeChromiumProcesses(rows, 10, 'D:\\Temp\\missing'), /isolated-profile/);
  assert.throws(() => summarizeChromiumProcesses(rows.filter(row => row.pid !== 11), 10, profile), /no owned renderer/);
  const invalid = structuredClone(rows);
  invalid[1].private_bytes = 0;
  assert.throws(() => summarizeChromiumProcesses(invalid, 10, profile), /unavailable/);
});
