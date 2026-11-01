"""Read-only native timing validation; --assemble explicitly writes its output."""
import argparse
import hashlib
import json
import math
import struct
from pathlib import Path

POLICY = "native_attack_contact_v1"
PROCEDURAL = {"M06", "M07", *(f"M{i:02}" for i in range(9, 19))}
UAL = {"M01", "M03", "M04", "M05", "M19", "M20"}
METHODS = {"authored_procedural_apex", "sampled_earliest_minimum_120hz", "declared_recovery_boundary_fallback"}


def validate(project, document):
    assets = json.loads((project / "data/design_pack_assets.json").read_text(encoding="utf-8-sig"))["assets"]
    expected = {entry["path"]: (aid, entry) for aid, entry in assets.items() if aid.startswith("M")}
    profiles = document.get("profiles", {})
    if document.get("schema_version") != 1 or document.get("policy") != POLICY or profiles.keys() != expected.keys():
        raise ValueError("Timing schema/policy or exact 20-source coverage differs from the canonical asset ledger")
    fallbacks = []
    for source, (aid, asset) in expected.items():
        profile = profiles[source]
        blob = (project / source.removeprefix("res://")).read_bytes()
        digest = hashlib.sha256(blob).hexdigest()
        if profile.get("id") != aid or profile.get("source") != source or profile.get("source_sha256") != digest or asset["sha256"] != digest:
            raise ValueError(f"{aid}: stale source/identity hash")
        length = struct.unpack_from("<I", blob, 12)[0]
        gltf = json.loads(blob[20:20 + length])
        animations = [entry for entry in gltf.get("animations", []) if entry.get("name") == profile.get("clip")]
        if len(animations) != 1 or profile.get("clip") != "Attack":
            raise ValueError(f"{aid}: exact native Attack is absent or ambiguous")
        duration = max(gltf["accessors"][sampler["input"]]["max"][0] for sampler in animations[0]["samplers"])
        fraction = profile.get("contact_fraction", 0)
        profile_duration = profile.get("duration_seconds", 0)
        if not math.isfinite(fraction) or not 0 < fraction < 1 or not math.isfinite(profile_duration) or profile_duration <= 0 or abs(duration - profile_duration) > 1e-4:
            raise ValueError(f"{aid}: invalid fraction or stale clip duration")
        method = profile.get("method")
        if profile.get("policy") != POLICY or method not in METHODS or not profile.get("probe_bone") or len(profile.get("probe_offset", [])) != 3 or not all(math.isfinite(x) for x in profile["probe_offset"]):
            raise ValueError(f"{aid}: invalid calibration provenance/probe")
        if aid in PROCEDURAL and (method != "authored_procedural_apex" or fraction != .5):
            raise ValueError(f"{aid}: retained sin(pi*t)^2 apex must remain .5")
        window = profile.get("sample_window", [])
        expected_window = [.28, .70] if aid in UAL else [0, 1]
        if len(window) != 2 or any(not math.isfinite(value) or abs(value - expected_window[index]) > 1e-6 for index, value in enumerate(window)) or profile.get("sampling_hz") != 120 or profile.get("sample_count", 0) < 2:
            raise ValueError(f"{aid}: invalid sampling window/cadence")
        if method == "sampled_earliest_minimum_120hz":
            tolerance = max(1e-6, .5 / (120 * duration))
            if aid in PROCEDURAL or fraction <= window[0] + tolerance or fraction >= window[1] - tolerance:
                raise ValueError(f"{aid}: window endpoint cannot be labelled measured")
        if method == "declared_recovery_boundary_fallback":
            if fraction != .7 or profile.get("requires_visual_acceptance") is not True:
                raise ValueError(f"{aid}: fallback must be labelled .7 and require visual acceptance")
            if profile.get("fallback_reason") not in {"flat_probe", "endpoint_minimum"}:
                raise ValueError(f"{aid}: fallback must retain its deterministic reason")
            fallbacks.append(aid)
        elif profile.get("requires_visual_acceptance") is not False:
            raise ValueError(f"{aid}: invalid visual-acceptance flag")
    return fallbacks


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--assemble", type=Path, help="Directory containing one explicit M01.json..M20.json per source")
    parser.add_argument("--output", type=Path, help="Required explicit output for --assemble")
    args = parser.parse_args()
    if args.assemble:
        if args.output is None:
            parser.error("--assemble requires --output")
        rows = [json.loads((args.assemble / f"M{i:02}.json").read_text(encoding="utf-8-sig")) for i in range(1, 21)]
        document = {"schema_version": 1, "policy": POLICY, "profiles": {row["source"]: row for row in rows}}
    else:
        document = json.loads((args.project / "data/native_attack_profiles.json").read_text(encoding="utf-8-sig"))
    fallbacks = validate(args.project, document)
    if args.assemble:
        args.output.write_text(json.dumps(document, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"NATIVE ATTACK PROFILES: PASS (20 hash-bound sources; visual acceptance required: {','.join(fallbacks) or 'none'})")


if __name__ == "__main__":
    main()
