# STREAM-003 Result - Verified Runtime Pack Streaming Lifecycle

## Status

`functional_but_incomplete`

The runtime now has a transactional pack lifecycle while retaining the
embedded-PCK fallback. External packs can download to a temporary user-cache
file, verify their PCK header, expected bytes, and SHA-256, commit atomically,
mount through Godot, and report progress, readiness, failure, cancellation,
and retry states. The current production Web artifact is unchanged.

## Changes

- Rebuilt `RuntimePackManager` around `HTTPRequest`, versioned `user://`
  cache paths, cache metadata, source overrides, and one-at-a-time download
  scheduling.
- Added `pack_cached`, `pack_mounted`, and `pack_cancelled` signals plus
  `get_state`, `get_last_error`, `is_cached`, `get_cache_path`,
  `set_pack_source`, and `retry_pack` APIs.
- Validated local and downloaded artifacts before mounting; failed or partial
  files never become ready and temporary files are removed.
- Preserved empty-URL embedded readiness so the current game remains playable
  before external pack hosting is configured.
- Added `tools/verify_stream_003.gd` and registered it under the streaming
  ticket profile.

## Verification

- Godot 4.6.3 headless startup: PASS, no parser or resource errors.
- `verify_stream_003.gd`: PASS for embedded fallback, queued HTTP request,
  cancellation, missing-file rejection, retry state, budget, and cache API.
- `verify_stream_003.gd` with the clean-room external base PCK:
  PASS for actual bytes/hash validation and `ProjectSettings.load_resource_pack`.
- Existing `verify_stream_001`: PASS.
- Pack candidate manifest and external v4 artifacts: PASS, six packs,
  `80.52 MB` total.
- Targeted PACK-003 gate after the lifecycle changes: PASS for content,
  runtime smoke, pack manifests, Web export, and packed startup.

## Limitations

- The checked-in manifest intentionally has empty production URLs, so normal
  builds continue using embedded content. Hosting and URL wiring belong to
  the next loading/candidate ticket.
- No production Web synchronization, `main` push, or Vercel deployment was
  performed for this development ticket.
- Godot resource packs cannot be unloaded from a running process; retirement
  prevents new references and cancels queued transfers while mounted packs
  remain process-resident by engine design.

## Running Steps

```powershell
cd C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOathTheRoadBetweenCrowns
& C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64.exe `
  --headless --path . --script tools/verify_stream_003.gd
```

To exercise a real local candidate mount, append the external base PCK path
after `--`:

```powershell
& C:\Users\User\.cache\codex-runtimes\godot-4.6.3\Godot_v4.6.3-stable_win64.exe `
  --headless --path . --script tools/verify_stream_003.gd -- `
  C:\Users\User\.cache\codex-runtimes\ashenoath-packs-v4\base.pck
```
