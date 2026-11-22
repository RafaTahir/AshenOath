import bisect
import csv
import json
from pathlib import Path

root = Path(__file__).parent / "v2"
frames = json.loads((root / "frames.json").read_text())
rows = list(csv.DictReader((root / "cpu.csv").open()))
times = [(int(row["utc_ticks"]) - 621355968000000000) / 1e7 for row in rows]
results = []
for frame in sorted(frames["frames"], key=lambda item: item["frame_ms"], reverse=True):
    if frame["frame_ms"] < 60:
        continue
    end = frame["epoch_seconds"]
    start = end - frame["frame_ms"] / 1000
    a = bisect.bisect_right(times, start) - 1
    b = bisect.bisect_left(times, end)
    if a < 0 or b >= len(rows):
        continue
    left, right = rows[a], rows[b]
    result = dict(frame)
    result.update({
        "os_window_ms": (times[b] - times[a]) * 1000,
        "main_cpu_ms": (int(right["main_cpu_ticks"]) - int(left["main_cpu_ticks"])) / 1e4,
        "all_thread_cpu_ms": (int(right["process_cpu_ticks"]) - int(left["process_cpu_ticks"])) / 1e4,
        "read_bytes": int(right["read_bytes"]) - int(left["read_bytes"]),
        "other_bytes": int(right["other_bytes"]) - int(left["other_bytes"]),
        "page_faults": int(right["page_faults"]) - int(left["page_faults"]),
    })
    results.append(result)
output = {"scope": "diagnostic CPU running versus wall time; NOT GPU timers or FPS acceptance", "sampler_max_query_ms": max(float(row["query_ms"]) for row in rows), "sampler_mean_query_ms": sum(float(row["query_ms"]) for row in rows) / len(rows), "long_frames": results}
(root / "analysis.json").write_text(json.dumps(output, indent=2))
print(json.dumps(output, indent=2))
