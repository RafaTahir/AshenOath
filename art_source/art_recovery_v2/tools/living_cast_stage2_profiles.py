"""Authored Stage2 contracts; dimensions are metres in actor-relative space.

These profiles describe source intent. Acceptance is recorded only after native
rig, prop-surface, garment and gameplay review, never from a profile declaration.
"""

CLIPS = {"Life_Idle_A": 6, "Life_Idle_B": 8, "Life_Work": 4,
         "Life_Listen": 4, "Life_Speak": 4}

PROFILES = {
    "C11": {"name": "Nessa", "identity": "nessa", "activity": "knead_dough", "scale": .85,
            "lean": [.16, .08, .015], "counter_head": -.10,
            "idle_intent": "Steady apron-weighted breath; inspect the flour-bearing palm and relax its fingers.",
            "work_intent": "Gather, press both palms into the supported flat dough, then ease apart.",
            "listen_intent": "Warm still attention with a small shoulder release.",
            "speak_intent": "Open-handed portion-sharing gesture; no broad courtly flourish.",
            "contact_response": "morph", "contact_shape": "TaskPress", "contact_amount": .055},
    "C05": {"name": "Elna", "identity": "elna", "activity": "fold_cloth", "scale": .55,
            "lean": [.16, .08, .015], "counter_head": -.10,
            "idle_intent": "Quiet breath; release and settle the left wrist close to the body.",
            "work_intent": "Left palm anchors the cloth while the right smooths a measured fold.",
            "listen_intent": "Reserved inclination with the hands close to the body.",
            "speak_intent": "Small left-hand invitation that returns gently to rest.",
            "contact_response": "morph", "contact_shape": "TaskPress", "contact_amount": .035},
    "C06": {"name": "Toma", "identity": "toma", "activity": "tend_seed_tray", "scale": .9,
            "lean": [.20, .10, .020], "counter_head": -.13,
            "idle_intent": "Rangy chest breath; inspect and loosen one wrist after field work.",
            "work_intent": "Inspect the seedbed, then press two shallow soil rows with grounded palms.",
            "listen_intent": "Slight browward tilt and a patient shoulder settle.",
            "speak_intent": "Practical low outward gesture toward a field-sized area.",
            "contact_response": "compress", "contact_amount": .035},
    "C12": {"name": "Nera", "identity": "nera", "activity": "check_load_strap", "scale": 1.0,
            "lean": [.26, .16, .025], "counter_head": -.16,
            "idle_intent": "Alert breath; check the coat cuff before surveying the next task.",
            "work_intent": "Grip both real fastenings, pull-check the attached freight strap, release.",
            "listen_intent": "Hold an attentive squared stance with a restrained nod.",
            "speak_intent": "Clear right-hand route indication, then return to the listener.",
            "contact_response": "compress", "contact_amount": .06},
    "C07": {"name": "Senn", "identity": "senn", "activity": "survey_approach", "scale": .7,
            "lean": [0, 0, 0], "counter_head": 0,
            "idle_intent": "Contained veteran breath; release a stiff shoulder without dropping watch.",
            "work_intent": "Survey left approach, settle centrally, check the right road edge.",
            "listen_intent": "Minimal acknowledging dip, shoulders remain guarded.",
            "speak_intent": "A low, firm instruction with one bounded hand movement.",
            "contact_response": "none", "contact_amount": 0, "contact_required": False},
    "C09": {"name": "Vale", "identity": "vale", "activity": "compare_ledger", "scale": .6,
            "lean": [.18, .09, .020], "counter_head": -.12,
            "idle_intent": "Measured breath; settle a sleeve before returning to a line of thought.",
            "work_intent": "Anchor the ledger with the left palm and follow a real page line with the right.",
            "listen_intent": "Still attention; a slight head tilt keeps a distinction in view.",
            "speak_intent": "A restrained right-hand counting gesture before the hand settles.",
            "contact_response": "tilt", "contact_amount": .025,
            "extra_clips": {"Life_Settle_Ledger": 4}},
    "C10": {"name": "Merrow", "identity": "merrow", "activity": "sort_receipts", "scale": .75,
            "lean": [.24, .14, .025], "counter_head": -.16,
            "idle_intent": "Waist-weighted breath; straighten a cuff and settle back into office routine.",
            "work_intent": "Compare two receipts and smooth their supported edges.",
            "listen_intent": "An inclined head with a small, deliberating pause.",
            "speak_intent": "Present a measured option with the right palm, then close the gesture.",
            "contact_response": "tilt", "contact_amount": .025,
            "extra_clips": {"Life_Cup_Hold": 4, "Life_Drink": 4}},
    "C08": {"name": "Edric", "identity": "edric", "activity": "inspect_dispatch", "scale": .45,
            "lean": [.23, .14, .025], "counter_head": -.15,
            "idle_intent": "Controlled breath; a deliberate lapel correction that preserves authority.",
            "work_intent": "Read the supported dispatch, touch its seal, then release without haste.",
            "listen_intent": "Small deliberate inclination with very little shoulder motion.",
            "speak_intent": "A precise outward presentation ending with the palm lowered.",
            "contact_response": "compress", "contact_amount": .025},
}

for asset, profile in PROFILES.items():
    profile.setdefault("contact_required", True)
    profile["palm_goals_lateral_forward_height"] = {
        "l": [-.12, .40, 1.115 if asset == "C12" else 1.02],
        "r": [.12, .40, 1.115 if asset == "C12" else 1.02],
    }
    profile["intent"] = " ".join(profile[key] for key in
                                ("idle_intent", "work_intent", "listen_intent", "speak_intent"))
    if profile["contact_required"]:
        profile["runtime_prop"] = "res://assets_external/environment_prepared/living_cast/station_" + profile["identity"] + ".scn"
