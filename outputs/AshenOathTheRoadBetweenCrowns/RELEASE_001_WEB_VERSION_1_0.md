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
