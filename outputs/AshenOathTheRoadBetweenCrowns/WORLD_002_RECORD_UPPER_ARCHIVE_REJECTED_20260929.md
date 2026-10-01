# WORLD-002 Record Hall Upper Archive Trial

Verdict: rejected visual candidate. Formal Recovery-004 acceptance remains
27/37. The fixed night ambient correction in `scripts/visual_director.gd`
remains retained; this trial did not change it.

The existing two-surface archive was rebaked with eight upper cabinets, their
48 book groups, two rear banners, and two chandeliers aligned to the existing
light positions. No route collision, interaction, quest state, lamp count or
material family changed. The candidate was 1,858,383 bytes and 99,602
triangles, versus the retained archive's 1,251,143 bytes and 65,170 triangles.

`verify_record_archive.gd` passed the candidate's structural and clearance
contract. `capture_pres_001.gd` captured matching-camera 1280x720 Record Hall
day and night frames with clean owned exit. Both were inspected at
`.release-gate/world002_record_upper_candidate_20260929/`.

The upper bookcases read as detached from the lower archive at gameplay
distance, and the two chandeliers overlap into one oversized central shape.
They consume substantially more triangles without resolving the empty
floor, testimony staging, or weak haunting identity. The candidate therefore
does not satisfy the room-composition cell. All source changes for this trial
were removed. The retained archive was deterministically rebaked and verified
at 1,251,143 bytes, SHA-256
`a46e34a572782c122aef8547caf1fd3e714d128ca35927399d06fa0f88aa39d4`.

Evidence: `D:/Temp/AshenOath/world002_record_upper_bake_20260929.log`,
`world002_record_upper_verify_20260929.log`,
`world002_record_upper_capture_20260929.log`,
`world002_record_restore_bake_20260929.log`, and
`world002_record_restored_verify_20260929.log` under the same D: scratch root.

Next action: park archive-density and light-placement variants. A future
Record Hall pass needs a distinct accepted encounter/story focal asset and
room-scale staging, then same-camera visual and real-input encounter review.
No Web export, commit, push, merge or deployment occurred.
