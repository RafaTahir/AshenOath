"""Verify exact new runtime speech, delivered codec envelopes and deferred bytes.

This is a technical delivery gate. It does not claim listening or visual acceptance.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

from story_voice_catalog import canonical_speaker

GAME = Path(__file__).resolve().parents[1]
VOICE_PREFIX = "res://assets_external/audio/voices/"


def resolve_audio(resource: str, roots: list[Path]) -> Path:
    if not resource.startswith(VOICE_PREFIX):
        raise ValueError("audio is outside the voice directory")
    relative = Path(resource[6:])
    if ".." in relative.parts or relative.is_absolute():
        raise ValueError("audio path escapes its resource root")
    for root in roots:
        path = (root / relative).resolve()
        if path.is_relative_to(root.resolve()) and path.is_file():
            return path
    raise ValueError("delivered audio is missing: " + resource)


def verify(manifest: dict, catalog: dict, roots: list[Path], canonicalize, decode) -> dict:
    failures, checked = [], {}
    by_key = {}
    for entry in manifest.get("lines", []):
        key = (canonicalize(str(entry.get("speaker_id", ""))), str(entry.get("text", "")))
        by_key.setdefault(key, []).append(entry)
    required = {}
    for row in catalog.get("lines", []):
        if row.get("required_new_or_recipe_changed", True):
            key = (row["canonical_speaker"], row["text"])
            required[key] = row
    if not required: failures.append("no required runtime utterances in the supplied catalog")
    for key, row in required.items():
        candidates = by_key.get(key, [])
        if not candidates:
            failures.append("missing recording for " + row["source_id"] + "/" + key[0])
            continue
        identities = {(entry.get("path"), entry.get("cast_role")) for entry in candidates}
        if len(identities) != 1:
            failures.append("ambiguous canonical recording for " + row["source_id"])
            continue
        entry = candidates[-1]
        if entry.get("cast_role") != row["cast_role"]:
            failures.append("incorrect cast recipe for " + row["source_id"])
            continue
        expected_text = hashlib.sha256(key[1].encode("utf-8")).hexdigest()
        if entry.get("text_sha256") != expected_text or row.get("text_sha256") != expected_text:
            failures.append("stale subtitle hash for " + row["source_id"])
            continue
        resource = str(entry.get("path", ""))
        try:
            path = resolve_audio(resource, roots)
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            if entry.get("audio_sha256") != digest or entry.get("audio_bytes") != path.stat().st_size:
                raise ValueError("audio bytes differ from the delivery manifest")
            if resource not in checked:
                measured = decode(path)
                checked[resource] = measured
            measured = checked[resource]
            duration = float(entry.get("duration_seconds", -1))
            rate = float(entry.get("speech_envelope_hz", -1))
            envelope = entry.get("speech_envelope", [])
            if not math.isfinite(duration) or abs(duration - measured["duration_seconds"]) > 2 / measured["sample_rate"]:
                raise ValueError("duration differs from decoded audio")
            if not math.isfinite(rate) or abs(rate - measured["speech_envelope_hz"]) > 1e-6:
                raise ValueError("speech envelope rate differs from decoded audio")
            if len(envelope) != len(measured["speech_envelope"]) or any(not isinstance(value, (float, int)) or not math.isfinite(value) or not 0 <= value <= 1 for value in envelope):
                raise ValueError("invalid speech envelope")
            if any(abs(float(a) - float(b)) > 0.0011 for a, b in zip(envelope, measured["speech_envelope"])):
                raise ValueError("speech envelope differs from delivered audio")
        except (OSError, ValueError, TypeError) as error:
            failures.append(resource + ": " + str(error))
    new_files = [path for directory in ("living_cast", "community")
                 for path in (roots[0] / "assets_external/audio/voices" / directory).glob("*.ogg")]
    new_bytes = sum(path.stat().st_size for path in new_files)
    if new_bytes > 16 * 1024 * 1024: failures.append("new voice payload exceeds 16 MiB")
    if any(path.stat().st_size >= 100 * 1024 * 1024 for path in new_files): failures.append("voice file exceeds committed-file limit")
    return {"status":"pass" if not failures else "fail", "failures":failures,
            "required_exact_utterances":len(required), "decoded_recordings":len(checked),
            "new_voice_bytes":new_bytes, "listening_acceptance":False, "gameplay_acceptance":False}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--retained-assets-from", type=Path)
    parser.add_argument("--runtime", type=Path)
    args = parser.parse_args()
    if args.runtime: sys.path.insert(0, str(args.runtime.resolve(strict=True)))
    import numpy as np
    import soundfile as sf

    def decoded(path):
        samples, sample_rate = sf.read(path, dtype="float32", always_2d=True)
        if not len(samples) or not np.isfinite(samples).all(): raise ValueError("empty or nonfinite audio")
        mono = samples.mean(axis=1)
        hop = max(1, int(sample_rate / 30))
        rms = np.array([float(np.sqrt(np.mean(mono[i:i + hop] ** 2))) for i in range(0, len(mono), hop)])
        reference = max(float(np.percentile(rms, 95)), 0.01)
        return {"duration_seconds":len(mono) / sample_rate, "sample_rate":sample_rate,
                "speech_envelope_hz":sample_rate / hop,
                "speech_envelope":np.round(np.clip((rms - 0.008) / reference, 0, 1), 3).tolist()}

    roots = [GAME]
    if args.retained_assets_from: roots.append(args.retained_assets_from.resolve(strict=True))
    manifest = json.loads((GAME / "voice_production_manifest.json").read_text(encoding="utf-8-sig"))
    catalog = json.loads(args.catalog.read_text(encoding="utf-8-sig"))
    result = verify(manifest, catalog, roots, lambda who: canonical_speaker(GAME, who), decoded)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result))
    return 0 if result["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
