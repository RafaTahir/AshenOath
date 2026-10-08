# LR-010 - Earned Companion Bond

Status: implemented_local_awaiting_user. No push or deployment; final combined
packaging follows LR-028. The currently generated LR-009 artifact predates this
source and is not represented as an LR-010 build.

## Implemented

- Adopted Bracken offers pet, share food and quiet rest interactions through his
  existing dialogue. Actor identity/proximity and current danger are rechecked
  after the dialogue surface closes, in any current sector, not only Greyfen.
- Care approaches through the existing physical route authority. Kael sheathes
  before offering a hand; the native right-arm solver follows Bracken's actual
  head bone. Head, neck and tail reactions modify the retained Dog skeleton after
  its original animation. No extra anatomy or forced player movement is added.
- Movement, new combat, injury, context change, departure and invalid approach
  cancel care without locking input. A bounded approach can refuse an obstructed
  location. Animation state is transient and never resumes from a saved coroutine.
- Travel Bread is an optional food item, two portions in the starting/legacy
  default loadout and a one-coin offer at Mira's existing shop (carry cap six at
  purchase). Existing saved quantities, including zero, override those defaults.
  A finished share consumes one portion through InventoryManager; interruptions
  consume none. It gives no health, skill, coin or relationship-point reward.
- StoryState records rescue, the first return after travelling together, surviving
  nearby danger, and resting after known testimony once each. Existing rescue flags
  backfill only the rescue event. Repeated care cannot increment these memories.
  Bracken's short narrative response derives from those recorded experiences.
- Heavy combat sends Bracken toward a supported, same-bank point away from nearby
  hostiles. Movement uses the same collision/route checks as following. No safe
  route means holding position, not teleporting. After three quiet seconds he
  resumes the saved follow/wait command. No enemy health or permanent death is added.

## Changed Files

Game-relative: `scripts/companion_controller.gd`, `scripts/companion_pose.gd`,
`scripts/player_controller.gd`, `scripts/story_state.gd`,
`scripts/dialogue_manager.gd`, `scripts/inventory_manager.gd`,
`data/dialogue.json`, `data/items.json`, `data/vendors.json`, and
`tools/build_bracken_asset.gd`; project/ticket/result records.

The asset builder now requires the native neck/head/tail chain on the final
package. Static source inspection of the retained FBX established Bone.002 /
Bone.003 / Bone.004 ownership, including its hierarchy. No game or animation was
launched to inspect it. Source/diff reasoning covered one-time event writes,
item-consumption ownership, cancellation and native equipment/animation callers.

## Persistence And Limits

Additive flags: `bracken_bond_events` (four keyed event records) and
`bracken_left_home`. Existing StoryState/InventoryManager saves own them. No save
version bump, story-choice replacement or separate affection currency.

UNVERIFIED - REQUIRES USER TESTING: care poses/contact, accessible approach,
retreat/rejoin, scene changes and Save/Continue. The final compiler/export has not
run for this ticket, as intermediate builds are deferred. No tests, browser QA,
screenshots, listening or performance runs were performed. No new voice is claimed.

## Manual Test Checklist

1. Adopt Bracken; pet, feed and rest. Interrupt by moving, pausing and drawing a
   weapon. Check free input and that only a completed share uses one Travel Bread.
2. Travel out and home, survive an encounter, then rest after Mira's/Senn's or
   recorded testimony. Save/Continue and check his remembered response.
3. Repeat care and revisit those events: no duplicated supplies/rewards or progress
   farming. In heavy combat check supported retreat and eventual follow/wait return.
