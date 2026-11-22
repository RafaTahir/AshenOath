"""Real native HTTP/PCK integration; no game export or browser required."""
import argparse
from collections import Counter
from functools import partial
import gzip
import hashlib
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import re
import subprocess
import tempfile
import threading
import time
from urllib.parse import urlsplit


class FixtureHandler(SimpleHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def do_GET(self):
        name = Path(urlsplit(self.path).path).name
        self.server.hits[name] += 1
        count = self.server.hits[name]
        if name == "retry.pck" and count == 1:
            self.send_error(503, "Intentional retry fixture")
            return
        if name not in {"corrupt.pck", "interrupted.pck", "cancel.pck", "gzip.pck", "decoded.pck"}:
            super().do_GET()
            return
        data = bytearray((Path(self.directory) / name).read_bytes())
        if name == "corrupt.pck":
            data[-1] ^= 1
        if name == "gzip.pck":
            data = gzip.compress(data, mtime=0)
        self.send_response(200)
        if name in {"gzip.pck", "decoded.pck"}:
            self.send_header("Content-Encoding", "gzip")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        try:
            if name == "interrupted.pck" and count == 1:
                self.wfile.write(data[:len(data) // 2])
                self.wfile.flush()
                self.close_connection = True
            elif name == "cancel.pck":
                for offset in range(0, len(data), 4096):
                    self.wfile.write(data[offset:offset + 4096])
                    self.wfile.flush()
                    time.sleep(0.03)
            else:
                self.wfile.write(data)
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
            pass  # Expected only when the client cancels the slow fixture.


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--report", type=Path, default=Path(".release-gate/pack_http.json"))
    args = parser.parse_args()
    root = Path("D:/Temp/AshenOath")
    root.mkdir(parents=True, exist_ok=True)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    log = args.report.with_suffix(".log")
    result = {"status": "fail", "scope": "native HTTP/PCK/cache integration", "log": str(log.resolve())}
    try:
        with tempfile.TemporaryDirectory(prefix="pack-http-", dir=root) as directory:
            result["temporary_root"] = directory
            server = ThreadingHTTPServer(("127.0.0.1", 0), partial(FixtureHandler, directory=directory))
            server.hits = Counter()
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                with log.open("w", encoding="utf-8") as output:
                    run = subprocess.run([
                        args.godot, "--headless", "--path", str(args.project.resolve()),
                        "--script", "res://tools/verify_pack_http.gd", "--", directory,
                        f"http://127.0.0.1:{server.server_port}",
                    ], stdout=output, stderr=subprocess.STDOUT, timeout=90,
                        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
                text = log.read_text(encoding="utf-8")
                expected = {"foundation.pck": 1, "dependent.pck": 1, "retry.pck": 2,
                            "interrupted.pck": 2, "corrupt.pck": 1, "cancel.pck": 1,
                            "gzip.pck": 1, "decoded.pck": 1}
                result["requests"] = dict(server.hits)
                result["exit_code"] = run.returncode
                result["runtime_errors"] = re.findall(r"^.*(?:SCRIPT ERROR:|^ERROR:|leaked|Orphan).*?$", text, re.MULTILINE)
                if run.returncode == 0 and "PACK HTTP INTEGRATION: PASS" in text and not result["runtime_errors"] and dict(server.hits) == expected:
                    result["status"] = "pass"
                else:
                    result["failure"] = "Native assertions, runtime errors, or exact HTTP request counts failed"
            finally:
                server.shutdown()
                server.server_close()
                thread.join(timeout=5)
        result["temporary_root_removed"] = not Path(result["temporary_root"]).exists()
    except Exception as error:
        result["status"] = "fail"
        result["failure"] = str(error)
    result["source_sha256"] = {
        name: hashlib.sha256((args.project / name).read_bytes()).hexdigest()
        for name in ["scripts/runtime_pack_manager.gd", "tools/verify_pack_http.gd", "tools/verify_pack_http.py"]
    }
    args.report.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"PACK HTTP: {result['status'].upper()} - {result.get('failure', 'dependency, retry, interruption, corruption, cancellation, offline cache; scratch removed')}")
    if result["status"] != "pass":
        print("\n".join(log.read_text(encoding="utf-8").splitlines()[-15:]))
    return 0 if result["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
