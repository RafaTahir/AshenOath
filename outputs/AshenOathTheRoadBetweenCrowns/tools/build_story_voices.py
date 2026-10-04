"""Produce version-bound campaign performances. This is an asset build, not a listening review."""
from __future__ import annotations
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import sys
import urllib.request
import wave

GAME = Path(__file__).resolve().parents[1]
REPO = GAME.parents[1]
REVISION = "road-renewal-1"
MODEL_BASE = "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_GB/vctk/medium/"
MODEL_NAME = "en_GB-vctk-medium.onnx"
ROLE_PROFILES = {
    "player": ("p226", 1.12), "sister_anwen": ("p225", 1.24),
    "rook": ("p232", 1.06), "mira": ("p228", 1.13),
    "tor": ("p227", 1.23), "elna": ("p229", 1.25),
    "toma": ("p231", 1.10), "edric": ("p243", 1.19),
    "halvern": ("p241", 1.30), "senn": ("p246", 1.18),
    "white_hart": ("p225", 1.38), "len": ("p226", 1.31),
}
ALIASES = {"kael":"player", "the_hunter":"player", "anwen":"sister_anwen", "sister_anwen":"sister_anwen", "the_white_hart":"white_hart", "white_hart":"white_hart", "captain_senn":"senn", "lord_edric":"edric", "mira_the_herbalist":"mira", "tor_the_smith":"tor", "toma_the_shepherd":"toma", "the_returned_soldier":"len"}
KEY_SCENES = {"sister_anwen", "rook", "mira", "tor", "elna", "toma", "report_decision", "crow_shrine_choice", "bog_core_choice", "names_decision", "miller_record", "captain_senn", "edric_campaign", "vargan_ledger_choice", "halvern", "assembly_choice", "white_hart", "greyfen_cart_work", "edric_proclamation", "renewal_record"}
PRONUNCIATION = {"Kael":"Kale", "Anwen":"Ann wen", "Greyfen":"Grey fenn", "Wychwood":"Witch wood", "Vargan":"Var gan", "Senn":"Sen", "Ghoulkin":"Ghoul kin"}

def speaker_id(name: str) -> str:
    value = name.lower().strip().replace("'", "").replace(" ", "_").replace("-", "_")
    return {"kael":"player", "the_hunter":"player", "anwen":"sister_anwen", "the_white_hart":"white_hart"}.get(value, value)

def pages(entry: dict):
    name = str(entry.get("name", "Unknown"))
    greeting = str(entry.get("greeting", "")).strip()
    if greeting:
        yield speaker_id(name), greeting
    for raw in entry.get("lines", []):
        text = str(raw.get("text", "")) if isinstance(raw, dict) else str(raw)
        text = text.strip()
        who = str(raw.get("speaker_id", speaker_id(raw.get("speaker", name)))) if isinstance(raw, dict) else speaker_id(name)
        split = text.find(": ")
        if 0 < split < 32:
            who, text = speaker_id(text[:split]), text[split+2:].strip()
        if text:
            yield who, text

def download(url: str, path: Path):
    if path.exists():
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    print(f"Downloading voice asset {path.name}", flush=True)
    request = urllib.request.Request(url, headers={"User-Agent":"AshenOathVoiceProduction/1.0"})
    temporary = path.with_suffix(path.suffix + ".partial")
    with urllib.request.urlopen(request, timeout=180) as response, temporary.open("wb") as output:
        while chunk := response.read(1024 * 1024):
            output.write(chunk)
    temporary.replace(path)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--runtime", type=Path, default=REPO / "work/voice-runtime")
    parser.add_argument("--models", type=Path, default=REPO / "work/voice-models")
    parser.add_argument("--all-scenes", action="store_true")
    args = parser.parse_args()
    sys.path.insert(0, str(args.runtime))
    from piper import PiperVoice, SynthesisConfig
    import soundfile as sf
    import numpy as np
    model = args.models / MODEL_NAME
    download(MODEL_BASE + MODEL_NAME, model)
    download(MODEL_BASE + MODEL_NAME + ".json", Path(str(model) + ".json"))
    download(MODEL_BASE + "MODEL_CARD", args.models / "VCTK_MODEL_CARD.txt")
    config = json.loads(Path(str(model) + ".json").read_text(encoding="utf-8"))
    voice = PiperVoice.load(str(model), use_cuda=False)
    output = GAME / "assets_external/audio/voices/story"
    output.mkdir(parents=True, exist_ok=True)
    credits = GAME / "docs/audio"
    credits.mkdir(parents=True, exist_ok=True)
    (credits / "VCTK_MODEL_CARD.txt").write_text((args.models / "VCTK_MODEL_CARD.txt").read_text(encoding="utf-8"), encoding="utf-8")
    entries = {}
    for source in ("dialogue.json", "campaign_dialogue.json", "interaction_scenes.json"):
        path = GAME / "data" / source
        if path.exists():
            entries.update(json.loads(path.read_text(encoding="utf-8-sig")))
    topics_path = GAME / "data" / "conversation_topics.json"
    if args.all_scenes and topics_path.exists():
        catalog = json.loads(topics_path.read_text(encoding="utf-8-sig"))
        for topic in catalog.get("topics", []):
            entries["conversation_topic:" + topic["id"]] = topic
    lines, seen = [], set()
    for scene_id, base in entries.items():
        if not args.all_scenes and scene_id not in KEY_SCENES and not scene_id.startswith("witness_"):
            continue
        variants = [base] + [{**base, **variant} for variant in base.get("variants", [])]
        for entry in variants:
            for who, text in pages(entry):
                role = ALIASES.get(who, who)
                if role not in ROLE_PROFILES:
                    continue
                key = hashlib.sha256((who + "|" + text).encode("utf-8")).hexdigest()
                if key in seen:
                    continue
                seen.add(key)
                clip = output / (key + ".ogg")
                speaker, pace = ROLE_PROFILES[role]
                if not clip.exists():
                    spoken = text
                    for term, pronunciation in PRONUNCIATION.items():
                        spoken = re.sub(r"\b" + re.escape(term) + r"\b", pronunciation, spoken)
                    syn = SynthesisConfig(speaker_id=config["speaker_id_map"][speaker], length_scale=pace, noise_scale=0.40, noise_w_scale=0.45, volume=0.85, normalize_audio=True)
                    buffer = io.BytesIO()
                    with wave.open(buffer, "wb") as wav:
                        voice.synthesize_wav(spoken, wav, syn_config=syn)
                    buffer.seek(0)
                    samples, rate = sf.read(buffer, dtype="float32")
                    # Bounded head/tail ramps avoid clicks without changing cadence.
                    ramp = min(int(rate * 0.008), len(samples) // 2)
                    if ramp:
                        samples[:ramp] *= np.linspace(0, 1, ramp)
                        samples[-ramp:] *= np.linspace(1, 0, ramp)
                    # Interrupted production must not leave a partial file at
                    # the exact-text cache key used by later resumed builds.
                    partial_clip = clip.with_suffix(".ogg.partial")
                    sf.write(partial_clip, samples, rate, format="OGG", subtype="VORBIS")
                    partial_clip.replace(clip)
                    print(f"Voiced {scene_id}: {who} ({len(lines)+1})", flush=True)
                lines.append({"id":"story_" + key[:20], "speaker_id":who, "text":text, "text_sha256":hashlib.sha256(text.encode("utf-8")).hexdigest(), "page_key":key, "narrative_revision":REVISION, "path":"res://" + clip.relative_to(GAME).as_posix(), "scene":scene_id, "production_mode":"generated", "human_reviewed":False, "review_status":"not_performed_user_requested", "status":"generated_current", "voice_model":"en_GB-vctk-medium", "model_speaker":speaker})
    manifest = {"ticket":"VOICE-STORY-002", "status":"generated_current_unreviewed", "narrative_revision":REVISION, "authoritative_delivery":"subtitles", "allow_generated_current_recordings":True, "human_reviewed":False, "review_status":"not_performed_user_requested", "production_mode":"generated", "source":"Piper 1.4.1; VCTK medium multi-speaker model", "source_url":MODEL_BASE, "attribution":"VCTK corpus: CSTR, University of Edinburgh, Junichi Yamagishi, Christophe Veaux and Kirsten MacDonald. Model card and attribution retained in docs/audio/VCTK_MODEL_CARD.txt.", "pronunciation":PRONUNCIATION, "roles":{role:{"model_speaker":value[0], "length_scale":value[1]} for role,value in ROLE_PROFILES.items()}, "lines":lines}
    # Bake delivery motion from the actual recording, including its silences.
    for line in lines:
        samples, rate = sf.read(GAME / line["path"].removeprefix("res://"), dtype="float32", always_2d=True)
        mono = samples.mean(axis=1)
        hop = max(1, int(rate / 30))
        rms = np.array([float(np.sqrt(np.mean(mono[i:i + hop] ** 2))) for i in range(0, len(mono), hop)])
        reference = max(float(np.percentile(rms, 95)), 0.01) if len(rms) else 0.01
        line["speech_envelope_hz"] = rate / hop
        line["speech_envelope"] = np.round(np.clip((rms - 0.008) / reference, 0, 1), 3).tolist()
        line["duration_seconds"] = len(mono) / rate
    (GAME / "voice_production_manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    (credits / "VOICE_PRODUCTION.md").write_text("# Current campaign voice production\n\nThese clips are newly generated from the revised campaign text using Piper and the VCTK model. They are synthetic performances, not recordings by a cast, and have not received a listening or human-performance review under the user's no-verification instruction. Each clip is tied to the exact speaker and displayed text with a page hash. Mismatched or absent pages remain subtitle-led. Advancing a page interrupts its clip; speech never auto-selects a decision.\n\nThe inference engine and model remain build-time dependencies under the ignored work directory. Only generated compressed clips and their provenance are shipped. Model-card attribution is included alongside this document.\n", encoding="utf-8")
    print(f"Generated campaign voice manifest: {len(lines)} exact-text clips", flush=True)

if __name__ == "__main__":
    main()
