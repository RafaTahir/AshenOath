"""Render Ashen Oath's authored, sparse story motifs. Production asset build only.

No external samples, voice model, network, tests, listening pass or QA process.
The phrases share an oath motif; different endings change its harmony and rests.
"""
from pathlib import Path
from array import array
import json
import math
import wave
import argparse
import hashlib
import subprocess

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


def render(score, duration=DURATION):
    size = int(RATE * duration)
    result = array("f", [0.0]) * size
    beat = 60.0 / score["tempo"]
    # Slowly breathed open strings retain acoustic space beneath the phrase.
    for midi in score["bed"]:
        hz = frequency(midi)
        for i in range(size):
            t = i / RATE
            edge = min(1.0, t / 1.6, (duration - t) / 2.2)
            breath = .62 + .12 * math.sin(2 * math.pi * t / 8.0)
            value = math.sin(2 * math.pi * hz * t) + .17 * math.sin(2 * math.pi * hz * 2 * t + .07 * math.sin(t))
            result[i] += value * max(edge, 0) * breath * .026
    for start, midi, beats, instrument, velocity in score["events"]:
        onset = start * beat
        length = min(beats * beat + (1.6 if instrument == "bell" else .8), duration - onset)
        hz = frequency(midi)
        for j in range(max(0, int(length * RATE))):
            t = j / RATE
            attack = min(1, t / .014)
            envelope = attack * math.exp(-t * (1.65 if instrument == "plucked" else 1.05))
            envelope *= min(1, (length - t) / .35)
            if instrument == "drum":
                value = math.sin(2 * math.pi * (hz * t + 18 * (1-math.exp(-t*16)))) * math.exp(-t*11)
                value += .12 * math.sin(t*17003) * math.sin(t*13117) * math.exp(-t*40)
            elif instrument == "bell":
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


def preview_scores():
    # Original project themes: one motif, different pacing and harmonic space.
    # Samples are for listening approval, not automatic production replacement.
    motifs = [[62,69,72,64], [65,69,74,72], [67,72,76,74], [64,69,72,62]]
    village = []
    threat = []
    combat = []
    for phrase, notes in enumerate(motifs * 2):
        start = phrase * 4
        for note, pitch in enumerate(notes):
            village.append((start+note*.8,pitch,1.1,"plucked",.34 if note == 0 else .25))
        village.append((start+2.5,notes[0]-12,1.6,"plucked",.20))
        threat.append((start,notes[0]-12,2.6,"bell",.17))
        threat.append((start+2.5,notes[3]-12,.9,"plucked",.22))
        for beat in range(4):
            combat.append((start+beat,38 if beat%2 == 0 else 45,.45,"drum",.62 if beat%2 == 0 else .36))
            combat.append((start+beat+.5,notes[beat]-12,.55,"plucked",.33))
        combat.append((start,notes[0],2,"bell",.15))
    return {
        "greyfen_belonging":{"tempo":68,"bed":[50,57,65],"events":village},
        "road_uncertainty":{"tempo":64,"bed":[38,45,53],"events":threat},
        "hold_the_road":{"tempo":92,"bed":[38,45],"events":combat},
    }

def build_previews(destination):
    destination.mkdir(parents=True, exist_ok=True)
    for name, score in preview_scores().items():
        duration = 32 * 60 / score["tempo"] + 3.0
        pcm = render(score, duration)
        with wave.open(str(destination / (name+".wav")), "wb") as stream:
            stream.setnchannels(1)
            stream.setsampwidth(2)
            stream.setframerate(RATE)
            stream.writeframes(pcm.tobytes())
        print("Original listening sample:", destination / (name+".wav"))
    (destination/"sample_manifest.json").write_text(json.dumps({"source":"tools/build_story_score.py","production_replacement":False,"listening_approval":"pending","composition":"original D-A-C-E motif variations","recording":"procedural synthesis; not live instrumental performance","tracks":list(preview_scores())},indent=2)+"\n",encoding="utf-8")


def build_arrangements():
    destination = OUTPUT / "arrangements"
    destination.mkdir(parents=True, exist_ok=True)
    tracks = {}
    for name, sketch in preview_scores().items():
        events = []
        # Statement, quieter answer, development, then a sparse return. The
        # final four beats leave room for the room tail before the loop joins.
        for section, velocity in enumerate((0.90, 0.66, 1.00, 0.72)):
            for start, pitch, length, instrument, gain in sketch["events"]:
                if section == 3 and start >= 28:
                    continue
                if section == 1 and instrument == "bell" and start % 8 >= 4:
                    continue
                ornament = 12 if section == 2 and instrument == "plucked" and start % 8 == 2 else 0
                events.append((section * 32 + start, pitch + ornament, length, instrument, gain * velocity))
        score = {**sketch, "events": events}
        duration = 128 * 60 / score["tempo"]
        pcm = render(score, duration)
        # Equal-power overlap joins the acoustic tail to the opening. This is
        # asset authoring, not a runtime crossfade or a playback verification.
        overlap = int(RATE * 0.25)
        for index in range(overlap):
            angle = index / max(1, overlap - 1) * math.pi / 2
            value = pcm[index] * math.sin(angle) + pcm[len(pcm) - overlap + index] * math.cos(angle)
            pcm[index] = round(max(-32768, min(32767, value)))
        del pcm[-overlap:]
        path = destination / (name + ".wav")
        with wave.open(str(path), "wb") as stream:
            stream.setnchannels(1)
            stream.setsampwidth(2)
            stream.setframerate(RATE)
            stream.writeframes(pcm.tobytes())
        tracks[name] = {"path": "res://" + path.relative_to(ROOT).as_posix(), "frames": len(pcm), "tempo": score["tempo"], "sections": 4}
        print("Production arrangement:", path)
    manifest = {"revision": "living-road-arrangements-1", "production_replacement_authorized": True,
                "human_listening_review": "pending_user", "license": "Ashen Oath original project composition",
                "source": "tools/build_story_score.py", "recording": "procedural synthesis; not live instruments",
                "sample_rate": RATE, "tracks": tracks}
    (destination / "arrangements.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def encode_arrangements(encoder):
    destination = OUTPUT / "arrangements"
    manifest_path = destination / "arrangements.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    for name, track in manifest["tracks"].items():
        master = destination / (name + ".wav")
        target = destination / (name + ".ogg")
        subprocess.run([str(encoder), "-hide_banner", "-loglevel", "error", "-y", "-i", str(master),
                        "-map_metadata", "-1", "-c:a", "libvorbis", "-q:a", "8", str(target)], check=True)
        track.update({"path": "res://" + target.relative_to(ROOT).as_posix(),
                      "master": "res://" + master.relative_to(ROOT).as_posix(),
                      "master_sha256": hashlib.sha256(master.read_bytes()).hexdigest(),
                      "encoding": "Vorbis quality 8; original PCM master retained"})
        print("Production music encoding:", target)
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview-directory", type=Path)
    parser.add_argument("--production-arrangements", action="store_true")
    parser.add_argument("--vorbis-encoder", type=Path)
    args = parser.parse_args()
    if args.vorbis_encoder:
        encode_arrangements(args.vorbis_encoder)
        return
    if args.production_arrangements:
        build_arrangements()
        return
    if args.preview_directory:
        build_previews(args.preview_directory)
        return
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
