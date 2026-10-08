# LR-013 - Human Conversation Rhythm

Status: implemented_local_awaiting_user. Source-only changes; build, push and
deployment remain deferred to the final combined release.

## Implemented

- Retained the existing short, speakable Anwen/Rook/Mira/Tor exchanges, their
  ordered pages, choices, topic navigation, history and authoritative subtitles.
  No campaign rewrite, dialogue ID migration or new voice service.
- Held compositions across consecutive same-speaker turns. Rapid advancement
  does not retrigger camera movement; a new framing beat waits for at least
  900 ms between moves, without delaying text, input or decisions.
- Dialogue now remembers and restores prior yaw, pitch, zoom and manual orbit,
  including first-person return and Kael visibility. Existing reduced-motion
  composition, collision-aware framing and 360-degree gameplay camera remain.
- Restaging releases the previous facing/performance owner before locking the
  next speaker. Paired face/animation cleanup is idempotent. Actor positions and
  grounding remain untouched; Anwen's stable approach behavior is preserved.
- Page advancement cancels pending/playing speech immediately. Exact-text,
  approved offline voice mappings use a brief 80-450 ms reaction pause before
  playback. History pauses the pending delay; leaving/skipping clears it. The
  old voice's existing short fade finishes before a replacement starts.
- Missing or unapproved recordings remain subtitles. Timing cannot select a
  choice, advance an objective or silently consume a dialogue page.
- Removed the old post-display scene-wide voice restart that cancelled the
  authoritative page recording (including when the legacy voice list was empty).

## Files And Review

`scripts/camera_controller.gd`, `scripts/dialogue_runtime_coordinator.gd`,
`scripts/story_performance.gd`, `scripts/audio_manager.gd`, `scripts/hud.gd`,
`scripts/game.gd`, and the project/status/ticket/result records. Static review covered actor/camera
ownership, normal and interrupted close paths, voice identity and queued playback.
No game, browser, compiler, QA, screenshots or listening run was launched.

## Unverified

UNVERIFIED - REQUIRES USER TESTING: actual camera framing and return, audio
timing, facing, rapid input, long-subtitle layout and controller focus. Final
compilation remains deferred; implementation does not claim runtime approval.

## Manual Test Checklist

1. Approach Anwen and another speaker from different angles. Converse in third
   and first person, then leave; check original zoom/orbit, body and movement.
2. Advance quickly, open History/topics, interrupt and re-enter. Check the full
   text remains available, choices are unchanged and old speech never resumes.
3. Read a longer passage at 720p and larger subtitle scale using controller
   focus. Save/Continue mid-quest and verify the current conversational state.
