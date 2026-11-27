"""Check the opt-in adapter against the actual committed engine glue."""

import gzip
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

from web_engine_owned_buffers import (
    BUFFER_REPLACEMENTS, MAIN_PACK_MARKER, MAIN_PACK_REPLACEMENTS, MARKER,
    REPLACEMENTS, enable_owned_pack_buffers,
)

ROOT = Path(__file__).resolve().parents[3]
WEB = Path(os.environ.get("ASHENOATH_TEST_WEB_ROOT", ROOT / "web"))
RELEASE = json.loads((WEB / "release_manifest.json").read_text())
STOCK = gzip.decompress((WEB / RELEASE["engine"]["script"]).read_bytes())
if MARKER.encode() in STOCK:
    for original, replacement in reversed(REPLACEMENTS):
        STOCK = STOCK.replace(replacement.encode(), original.encode(), 1)


class OwnedPackBuffers(unittest.TestCase):
    def test_actual_engine_and_idempotence(self):
        patched = enable_owned_pack_buffers(STOCK)
        self.assertIn(MARKER.encode(), patched)
        self.assertIn(MAIN_PACK_MARKER.encode(), patched)
        self.assertEqual(enable_owned_pack_buffers(patched), patched)
        restored = patched.decode()
        for original, replacement in reversed(REPLACEMENTS):
            restored = restored.replace(replacement, original, 1)
        self.assertEqual(restored.encode(), STOCK)

    def test_unknown_glue_fails_closed(self):
        for original, _ in REPLACEMENTS:
            with self.subTest(boundary=original):
                candidate = STOCK
                if original.encode() not in candidate:
                    for old, replacement in BUFFER_REPLACEMENTS:
                        candidate = candidate.replace(old.encode(), replacement.encode(), 1)
                with self.assertRaisesRegex(ValueError, "Unsupported Godot"):
                    enable_owned_pack_buffers(candidate.replace(original.encode(), b"unknown", 1))

    def test_previous_owned_adapter_upgrades_without_changing_default_semantics(self):
        legacy = STOCK
        for original, replacement in BUFFER_REPLACEMENTS:
            legacy = legacy.replace(original.encode(), replacement.encode(), 1)
        self.assertEqual(enable_owned_pack_buffers(STOCK), enable_owned_pack_buffers(legacy))

    def test_partial_patch_fails_closed(self):
        patched = enable_owned_pack_buffers(STOCK)
        broken = patched.replace(REPLACEMENTS[1][1].encode(), REPLACEMENTS[1][0].encode())
        with self.assertRaisesRegex(ValueError, "Incomplete"):
            enable_owned_pack_buffers(broken)
        broken_main = patched.replace(MAIN_PACK_REPLACEMENTS[0][1].encode(), MAIN_PACK_REPLACEMENTS[0][0].encode())
        with self.assertRaisesRegex(ValueError, "Incomplete"):
            enable_owned_pack_buffers(broken_main)

    def test_packaging_round_trip_and_repeated_build(self):
        from build_web_runtime_manifest import compress_engine_script
        with tempfile.TemporaryDirectory(prefix="owned-pack-build-", dir=ROOT.parent) as scratch:
            script = Path(scratch) / "index.js"
            script.write_bytes(STOCK)
            compress_engine_script(script)
            first = script.read_bytes()
            self.assertEqual(gzip.decompress(first), enable_owned_pack_buffers(STOCK))
            compress_engine_script(script)
            self.assertEqual(script.read_bytes(), first)

    def test_real_glue_parses_and_transfers_only_when_explicit(self):
        script = r"""
const assert = require('node:assert/strict'), vm = require('node:vm'), fs = require('node:fs');
const source = fs.readFileSync(0, 'utf8');
new vm.Script(source);
const start = source.indexOf('copy_to_fs:function(path,buffer,takeOwnership){');
const end = source.indexOf('}};var GodotOS=', start);
assert(start >= 0 && end > start);
let stored, options;
const FS = { stat() {}, mkdirTree() {}, writeFile(path, bytes, flags) {
  options = flags;
  stored = flags.canOwn ? bytes : bytes.slice();
} };
const fn = vm.runInNewContext('({' + source.slice(start, end + 1) + '}).copy_to_fs',
  { FS, Uint8Array, GodotFS: { ENOENT: 44 }, GodotRuntime: { error: assert.fail } });
for (const owned of [undefined, false, true, 1]) {
  const bytes = new Uint8Array([71, 68, 80, 67, 9]);
  fn('/verified.pck', bytes.buffer, owned);
  assert.equal(options.canOwn, owned === true);
  assert.deepEqual([...stored], [...bytes]);
  assert.equal(stored.buffer === bytes.buffer, owned === true);
  if (owned !== true) { bytes[0] = 0; assert.equal(stored[0], 71); }
}
const publicStart = source.indexOf('copyToFS: function (path, buffer, takeOwnership) {');
const publicEnd = source.indexOf('\n\t\t\t},', publicStart);
assert(publicStart >= 0 && publicEnd > publicStart);
const method = vm.runInNewContext('({' + source.slice(publicStart, publicEnd + 5) + '}).copyToFS');
let forwarded;
for (const value of [undefined, false, true, 1]) {
  method.call({ rtenv: { copyToFS: (...args) => forwarded = args } }, '/p', new ArrayBuffer(4), value);
  assert.equal(forwarded[2], value === true);
}
assert.throws(() => method.call({ rtenv: null }, '/p', new ArrayBuffer(4)), /inited/);
console.log('OWNED PACK GLUE: PASS (default copies, explicit ownership, full engine syntax)');
"""
        result = subprocess.run(["node", "-e", script], input=enable_owned_pack_buffers(STOCK),
                                capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr.decode())

    def test_actual_preloader_only_transfers_private_network_main_pack(self):
        script = r"""
const assert = require('node:assert/strict'), vm = require('node:vm'), fs = require('node:fs');
const source = fs.readFileSync(0, 'utf8');
const preloadStart = source.indexOf('const Preloader =');
const preloadEnd = source.indexOf('\n/**', preloadStart);
assert(preloadStart >= 0 && preloadEnd > preloadStart);
const Preloader = vm.runInNewContext(source.slice(preloadStart, preloadEnd) + '; Preloader;', { ArrayBuffer, Uint8Array });
const start = source.indexOf('\t\t\tstart: function (override) {');
const end = source.indexOf('\n\t\t\t},', start);
assert(start >= 0 && end > start);
(async () => {
  for (const mainPack of ['', 'custom-main.pck']) {
    const preloader = new Preloader();
    const root = mainPack || 'index.pck';
    const network = new Uint8Array([71,68,80,67,9]).buffer;
    preloader.loadPromise = () => Promise.resolve(network);
    await preloader.preload('/download-root', root);
    await preloader.preload('/other-url', 'other.bin');
    const caller = new Uint8Array([71,68,80,67,1]).buffer;
    const view = new Uint8Array([3,4,5,6]).subarray(1,3);
    await preloader.preload(caller, root);
    await preloader.preload(view, root);
    assert.equal(preloader.preloadedFiles[0].ashenPrivateNetworkBuffer, true);
    assert.equal(preloader.preloadedFiles[2].ashenPrivateNetworkBuffer, undefined);
    assert.equal(preloader.preloadedFiles[3].ashenPrivateNetworkBuffer, undefined);
    const calls = [];
    let ran = false;
    const method = vm.runInNewContext('({' + source.slice(start, end + 5) + '}).start', { preloader, initPromise: null });
    await method.call({
      config: { update() {}, getGodotConfig() { return {}; }, mainPack, executable: 'index', gdextensionLibs: [], args: [] },
      init() { return Promise.resolve(); }, installServiceWorker() {},
      rtenv: { initConfig() {}, copyToFS(path, buffer, owned) { calls.push({path, buffer, owned}); },
        callMain() { assert.equal(preloader.preloadedFiles.length, 0); ran = true; } },
    });
    assert.equal(ran, true);
    assert.equal(calls.length, 4);
    assert.equal(calls[0].owned, true);
    assert.equal(calls[0].buffer, network);
    assert.equal(calls[1].owned, false); // Network data outside the main pack keeps copying.
    assert.equal(calls[2].owned, false); // Caller data at the same root path keeps copying.
    assert.equal(calls[3].owned, false); // Caller views also keep copying.
    assert.equal(calls[2].buffer, caller);
    assert.equal(calls[3].buffer, view);
  }
  console.log('OWNED MAIN PACK: PASS (actual network preloader, caller isolation, record cleanup)');
})().catch(error => { console.error(error); process.exitCode = 1; });
"""
        result = subprocess.run(["node", "-e", script], input=enable_owned_pack_buffers(STOCK), capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr.decode())


if __name__ == "__main__":
    unittest.main()
