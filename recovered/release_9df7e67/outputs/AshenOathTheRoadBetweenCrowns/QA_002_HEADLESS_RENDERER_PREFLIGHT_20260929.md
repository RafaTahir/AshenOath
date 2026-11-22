# QA-002 Headless Hardware Renderer Preflight

Status: isolated browser capability check only; QA-002 remains pending and
Recovery-004 remains 27/37 accepted.

An isolated `data:` page with a WebGL2 canvas was launched through
`puppeteer-core` using separate D: QA profiles, no game artifact, and no
software-renderer flags. Headless Chrome reported
`ANGLE (Intel, Intel(R) HD Graphics 620 ... Direct3D11 ..., D3D11)`.
Headless Firefox reported
`ANGLE (Intel, Intel(R) HD Graphics 400 Direct3D11 ...), or similar`.
Both exposed `WEBGL_debug_renderer_info` and a non-software renderer string.
The Firefox identity is privacy-coarsened and is not a claim that the Dell's
physical GPU is an HD 400; the native hardware inventory identifies HD 620.

This directly checks the concern that `--renderer hardware` in the headless
release runner is intrinsically incompatible with WebGL2 on this host. It is
not a source-aligned Web build, campaign route, audio, memory, or FPS result.
The QA profiles were created at
`D:/Temp/AshenOath/qa002_chrome_renderer_probe_20260929/` and
`D:/Temp/AshenOath/qa002_firefox_renderer_probe_20260929/`.
The sandbox rejected recursive profile cleanup, so they remain isolated D:
scratch data; no repository or Windows TEMP setting changed.

Next: preserve this capability result and run the one immutable production
candidate browser matrix only after native visual and PERF-001 prerequisites
pass. No export, commit, push, merge, or deployment occurred.
