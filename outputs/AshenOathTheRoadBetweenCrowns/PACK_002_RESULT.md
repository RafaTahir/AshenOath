# PACK-002 Result - Content-Addressed Release Manifest

Status: accepted on 2026-09-20.

## Delivered

- External pack URLs and cache keys use each pack's SHA-256 digest.
- The exported shell, runtime-pack manifest, root PCK, source commit, complete
  artifact inventory, dependencies, sizes, and hashes are bound by one
  generated `release_manifest.json`.
- The boot shell rejects a release identity or runtime-pack sidecar that does
  not match its embedded build identity.
- Export verification rejects stale shell/release combinations and verifies
  the exact generated artifact graph.

## Verified Candidate

- Build ID: `recovery004-pack002-v109`
- Artifact: `D:\Temp\AshenOath\recovery004_pack002_v109\web`
- Artifact shape: 15 files, 96.5 MB
- Release inventory: 14 hashed artifacts plus `release_manifest.json`
- Root PCK SHA-256:
  `7cb347b9e1c78665573c534d826120cb1611ff23743c3496c2a2880b0c13c656`
- Runtime packs: base, opening, campaign, characters, monsters, audio, and
  quality materials; combined pack payload 56.46 MB.

## Verification

- `tools/verify_runtime_packs.py`: PASS.
- `tools/verify_web_export.py`: PASS against the assembled v109 artifact.
- Shell-build identity tamper: correctly rejected with exit code 1.
- Release-manifest identity tamper: correctly rejected with exit code 1.
- Restored artifact verification: PASS.
- `tools/verify_packed_startup.gd`: PASS; runtime ready in 180 ms and clean
  staged shutdown.

Detailed evidence is under
`D:\Temp\AshenOath\recovery004_pack002_v109`, including
`web_export_report_restored.json`, `tamper_shell_identity.log`,
`tamper_release_identity.log`, and `packed_startup.log`.

## Remaining Scope

`WEB-001` independently owns hardware Chrome/Edge certification of these exact
bytes. PACK-002 does not claim browser-route or live-production acceptance.

## Running Steps

Generate the sidecar for an assembled artifact with:

```powershell
python .\tools\build_web_runtime_manifest.py <web-artifact> `
  --runtime-pack-manifest .\runtime_pack_manifest.json `
  --source-commit <git-sha>
```

Verify it with:

```powershell
python .\tools\verify_web_export.py <web-artifact> `
  --runtime-manifest .\runtime_pack_manifest.json `
  --json-report <report-path>
```
