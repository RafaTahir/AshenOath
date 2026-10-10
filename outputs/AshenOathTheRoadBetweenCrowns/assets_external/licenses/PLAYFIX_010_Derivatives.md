# PLAYFIX-010 Approved Derivatives

The user approved all three source-body references on 2026-10-10. This is
reference selection, not approval of gameplay or animation in the final build.

- BellEater_Playfix.glb and BogWretch_Playfix.glb derive from the retained
  project-authored Ghoulkin_Authored_Atlas.gltf and Quaternius Universal Base
  Characters, CC0: https://quaternius.com/packs/universalbasecharacters.html.
  Original notice: Quaternius_Universal_Base_Characters_CC0.txt.
- Ashwing_Playfix.glb derives from the retained Dragon.fbx in Quaternius
  Animated Monsters, CC0: https://quaternius.com/packs/animatedmonster.html.
  Original notice: quaternius_lowpoly_animated_monsters/License.txt.

Derivatives retain source skeletons, weights and textures. The authoring script
changes weighted proportions and material tints. Humanoid animation is supplied
once by the existing shared UAL2 library. Runtime exports use bind rest, not the
pose chosen for the approved portraits. Original source assets remain intact.

Godot extracts the embedded humanoid atlas into
BellEater_Playfix_Ghoulkin_Authored_Atlas.png and
BogWretch_Playfix_Ghoulkin_Authored_Atlas.png. Both companion files are owned by
their corresponding runtime role and included explicitly in the monster pack.

Reference portraits in Development_Gallery/screenshots/
PLAYFIX_010_approved_references are excluded from deployment. They are not
gameplay evidence. Runtime dimensions and encounter behavior still need the
authorized final playthrough.

greyfen_menu_stylized.png is AI-generated menu/journal illustration derived from
the retained Greyfen image. It is not a screenshot or a fidelity claim.
