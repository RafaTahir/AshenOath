"""Reproducible original creature accents; no third-party recordings or voices."""
from __future__ import annotations

import argparse
from array import array
import hashlib
import json
import math
from pathlib import Path
import random
import subprocess
import wave

RATE = 24000


def samples(kind: str) -> array:
    seconds = 0.68 if kind == "reed_choir_call" else 0.24
    rng = random.Random(41107)
    previous = 0.0
    result = array("h")
    for index in range(round(seconds * RATE)):
        t = index / RATE
        u = t / seconds
        envelope = math.sin(math.pi * u) ** 2
        if kind == "reed_choir_call":
            # Three short pressure pulses answer the three visible air sacs.
            pulse = 0.62 + 0.38 * math.sin(math.tau * 7.5 * t)
            phase = math.tau * (287.0 * t - 30.0 * t * t)
            value = envelope * pulse * (0.11 * math.sin(phase) + 0.032 * math.sin(phase * 2.03))
        elif kind == "inkblind_brush":
            noise = rng.uniform(-1.0, 1.0)
            value = (noise - previous) * 0.018 * envelope * (0.7 + 0.3 * math.cos(math.tau * 19 * t))
            previous = noise
        else:
            raise ValueError(kind)
        result.append(round(max(-0.95, min(0.95, value)) * 32767))
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--game", type=Path, required=True)
    parser.add_argument("--ffmpeg", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()
    output = args.game.resolve() / "assets_external/audio/authored"
    output.mkdir(parents=True, exist_ok=True)
    args.evidence.mkdir(parents=True, exist_ok=True)
    receipts = []
    for kind in ("reed_choir_call", "inkblind_brush"):
        pcm = samples(kind)
        source = args.evidence / (kind + ".wav")
        with wave.open(str(source), "wb") as stream:
            stream.setnchannels(1)
            stream.setsampwidth(2)
            stream.setframerate(RATE)
            stream.writeframes(pcm.tobytes())
        path = output / (kind + ".ogg")
        def encode(destination):
            subprocess.run([str(args.ffmpeg), "-hide_banner", "-loglevel", "error", "-y", "-i", str(source),
                            "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact",
                            "-c:a", "libvorbis", "-q:a", "3", "-threads", "1", str(destination)], check=True,
                           creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        encode(path)
        repeated = args.evidence / (kind + "_repeat.ogg")
        encode(repeated)
        if repeated.read_bytes() != path.read_bytes():
            raise RuntimeError("Creature cue regeneration is not byte-identical: " + kind)
        repeated.unlink()
        receipts.append({"id":kind, "sample_rate":RATE, "frames":len(pcm), "duration":len(pcm)/RATE,
                         "path":"res://"+path.relative_to(args.game.resolve()).as_posix(),
                         "sha256":hashlib.sha256(path.read_bytes()).hexdigest(), "bytes":path.stat().st_size,
                         "authorship":"Original deterministic synthesis", "byte_repeat_verified":True, "listening_accepted":False})
    with args.ffmpeg.open("rb") as encoder:
        encoder_hash = hashlib.file_digest(encoder, "sha256").hexdigest()
    (args.evidence / "audio_receipt.json").write_text(json.dumps({"recipe_sha256":hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), "encoder_sha256":encoder_hash, "cues":receipts}, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({"cues":len(receipts), "bytes":sum(row["bytes"] for row in receipts), "listening_accepted":False}))


if __name__ == "__main__":
    main()
