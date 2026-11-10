"""Pure ledger merge rules; old evidence never certifies different bytes."""
from copy import deepcopy
import hashlib
from pathlib import Path

ACCEPTANCE = ("authored", "runtime_verified", "native_verified", "visual_accepted", "user_accepted",
              "in_level_accepted", "performance_verified", "browser_accepted", "confirmed_world_usage")
SOURCE_ACCEPTANCE = ("work_apex_clay_reviewed", "source_contract_verified", "runtime_visual_acceptance")


def resource_inputs(game, paths, cache=None):
    """Fingerprint actual resources without changing the recorded audit receipts."""
    game = Path(game).resolve()
    cache = {} if cache is None else cache
    result = {}
    for path in sorted(set(paths)):
        if not isinstance(path, str) or not path.startswith("res://"):
            raise ValueError("Expected a resource input: " + str(path))
        resolved = (game / path[6:]).resolve()
        if not resolved.is_relative_to(game):
            raise ValueError("Resource input escapes the game: " + path)
        if path not in cache:
            cache[path] = hashlib.sha256(resolved.read_bytes()).hexdigest() if resolved.is_file() else None
        result[path] = cache[path]
    return result


def refresh_review(current, previous, inputs):
    """Keep annotations/history, and reuse acceptance only for bound, equal inputs.

    A legacy row without a complete fingerprint remains useful historical
    evidence. It cannot establish current acceptance from an unchanged filename.
    """
    previous = previous or {}
    result = deepcopy(previous)
    result.update(deepcopy(current))
    before = previous.get("verification_inputs", {})
    bound = bool(inputs) and all(isinstance(value, str) and len(value) == 64 for value in inputs.values())
    fresh = bound and isinstance(before, dict) and before == inputs
    changed = sorted(key for key in set(before if isinstance(before, dict) else {}) | set(inputs)
                     if not isinstance(before, dict) or before.get(key) != inputs.get(key))
    if fresh:
        for key in (*ACCEPTANCE, "life_status", "current_visual_evidence", "assessment"):
            if key in previous:
                result[key] = deepcopy(previous[key])
    else:
        source_review = previous.get("source_review", {})
        claimed = any(previous.get(key) is True for key in ACCEPTANCE)
        claimed |= isinstance(source_review, dict) and any(source_review.get(key) is True for key in SOURCE_ACCEPTANCE)
        claimed |= bool(previous.get("current_visual_evidence"))
        independent_review = any(key in previous for key in ("runtime_ownership_audit", "notes", "assessment", "evidence", "source_review"))
        if claimed or (independent_review and before != inputs):
            historical = deepcopy(previous)
            historical.pop("review_history", None)
            entry = {"reason": "verified_inputs_changed_or_unbound", "review": historical}
            history = deepcopy(previous.get("review_history", []))
            if entry not in history:
                history.append(entry)
            result["review_history"] = history
        for key in ACCEPTANCE:
            if key in result:
                result[key] = False
        if "current_visual_evidence" in result:
            result["current_visual_evidence"] = []
        if isinstance(result.get("source_review"), dict):
            for key in SOURCE_ACCEPTANCE:
                if key in result["source_review"]:
                    result["source_review"][key] = False
        if claimed and "life_status" in result:
            result["life_status"] = "changed_inputs_pending_review"
    result["verification_inputs"] = deepcopy(inputs)
    result["evidence_freshness"] = {"inputs_unchanged": fresh, "changed_inputs": changed,
                                    "unbound_inputs": sorted(key for key, value in inputs.items() if value is None)}
    return result


def preserve_removed(previous_rows, current_rows, history):
    """An asset leaving runtime scope does not erase its authored audit."""
    result = deepcopy(history)
    current_ids = {row["id"] for row in current_rows}
    for row in previous_rows:
        if row["id"] not in current_ids and row not in result:
            result.append(deepcopy(row))
    return result
