"""Render Ashen Oath's authored, sparse story motifs. Production asset build only.

No external samples, voice model, network, tests, listening pass or QA process.
The phrases share an oath motif; different endings change its harmony and rests.
"""
from pathlib import Path
from array import array
import json
import math
import wave

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets_external" / "audio" / "story_score"
RATE = 16000
DURATION = 16.0

# MIDI pitches, quarter-note start, duration in beats, instrument and velocity.
# The common cell is D-A-C-E: a return interrupted before the tonic can settle.
SCORES = {
    "story_road": {"tempo": 60, "bed": [50, 57], "events": [(0,62,1.2,"plucked",.50),(2,69,.9,"plucked",.40),(3.5,72,1.2,"plucked",.32),(6,64,1.1,"plucked",.35),(9,62,2,"plucked",.37),(11,57,2,"plucked",.27)]},
    "story_names": {"tempo": 56, "bed": [50, 53], "events": [(0,74,2,"bell",.32),(3,69,2,"bell",.25),(6,72,1.5,"bell",.27),(8,76,2,"bell",.25),(11,74,2,"bell",.20)]},
    "story_renewal": {"tempo": 66, "bed": [38, 45, 51], "events": [(0,50,.8,"plucked",.36),(1.5,57,.8,"plucked",.28),(3,60,1,"bell",.24),(5,64,1,"plucked",.27),(7.5,50,.8,"plucked",.36),(9,57,.8,"plucked",.24),(11,63,2,"bell",.22)]},
    "ending_witness": {"tempo": 60, "bed": [50, 57, 66], "events": [(0,62,1.4,"plucked",.46),(2,69,1,"plucked",.37),(4,72,1.2,"bell",.23),(6,76,1.4,"plucked",.35),(8,74,2,"bell",.28),(11,66,2,"plucked",.30)]},
    "ending_mercy": {"tempo": 54, "bed": [48, 55, 62], "events": [(0,62,2,"plucked",.33),(3,69,2,"plucked",.28),(6,72,2,"bell",.19),(9,67,2,"plucked",.25)]},
    "ending_duty": {"tempo": 60, "bed": [38, 45, 50], "events": [(0,62,1.6,"plucked",.38),(2,69,1.2,"plucked",.29),(4,72,1.6,"bell",.20),(6,64,1.6,"plucked",.31),(8,62,1.6,"plucked",.35),(10,57,2,"plucked",.26)]},
    "ending_ash": {"tempo": 58, "bed": [38, 50], "events": [(0,62,1.8,"plucked",.28),(2.5,69,1.4,"plucked",.20),(5,72,2,"bell",.16),(9,62,1.8,"plucked",.13)]},
}


def frequency(midi):
    return 440.0 * 2.0 ** ((midi - 69.0) / 12.0)


def render(score):
    size = int(RATE * DURATION)
    result = array("f", [0.0]) * size
    beat = 60.0 / score["tempo"]
    # Slowly breathed open strings retain acoustic space beneath the phrase.
    for midi in score["bed"]:
        hz = frequency(midi)
        for i in range(size):
            t = i / RATE
            edge = min(1.0, t / 1.6, (DURATION - t) / 2.2)
            breath = .62 + .12 * math.sin(2 * math.pi * t / 8.0)
            value = math.sin(2 * math.pi * hz * t) + .17 * math.sin(2 * math.pi * hz * 2 * t + .07 * math.sin(t))
            result[i] += value * max(edge, 0) * breath * .026
    for start, midi, beats, instrument, velocity in score["events"]:
        onset = start * beat
        length = min(beats * beat + (1.6 if instrument == "bell" else .8), DURATION - onset)
        hz = frequency(midi)
        for j in range(max(0, int(length * RATE))):
            t = j / RATE
            attack = min(1, t / .014)
            envelope = attack * math.exp(-t * (1.65 if instrument == "plucked" else 1.05))
            envelope *= min(1, (length - t) / .35)
            if instrument == "bell":
                value = math.sin(2 * math.pi * hz * t) + .30 * math.sin(2 * math.pi * hz * 2.006 * t) * math.exp(-t * 1.5) + .13 * math.sin(2 * math.pi * hz * 3.98 * t) * math.exp(-t * 2)
            else:
                value = math.sin(2 * math.pi * hz * t) + .24 * math.sin(2 * math.pi * hz * 2 * t) * math.exp(-t * 2.4) + .07 * math.sin(2 * math.pi * hz * 3 * t) * math.exp(-t * 4)
            index = int(onset * RATE) + j
            if index < size:
                result[index] += value * envelope * velocity * .21
    # Short, diminishing room reflections, baked once instead of a runtime bus.
    dry = array("f", result)
    for delay, gain in [(0.083,.13),(.137,.08),(.231,.04)]:
        offset = int(delay * RATE)
        for i in range(offset, size):
            result[i] += dry[i-offset] * gain
    pcm = array("h", (int(max(-1, min(1, math.tanh(value * 1.45))) * 32767) for value in result))
    return pcm


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name, score in SCORES.items():
        pcm = render(score)
        with wave.open(str(OUTPUT / (name + ".wav")), "wb") as stream:
            stream.setnchannels(1)
            stream.setsampwidth(2)
            stream.setframerate(RATE)
            stream.writeframes(pcm.tobytes())
        print("Rendered " + name)
    manifest = {
        "revision": "road-renewal-1",
        "production_mode": "original_procedural_composition",
        "human_listening_review": "not_performed_user_requested",
        "source": "tools/build_story_score.py",
        "license": "Ashen Oath original project composition",
        "sample_rate": RATE,
        "duration_seconds": DURATION,
        "motif": "D-A-C-E; endings alter resolution and silence",
        "tracks": {name: {"path": "res://assets_external/audio/story_score/" + name + ".wav", **score} for name, score in SCORES.items()},
    }
    (ROOT / "story_score_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
