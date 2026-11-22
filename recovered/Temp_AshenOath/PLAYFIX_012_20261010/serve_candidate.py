"""Local static preview only; no gameplay automation or acceptance checks."""
import functools
import http.server
import pathlib
import sys
import urllib.parse


class CandidateHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if urllib.parse.urlsplit(self.path).path == "/favicon.ico":
            self.send_response(204)
            self.end_headers()
            return
        if urllib.parse.urlsplit(self.path).path == "/__playfix_observer":
            page = pathlib.Path(__file__).with_name("read_only_observer.html").read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(page)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(page)
            return
        super().do_GET()

    def end_headers(self):
        path = pathlib.Path(self.translate_path(urllib.parse.urlsplit(self.path).path))
        if path.is_file() and path.suffix in {".pck", ".wasm", ".js"}:
            with path.open("rb") as stream:
                if stream.read(2) == b"\x1f\x8b":
                    self.send_header("Content-Encoding", "gzip")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()


root = pathlib.Path(sys.argv[1]).resolve(strict=True)
port = int(sys.argv[2]) if len(sys.argv) > 2 else 0
server = http.server.ThreadingHTTPServer(
    ("127.0.0.1", port), functools.partial(CandidateHandler, directory=str(root))
)
print(f"http://127.0.0.1:{server.server_port}/", flush=True)
server.serve_forever()
