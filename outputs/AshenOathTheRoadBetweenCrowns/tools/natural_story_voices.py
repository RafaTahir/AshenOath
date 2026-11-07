"""Produce the complete synthetic cast; asset compilation, not listening QA."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import urllib.request
from story_voice_catalog import extra_utterances, role_for, canonical_speaker, source_identity, voice_directory, expansion_captions

GAME = Path(__file__).resolve().parents[1]
REPO = GAME.parents[1]
REVISION = "road-renewal-1"
MODEL_BASE = "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.1/"
MODEL = "kokoro-v1.0.onnx"
VOICES = "voices-v1.0.bin"
RECIPE_VERSION = "kokoro-cast-master-1"
ALIASES = {
    "kael":"player", "the_hunter":"player", "anwen":"sister_anwen",
    "blacksmith_tor":"tor", "tor_the_smith":"tor", "widow_elna":"elna",
    "farmer_toma":"toma", "toma_the_shepherd":"toma", "mira_fen":"mira",
    "mira_the_herbalist":"mira", "captain_senn":"senn", "sir_halvern":"halvern",
    "lord_edric":"edric", "lord_edric_vargan":"edric", "the_white_hart":"white_hart",
    "the_returned_soldier":"len", "steward_merrow":"merrow", "record_keeper_vale":"vale",
    "vargan_gate_guard":"guard", "vargan_patrol_guard":"patrol_guard",
    "tired_castle_servant":"servant",
}
PRONUNCIATION = {
    "Kael":"Kale", "Anwen":"Annwen", "Greyfen":"Grey fenn", "Wychwood":"Witch wood",
    "Vargan":"Var gan", "Senn":"Sen", "Ghoulkin":"Ghoul kin", "Oren":"Orren",
    "Toma":"Toh mah", "Merrow":"Merr oh", "Halvern":"Hal vern",
}

def speaker_id(name: str) -> str:
    value = name.lower().strip().replace("'", "").replace(" ", "_").replace("-", "_")
    return {"kael":"player", "the_hunter":"player", "anwen":"sister_anwen", "the_white_hart":"white_hart"}.get(value, value)

def pages(entry: dict):
    # Mirror DialogueManager's page speaker rules, retaining exact subtitle text.
    name = str(entry.get("name", "Unknown"))
    greeting = str(entry.get("greeting", "")).strip()
    if greeting:
        yield speaker_id(name), greeting, ""
    for raw in entry.get("lines", []):
        text = str(raw.get("text", "")) if isinstance(raw, dict) else str(raw)
        who = str(raw.get("speaker_id", speaker_id(raw.get("speaker", name)))).strip() if isinstance(raw, dict) else speaker_id(name)
        direction = str(raw.get("direction", "")) if isinstance(raw, dict) else ""
        text = text.strip()
        split = text.find(": ")
        if 0 < split < 32:
            who, text = speaker_id(text[:split]), text[split + 2:].strip()
        if text:
            yield who, text, direction

def download(url: str, path: Path):
    if path.exists():
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    print(f"Downloading production voice asset: {path.name}", flush=True)
    request = urllib.request.Request(url, headers={"User-Agent":"AshenOathVoiceProduction/2.0"})
    temporary = path.with_suffix(path.suffix + ".partial")
    with urllib.request.urlopen(request, timeout=180) as response, temporary.open("wb") as output:
        while chunk := response.read(1024 * 1024):
            output.write(chunk)
    temporary.replace(path)

def ambient_pages():
    # Read the authored bark pools directly: the game and asset build share text.
    source = (GAME / "scripts/greyfen_life_controller.gd").read_text(encoding="utf-8-sig")
    def constant(name):
        match = re.search(r"const " + name + r" := (\{.*?\n\})", source, re.S)
        if match is None:
            raise RuntimeError(f"Missing authored bark pool: {name}")
        return json.loads(match.group(1))
    profiles = constant("ROUTINE_PROFILES")
    ordinary = constant("AMBIENT_LINES")
    occupations = constant("OCCUPATION_LINES")
    post_report = constant("POST_REPORT_LINES")
    consequences = (GAME / "scripts/village_consequence_routines.gd").read_text(encoding="utf-8-sig")
    outcome_lines = [json.loads(value) for value in re.findall(r'"(?:line|witness|mercy|duty|ash)"\s*:\s*("(?:[^"\\]|\\.)*")', consequences)]
    outcome_lines.append("We keep the names, and tomorrow's work.")
    shared = [line for group in post_report.values() for line in group] + outcome_lines
    for actor_id, profile in profiles.items():
        if actor_id in ["blacksmith_tor", "mira", "rook"]:
            continue
        actor_lines = [occupations.get(actor_id, ordinary[profile["line"]]), ordinary["greyfen_keep_working"], *shared]
        for text in dict.fromkeys(actor_lines):
            yield "ambient:" + actor_id, actor_id, text, "everyday"

def utterances(cast):
    # Keep separate catalogs: merging by scene ID would discard a source variant.
    for source in ("dialogue.json", "campaign_dialogue.json", "interaction_scenes.json"):
        entries = json.loads((GAME / "data" / source).read_text(encoding="utf-8-sig"))
        for scene_id, base in entries.items():
            for entry in [base, *[{**base, **variant} for variant in base.get("variants", [])]]:
                for who, text, direction in pages(entry):
                    role = role_for(GAME, who, ALIASES)
                    if role in cast:
                        if who == "guard" and scene_id == "vargan_patrol": role = "patrol_guard"
                        yield source_identity(scene_id, entry), who, text, role, direction or str(entry.get("voice_direction", ""))
    topics = json.loads((GAME / "data/conversation_topics.json").read_text(encoding="utf-8-sig"))
    for topic in topics.get("topics", []):
        for entry in [topic, *[{**topic, **variant} for variant in topic.get("variants", [])]]:
            for who, text, direction in pages(entry):
                role = role_for(GAME, who, ALIASES)
                if role not in cast:
                    raise RuntimeError(f"Uncast conversation speaker: {who}")
                yield "conversation_topic:" + topic["id"], who, text, role, direction
    for scene, who, text, direction in ambient_pages():
        yield scene, who, text, role_for(GAME, who, ALIASES), direction
    yield from extra_utterances(GAME, cast, ALIASES, pages)


def baseline_inventory(reference, current_cast):
    """Collect the retained release's text without checking it out or loading models."""
    global GAME
    commit = subprocess.check_output(["git", "-C", str(REPO), "rev-parse", "--verify", reference + "^{commit}"], text=True).strip()
    files = ["data/" + name + ".json" for name in ("dialogue", "campaign_dialogue", "interaction_scenes", "conversation_topics", "design_pack_cast", "people_place_scenes", "everyday_scenes", "everyday_life", "regional_performances", "cast_life", "voice_cast")]
    files += ["scripts/" + name + ".gd" for name in ("greyfen_life_controller", "village_consequence_routines", "saga_catalog", "saga_activities", "story_scene_direction", "everyday_life")]
    prefix = GAME.relative_to(REPO).as_posix()
    current_game = GAME
    with tempfile.TemporaryDirectory(prefix="ashen-voice-baseline-") as folder:
        baseline = Path(folder)
        for relative in files:
            content = subprocess.check_output(["git", "-C", str(REPO), "show", commit + ":" + prefix + "/" + relative])
            target = baseline / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(content)
        old_cast = json.loads((baseline / "data/voice_cast.json").read_text(encoding="utf-8-sig"))["roles"]
        try:
            GAME = baseline
            keys = {(scene, canonical_speaker(baseline, who), text) for scene, who, text, _, _ in utterances(current_cast)}
        finally:
            GAME = current_game
    return commit, keys, old_cast


def prioritize_required(scheduled, baseline_keys, baseline_cast, current_cast):
    # A new scene may reuse a short reply whose older scene was subtitle-only.
    # Process the required source first, before canonical-text deduplication.
    def priority(row):
        scene, who, text, role, _ = row
        required = (scene, canonical_speaker(GAME, who), text) not in baseline_keys or baseline_cast.get(role) != current_cast[role]
        return (not required, voice_directory(scene) != "community")
    return sorted(scheduled, key=priority)

def delivery_speed(profile, text, scene, direction):
    # Kokoro supports cadence, not free-form acting instructions. Never speak
    # stage directions or pretend that speed changes are emotion conditioning.
    speed = float(profile["speed"])
    if any(term in direction.lower() for term in ("exhaust", "grief", "quiet", "intimate")):
        speed *= 0.97
    if scene.startswith("opening_care_") or "orens_coat" in scene or "preserved_words" in scene:
        speed *= 0.97
    if text.lower().startswith(("i left", "i abandoned", "i never went back")):
        speed *= 0.96
    return round(max(0.90, min(speed, 1.08)), 3)

def master(samples, rate, np):
    samples = np.asarray(samples, dtype=np.float32).reshape(-1)
    if not len(samples):
        raise RuntimeError("Speech synthesis produced an empty asset")
    # Remove DC, retain internal breaths and punctuation pauses, trim only the
    # outer silence, then use bounded gain instead of crushing voice dynamics.
    samples -= float(samples.mean())
    edges = np.flatnonzero(np.abs(samples) > 0.003)
    if len(edges):
        samples = samples[max(0, edges[0] - int(rate * 0.06)):min(len(samples), edges[-1] + int(rate * 0.13))]
    voiced = samples[np.abs(samples) > 0.012]
    if len(voiced):
        rms = max(float(np.sqrt(np.mean(voiced ** 2))), 0.001)
        gain = min(2.0, max(0.5, 10 ** (-19 / 20) / rms))
        peak = max(float(np.max(np.abs(samples))), 0.001)
        samples *= min(gain, 0.89 / peak)
    ramp = min(int(rate * 0.005), len(samples) // 2)
    if ramp:
        samples[:ramp] *= np.linspace(0, 1, ramp)
        samples[-ramp:] *= np.linspace(1, 0, ramp)
    return samples

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--runtime", type=Path, default=REPO / "work/natural-voice-runtime")
    parser.add_argument("--models", type=Path, default=REPO / "work/natural-voice-models")
    parser.add_argument("--all-scenes", action="store_true", help="Compatibility flag; full cast is always produced")
    parser.add_argument("--dialogue-only", action="store_true", help="Finish dialogue while leaving village remarks pending")
    parser.add_argument("--finalize-existing", action="store_true", help="Publish completed upgrades and retain earlier recordings without further synthesis")
    parser.add_argument("--collect-only", type=Path, help="Write exact runtime tuples without importing inference or producing audio")
    parser.add_argument("--incremental", action="store_true", help="Keep existing exact canonical-speaker performances and produce only missing lines")
    parser.add_argument("--retained-assets-from", type=Path, help="Read retained audio from a verified source checkout; never write into it")
    parser.add_argument("--new-directory", choices=["story", "living_cast", "community"], default="story")
    parser.add_argument("--recipes", type=Path, help="Separate writable recipe cache when model files are shared read-only")
    parser.add_argument("--max-new-bytes", type=int, default=16 * 1024 * 1024, help="Combined living_cast/community voice budget")
    parser.add_argument("--threads", type=int, default=1, help="Bound inference concurrency on the shared workstation")
    parser.add_argument("--baseline-ref", help="With --incremental, synthesize new runtime text and changed cast recipes; retain pre-existing subtitle-only lines")
    args = parser.parse_args()
    cast_data = json.loads((GAME / "data/voice_cast.json").read_text(encoding="utf-8-sig"))
    cast = cast_data["roles"]
    scheduled = list(utterances(cast))
    baseline_commit, baseline_keys, baseline_cast = "", set(), {}
    if args.baseline_ref:
        if not args.incremental: parser.error("--baseline-ref requires --incremental")
        baseline_commit, baseline_keys, baseline_cast = baseline_inventory(args.baseline_ref, cast)
        scheduled = prioritize_required(scheduled, baseline_keys, baseline_cast, cast)
    if args.collect_only:
        rows = [{"source_id":scene, "speaker_id":who, "canonical_speaker":canonical_speaker(GAME, who), "text":text,
                 "text_sha256":hashlib.sha256(text.encode("utf-8")).hexdigest(), "cast_role":role, "direction":direction,
                 "required_new_or_recipe_changed":not baseline_commit or (scene, canonical_speaker(GAME, who), text) not in baseline_keys or baseline_cast.get(role) != cast[role],
                 "directory":voice_directory(scene, args.new_directory)}
                for scene, who, text, role, direction in scheduled]
        captions = list(expansion_captions(GAME, pages))
        for caption in captions:
            caption["canonical_speaker"] = caption["speaker_id"]
            caption["text_sha256"] = hashlib.sha256(caption["text"].encode("utf-8")).hexdigest()
        args.collect_only.parent.mkdir(parents=True, exist_ok=True)
        args.collect_only.write_text(json.dumps({"lines":rows, "captions":captions, "baseline_commit":baseline_commit, "synthesis_performed":False}, indent=2, ensure_ascii=False)+"\n", encoding="utf-8")
        print(f"Collected {len(rows)} runtime tuples; no audio generated.")
        return
    sys.path.insert(0, str(args.runtime))
    import numpy as np
    import onnxruntime as ort
    import soundfile as sf
    from kokoro_onnx import Kokoro

    for asset in [MODEL, VOICES]:
        download(MODEL_BASE + asset, args.models / asset)
    credits = GAME / "docs/audio"
    credits.mkdir(parents=True, exist_ok=True)
    for remote, local in [("README.md", "KOKORO_MODEL_CARD.md"), ("VOICES.md", "KOKORO_VOICES.md")]:
        download("https://huggingface.co/hexgrad/Kokoro-82M/resolve/main/" + remote, credits / local)
    download("https://www.apache.org/licenses/LICENSE-2.0.txt", credits / "KOKORO_LICENSE.txt")
    options = ort.SessionOptions()
    options.intra_op_num_threads = max(1, min(args.threads, os.cpu_count() or 1))
    options.inter_op_num_threads = 1
    engine = None
    styles = {}
    if not args.finalize_existing:
        session = ort.InferenceSession(str(args.models / MODEL), sess_options=options, providers=["CPUExecutionProvider"])
        engine = Kokoro.from_session(session, str(args.models / VOICES))
        styles = {role: sum(engine.get_voice_style(name) * weight for name, weight in profile["voices"].items()) / sum(profile["voices"].values()) for role, profile in cast.items()}
    recipe_cache = args.recipes or args.models / "render-recipes"
    recipe_cache.mkdir(parents=True, exist_ok=True)
    lines, seen = [], set()
    prior_path = GAME / "voice_production_manifest.json"
    prior = json.loads(prior_path.read_text(encoding="utf-8-sig")) if prior_path.exists() else {}
    previous_lines = {line["page_key"]:line for line in prior.get("lines", [])}
    canonical_previous = {}
    for line in prior.get("lines", []):
        identity = canonical_speaker(GAME, str(line.get("speaker_id", "")))
        canonical_previous.setdefault((identity, str(line.get("text", ""))), []).append(line)
    if args.incremental:
        lines = list(prior.get("lines", []))
    retained, pending, legacy_subtitle_only = 0, [], []
    synthesized = 0
    print(f"Producing full cast: {len({(who, text) for _, who, text, _, _ in scheduled})} exact-text recordings", flush=True)
    for scene, who, text, role, direction in scheduled:
        identity = canonical_speaker(GAME, who)
        key = hashlib.sha256(((identity if args.incremental else who) + "|" + text).encode("utf-8")).hexdigest()
        if key in seen: continue
        seen.add(key)
        if args.incremental:
            reusable = False
            for existing in canonical_previous.get((identity, text), []):
                if existing.get("cast_role") != role or existing.get("text_sha256") != hashlib.sha256(text.encode("utf-8")).hexdigest(): continue
                if prior.get("roles", {}).get(role) != cast[role]: continue
                path = str(existing.get("path", ""))
                if not path.startswith("res://assets_external/audio/voices/"): continue
                relative = Path(path[6:])
                if ".." in relative.parts: raise ValueError("Retained voice path escapes asset root")
                candidates = [GAME / relative]
                if args.retained_assets_from: candidates.append(args.retained_assets_from.resolve() / relative)
                for candidate in candidates:
                    if not candidate.is_file(): continue
                    actual_hash = hashlib.sha256(candidate.read_bytes()).hexdigest()
                    if existing.get("audio_sha256") and existing["audio_sha256"] != actual_hash:
                        raise ValueError("Retained voice bytes changed: " + str(candidate))
                    existing["audio_sha256"] = actual_hash
                    existing["audio_bytes"] = candidate.stat().st_size
                    reusable = True
                    break
                if reusable: break
            if reusable:
                lines = [line for line in lines if (canonical_speaker(GAME, str(line.get("speaker_id", ""))), str(line.get("text", ""))) != (identity, text)]
                selected = dict(existing)
                selected.update(speaker_id=identity, page_key=key, retained_previous_performance=True)
                lines.append(selected)
                retained += 1
                continue
        if baseline_commit and (scene, identity, text) in baseline_keys and baseline_cast.get(role) == cast[role]:
            # An unverified stale manifest row must not defeat subtitle fallback.
            lines = [line for line in lines if (canonical_speaker(GAME, str(line.get("speaker_id", ""))), str(line.get("text", ""))) != (identity, text)]
            legacy_subtitle_only.append({"scene":scene, "speaker_id":who, "page_key":key})
            continue
        if args.dialogue_only and scene.startswith("ambient:"):
            pending.append({"scene":scene, "speaker_id":who, "page_key":key})
            continue
        profile = cast[role]
        speed = delivery_speed(profile, text, scene, direction)
        spoken = text.replace("—", ", ").replace("…", "... ")
        for term, pronunciation in PRONUNCIATION.items():
            spoken = re.sub(r"\b" + re.escape(term) + r"\b", pronunciation, spoken)
        recipe = {"version":RECIPE_VERSION, "cast_revision":cast_data["revision"], "model":cast_data["model"], "role":role, "profile":profile, "speed":speed, "spoken":spoken}
        recipe_hash = hashlib.sha256(json.dumps(recipe, sort_keys=True).encode("utf-8")).hexdigest()
        stamp = recipe_cache / (key + ".txt")
        output = GAME / "assets_external/audio/voices" / voice_directory(scene, args.new_directory)
        output.mkdir(parents=True, exist_ok=True)
        clip = output / (key + ".ogg")
        if clip.exists() and stamp.exists() and stamp.read_text(encoding="utf-8") == recipe_hash and previous_lines.get(key, {}).get("render_recipe_sha256") == recipe_hash:
            lines.append(previous_lines[key])
            continue
        if not clip.exists() or not stamp.exists() or stamp.read_text(encoding="utf-8") != recipe_hash:
            if args.finalize_existing:
                if key in previous_lines and clip.exists() and not stamp.exists():
                    existing = dict(previous_lines[key])
                    existing["cast_role"] = role
                    existing["retained_previous_performance"] = True
                    lines.append(existing)
                    retained += 1
                else:
                    pending.append({"scene":scene, "speaker_id":who, "page_key":key})
                continue
            samples, rate = engine.create(spoken, voice=styles[role], speed=speed, lang=profile["lang"])
            samples = master(samples, rate, np)
            partial = clip.with_suffix(".ogg.partial")
            sf.write(partial, samples, rate, format="OGG", subtype="VORBIS")
            partial.replace(clip)
            synthesized += 1
            stamp.write_text(recipe_hash, encoding="utf-8")
            print(f"Produced {len(lines) + 1}: {scene} / {role}", flush=True)
        # Decode the delivered codec to bake the same timing that players hear.
        samples, rate = sf.read(clip, dtype="float32", always_2d=True)
        mono = samples.mean(axis=1)
        hop = max(1, int(rate / 30))
        rms = np.array([float(np.sqrt(np.mean(mono[i:i + hop] ** 2))) for i in range(0, len(mono), hop)])
        reference = max(float(np.percentile(rms, 95)), 0.01) if len(rms) else 0.01
        if args.incremental:
            # Canonical aliases share the new performance; do not leave an old
            # cast recipe competing for the same character and exact text.
            lines = [line for line in lines if (canonical_speaker(GAME, str(line.get("speaker_id", ""))), str(line.get("text", ""))) != (identity, text)]
        lines.append({"id":"story_" + key[:20], "speaker_id":identity if args.incremental else who, "cast_role":role, "text":text,
            "text_sha256":hashlib.sha256(text.encode("utf-8")).hexdigest(), "page_key":key,
            "narrative_revision":REVISION, "path":"res://" + clip.relative_to(GAME).as_posix(), "scene":scene,
            "production_mode":"generated", "human_reviewed":False, "review_status":"pending_listening_review",
            "status":"generated_current", "voice_model":cast_data["model"], "render_recipe_sha256":recipe_hash,
            "audio_sha256":hashlib.sha256(clip.read_bytes()).hexdigest(), "audio_bytes":clip.stat().st_size,
            "speech_envelope_hz":rate / hop, "speech_envelope":np.round(np.clip((rms - 0.008) / reference, 0, 1), 3).tolist(),
            "duration_seconds":len(mono) / rate, "delivery_speed":speed})
    new_bytes = sum(path.stat().st_size for folder in ["living_cast", "community"] for path in (GAME / "assets_external/audio/voices" / folder).glob("*.ogg"))
    if new_bytes > args.max_new_bytes:
        raise RuntimeError(f"New dialogue audio exceeds its budget: {new_bytes} > {args.max_new_bytes}; candidate remains local")
    manifest = {"ticket":"VOICE-CAST-003", "status":"generated_current_unreviewed", "narrative_revision":REVISION,
        "cast_revision":cast_data["revision"], "authoritative_delivery":"subtitles", "allow_generated_current_recordings":True,
        "human_reviewed":False, "review_status":"pending_listening_review", "production_mode":"generated",
        "source":"Kokoro-82M v1.0 full precision; kokoro-onnx 0.6.1", "source_url":"https://huggingface.co/hexgrad/Kokoro-82M",
        "attribution":"Kokoro by hexgrad, Apache-2.0 model weights. kokoro-onnx by thewh1teagle, MIT build-time runtime.",
        "pronunciation":PRONUNCIATION, "roles":cast, "lines":lines}
    manifest["retained_previous_recordings"] = retained
    manifest["synthesized_this_run"] = synthesized
    manifest["new_dialogue_bytes"] = new_bytes
    manifest["pending_recordings"] = pending
    manifest["baseline_commit"] = baseline_commit
    manifest["retained_legacy_subtitle_only"] = legacy_subtitle_only
    manifest["publication_mode"] = "incremental_living_cast" if args.incremental else ("completed_upgrades_with_existing_fallbacks" if args.finalize_existing else ("dialogue_complete" if args.dialogue_only else "full_cast"))
    if retained and not args.incremental:
        manifest["source"] += "; retained Piper VCTK recordings for unfinished replacements"
        manifest["attribution"] += " Retained Piper/VCTK performances retain their original provenance and VCTK attribution."
    manifest_path = GAME / "voice_production_manifest.json"
    temporary = manifest_path.with_suffix(".json.partial")
    temporary.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    temporary.replace(manifest_path)
    counts = {role:sum(line["cast_role"] == role for line in lines) for role in cast}
    summary = "\n".join(f"| {role} | {count} |" for role, count in counts.items())
    (credits / "VOICE_PRODUCTION.md").write_text(
        "# Natural cast production\n\nKokoro-82M v1.0 full-precision synthesis replaces the previous Piper performances. "
        "These are generated voices, not a human cast or cloned actor performances. This compiler does not perform listening or gameplay acceptance. "
        "Written notices and narration stay text-led. Dialogue, optional conversation topics and supporting characters are included; pending village remarks remain caption-led.\n\n"
        "Cast recipes in `data/voice_cast.json` preserve identity using fixed model voice blends. Cadence is adjusted conservatively for intimate scenes. "
        "Character direction notes guide casting and cadence; Kokoro does not interpret free-form emotional acting prompts. "
        "Outer-silence trimming, bounded mastering gain and short click ramps preserve internal pauses and dynamics. "
        "No pitch-shifting or artificial ghost effects are used. The speech envelopes are baked from each final Ogg file.\n\n"
        "The model and inference dependencies stay under ignored work directories. Only compressed audio, recipes and provenance ship. "
        "Kokoro's Apache-2.0 model card, license and voice table are retained here. The old VCTK attribution remains for historical provenance.\n\n"
        f"Manifest contains {len(lines)} exact-text performances. This run synthesized {synthesized} files and reused {retained} scheduled performances. "
        f"{len(pending)} collected recordings remain unproduced and use subtitles until completed.\n\n"
        f"| Cast role | Clips |\n|---|---:|\n{summary}\n", encoding="utf-8")
    print(f"Voice candidate: {synthesized} synthesized files, {retained} reused performances, {len(pending)} pending; {new_bytes} new-dialogue bytes. Publication and listening acceptance are separate.", flush=True)

if __name__ == "__main__":
    main()
