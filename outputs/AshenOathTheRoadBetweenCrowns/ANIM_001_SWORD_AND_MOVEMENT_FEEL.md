# ANIM-001 Sword And Movement Feel

## Files Changed
- `scripts/player_controller.gd`
- `scripts/enemy_ai.gd`
- `tools/verify_visible_quality.gd`
- `tools/capture_slice_screenshots.gd`
- `ANIM_001_SWORD_AND_MOVEMENT_FEEL.md`

## Sword Swing Changes
- Strengthened light/heavy attack pose timing so attacks progress from readable windup to strike to recovery.
- Increased torso commitment during strikes so the body rotates with the weapon instead of the weapon moving alone.
- Heavy attack now uses a larger windup, wider sword rotation, stronger forward commitment, and heavier recovery than light attack.

## Sword Trail / Slash Arc Changes
- Added `visible_sword_slash_arc_root` with broad low-poly slash panels separate from the sword-local trail.
- Slash arcs appear only during attack strike windows.
- Light and heavy attacks now drive visibly different arc scale/rotation.
- Tightened the second pass by making the trail/arc panels thicker and brighter enough to read from the third-person camera.
- Updated screenshot timing so attack captures land during the strike moment instead of after the arc fades.

## Player Locomotion Changes
- Increased walk/run body lean, lateral sway, arm swing, leg swing, and cloak motion.
- Added more visible idle breathing through root/proxy motion.
- Movement still uses cheap procedural animation, safe for Web/Potato mode.

## Combat Body-Language Changes
- Weapon arm proxy now commits harder into windup and strike.
- Left arm, torso, cloak, and root rotation now react during combat instead of leaving the body dead-still.
- Block pose remains intact and still uses existing input/combat balance.

## Ghoulkin Animation Changes
- Windup now has a more pronounced crouched lean, squash/stretch, side roll, and anticipation charge.
- Stagger/recovery poses are stronger.
- Death collapse now falls flatter, lower, and with a more readable twist.

## Screenshot Paths
Fresh screenshots were saved to `Development_Gallery/screenshots/`:
- `Capture_11_player_idle_pose_2026-06-22_013801.png`
- `Capture_12_player_walking_pose_2026-06-22_013801.png`
- `Capture_13_player_light_attack_arc_2026-06-22_013801.png`
- `Capture_14_player_heavy_attack_arc_2026-06-22_013801.png`
- `Capture_15_ghoulkin_windup_hud_2026-06-22_013801.png`
- `Capture_17_ghoulkin_death_read_2026-06-22_013801.png`

## Verifier Results
- `tools/verify_visible_quality.gd` passed after adding light/heavy sword and slash-arc checks.
- `tools/verify_runtime.gd` passed.
- `tools/capture_slice_screenshots.gd` passed.

## Export Result
- `Export_Web_Build.bat` passed.
- `AshenOath_Web_Slim` verified at 7 files / 43.2 MB.

## Remaining Animation Weaknesses
- Animation remains procedural/proxy-based, not true skeletal animation.
- Sword arcs now read clearly in verification screenshots, but still need future camera-aware tuning during live combat.
- Ghoulkin movement is more readable but still lacks authored creature animation clips.

## Run Steps
1. Open PowerShell.
2. Run: `cd "C:\Users\User\Documents\Codex\2026-06-12\we-re-gonna-build-a-video\outputs\AshenOath_Web_Slim"`
3. Run: `& "C:\Users\User\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" -m http.server 8787 --bind 127.0.0.1`
4. Open Chrome or Edge to: `http://127.0.0.1:8787/index.html?v=anim001`
5. Click inside the game window to start/capture input.
6. Use `WASD` to move, mouse to look, `Left Click` light attack, `Shift + Left Click` heavy attack, `Q` block/parry, `Space` dodge, `Esc` pause/release mouse.
