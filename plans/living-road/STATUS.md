# Living Road Status

Updated: 2026-10-08. Implementation and user acceptance are separate.
User-accepted tickets: **0/28**. Published tickets: **8/28**. Implemented locally:
**28/28** (including the eight published tickets). LR-028 combined packaging is
complete; publication is pending. Runtime checks
belong to the user. The 2026-10-08 user amendment stops per-ticket pushes and
deployments: LR-009 onward remain local until one combined release after LR-028.
Continue sequential implementation without waiting between tickets.
LR-001 remains published and awaiting user acceptance.
Latest package commit: `d60726623ed20c752fc2cd8b72d292351913edb7`.
Vercel deployment: `dpl_CniSq1Fy5wfxUVP7CFgU8Es3Vrc5`, provider state READY.
Live: https://ashenoath.vercel.app/?v=lr-008-d607266

| Ticket | Work | State |
| --- | --- | --- |
| [LR-001](tickets/LR-001.md) | Baseline and Delivery | published_awaiting_user |
| [LR-002](tickets/LR-002.md) | Two Blades, One Loadout | published_awaiting_user |
| [LR-003](tickets/LR-003.md) | Draw, Sheathe and Interrupt | published_awaiting_user |
| [LR-004](tickets/LR-004.md) | Steel and Oathblade Combat | published_awaiting_user |
| [LR-005](tickets/LR-005.md) | Readable Inventory | published_awaiting_user |
| [LR-006](tickets/LR-006.md) | Knowledge and Preparation | published_awaiting_user |
| [LR-007](tickets/LR-007.md) | Greyfen Services | published_awaiting_user |
| [LR-008](tickets/LR-008.md) | Bracken's Rescue | published_awaiting_user |
| [LR-009](tickets/LR-009.md) | A Companion Who Keeps Up | implemented_local_awaiting_user |
| [LR-010](tickets/LR-010.md) | Earned Companion Bond | implemented_local_awaiting_user |
| [LR-011](tickets/LR-011.md) | Tracking and Wildlife | implemented_local_awaiting_user |
| [LR-012](tickets/LR-012.md) | Resting Places | implemented_local_awaiting_user |
| [LR-013](tickets/LR-013.md) | Human Conversation Rhythm | implemented_local_awaiting_user |
| [LR-014](tickets/LR-014.md) | Promises and Boundaries | implemented_local_awaiting_user |
| [LR-015](tickets/LR-015.md) | Friends in Greyfen | implemented_local_awaiting_user |
| [LR-016](tickets/LR-016.md) | Mira: Care and Closeness | implemented_local_awaiting_user |
| [LR-017](tickets/LR-017.md) | Mira: An Honest Commitment | implemented_local_awaiting_user |
| [LR-018](tickets/LR-018.md) | Vale Before Vargan | implemented_local_awaiting_user |
| [LR-019](tickets/LR-019.md) | Vale: A Future Chosen | implemented_local_awaiting_user |
| [LR-020](tickets/LR-020.md) | Relationships Across the Cast | implemented_local_awaiting_user |
| [LR-021](tickets/LR-021.md) | Greyfen Archery Range | implemented_local_awaiting_user |
| [LR-022](tickets/LR-022.md) | Archery Challenges | implemented_local_awaiting_user |
| [LR-023](tickets/LR-023.md) | Bracken's Field Trial | implemented_local_awaiting_user |
| [LR-024](tickets/LR-024.md) | A Greyfen Gathering | implemented_local_awaiting_user |
| [LR-025](tickets/LR-025.md) | Bell-Eater and Rootbound | implemented_local_awaiting_user |
| [LR-026](tickets/LR-026.md) | Ashwing, Halvern and the Hart | implemented_local_awaiting_user |
| [LR-027](tickets/LR-027.md) | Regions That Remember | implemented_local_awaiting_user |
| [LR-028](tickets/LR-028.md) | Lives After the Covenant | implemented_local_packaging_pending |

LR-009 local package: `lr-009-20261008-companion-travel`, 92,023,442 bytes across
the complete Web directory. Build completed; no runtime testing, push or deployment.
Source provenance: `9a279c44a4a2187740117a842b302eb75b02a5e2` plus working changes.
LR-010 through LR-028 are included in the combined `lr-028-20261008-living-road`
production package: 15 files, 92,124,361 bytes, 12,733,239 bytes below 100 MiB.
Build directory: `.release-gate/LR-028-20261008-final-build`. Compilation and export
completed after explicit type fixes in the activity scripts. No runtime tests.
Next: publish the combined source/package once, then record the provider receipt.
Preserve the Black Dog Contract. Pending user checklists
remain attached to each result. No Recovery-004 certification is
transferred to this package or to future Living Road changes.
