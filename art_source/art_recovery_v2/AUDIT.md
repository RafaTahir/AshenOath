# Art recovery: rejected production milestone

Baseline: `4cae67f`; review branch `codex/art-recovery-anwen`. No production publication is authorized before the user's visual acceptance.

Current continuation policy: the approved **Practical, Zero-Cost Character Production** plan authorizes grounded-stylized candidates for all 33 assets, individually, without numerical or per-character approval stops. Anwen, Ghoulkin and Bell-Eater remain first in sequence, followed by the complete roster. Inspect actual art and disclose limitations; never substitute a technical pass for visual acceptance. User acceptance and publication remain separate. Historical scores and evidence below remain unchanged. See `quality_gate.json` for the active production order.

## Current Practical Roster, 2026-10-31

All 33 candidate slots now have separate editable source and exported derivatives.
The current exact files are in `stylized_roster.json`, not the historical table
below. Twelve non-Anwen humans received a final garment/equipment fitting pass;
Anwen retains the previously inspected retained garment/face rig. Tor, Nessa and
Merrow received bounded larger torso/face/forearm corrections after their earlier
mass differences proved too subtle. No per-character acceptance is claimed.

The Stalker now uses the licensed articulated Creep foundation. The Gravebound
uses fitted Ranger garments, an enclosed CC0 Knight helmet and a real sword/shield
assembly rather than its inflated prototype body. The actual native stag and its
rigid antlers are retained for the Hart. Bell-Eater's bell/chains mount to the
pelvis; fitted harness ribbons follow body skinning. Other creature foundations
are explicitly retained/refined, not passed off as wholly new anatomical sculpts.

Runtime-only consolidation brought Hearthscale to one mesh/20,000 triangles and
Ashwing to 33,999 triangles. Other triangle exceptions remain in the ledger.
Lossless external sharing of the candidate image payloads saves 39,790,886 bytes:
147,048,396 embedded bytes become 107,257,510 bytes of GLBs plus unique images.
This is file-size arithmetic, not process memory or a measured performance gain.

Authoring is frozen. Native art inspection, private asset compilation and the
combined review package are complete. User acceptance remains **0/33**;
no commit, push, production Web synchronization or deployment is authorized.
The recovery publication-budget conflict is still unresolved. Historical failed
scores below remain unchanged and are not current candidate acceptance results.

### Private Delivery

- Build: `private-stylized-24369b7da1de`; complete local Web bytes:
  **230,205,500**. Baseline commit: `5f92ac0`; dirty private overlays are explicit.
- All 33 have editable sources, runtime derivatives, neutral/side/rear views,
  motion/action samples and prepared-body staging under actual Greyfen lighting.
  Staging never starts a journey or performs a gameplay save. It is not regional
  encounter, campaign, phone, performance or final visual acceptance.
  The initial level camera was behind a house; those failed views are preserved
  under `level_obstructed_camera` and `level_garment_obstructed_camera`. The final
  captures use a clear street camera and an explicitly staged body turntable,
  not real NPC placement. Unclassified red/black background geometry remains
  visible in that prepared-menu stage. Its gameplay owner/cause is unresolved;
  it is not concealed, attributed to a new candidate, or declared passed.
- Six combined creature meshes were renamed so equipment exclusion does not
  exclude their bodies. Scaled skin exports use explicitly compiled bind-pose
  bounds in the existing asset/preparation owners; raw mesh AABBs were unreliable.
  JSON mesh-transform adjustments alone did not resolve Godot's framing issue.
- The apparent apron holes were hand intersections. Surface-weight and trouser-
  seam adjustments alone did not close them. The final four garment profiles use
  the existing locomotion pose owner for bounded arm clearance; work, dialogue,
  death and combat retain their own poses. The affected native samples were
  refreshed; unchanged bodies were reused.
- Current package encoded/decoded hashes, gzip formats and pack graph agree.
  Strict release validation remains **FAILED / BUDGET**, not accepted:
  `opening.pck` is **110,802,973 bytes**, requiring at least **5,945,374 bytes**
  less in that individual file to satisfy the strict Git limit. The complete
  private package also exceeds the recovery ceiling by **125,347,901 bytes**.
  The ordinary 256-MiB total ceiling passes, with its 200-MiB warning. No cap was
  changed and no content was removed to claim release eligibility.
  Initial required transport is **126,516,202 bytes** on Balanced/Potato and
  **133,733,297 bytes** on Quality. Balanced transfer alone is approximately
  **50.6 seconds at 20 Mbps**, before preparation. This is arithmetic, not a
  network benchmark; no startup/FPS/memory target is claimed as met.
- The isolated D: application-data profile resolves the earlier shader-cache/
  default-log path failures. Existing Web templates were copied into that private
  profile after the first export reported missing templates. Valid packs were
  reused. Historical rejected sources, retained earlier evidence and these named
  compilation/export failures remain recorded.

Review index: `evidence/stylized/index.html`. Exact models, costs and limitations:
`stylized_roster.json`. Exact Web files and failures:
`D:/Temp/AshenOath/stylized_review/private_review_build.json`.

## Historical Rejected Milestone, Preserved

The earlier implementation delivered functional prototypes, not faithful production characters. The production claim was too broad. Every supplied reference was opened through the comparison sheets; all 33 authored Blender sources were opened read-only, and all 33 exported GLBs were rendered from four directions in Godot Compatibility on the HD 620. The reference PDF has 42 pages; its introduction, production handoff and individual dossiers distinguish concept art from finished assets.

Evidence: `D:/Temp/AshenOath/art_recovery_v2/audit/`, including exact exported-body hashes and nine reference/render comparison sheets. The capture script's original `front`/`rear` filenames describe camera -Z/+Z, respectively; the sheets label the actual body views correctly. Raw captures remain preserved. These are neutral Godot inspection scenes, NOT screenshots of the live campaign or proof of its playback.

## Scoring

Subjective 1-5, supported by the captures. Order: **silhouette / anatomy / face / geometry / materials / clothing / creature identity / neutral Godot presentation / fidelity**. `-` means inapplicable. Animation and actual level-lighting scores are **NR for every asset**: neither static rest-pose captures nor the existence of fifteen clips proves credible motion. A missing score blocks acceptance just like a score below 4. No current asset is approved.

| Asset | Scores | Three largest discrepancies and causes |
| --- | --- | --- |
| C01 Anwen | 2/2/1/2/1/1/-/1/1 | Youthful generic face instead of mature alert identity: reused facial topology with tiny displacements. Rigid cut-out shoulder collar: concentric shell construction instead of a draped wrap. Smooth straight gown and plastic hair: periodic folds/painted noise without garment pattern, fibers or proper braid masses. |
| C02 Rook | 2/2/1/1/1/1/-/1/1 | Generic narrow head misses rounded expressive face: shared base. Uniform cylindrical sleeves miss rolled cuffs: tube construction. Flat green torso lacks the reference jacket/lapel structure: costume approximated by color. |
| C03 Mira | 2/2/1/1/1/1/-/1/1 | Missing strong individual facial planes: shared female base. Colored patches break the skirt rather than a credible layered apron: atlas/panel construction. Rigid cord-like hair instead of a substantial braid: simplified tubes. |
| C04 Tor | 2/2/1/1/1/1/-/1/1 | Lean torso misses working bulk: insufficient structural change. Thin beard mask does not establish the face: surface substitute. Apron straps and sleeves lack thickness/contact: flat assemblies and generic tubular arms. |
| C05 Elna | 2/2/1/1/1/1/-/1/1 | Young generic face misses age: reused base. Shawl has an open cut-out shape, not folded cloth: shell profile. Straight purple skirt lacks layered patched weave: procedural surfaces. |
| C06 Toma | 2/2/1/1/1/1/-/1/1 | Face and beard do not capture tired identity: generic head. Flat tunic and segmented belt do not hang naturally: shell geometry. Hands and shoulder junctions read disconnected: inherited anatomy with approximate garment joins. |
| C07 Senn | 2/2/1/1/1/1/-/1/1 | Young narrow face misses older stern bearing: shared head. Coat is a straight tunic, not a tailored military garment: generic pattern. Armor/straps lack credible fastening: decorative layers. |
| C08 Edric | 2/2/1/1/1/1/-/1/1 | Face resembles Toma/Kael rather than Edric: common head. Burgundy coat lacks folded lapels and structured tailoring: shell. Beard and hair are flat masses: insufficient sculpt and strand work. |
| C09 Vale | 2/2/1/1/1/1/-/1/1 | Mature facial structure absent: generic base. Cream vest is a flat strip rather than layered fabric: texture/shell substitution. Grey hair lacks curls and volume: cap geometry. |
| C10 Merrow | 2/2/1/1/1/1/-/1/1 | Thin youthful face misses round older identity: shared head. Jacket lacks belly, lapels and open layering: stock silhouette. Book/key hardware is simplified decoration: unrefined geometry/materials. |
| C11 Nessa | 2/2/1/1/1/1/-/1/1 | Narrow generic face/body misses broad warm presence: base reuse. Color discontinuities replace bodice/skirt construction: atlas treatment. Hair/kerchief appears as a cap/ring: inadequate modeling. |
| C12 Nera | 2/2/1/1/1/1/-/1/1 | Generic face misses angular alert identity: common base. Coat/scarf are thin geometric bands: no convincing cloth construction. Rope/accessory shape is rigid and over-simple: tube approximation. |
| M01 Ghoulkin | 1/1/1/1/1/-/1/1/1 | Upright bulbous torso misses crouched predatory silhouette: ellipsoid assembly. Forearms/haunches lack muscle/joint continuity: disconnected volume design. Skull/jaw/skin lack identity: generic muzzle and uniform procedural surface. |
| M02 Stalker | 1/1/1/1/1/-/1/1/1 | Essentially Ghoulkin body rather than lank stalking species: reused volume recipe. Skull lacks animal planes: rounded primitive. Hair/back strips replace fur anatomy: decorative geometry. |
| M03 Bog Wretch | 1/1/1/1/1/-/1/1/1 | Upright generic body misses hanging abdomen/low water stance: reused biped recipe. Broad toothed mouth absent: generic face. Reeds/core look attached decorations, not integrated tissue: surface assembly. |
| M04 Gravebound | 1/1/1/1/1/1/1/1/1 | Massive rounded body misses human armored proportions: shared creature core. Armor is sparse inflated pieces rather than articulated plates: primitive layout. Cloth/steel material separation inadequate: procedural atlas. |
| M05 Bell-Eater | 1/1/1/1/1/-/1/1/1 | Generic inflated biped misses heavy coherent anatomy: shared recipe. Bell/harness reads as a small cone and straight straps: insufficient modeled equipment. Chains lack convincing anchor/weight relationships: decorative assembly. |
| M06 Rootbound | 1/1/1/1/1/-/1/1/1 | Rounded biped instead of interlocked roots/bark: reused core. Pyramid projections replace plates/wood fibers: primitive detail. Glow/heart unsupported by surrounding structure: disconnected decoration. |
| M07 Ashwing | 2/2/1/2/1/-/2/2/2 | Neck/skull too simple for carrion profile: generic sweep. Wings too planar and clean: no anatomical fold hierarchy. Skin/scales lack layered feather-like breakup: noise material. |
| M08 Hart | 3/2/2/2/1/-/2/2/2 | Neck/body/haunch transitions too tubular: volume construction. Hoof/leg articulation thin and simplified: inadequate anatomical refinement. Coat reads as smooth ivory rather than fur: material/detail deficit. |
| M09 Silt-Maw | 2/1/1/1/1/-/1/1/1 | Head fails broad weighty jaw: primitive shape. Segments mechanically repetitive: procedural rings. Surface lacks wet folded flesh: uniform roughness/no sculpt. |
| M10 Millback | 2/1/1/1/1/-/1/1/1 | Shell lacks layered armored structure: ellipsoid cap. Legs are disconnected rods and balls: missing joint design. Face/claws lack credible functional forms: simplified geometry. |
| M11 Glassmoth | 3/2/1/2/1/-/2/2/2 | Wing arrangement recognizable but planar: paper surfaces. Head/antennae lack dense biological detail: sparse shapes. Thorax lacks fur/leg connections: primitive volumes. |
| M12 Knell Leech | 2/1/-/1/1/-/1/1/1 | Mechanical cylinder instead of folded living body: periodic profile. Mouth teeth lack tissue attachment: repeated inserts. Material lacks moisture and skin variation: noise-only treatment. |
| M13 Hearthscale | 2/1/1/1/1/-/1/1/1 | Rounded body lacks muscular low stance: volume recipe. Back plates are tiny decorations: missing armor geometry. Feet/skull lack grounded anatomy: primitive junctions. |
| M14 Weaver | 2/1/1/1/1/-/1/1/1 | Abdomen and thorax poorly differentiated: simple volumes. Rod legs lack organic articulation: uniform taper. Face/chelicerae/fur absent at required fidelity: insufficient topology. |
| M15 Reed Choir | 2/1/1/1/1/-/1/1/1 | Frog structure overwhelmed by inflated volumes: primitive construction. Sacs not integrated into back: intersecting shapes. Skin lacks granular anatomy: noise-only surface. |
| M16 Inkblind | 2/1/1/1/1/-/1/1/1 | Head underside lacks feeding appendage structure: sparse inserts. Shell has no credible layered rim: ellipsoid. Limbs look ball-and-rod: no joint refinement. |
| M17 Cairn Mother | 2/1/1/1/1/-/1/1/1 | Shell replaced by stacked block/pyramid silhouette: wrong structural method. Foot lacks continuous muscular sole: repetitive rods. Stone/skin distinction weak: inadequate sculpt/materials. |
| M18 Swimmer | 2/1/1/1/1/-/1/1/1 | Body appears almost flat: insufficient 3D volume. Eyes/gill/mouth structure unreadable: omitted anatomy. Membrane surface lacks biological detail: simple patch. |
| M19 Raider | 1/1/1/1/1/-/1/1/1 | Near-copy of Ghoulkin instead of distinct lean raider: shared recipe. Hands/skull lack reference hooks/planes: primitives. Skin/fur lacks material distinction: uniform treatment. |
| M20 Brute | 1/1/1/1/1/-/1/1/1 | Enlarged shared biped rather than credible power anatomy: scale changes. Tusks/jaw do not define face: decoration on generic muzzle. Forearms/feet lack articulated weight-bearing structure: volume joins. |
| P01 Kael | 2/2/1/1/1/1/-/1/NR | No supplied Kael sheet: fidelity cannot be scored. Generic shared face misses an authored protagonist identity. Tunic/equipment lack believable construction. Gloves/boots/materials remain prototype level. |

## Recovery decisions

Salvage: identifiers, original references, provenance, compatible human body rig, animation-library mapping, gameplay wrappers and exact build history. Preserve old sources read-only for comparison.

Reconstruct: individual facial topology/landmarks; hair mass/strands; patterned layered clothing with contact, seams, wear and proper UVs. For Anwen, use a CC0 anatomically detailed head as a sculpting foundation, not another colored generic face; maintain explicit provenance and existing body/face control compatibility.

Rebuild later, ONLY after Anwen acceptance: Ghoulkin's connected anatomy and skeleton, then Bell-Eater's mass, equipment and dedicated motion. Do not repeat the creature ellipsoid factory. Other prototype assets remain rejected, not queued for mass regeneration now.

The current published package is 242,429,964 bytes. The new brief states under 100 MiB, superseding the earlier 256 MiB budget for this recovery deliverable; current full release exceeds 100 MiB by 137,572,364 bytes. No under-budget claim or publication is permitted. Keep high-resolution production sources outside exports; quantify the eventual optimized candidate rather than silently degrading anatomy or deleting content.

## Non-bypassable slice gate

Each required score must be >=4 with reference, neutral front/side/rear/quarter, detail, motion, Blender and actual Godot-level evidence, exact source/export hashes, technical results and known defects. Missing evidence or a lower score means REWORK, never accepted. User acceptance is separately required. Anwen comes first; Ghoulkin and Bell-Eater production stay locked until the preceding slice is accepted. Compilation alone cannot change these states.
