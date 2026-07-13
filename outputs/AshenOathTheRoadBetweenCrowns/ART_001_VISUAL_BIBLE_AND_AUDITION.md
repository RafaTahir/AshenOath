# ART-001 Visual Bible and Asset Audition

## Goal

Establish one achievable visual language before more assets are integrated. This ticket does not pretend the current candidates are final character art. It determines which existing assets are worth carrying into `CHAR-001`, `MON-001`, and `WORLD-001` and which presentation patterns are prohibited.

## Direction

**Grounded stylized dark fantasy** means believable scale, construction, wear, weight, and lighting expressed through optimized stylized geometry. It does not mean photoreal textures attached to crude silhouettes, nor low-poly assets left without art direction.

### Shape Language

- Greyfen: heavy stone foundations, uneven plaster, dark timber frames, steep practical roofs, compact door and window proportions.
- Kael: narrow travel silhouette, layered protection, practical sword, restrained cloak, no heroic shoulder exaggeration.
- Anwen: vertical robe silhouette, worn ceremonial layers, prayer object or staff, calm grounded posture.
- Ghoulkin: human origin remains visible, but posture, asymmetry, jaw and limb rhythm create unease. No bright cartoon skin or toy teeth.
- Props: broad readable forms at gameplay distance with believable ground contact and a reason to exist.

### Palette

- Charcoal: `#1C2021`.
- Wet earth: `#3B3026`.
- Moss: `#3D4B37`.
- Bone: `#B8AD98`.
- Shrine amber: `#D29A55`.
- Oathfire cyan is reserved for Kael's supernatural actions and never becomes general scenery color.

### Materials

- Roughness and value separation do more work than saturation.
- Wood, stone, plaster, cloth, skin and metal must remain distinguishable under dusk lighting.
- Major actors require textured materials on every visible surface; fallbacks may not be plain white.
- Terrain requires blended edges and contact dressing. Rectangular material patches are rejected.

### Lighting

- One readable directional key, cool ambient fill and restrained warm local lights.
- Faces remain readable in interaction range without glowing.
- Fog separates depth planes but may not erase roads or silhouettes.
- Night remains navigable and clearly nocturnal; daylight retains directional contrast.

## Identical-Camera Gate

All portrait candidates use 1280x720, 34 degree FOV, the same camera position, target, key light, fill and ground. Street candidates use a fixed 1280x720 camera and dusk lighting. Comparison images are written to `Development_Gallery/screenshots/ART_001_*`.

## Acceptance Rules

### Characters

- Correct role height within 5 cm after normalization.
- Complete skinned body, modeled head, non-empty materials, Skeleton3D and active animation.
- Face and occupation readable at conversation distance.
- No detached face cards, proxy limbs, root-mounted clothing or floating equipment.
- Kael and Anwen must be immediately distinguishable in silhouette and palette.

### Monsters

- Complete animated body and readable attack silhouette.
- Human origin and corruption both legible.
- No toy proportions, debug telegraph anatomy or identity based only on tint.

### Greyfen

- Buildings must read as complete structures with foundation, walls, openings, roof, chimney and ground contact.
- The street requires a clear walkable corridor, one compositional landmark and layered foreground/midground/background.
- Repeated pieces must be assembled intentionally; isolated modules cannot masquerade as complete assets.

## Audition Decision

| Role | Current baseline | Audition candidate | Decision |
|---|---|---|---|
| Kael | Poly Pizza Adventurer | Quaternius animated Warrior | Candidate rejected: faceless, squat and less readable as Kael. Baseline remains temporary only. |
| Sister Anwen | Poly Pizza Animated Woman | Quaternius animated Cleric | Candidate rejected: masked, oversized head and combatant silhouette contradict Anwen. Baseline remains temporary only. |
| Ghoulkin | Generated segmented Ghoul | Quaternius animated OrcSkull | Candidate rejected for final use: bright, toy-like and not cursed-human horror. Retain only as a rig reference. |
| Greyfen | Procedural box street | Existing modular village kit | Individual modules advance to `ASSET-001`; the sparse audition composition is rejected. |

No character audition candidate is approved for runtime replacement. `ASSET-001` must therefore quarantine these three candidate mappings and identify a better licensed source or a feasible authored derivative before `CHAR-001`/`MON-001`. The existing runtime actors are knowingly temporary, not silently promoted as acceptable art.

## Performance Budget

- Hero actor: one skeleton, one primary atlas, no more than four visible material surfaces.
- Crowd actor: shared skeleton and atlas, distance animation throttling.
- First encounter: five actors but no more than three full-rate animation updates outside attack windows.
- Greyfen street audition: no per-prop processing and no dynamic local shadows.
- Balanced remains native 720p and targets stable 30 FPS on Dell 7280-class hardware.

## Next Ticket Contract

`ASSET-001` must inventory only the assets selected here, record their licenses and dependencies, remove low-confidence runtime mappings, and define a minimal export set. It may not promote a candidate that failed the identical-camera gate.
