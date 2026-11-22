# QA-002 Mobile Browser Selector Repair

Status: offline release-tooling correction. QA-002 and Recovery-004 acceptance
remain pending at 27/37.

The release runner's three `verify_web_002_mobile` paths requested
`--browser all`, but the driver explicitly rejects Firefox mobile emulation.
That made the milestone mobile gate deterministically fail after potentially
long Chrome and Edge runs. The driver now has `--browser chromium`, which
requires both Chrome and Edge and excludes Firefox. Unsupported `--mobile`
with `--browser all` or `firefox` fails before any browser launches. The
ordinary ticket runner uses the same selection and requests hardware WebGL.

Focused candidate/wiring tests: 16/16 pass, including the deliberate
unsupported-selector failure. Both affected PowerShell scripts parse; the
targeted diff passes whitespace validation. No game source, export, browser
route, result threshold, or production artifact changed.

Next: keep the final browser candidate blocked on native PERF-001 and visual
acceptance. Then use one immutable production export for desktop
Chrome/Edge/Firefox and mobile Chrome/Edge. No commit, push, merge, or
deployment occurred.
