# BOOT-005 - Required HUD Assets in the Web Package

Implemented, published and verified through one focused startup-to-gameplay browser
session. This is a flow check, not campaign, mobile-device or performance certification.

## Confirmed Cause

The production BOOT-004 browser emitted:
`Parse Error: Preload file "res://assets/icons/iron_trap.svg" does not exist.`
This prevents `hud_emblem.gd`, HUD, runtime services and `game.gd` from compiling
from the PCK. The subsequent WASM memory-access error is secondary. The page's
generic connection message hid this packaging failure. HTTP gzip headers are
present and correct; the deployed page identifies BOOT-004.

## Repair

Explicitly include all six item icons in Web Browser, Runtime Pack Base and Web QA
Browser export resource lists. The trap icon and every item-data icon now share
the required root/base ownership. All other active literal asset preloads were
compared with export declarations as one static pass. No placeholder or fallback
replaces the missing resource.

The bootstrap preserves native errors in the console/boot record and identifies
required-resource failures separately from connection failures. Crow Flight and
the loading page remain removed; saves, settings, mobile controls and content remain.

Files: `export_presets.cfg`, `web_boot_shell.html`, generated Web/pack files,
current project state and this record. One production build/publication follows.

## Focused Verification

The same browser session first captured the precise production failure above.
After replacement publication, reload that session once, activate the actual New
Game button, inspect complete Greyfen and verify ordinary movement. No campaign
suite, second browser/profile, benchmark or unrelated verification is authorized.
The session uses the Codex in-app Chromium browser; iPhone/WebKit is not available
on this Windows host and will remain explicitly untested.

The production build `boot-005-20261008-hud-assets` completed. Whole Web payload:
92,418,628 bytes, below 104,857,600. Static inspection of decoded root-PCK bytes
found all six icon import records and corresponding imported-texture names.
The source scan covered 48 active literal asset preloads with no undeclared paths.

Stored root PCK: 16,374,381 bytes, SHA-256
`abfbdf8c773bc213319c469af8b7f7892b2737cd6282d923b20bac3db94cbd57`.
Decoded root: 19,581,848 bytes, SHA-256
`fa715818ce61c49a5f1f9d0ee3727470f3cf7a55c379b770260fd323cdfa292d`.
Build provenance is `c7adc06035ba5cd7d6dc39aa9bff0876df463b97` plus the working
changes packaged here. Package commit: `ace9604de541658048930107e14d66dbad2ec410`.
Development/main pushes succeeded. The separate CLI deployment returned
`Not authorized`, but GitHub's automatic Vercel deployment published the candidate.
The live release manifest identifies BOOT-005 and a direct download of the live
root PCK matched the local stored SHA-256 and 16,374,381-byte size exactly.
Live: https://ashenoath.vercel.app/?v=boot-005-ace9604
Publication record: `.release-gate/living-road/BOOT-005-20261008T071633Z/publication.json`.

## Flow Result

PASS: the same Codex in-app Chromium session was reloaded after publication; the
native main menu rendered, the real New Game button was clicked, Greyfen appeared
with Kael/buildings/bridge/HUD, and a 1.2-second W-key input moved Kael/camera along
the road. The previous missing-resource compilation failure and WASM crash did not
recur. No telemetry mutation, teleport, manufactured progression or handler call
was used. No second browser/profile or campaign suite was run.

The existing game timer reported click-to-ready 25,296.4 ms and prewarm 24,375 ms:
loading remains slow and no instant-loading/performance compliance is claimed.
Two non-blocking problems were recorded: a GDScript unsupported-format message
during startup and an in-app Chromium UnknownError during pointer capture/movement.
Their exact ownership remains unconfirmed; the flow still completed. This is not a
zero-console-error result. iPhone/WebKit remains untested on this Windows host.

Evidence: `D:/Temp/AshenOath/BOOT-005/flow-result.json` and
`D:/Temp/AshenOath/BOOT-005/greyfen-after-movement.png`. The complete runtime logs
and residual errors are retained there. User visual/UX acceptance remains pending.
