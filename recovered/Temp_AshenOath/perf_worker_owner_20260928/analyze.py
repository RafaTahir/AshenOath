import bisect
import csv
import json
from pathlib import Path
from statistics import mean

base = Path(__file__).parent
frames = json.loads((base / "frames.json").read_text(encoding="utf-8"))
identities = json.loads((base / "identities.json").read_text(encoding="utf-8-sig"))
identities = {f'{item["id"]}:{item["created_ticks"]}': item for item in identities}
with (base / "process.csv").open(encoding="utf-8-sig", newline="") as handle:
    process = [{key: float(value) for key, value in row.items()} for row in csv.DictReader(handle)]
workers = {}
with (base / "threads.csv").open(encoding="utf-8-sig", newline="") as handle:
    for row in csv.DictReader(handle):
        row["epoch"] = int(row["utc_ticks"]) / 10_000_000 - 62_135_596_800
        row["cpu_ticks"] = int(row["cpu_ticks"])
        workers.setdefault(row["identity"], []).append(row)
times = [row["utc_ticks"] / 10_000_000 - 62_135_596_800 for row in process]
worker_times = {key: [row["epoch"] for row in rows] for key, rows in workers.items()}


def bracket(rows, timestamps, start, end):
    left = bisect.bisect_right(timestamps, start) - 1
    right = bisect.bisect_left(timestamps, end)
    if left < 0 or right >= len(rows):
        return None
    return left, right


findings = []
ordered_frames = frames["frames"]
for index, frame in enumerate(ordered_frames):
    if frame["frame_ms"] < 80:
        continue
    end = frame["epoch_seconds"]
    start = end - frame["frame_ms"] / 1000
    bounds = bracket(process, times, start, end)
    if bounds is None:
        continue
    left, right = bounds
    first, last = process[left], process[right]
    cpu = []
    for key, rows in workers.items():
        limits = bracket(rows, worker_times[key], start, end)
        if limits is None:
            continue
        a, b = limits
        used = (rows[b]["cpu_ticks"] - rows[a]["cpu_ticks"]) / 10_000
        if used > 0:
            identity = identities[key]
            cpu.append({"identity": key, "description": identity["description"] or "UNNAMED_NOT_CLASSIFIED", "cpu_ms": used, "start_address": identity["start_address"], "wait_states": sorted({f'{row["state"]}:{row["wait_reason"]}' for row in rows[a:b + 1]})})
    cpu.sort(key=lambda item: item["cpu_ms"], reverse=True)
    findings.append({
        **frame, "os_bracket_ms": (times[right] - times[left]) * 1000,
        "process_cpu_ms": (last["process_cpu_ticks"] - first["process_cpu_ticks"]) / 10_000,
        "read_bytes": last["read_bytes"] - first["read_bytes"],
        "write_bytes": last["write_bytes"] - first["write_bytes"],
        "page_faults": last["page_faults"] - first["page_faults"],
        "pending_before": ordered_frames[index - 1]["pending_resources"] if index else {},
        "thread_cpu_brackets": cpu,
    })
findings.sort(key=lambda item: item["frame_ms"], reverse=True)
summary = {
    "scope": "instrumented diagnostic NOT FPS acceptance; unnamed/zero-start threads remain unclassified; interval brackets include sampler boundary slack",
    "sampler_mean_query_ms": mean(row["query_ms"] for row in process),
    "sampler_max_query_ms": max(row["query_ms"] for row in process),
    "long_frames": findings[:18],
}
(base / "analysis.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
for item in findings[:8]:
    print(json.dumps({key: item[key] for key in ("frame_ms", "stage_before", "stage_after", "process_cpu_ms", "read_bytes", "write_bytes", "pending_before")}, separators=(",", ":")))
    print("TOP THREADS", [(row["description"], row["identity"], row["cpu_ms"]) for row in item["thread_cpu_brackets"][:6]])
print("SAMPLER query mean/max", summary["sampler_mean_query_ms"], summary["sampler_max_query_ms"])
