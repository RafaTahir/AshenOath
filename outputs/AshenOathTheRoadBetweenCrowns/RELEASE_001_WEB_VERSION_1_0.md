# RELEASE-001 Web Version 1.0 Candidate

## Scope

This release publishes the complete current Web campaign. Android, iOS, and store packages are explicitly deferred.

## Mandatory Gates

- Complete runtime, story, save, input, accessibility, audio, combat, world, and choice suite.
- PERF-003 asset/budget checks and graphical native-720p performance.
- Fresh 1280x720 screenshot suites.
- Seven-file Web export below 100 MB.
- Packed-PCK startup.
- Chrome and Edge launch plus complete campaign traversal.
- Lightweight mobile-Web emulation.
- Local/live PCK hash identity.

## Performance Contract

- Balanced average: at least 32 FPS.
- Balanced 1% low: at least 30 FPS.
- No profiled zone at or below 30 FPS average.
- Warm transition: at most 350 ms.
- Cold transition: at most 900 ms.
- Static memory: below 450 MB.

Final artifact hashes, commit, deployment result, and production URL are recorded by the release report and deployment pipeline.

## Verified Result

- Authoritative release gate: PASS.
- Artifact: seven files, 65.59 MB total, 29.30 MB PCK.
- PCK SHA-256: `d96c15e31c1488a3918aae4686a33a0594a23b61982ee813a91d08c5eb9f2340`.
- Greyfen: 60.00 average / 52.92 FPS 1% low.
- Wychwood: 60.00 average / 57.44 FPS 1% low.
- Wychwood combat: 60.00 average / 47.17 FPS 1% low.
- Castle courtyard: 60.00 average / 57.19 FPS 1% low.
- Record Hall: 60.00 average / 57.44 FPS 1% low.
- Hart Glade: 60.00 average / 56.50 FPS 1% low.
- New Game: 116.52 ms; warm return: 140.56 ms; slowest measured cold transition: 306.98 ms.
- Chrome and Edge completed the full released campaign without console or network errors.
- Mobile-Web emulation passed as a compatibility check; native Android/iOS certification remains deferred.
