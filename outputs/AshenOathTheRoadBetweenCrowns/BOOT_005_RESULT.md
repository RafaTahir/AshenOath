# BOOT-005 - Required HUD Assets in the Web Package

In progress. One focused browser session is authorized for startup-to-gameplay.

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
changes packaged here. Final flow result and provider receipt are pending.
