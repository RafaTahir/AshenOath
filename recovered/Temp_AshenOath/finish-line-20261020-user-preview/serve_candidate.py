"""Serve the frozen package for user-owned checks; never launch a browser/game."""

import functools
import http.server
import json
import sys
from pathlib import Path


ROOT = (Path(sys.argv[1]) if len(sys.argv) > 1 else Path(
    "D:/Projects/AshenOath/.release-gate/"
    "finish-line-20261020-user-candidate/export"
)).resolve()
MANIFEST = json.loads((ROOT / "release_manifest.json").read_text(encoding="utf-8"))
ENCODINGS = {
    item["path"]: item["content_encoding"]
    for item in MANIFEST["artifacts"]
    if item.get("content_encoding")
}


class CandidateHandler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
        ".js": "application/javascript",
    }

    def end_headers(self):
        path = Path(self.translate_path(self.path))
        relative = path.relative_to(ROOT).as_posix()
        if self.command in ("GET", "HEAD") and path.is_file() and relative in ENCODINGS:
            self.send_header("Content-Encoding", ENCODINGS[relative])
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def list_directory(self, path):
        self.send_error(404)
        return None


handler = functools.partial(CandidateHandler, directory=str(ROOT))
server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
print(f"User preview: http://127.0.0.1:{server.server_port}/", flush=True)
print(f"Candidate: {MANIFEST['build_id']}", flush=True)
print(f"Serving only: {ROOT}", flush=True)
server.serve_forever()
