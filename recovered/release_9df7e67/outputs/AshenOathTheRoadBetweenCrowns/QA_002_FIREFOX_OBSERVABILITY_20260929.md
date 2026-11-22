# QA-002 Firefox observation contract (2026-09-29)

Status: harness implementation and isolated live proof, **not** campaign browser acceptance. Formal recovery count remains **27/37**.

The Firefox BiDi route now installs `tools/firefox_audio_context_probe.js` before game navigation. It records real-time AudioContext creation and state changes without forcing autoplay or changing game code. A full campaign must observe a context enter `running` after ordinary input, just as Chrome and Edge must. The candidate assessor rejects an absent Firefox unlock.

Firefox BiDi does not provide CDP's `JSHeapUsedSize`. The harness now reads Windows private bytes for the content processes descended from its own Firefox process and unique QA profile. Their sum is a conservative upper bound for the isolated tab's JavaScript/WASM heap, not a claim to be an exact heap measurement. It also records total owned-process private bytes separately for diagnosis. An absent process, missing measurement, wrong method or bound at/above 450 MB fails the route and candidate assessor. Mozilla's [process model](https://firefox-source-docs.mozilla.org/dom/ipc/process_model.html) identifies content processes as the owners of web content and JS execution.

`tools/release_identity.py` now fingerprints `.js` harness files as well as `.mjs`, so a changed preload probe invalidates resumed browser evidence without invalidating unchanged game bytes.

Proof:

- Node syntax checks pass.
- Focused offline audio, process-isolation, candidate and Firefox transport tests: 18 pass, one intentionally live-only skip, zero fail (`D:/Temp/AshenOath/qa002_firefox_observer_final_20260929.log`).
- The isolated live Firefox BiDi page passed pointer input, read-only observation, a click-created AudioContext reaching `running`, content-process memory collection, screenshot and profile cleanup (`D:/Temp/AshenOath/qa002_firefox_audio_memory_probe_20260929.log`). This was a data URL, not a game export.
- Release-identity dirty-`.js` regression test passes.

The source-aligned production artifact, Firefox game audio unlock, full campaign, memory peak during gameplay, browser console and network state remain untested. Native PERF-001 and world visual gates are still red; no Web export, production push or deployment occurred.
