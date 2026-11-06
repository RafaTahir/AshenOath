"""Check the opt-in adapter against the actual committed engine glue."""

import gzip
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

from web_engine_owned_buffers import MARKER, REPLACEMENTS, enable_owned_pack_buffers

ROOT = Path(__file__).resolve().parents[3]
RELEASE = json.loads((ROOT / "web/release_manifest.json").read_text())
STOCK = gzip.decompress((ROOT / "web" / RELEASE["engine"]["script"]).read_bytes())
if MARKER.encode() in STOCK:
    for original, replacement in reversed(REPLACEMENTS):
        STOCK = STOCK.replace(replacement.encode(), original.encode(), 1)


class OwnedPackBuffers(unittest.TestCase):
    def test_actual_engine_and_idempotence(self):
        patched = enable_owned_pack_buffers(STOCK)
        self.assertIn(MARKER.encode(), patched)
        self.assertEqual(enable_owned_pack_buffers(patched), patched)
        restored = patched.decode()
        for original, replacement in reversed(REPLACEMENTS):
            restored = restored.replace(replacement, original, 1)
        self.assertEqual(restored.encode(), STOCK)

    def test_unknown_glue_fails_closed(self):
        for original, _ in REPLACEMENTS:
            with self.subTest(boundary=original):
                with self.assertRaisesRegex(ValueError, "Unsupported Godot"):
                    enable_owned_pack_buffers(STOCK.replace(original.encode(), b"unknown", 1))

    def test_partial_patch_fails_closed(self):
        patched = enable_owned_pack_buffers(STOCK)
        broken = patched.replace(REPLACEMENTS[1][1].encode(), REPLACEMENTS[1][0].encode())
        with self.assertRaisesRegex(ValueError, "Incomplete"):
            enable_owned_pack_buffers(broken)

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


if __name__ == "__main__":
    unittest.main()
