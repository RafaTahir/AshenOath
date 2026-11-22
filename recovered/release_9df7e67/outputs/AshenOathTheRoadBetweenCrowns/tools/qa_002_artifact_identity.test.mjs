import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { join, resolve, sep } from "node:path";
import test from "node:test";
import { artifactIdentity } from "./qa_002_artifact_identity.mjs";

test("browser reports bind every candidate byte, including packs", () => {
  const root = "D:\\Temp\\AshenOath";
  mkdirSync(root, { recursive: true });
  const directory = mkdtempSync(join(root, "qa002-identity-"));
  try {
    mkdirSync(join(directory, "packs"));
    writeFileSync(join(directory, "index.pck"), "base");
    writeFileSync(join(directory, "packs", "opening.pck"), "opening");
    const first = artifactIdentity(directory);
    assert.equal(first.files.length, 2);
    assert.equal(artifactIdentity(directory).fingerprint, first.fingerprint);
    writeFileSync(join(directory, "packs", "opening.pck"), "changed");
    assert.notEqual(artifactIdentity(directory).fingerprint, first.fingerprint);
    rmSync(join(directory, "index.pck"));
    assert.throws(() => artifactIdentity(directory), /no index.pck/);
  } finally {
    assert.ok(resolve(directory).startsWith(resolve(root) + sep));
    rmSync(directory, { recursive: true, force: true });
  }
});
