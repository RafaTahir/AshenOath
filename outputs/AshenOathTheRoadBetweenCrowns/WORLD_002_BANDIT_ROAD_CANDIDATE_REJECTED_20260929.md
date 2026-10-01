# WORLD-002 Bandit Road Candidate Rejected

The integrated terrain/checkpoint/palette candidate passed parser checks, the 60 KB checkpoint resource budget, the campaign wilds resource/collision contract, and a 1280x720 day/night/checkpoint capture from the genuine pre-fight save. It was **visually rejected** after matching-camera comparison with the retained v4 frames.

The new verge patches produced repeated dark oval marks instead of natural road wear. The added wagon did not strengthen the arrival silhouette, the checkpoint still read as a small blockout, and guards remained unreadable at night. The capture also logged explicit diagnostic fallbacks for `bandit_deserter` and `bandit_tracker` because neither role has an acceptance record; that is a separate release blocker, not a passing visual mapping.

Candidate evidence is retained at `D:/Temp/AshenOath/bandit_road_authored_v5/` (day, night, checkpoint and capture report). Only this candidate's generator, palette and manifest edits were removed. The two regenerated resource hashes match the retained v4 resources exactly:

- `Campaign_bandit_road_Landscape.res`: `7e33af4ed05f4cf19f09e3e6b41873610e525210b36968983ec8521ca031d6bf`
- `RoadCheckpoint_Authored.res`: `1cb1877f36efb836b7e3f3bd70d9a1e0a04f6049478e44a49154454a5966cee9`

WORLD-002 remains visually rejected. The next art intervention needs a different authored environment/hostile-costume method with accepted runtime role records; do not repeat near-flat patch or isolated prop/tint treatments. Collision, quest, save and gate code was not changed.
