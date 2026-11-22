import functools
import http.server
import pathlib
import sys


class CandidateHandler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map,
                      ".wasm": "application/wasm", ".pck": "application/octet-stream"}

    def end_headers(self):
        path = pathlib.Path(self.translate_path(self.path))
        if path.is_file():
            with path.open("rb") as stream:
                if stream.read(2) == b"\x1f\x8b":
                    self.send_header("Content-Encoding", "gzip")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()


handler = functools.partial(CandidateHandler, directory=sys.argv[1])
server = http.server.ThreadingHTTPServer(("127.0.0.1", int(sys.argv[2])), handler)
print(f"Candidate server: http://127.0.0.1:{server.server_port}", flush=True)
try:
    server.serve_forever()
except KeyboardInterrupt:
    pass
finally:
    server.server_close()
