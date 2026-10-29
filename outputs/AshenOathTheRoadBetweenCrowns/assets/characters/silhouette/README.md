# Character Silhouettes

## Ownership

`character_role_spec.gd` owns anatomical ratios and idle posture. The additive
`systems/character_silhouette.gd` modifier is first in the skeleton's modifier
order, before gaze, facial acting, work poses and hand solvers. It changes spine
length, shoulder locations and native head scale without editing shared meshes,
skins, animation clips, rests, actor roots, collision bodies or saved state.

Rest posture fades out for movement, dialogue, work and protected actions. The
proportion offsets remain. Existing driver suspension also suspends modifiers;
no separate per-frame actor scan or competing animation clock is introduced.

| Archetype | Shoulders | Head | Torso | Hunch | Rest posture | Shape layers |
|---|---:|---:|---:|---:|---|---|
| Blacksmith | 1.25 | 0.98 | 0.92 | 10 degrees | worked | Two-part apron, stowed/working hammer |
| Ranger | 0.85 | 1.08 | 1.04 | 5 degrees | coiled | Cloak, hip satchel |
| Cleric | 0.90 | 1.12 | 0.94 | 16 degrees | weary | Native clothing and existing staff; no added hood/mantle |
| Guard | 1.18 | 0.88 | 1.08 | 0 degrees | guarded | Helmet, two shoulder pads |

Nobles, workers and scholars have additional bounded profiles. Ordinary crowds
use the neutral profile. Kael keeps his existing anatomy and equipment. Monsters,
the actual Hart and non-humanoid rigs are excluded. All six supported postures
are explicit in the role specification.

## Retained Assets And Materials

`tools/build_silhouette_layers.py` extracts original Quaternius OBJ groups and
fits them in metres. `provenance.json` records source hashes, group selection,
cloth/hood cuts and exact generated geometry. The working apron adapts the
retained cloak cloth; the hood excludes Monk's separate face. No extra face,
replacement body, downloaded model or duplicate texture is introduced.

The retained hood mesh is no longer attached to clerics. Opening its front did
not resolve the unwanted rear shell reported by the user. Both that hood and
the added mantle are removed from this role; native heads, hair, clothing and
staffs remain. Reconfiguration also removes obsolete silhouette-owned layers.
Other roles retain their own cloak/mantle recipes. The mesh stays in the asset
library, not on Anwen or pilgrims.

Layers use BoneAttachment3D on actual chest, head, shoulder and hip bones.
The smith's stowed hammer yields to the existing held work hammer. Anwen and
pilgrims retain their authoritative staff socket. Body and shape culling extend
to at least 28 m so a 20 m review cannot show floating equipment without bodies.

`data/palettes.json` is the current wardrobe palette authority: six regional
bases, natural retained skin/hair, and exactly one reserved accent per named
person. Crowds have no accent. Existing keepsakes carry the named accent;
large clothing/accessory surfaces use regional bases. Kael/Anwen's A-set atlases
are preserved. The regional shader changes only the clothing tile of other
Universal atlases, retaining face/hair/eye texels and texture detail. Material
recovery recognizes this exact shader and still requires its bound atlas.

## User-Run Mask Review

The focused 2026-10-29 front/side/rear character captures do not establish
20 m role-mask acceptance. When authorized, run the following from the project
using a graphical Compatibility renderer:

```powershell
& 'D:\Temp\AshenOath\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --path . --rendering-method gl_compatibility --script tools/verify_silhouette.gd -- --output-dir=D:/Temp/AshenOath/silhouette
```

The isolated scene captures all four roles at 20 m, 1280x720, 55-degree FOV,
front/45-degree/side/back, with every material replaced by opaque unshaded black
and a transparent background. It checks nonblank/unclipped masks, required smith
and guard layers, and a pairwise XOR/union difference of at least 12% in two views.
It saves alpha-mask PNGs and a report with hashes. No rescaling/cropping or save
mutation is used. Numerical shape difference is not proof that a human correctly
recognizes an occupation; that remains a player-facing visual judgement.

Manual checks: identify Tor, rangers, Anwen and guards at 20 m without texture
cues; inspect bending, hands, helmet/hood clearance, dialogue and attacks; return
from a zone/Continue; confirm stable colours, original faces and unchanged gear.
