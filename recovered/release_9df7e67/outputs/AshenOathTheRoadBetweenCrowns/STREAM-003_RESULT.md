# STREAM-003 Result - Verified Runtime Pack Streaming Lifecycle

## Status

`verified`

The runtime now has a transactional pack lifecycle while retaining the
embedded-PCK fallback. External packs can download to a temporary user-cache
file, verify their PCK header, expected bytes, and SHA-256, commit atomically,
mount through Godot, and report progress, readiness, failure, cancellation,
and retry states. The current Milestone-A Web candidate mounts the relative
streamed packs while retaining the embedded base fallback.

## Changes

- Rebuilt `RuntimePackManager` around `HTTPRequest`, versioned `user://`
  cache paths, cache metadata, source overrides, and one-at-a-time download
  scheduling.
- Added `pack_cached`, `pack_mounted`, and `pack_cancelled` signals plus
  `get_state`, `get_last_error`, `is_cached`, `get_cache_path`,
  `set_pack_source`, and `retry_pack` APIs.
- Validated local and downloaded artifacts before mounting; failed or partial
  files never become ready and temporary files are removed.
- Preserved embedded readiness as a fallback while the candidate manifest
  resolves streamed pack URLs relative to the Web export.
- Added `tools/verify_stream_003.gd` and registered it under the streaming
  ticket profile.

## Verification

- Godot 4.6.3 headless startup: PASS, no parser or resource errors.
- `verify_stream_003.gd`: PASS for embedded fallback, queued HTTP request,
  cancellation, missing-file rejection, retry state, budget, and cache API.
- `verify_stream_003.gd` with the clean-room external base PCK:
  PASS for actual bytes/hash validation and `ProjectSettings.load_resource_pack`.
- Existing `verify_stream_001`: PASS.
- Pack candidate manifest and external artifacts: PASS, six packs,
  `55,217,080` bytes total.
- Targeted PACK-003 gate after the lifecycle changes: PASS for content,
  runtime smoke, pack manifests, Web export, and packed startup.

## Limitations

- The candidate manifest uses relative URLs beside the Web export; an embedded
  base PCK remains available when a streamed pack cannot be reached.
- Production synchronization, `main` push, and Vercel deployment are handled
  once at the Milestone-A boundary.
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
