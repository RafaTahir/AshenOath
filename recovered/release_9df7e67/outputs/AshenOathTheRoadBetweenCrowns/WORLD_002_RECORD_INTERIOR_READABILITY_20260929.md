# WORLD-002 Record Hall Interior Readability (2026-09-29)

Status: retained lighting subcell, not WORLD-002 or PRES-001 acceptance.
Recovery remains 27/37 accepted.

The previous four-light relocation trial left both archive wings nearly black
at night and reduced center-path contrast. This change instead corrects only
the Record Hall's authored interior ambient profile: cooler night ambient
color and energy now remain close to the fixed daytime interior treatment.
Lamp count, placement, range, geometry, materials, actors, routes and quest
state are unchanged.

Direct verification: `verify_light_001.gd` PASS, owned exit 0; full log at
`D:/Temp/AshenOath/world002_record_profile_verify_20260929.log`. The
graphical `capture_pres_001.gd` run produced current 1280x720 day/night views
with the prior camera transforms under
`.release-gate/world002_record_ambient_candidate_20260929/`, plus a report
and full log at
`D:/Temp/AshenOath/world002_record_ambient_capture_20260929.log`. Both frames
were inspected. The night view retains visible bookshelves, side floor and
central route; it is no longer a black-wing room. Interior exposure remains
largely fixed, as authored, rather than tracking outdoor daylight.

This does not address the room's sparse aisle, weak haunting identity, story
or aftermath states, or final browser/performance proof. The staged capture's
HUD state is not a real-route objective acceptance. Those cells remain red.
No Web export, commit, push or deployment occurred.
