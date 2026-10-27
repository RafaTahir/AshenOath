# Web Packaging and Publication

## One Source-Aligned Candidate

Build locally on D: using Godot 4.6.3 and the existing `Web Browser` production
preset. Compile the eight `Runtime Pack` presets, synchronize their identities
with `tools/sync_runtime_pack_manifest.py`, and export with those same manifests.
Base content belongs in the root pack; seven external packs live under `packs/`.
Never delete a required pack to meet a budget.

Use `tools/build_web_runtime_manifest.py` to generate transport metadata and
lossless gzip transport, then `--check-existing` to check the final directory.
`tools/verify_web_export.py` checks completeness. Keep logs and disposable builds
outside the source root in existing D: release/scratch directories. Do not overwrite
historical receipts to make a new candidate appear certified.

`data/deployment_policy.json` owns the budget: strictly less than 268,435,456
deployed bytes, warning at 209,715,200 bytes. Count every deployed file, including
engine, packs, artwork and manifests. Individual Git files stay below 104,857,600
bytes. This is an internal ceiling, not a blanket Vercel hosting guarantee. Keep
transfer bytes, decoded content and runtime memory separate; no content removal
or quality reduction to fit.

## Git Owns Deployment

The repository's `vercel.json` supplies static build/output and response headers.
Synchronize the exact candidate to repository-level `web/`, commit source and
generated identities, push `codex/masterpiece-rebuild`, then advance `main` without
force-pushing or discarding concurrent changes. Existing Vercel Git integration
builds and publishes automatically from `main`.

The 2026-10-27 cleanup remains on development because its recorded integration
and strict-asset checks are red; the candidate and failures remain available for
review without promoting production.

Use `tools/publish_living_road.ps1` with explicit commit paths. No duplicate
`vercel --prod`, CLI static upload or manual promotion. A Git push does not prove
provider deployment completion. Preserve the production origin for browser saves.

Keep content-addressed engine paths, gzip Content-Encoding, JavaScript/WASM MIME
types, immutable engine caching and root/pack invalidation from existing config.
Never publish credentials or local saves. Runtime startup, Continue, audio,
transitions and actual phone input require separate acceptance.
