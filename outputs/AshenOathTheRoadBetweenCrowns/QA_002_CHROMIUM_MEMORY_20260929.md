# QA-002 Chromium Runtime Memory Contract

Status: harness repair and isolated browser preflight only. QA-002 remains
pending; Recovery-004 remains 27/37 accepted.

The prior Chrome/Edge `runtime_memory_mb` value came from CDP's
`JSHeapUsedSize`. That is V8 heap usage, not the Web game's renderer memory:
it omits WASM and other renderer allocations, so it could falsely pass the
450 MB gate. `js_heap_mb` is retained as a diagnostic. The acceptance field
now sums private bytes for all renderer processes owned by the browser's
isolated QA profile. Full owned browser-process private memory remains a
separate diagnostic, not a substitute for tab runtime memory. A missing
renderer or unmeasurable private-byte count fails closed. Firefox retains its
existing isolated content-process upper-bound measurement.

The release harness fingerprint includes all `tools/*.mjs` files, including
the new helper. Old results cannot be resumed under the changed test harness.
The candidate assessor requires the process-memory method, so a historical
V8-heap-only report cannot be promoted to acceptance.

Verification: the targeted Node suites passed 19/19. One isolated WebGL2
`data:` page per browser then exercised live process ownership on the Dell:
Chrome measured 51.1 MB across three renderer processes (213.4 MB across
eight owned browser processes); Edge measured 59.2 MB across three renderer
processes (181.0 MB across eight owned browser processes). These small pages
are a measurement preflight, not Ashen Oath memory, route, or FPS evidence.
No export, source-game change, commit, push, or deployment followed.

The full route still needs source-aligned browser measurements. The current
end-of-route sample is not yet a sustained or peak-memory measurement; that
limitation remains explicit for final certification.
