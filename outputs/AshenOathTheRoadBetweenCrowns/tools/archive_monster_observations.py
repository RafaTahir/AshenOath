#!/usr/bin/env python3
"""Archive explicitly selected small QA receipts and optional exact PNGs.

Never crawl a run tree, follow reparse points, open profiles/PCKs, or rehash art
sources. Source/artifact hashes declared by immutable run receipts remain labelled
as declarations; only copied receipts and selected images are rehashed here.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import stat
import sys

CATEGORIES = {"source_preview", "frozen_export_native", "live_route_performance", "publication", "fixture"}
DEFAULT_REPORTS = ("runner.json", "report.json", "smoke.json", "preparation.json", "comparison.json",
                   "mechanics/report.json", "mechanics/mechanics.json", "desktop/smoke.json", "touch/smoke.json",
                   "stdout.log", "godot.log", "engine.log", "desktop/engine.log", "touch/engine.log")
FORBIDDEN = {"profile", "profiles", "decoded", "isolated_project", "resource-root", ".godot"}
MAX_RECEIPT = 8 * 1024 * 1024
MAX_IMAGE = 8 * 1024 * 1024
MAX_ARCHIVE = 48 * 1024 * 1024


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def relative(value: str) -> str:
    if not value or "\\" in value or ":" in value or "\x00" in value:
        raise ValueError("relative archive path required: " + repr(value))
    path = PurePosixPath(value)
    parts = value.split("/")
    if path.is_absolute() or any(part in {"", ".", ".."} or part.casefold() in FORBIDDEN for part in parts):
        raise ValueError("forbidden archive path: " + value)
    return value


def regular_path(root: Path, name: str) -> Path:
    current = root
    for part in ("", *relative(name).split("/")):
        if part: current = current / part
        info = current.lstat()
        if stat.S_ISLNK(info.st_mode) or getattr(info, "st_file_attributes", 0) & stat.FILE_ATTRIBUTE_REPARSE_POINT:
            raise ValueError("reparse-point traversal is forbidden: " + str(current))
    if not current.is_file() or not current.resolve().is_relative_to(root.resolve()):
        raise ValueError("archive input is not a contained regular file: " + str(current))
    return current


def declared_hashes(value, pointer="") -> list[dict]:
    rows = []
    if isinstance(value, dict):
        for key, entry in value.items():
            if isinstance(entry, str) and key.endswith("sha256") and re.fullmatch(r"[0-9a-f]{64}", entry):
                rows.append({"pointer":pointer + "/" + key, "sha256":entry,
                             "hash_field":key,
                             "hash_role":"file_content" if key == "sha256" else "semantic_or_associated",
                             "declared_path":value.get("path", value.get("source", value.get("file", ""))),
                             "verification":"copied receipt declaration; original source/artifact not reopened"})
            if isinstance(entry, (dict, list)):
                rows.extend(declared_hashes(entry, pointer + "/" + str(key)))
    elif isinstance(value, list):
        for index, entry in enumerate(value): rows.extend(declared_hashes(entry, pointer + "/" + str(index)))
    return rows


def observed_status(documents: list[dict]) -> str:
    for document in documents:
        if document.get("status") in {"fail", "failed", "cancelled", "error"} or document.get("passed") is False:
            return "failed_diagnostics"
        if document.get("failures") or document.get("engine_error_lines") or document.get("engine_errors"):
            return "failed_diagnostics"
    if any(document.get("status") in {"pass", "passed"} or document.get("passed") is True for document in documents):
        return "passing_observation"
    return "incomplete_diagnostics"


def archive(runs: list[tuple[str, str, Path]], extras: list[tuple[str, str]],
            images: list[tuple[str, str]], output: Path) -> dict:
    if output.exists(): raise ValueError("archive output already exists; preserve prior evidence")
    sources = {}
    for category, label, root in runs:
        if category not in CATEGORIES or not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9_-]{0,79}", label) or label in sources:
            raise ValueError("distinct safe run label and explicit supported category required")
        if not root.is_absolute(): raise ValueError("run directories must be absolute")
        sources[label] = {"category":category, "root":root, "files":[], "documents":[], "images":[]}
    if not sources: raise ValueError("at least one explicit run directory is required")
    if len(images) != len(set(images)): raise ValueError("selected PNGs must be distinct")
    for label, name in extras + images:
        if label not in sources: raise ValueError("unknown selected run: " + label)
        relative(name)
    copies, records, total = [], [], 0
    for label, source in sources.items():
        root = source["root"]
        selected_reports = list(DEFAULT_REPORTS)
        selected_reports.extend(name for chosen, name in extras if chosen == label)
        for name in dict.fromkeys(selected_reports):
            try:
                path = regular_path(root, name)
            except FileNotFoundError:
                if (label, name) in extras: raise ValueError("selected report missing: " + str(root / name))
                continue
            if path.suffix.casefold() not in {".json", ".log"}: raise ValueError("only small JSON/log receipts may be selected")
            if path.stat().st_size > MAX_RECEIPT: raise ValueError("receipt exceeds bounded small-file allowance: " + str(path))
            data = path.read_bytes()
            document = json.loads(data.decode("utf-8-sig")) if path.suffix.casefold() == ".json" else None
            if isinstance(document, dict): source["documents"].append(document)
            source["files"].append({"file":name, "bytes":len(data), "sha256":sha(data),
                                     "declared_hashes":declared_hashes(document) if document is not None else []})
            copies.append((label, name, data))
            total += len(data)
        if not source["documents"]: raise ValueError("run has no small JSON evidence: " + label)
        for chosen, name in images:
            if chosen != label: continue
            path = regular_path(root, name)
            if path.suffix.casefold() != ".png" or path.stat().st_size > MAX_IMAGE:
                raise ValueError("only bounded explicit PNG selections may be archived")
            data = path.read_bytes()
            if not data.startswith(b"\x89PNG\r\n\x1a\n"): raise ValueError("selected image is not PNG")
            exact = sha(data)
            matched = [row for record in source["files"] for row in record["declared_hashes"]
                       if row["hash_field"] == "sha256"
                       and str(row["declared_path"]).replace("\\", "/").casefold() == str(path).replace("\\", "/").casefold()]
            if any(row["sha256"] != exact for row in matched): raise ValueError("selected PNG differs from its run receipt: " + str(path))
            source["images"].append({"file":name, "bytes":len(data), "sha256":exact,
                                       "matched_declared_image_hash":bool(matched), "visual_acceptance":False})
            copies.append((label, name, data))
            total += len(data)
        status = observed_status(source["documents"])
        destination = ("observations" if status == "passing_observation" else "diagnostics") + "/" + source["category"] + "/" + label
        records.append({"label":label, "category":source["category"], "observed_status":status,
                        "source_directory":str(root), "archive_directory":destination,
                        "receipts":source["files"], "selected_images":source["images"]})
    if total > MAX_ARCHIVE: raise ValueError("compact archive exceeds 48 MiB; select fewer images/reports")
    destinations = {row["label"]:row["archive_directory"] for row in records}
    output.mkdir(parents=True, exist_ok=False)
    for label, name, data in copies:
        path = output / destinations[label] / name
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("xb") as stream: stream.write(data)
    result = {"schema_version":1, "kind":"monster_observation_archive", "copied_bytes":total,
              "runs":records, "source_assets_rehashed":False, "profile_or_pack_directories_copied":False,
              "visual_acceptance":False, "user_acceptance":False, "deployment_confirmed_by_archive":False,
              "limitations":"Categories remain distinct. Passing receipts establish only their stated checks. Copied hash declarations are not fresh source verification; selected PNG bytes are freshly verified. Native material controls are not automatically pre-edit deployment screenshots."}
    with (output / "archive.json").open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(result, stream, indent=2)
        stream.write("\n")
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="append", required=True, help="category:label=absolute-run-directory")
    parser.add_argument("--report", action="append", default=[], help="label=relative-small-report.json (or .log)")
    parser.add_argument("--image", action="append", default=[], help="label=relative-explicit-selected.png")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        runs = []
        for entry in args.run:
            identity, path = entry.split("=", 1)
            category, label = identity.split(":", 1)
            runs.append((category, label, Path(path)))
        result = archive(runs, [tuple(entry.split("=", 1)) for entry in args.report],
                         [tuple(entry.split("=", 1)) for entry in args.image], args.output)
        print(json.dumps({"runs":len(result["runs"]), "copied_bytes":result["copied_bytes"], "visual_acceptance":False}))
        return 0
    except (OSError, ValueError, TypeError, KeyError) as error:
        print("MONSTER ARCHIVE: FAIL: " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__": raise SystemExit(main())
