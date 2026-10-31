"""Fetch only the credited robe foundations from the official CC0 archive."""
import io
import json
import urllib.request
import zipfile
from pathlib import Path

URL = "https://files2.makehumancommunity.org/asset_packs/suits02/suits02_cc0.zip"
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "upstream/makehuman/donitz_robe"


class RemoteZip(io.RawIOBase):
    def __init__(self):
        with urllib.request.urlopen(urllib.request.Request(URL, method="HEAD"), timeout=60) as response:
            self.length = int(response.headers["Content-Length"])
        self.position = 0

    def seekable(self):
        return True

    def seek(self, offset, whence=0):
        self.position = offset if whence == 0 else self.position + offset if whence == 1 else self.length + offset
        return self.position

    def tell(self):
        return self.position

    def read(self, size=-1):
        size = min(self.length - self.position, size if size >= 0 else self.length)
        if size <= 0:
            return b""
        request = urllib.request.Request(URL, headers={"Range": f"bytes={self.position}-{self.position + size - 1}"})
        with urllib.request.urlopen(request, timeout=120) as response:
            if response.status != 206:
                raise RuntimeError("Archive server did not honor bounded Range request")
            data = response.read()
        if len(data) != size:
            raise RuntimeError("Incomplete archive range")
        self.position += size
        return data


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    archive = zipfile.ZipFile(RemoteZip())
    selected = [entry for entry in archive.infolist()
                if any(part in ("donitz_monk_robe", "donitz_monk_robe_hood_down", "donitz_monk_robe_hood_off")
                       for part in Path(entry.filename).parts)
                and not entry.is_dir()
                and Path(entry.filename).suffix.lower() in (".obj", ".mhclo", ".mhmat", ".txt", ".md")]
    if not selected:
        raise RuntimeError("Expected exact robe directories absent: " + str(archive.namelist()[:30]))
    records = []
    for entry in selected:
        print("FETCHING", entry.filename, entry.file_size, flush=True)
        relative = Path(entry.filename)
        target = (OUT / relative).resolve()
        if not target.is_relative_to(OUT.resolve()):
            raise RuntimeError("Unsafe archive member")
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists() or target.stat().st_size != entry.file_size:
            target.write_bytes(archive.read(entry))
        records.append({"member": entry.filename, "bytes": entry.file_size, "crc32": f"{entry.CRC:08x}"})
        print("FETCHED", entry.filename, entry.file_size, flush=True)
    (OUT / "download.json").write_text(json.dumps({"source": URL, "catalog": "https://static.makehumancommunity.org/assets/assetpacks/suits02.html", "files": records}, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
