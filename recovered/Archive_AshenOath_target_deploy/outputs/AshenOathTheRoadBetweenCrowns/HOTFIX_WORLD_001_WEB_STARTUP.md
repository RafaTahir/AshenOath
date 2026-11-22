# WORLD-001 Web Startup Hotfix

The WORLD-001 source build passed local verifiers, but the selective Web export omitted `scripts/zones/cemetery_section.gd`. The live browser therefore failed while parsing `game.gd` and displayed a black screen.

Both Web export presets now include the cemetery helper explicitly. Acceptance requires the exported build to start in a real browser with no missing-preload or script parse errors.
