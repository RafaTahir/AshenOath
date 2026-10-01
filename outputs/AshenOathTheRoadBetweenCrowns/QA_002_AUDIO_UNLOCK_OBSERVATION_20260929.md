# QA-002 / AUDIO-001 Web Audio observation

Status: implementation and offline tests pass; browser audio acceptance remains pending.
Formal Recovery-004 acceptance is 27/37.

The Chrome/Edge QA route and generic Web smoke harness previously launched with
`--autoplay-policy=no-user-gesture-required`. That flag could make an audio test
pass even when an ordinary player could not unlock the game mix. Both harnesses
now use the browser's default gesture policy. The QA route enables CDP WebAudio
before game navigation, records context creation/state changes, and requires a
real-time context to reach `running` during a full campaign. The report retains
the state timeline and an explicit unlock status. Firefox BiDi has no equivalent
CDP observation in this driver and is reported as unobserved, never passed.

Focused test: `node --test tools/verify_qa_002_audio_unlock.test.mjs`: 3 passed.
Affected offline QA suite: 99 passed, one live-only skipped, zero failed.
Full log: `D:/Temp/AshenOath/qa002_offline_audio_unlock_20260929.log`.

This proves the harness no longer suppresses the gesture requirement. It does
not prove audible quality, browser playback, volume persistence, or a campaign
route. Next: on the same source-aligned production-preset candidate, use the
real-input Chrome and Edge route to observe Web Audio running after interaction;
collect audio state, pause and volume persistence alongside the shared QA matrix.
Do not export while native performance and visual prerequisites are red.
