"""Local-only delivery server for the private, precompressed review export."""
import json
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT=Path('D:/Temp/AshenOath/stylized_review')
receipt=json.loads((ROOT/'private_review_build.json').read_text())
assert receipt['publication_authorized'] is False
assert Path(receipt['export'])==ROOT/'export'
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--port',type=int,default=8768)
args=parser.parse_args()

class PrivateFiles(SimpleHTTPRequestHandler):
    extensions_map={**SimpleHTTPRequestHandler.extensions_map,
                    '.wasm':'application/wasm','.pck':'application/octet-stream',
                    '.js':'text/javascript','.json':'application/json'}

    def end_headers(self):
        path=Path(self.translate_path(self.path))
        if path.is_file():
            with path.open('rb') as stream:
                if stream.read(2)==b'\x1f\x8b':
                    self.send_header('Content-Encoding','gzip')
        self.send_header('Cache-Control','no-store')
        self.send_header('Cross-Origin-Opener-Policy','same-origin')
        self.send_header('Cross-Origin-Embedder-Policy','require-corp')
        super().end_headers()

print(f'Private unaccepted review build: http://127.0.0.1:{args.port}/',flush=True)
ThreadingHTTPServer(('127.0.0.1',args.port),partial(PrivateFiles,directory=receipt['export'])).serve_forever()
