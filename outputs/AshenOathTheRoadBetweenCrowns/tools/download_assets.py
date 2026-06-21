from __future__ import annotations

import argparse
import http.cookiejar
import html.parser
import json
import re
import shutil
import sys
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from dataclasses import dataclass
from pathlib import Path

from pipeline_common import (
    ASSETS_ROOT,
    AUDIO_EXTS,
    LICENSE_NAMES,
    MODEL_EXTS,
    PROJECT_ROOT,
    SOURCES_PATH,
    TEXTURE_EXTS,
    category_root,
    read_json,
    safe_name,
)

USEFUL_EXTS = MODEL_EXTS | TEXTURE_EXTS | AUDIO_EXTS | {".txt", ".md", ".pdf", ".rtf"}
DOWNLOAD_EXTS = {".zip", ".7z", ".rar"} | MODEL_EXTS | TEXTURE_EXTS | AUDIO_EXTS
PLACEHOLDER = "PASTE_DIRECT_DOWNLOAD_URL_HERE"
DEFAULT_TIMEOUT = 60


@dataclass
class ResolvedURL:
    url: str
    file_name: str
    source: str
    content_type: str = ""
    content_length: str = ""


class LinkParser(html.parser.HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.links: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag.lower() not in {"a", "link"}:
            return
        for key, value in attrs:
            if key and key.lower() == "href" and value:
                self.links.append(value)


class AssetDownloader:
    def __init__(self, verbose: bool = False, timeout: int = DEFAULT_TIMEOUT) -> None:
        self.verbose = verbose
        self.timeout = timeout
        self.cookie_jar = http.cookiejar.CookieJar()
        self.opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(self.cookie_jar),
            urllib.request.HTTPRedirectHandler(),
        )

    def log(self, message: str) -> None:
        print(f"[asset-pipeline] {message}")

    def debug(self, message: str) -> None:
        if self.verbose:
            self.log(f"DEBUG {message}")

    def request(self, url: str, method: str = "GET", headers: dict | None = None):
        request_headers = {
            "User-Agent": "AshenOathAssetPipeline/1.0",
            "Accept": "*/*",
        }
        if headers:
            request_headers.update(headers)
        request = urllib.request.Request(url, headers=request_headers, method=method)
        return self.opener.open(request, timeout=self.timeout)

    def resolve(self, original_url: str, pack_name: str) -> ResolvedURL | None:
        parsed = urllib.parse.urlparse(original_url)
        if parsed.scheme not in {"http", "https"}:
            self.log(f"ERROR unsupported URL scheme for {pack_name}: {original_url}")
            return None

        github = self.resolve_github_release(original_url, pack_name)
        if github:
            return github

        direct = self.resolve_direct(original_url, pack_name)
        if direct:
            return direct

        page = self.resolve_page(original_url, pack_name)
        if page:
            return page

        self.log(f"ERROR could not resolve downloadable asset for {pack_name}: {original_url}")
        return None

    def resolve_direct(self, url: str, pack_name: str) -> ResolvedURL | None:
        self.debug(f"Testing direct URL: {url}")
        try:
            info = self.open_metadata(url)
        except Exception as exc:
            self.debug(f"Direct URL metadata failed: {exc}")
            return None

        final_url = info["url"]
        content_type = info.get("content_type", "")
        content_length = info.get("content_length", "")
        file_name = self.file_name_from_response(final_url, info.get("content_disposition", ""), pack_name)
        ext = Path(file_name).suffix.lower()
        if ext in DOWNLOAD_EXTS or self.looks_downloadable(content_type):
            if "." not in file_name:
                file_name = f"{pack_name}{self.default_extension(content_type)}"
            self.debug(f"Direct URL resolved to {final_url} ({content_type}, {content_length} bytes)")
            return ResolvedURL(final_url, file_name, "direct", content_type, content_length)
        self.debug(f"URL looks like a page, not a file: ext={ext}, content_type={content_type}")
        return None

    def resolve_page(self, url: str, pack_name: str) -> ResolvedURL | None:
        self.debug(f"Fetching page for asset links: {url}")
        try:
            with self.request(url, headers={"Accept": "text/html,application/xhtml+xml"}) as response:
                final_url = response.geturl()
                content_type = response.headers.get("Content-Type", "")
                body = response.read(2_500_000)
        except Exception as exc:
            self.debug(f"Page fetch failed: {exc}")
            return None

        if "html" not in content_type.lower():
            self.debug(f"Page resolver skipped non-HTML content: {content_type}")
            return None

        parser = LinkParser()
        try:
            parser.feed(body.decode("utf-8", errors="replace"))
        except Exception as exc:
            self.debug(f"HTML parse failed: {exc}")
            return None

        candidates = self.rank_page_links(final_url, parser.links)
        for candidate in candidates:
            self.debug(f"Testing page candidate: {candidate}")
            direct = self.resolve_direct(candidate, pack_name)
            if direct:
                direct.source = "page-link"
                return direct
        return None

    def resolve_github_release(self, url: str, pack_name: str) -> ResolvedURL | None:
        parsed = urllib.parse.urlparse(url)
        if parsed.netloc.lower() != "github.com":
            return None
        parts = [part for part in parsed.path.strip("/").split("/") if part]
        if len(parts) < 4 or parts[2] != "releases":
            return None

        owner, repo = parts[0], parts[1]
        release_ref = ""
        if len(parts) >= 4 and parts[3] == "latest":
            api_url = f"https://api.github.com/repos/{owner}/{repo}/releases/latest"
            release_ref = "latest"
        elif len(parts) >= 5 and parts[3] == "tag":
            tag = urllib.parse.quote(parts[4], safe="")
            api_url = f"https://api.github.com/repos/{owner}/{repo}/releases/tags/{tag}"
            release_ref = parts[4]
        else:
            return None

        self.debug(f"Resolving GitHub release {owner}/{repo} {release_ref} via API")
        try:
            with self.request(api_url, headers={"Accept": "application/vnd.github+json"}) as response:
                data = json.loads(response.read().decode("utf-8"))
        except Exception as exc:
            self.debug(f"GitHub release API failed: {exc}")
            return None

        assets = data.get("assets", [])
        candidates = []
        for asset in assets:
            asset_url = asset.get("browser_download_url", "")
            name = asset.get("name", "")
            if Path(name).suffix.lower() in DOWNLOAD_EXTS:
                candidates.append((self.asset_priority(name), asset_url, name))
        candidates.sort(reverse=True)
        if not candidates:
            archive_url = data.get("zipball_url") or data.get("tarball_url")
            if archive_url:
                file_name = f"{pack_name}.zip"
                return ResolvedURL(archive_url, file_name, "github-release-archive")
            return None
        _, asset_url, name = candidates[0]
        self.debug(f"GitHub release selected asset: {name}")
        return ResolvedURL(asset_url, safe_name(name), "github-release")

    def open_metadata(self, url: str) -> dict:
        try:
            with self.request(url, method="HEAD") as response:
                return self.response_metadata(response)
        except Exception as exc:
            self.debug(f"HEAD failed for {url}: {exc}; falling back to ranged GET")
            with self.request(url, headers={"Range": "bytes=0-0"}) as response:
                return self.response_metadata(response)

    def response_metadata(self, response) -> dict:
        return {
            "url": response.geturl(),
            "content_type": response.headers.get("Content-Type", ""),
            "content_length": response.headers.get("Content-Length", ""),
            "content_disposition": response.headers.get("Content-Disposition", ""),
        }

    def file_name_from_response(self, url: str, content_disposition: str, pack_name: str) -> str:
        match = re.search(r'filename\*?=(?:UTF-8\'\')?"?([^";]+)', content_disposition, flags=re.I)
        if match:
            return safe_name(urllib.parse.unquote(match.group(1)))
        parsed = urllib.parse.urlparse(url)
        candidate = Path(urllib.parse.unquote(parsed.path)).name
        if not candidate:
            candidate = pack_name
        return safe_name(candidate)

    def looks_downloadable(self, content_type: str) -> bool:
        lowered = content_type.lower()
        return any(
            token in lowered
            for token in [
                "application/zip",
                "application/x-zip",
                "application/octet-stream",
                "application/gzip",
                "model/gltf",
                "audio/",
                "image/",
            ]
        )

    def default_extension(self, content_type: str) -> str:
        lowered = content_type.lower()
        if "gzip" in lowered:
            return ".gz"
        if "audio/" in lowered:
            return ".ogg"
        if "image/png" in lowered:
            return ".png"
        if "image/jpeg" in lowered:
            return ".jpg"
        if "image/" in lowered:
            return ".image"
        if "gltf" in lowered:
            return ".gltf"
        return ".zip"

    def rank_page_links(self, base_url: str, links: list[str]) -> list[str]:
        scored: list[tuple[int, str]] = []
        seen = set()
        for link in links:
            absolute = urllib.parse.urljoin(base_url, link)
            parsed = urllib.parse.urlparse(absolute)
            if parsed.scheme not in {"http", "https"}:
                continue
            if absolute in seen:
                continue
            seen.add(absolute)
            hay = urllib.parse.unquote(absolute).lower()
            ext = Path(parsed.path).suffix.lower()
            score = 0
            if ext in DOWNLOAD_EXTS:
                score += 100
            if "/sites/default/files/" in hay:
                score += 30
            if "download" in hay:
                score += 25
            if "files" in hay or "releases/download" in hay:
                score += 15
            if any(bad in hay for bad in ["forum", "comment", "login", "register", "contact"]):
                score -= 50
            if score > 0:
                scored.append((score, absolute))
        scored.sort(reverse=True)
        return [url for _, url in scored]

    def asset_priority(self, name: str) -> int:
        ext = Path(name).suffix.lower()
        if ext in {".zip", ".glb", ".gltf"}:
            return 100
        if ext in MODEL_EXTS:
            return 80
        if ext in AUDIO_EXTS or ext in TEXTURE_EXTS:
            return 40
        return 10

    def download_file(self, resolved: ResolvedURL, destination: Path) -> bool:
        destination.parent.mkdir(parents=True, exist_ok=True)
        try:
            with self.request(resolved.url) as response:
                final_url = response.geturl()
                with destination.open("wb") as handle:
                    shutil.copyfileobj(response, handle)
            self.log(f"Downloaded {resolved.source}: {final_url} -> {destination.relative_to(PROJECT_ROOT)}")
            return True
        except (urllib.error.URLError, TimeoutError, OSError) as exc:
            self.log(f"ERROR downloading {resolved.url}: {exc}")
            return False


def log(message: str) -> None:
    print(f"[asset-pipeline] {message}")


def extract_zip(archive: Path, raw_dir: Path) -> None:
    raw_dir.mkdir(parents=True, exist_ok=True)
    try:
        with zipfile.ZipFile(archive, "r") as zip_file:
            zip_file.extractall(raw_dir)
        log(f"Extracted {archive.name} -> {raw_dir.relative_to(PROJECT_ROOT)}")
    except zipfile.BadZipFile as exc:
        log(f"ERROR extracting {archive}: {exc}")


def is_license_file(path: Path) -> bool:
    stem = path.stem.lower()
    return any(name in stem for name in LICENSE_NAMES)


def unique_destination(dest_dir: Path, pack_name: str, source_path: Path) -> Path:
    dest_dir.mkdir(parents=True, exist_ok=True)
    proposed = dest_dir / source_path.name
    if not proposed.exists():
        return proposed
    prefixed = dest_dir / f"{pack_name}__{source_path.name}"
    if not prefixed.exists():
        return prefixed
    index = 2
    while True:
        candidate = dest_dir / f"{pack_name}__{source_path.stem}_{index}{source_path.suffix}"
        if not candidate.exists():
            return candidate
        index += 1


def copy_useful_files(pack_name: str, category: str, raw_dir: Path) -> None:
    target_dir = category_root(category)
    license_dir = ASSETS_ROOT / "licenses" / pack_name
    copied = 0
    licenses = 0
    for source_path in raw_dir.rglob("*"):
        if not source_path.is_file():
            continue
        ext = source_path.suffix.lower()
        if is_license_file(source_path):
            destination = unique_destination(license_dir, pack_name, source_path)
            shutil.copy2(source_path, destination)
            licenses += 1
            continue
        if ext not in USEFUL_EXTS:
            continue
        if ext in {".txt", ".md", ".pdf", ".rtf"}:
            destination = unique_destination(license_dir, pack_name, source_path)
            shutil.copy2(source_path, destination)
            licenses += 1
            continue
        destination = unique_destination(target_dir, pack_name, source_path)
        shutil.copy2(source_path, destination)
        copied += 1
    log(f"Organized {copied} useful files and {licenses} license/readme files for {pack_name}.")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Download, extract, and organize Ashen Oath asset packs.")
    parser.add_argument("--dry-run", action="store_true", help="Resolve and test URLs without downloading files.")
    parser.add_argument("--verbose", "-v", action="store_true", help="Print detailed URL resolution logs.")
    parser.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT, help="Network timeout in seconds.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    data = read_json(SOURCES_PATH, {"packs": []})
    downloads_dir = ASSETS_ROOT / "downloads"
    raw_root = ASSETS_ROOT / "raw"
    downloads_dir.mkdir(parents=True, exist_ok=True)
    raw_root.mkdir(parents=True, exist_ok=True)
    downloader = AssetDownloader(verbose=args.verbose, timeout=args.timeout)

    packs = data.get("packs", [])
    if not packs:
        log("No packs found in asset_sources.json.")
        return 0

    failures = 0
    for pack in packs:
        pack_name = safe_name(pack.get("name", "asset_pack"))
        url = str(pack.get("url", "")).strip()
        category = str(pack.get("category", "raw")).strip() or "raw"
        if not url or PLACEHOLDER in url:
            log(f"Skipping {pack_name}: URL placeholder still present.")
            continue

        log(f"Resolving {pack_name}: {url}")
        resolved = downloader.resolve(url, pack_name)
        if not resolved:
            failures += 1
            continue
        log(
            f"Resolved {pack_name}: source={resolved.source}, file={resolved.file_name}, "
            f"type={resolved.content_type or 'unknown'}, bytes={resolved.content_length or 'unknown'}"
        )
        if args.dry_run:
            continue

        download_path = downloads_dir / resolved.file_name
        if download_path.exists():
            log(f"Using existing download for {pack_name}: {download_path.relative_to(PROJECT_ROOT)}")
        elif not downloader.download_file(resolved, download_path):
            failures += 1
            continue

        raw_dir = raw_root / pack_name
        if download_path.suffix.lower() == ".zip":
            extract_zip(download_path, raw_dir)
        else:
            raw_dir.mkdir(parents=True, exist_ok=True)
            shutil.copy2(download_path, raw_dir / download_path.name)
            log(f"Copied non-zip download into {raw_dir.relative_to(PROJECT_ROOT)}")

        copy_useful_files(pack_name, category, raw_dir)

    if args.dry_run:
        log(f"Dry run complete. failures={failures}")
    else:
        log(f"Done. failures={failures}. Run tools/scan_assets.py next.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
