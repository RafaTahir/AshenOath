"""Configure Git delivery; retain explicit staged-release recovery for history.

No game execution. Credentials stay in the CLI credential store/environment and
are never included in receipts, URLs, or diagnostic output.
"""

import argparse
import gzip
import hashlib
import json
import os
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import urlencode, urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener

from build_web_runtime_manifest import inspect_packaged_export
from deployment_policy import POLICY, check_file_size


REPO = Path(__file__).resolve().parents[3]
WEB = REPO / "web"
PROJECT_ID = "prj_hJ4rsZ7wOpK7XKVpbqGlMx3VjMSQ"
PRODUCTION = "https://ashenoath.vercel.app"


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, msg, headers, newurl):
        return None


HTTP = build_opener(NoRedirect())


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def git(*args):
    return subprocess.check_output(["git", "-C", str(REPO), *args], text=True).strip()


def utc():
    return datetime.now(timezone.utc).isoformat()


class Vercel:
    def __init__(self):
        link = read_json(REPO / ".vercel/project.json")
        if link["projectId"] != PROJECT_ID:
            raise ValueError("The checkout is linked to a different Vercel project")
        self.team = link["orgId"]
        self.token = os.environ.get("VERCEL_TOKEN")
        if not self.token:
            self.token = read_json(Path(os.environ["APPDATA"]) / "com.vercel.cli/Data/auth.json")["token"]

    def api(self, path, method="GET", body=None, **query):
        query["teamId"] = self.team
        request = Request("https://api.vercel.com" + path + "?" + urlencode(query),
                          data=json.dumps(body).encode() if body is not None else None,
                          headers={"Authorization": "Bearer " + self.token, "Content-Type": "application/json"}, method=method)
        try:
            with HTTP.open(request, timeout=60) as response:
                content = response.read()
                return json.loads(content) if content else {}
        except HTTPError as error:
            try:
                details = json.loads(error.read()).get("error", {})
            except (ValueError, AttributeError):
                details = {}
            # Never echo arbitrary API response bodies, which can contain secrets.
            code = details.get("code", "unknown")
            raise RuntimeError(f"Vercel {method} {path}: HTTP {error.code}, code={code}") from None

    def project(self):
        return self.api(f"/v9/projects/{PROJECT_ID}")

    def live_deployment(self):
        alias = self.api("/v4/aliases/ashenoath.vercel.app")
        if alias.get("projectId") != PROJECT_ID:
            raise ValueError("Production alias belongs to another project")
        return alias["deploymentId"]

    def assert_configuration(self, project):
        team = self.api(f"/v2/teams/{self.team}")
        if team.get("billing", {}).get("plan") != "hobby":
            raise ValueError("Expected the existing Hobby plan; no plan changes are authorized")
        if project.get("link", {}).get("productionBranch") != "main" or project.get("outputDirectory") != "web":
            raise ValueError("Expected Git production branch main and output web")
        if project.get("gitProviderOptions", {}).get("createDeployments") != "enabled":
            raise ValueError("Git deployment integration is disabled")
        if project.get("buildCommand") != 'echo "Static Godot build"':
            raise ValueError("Static build command changed; refusing an unreviewed remote build")

    def bypass(self):
        secrets = self.project().get("protectionBypass") or {}
        if not secrets:
            raise ValueError("No authenticated HTTP automation access is configured; run setup")
        for secret, metadata in secrets.items():
            if metadata.get("note") == "Ashen Oath release integrity":
                return secret
        return next(iter(secrets))


def save_receipt(path, receipt):
    receipt["updated_at_utc"] = utc()
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def check_committed_package(receipt):
    commit = receipt["package_commit"]
    if git("rev-parse", "HEAD") != commit:
        raise ValueError("HEAD changed since the candidate was bound")
    changed = git("diff", commit, "--name-only", "--", "web", "vercel.json")
    if changed:
        raise ValueError("Committed hosting files differ from the local candidate")
    actual = inspect_packaged_export(WEB)
    if actual != receipt["package"]:
        raise ValueError("Package identity/policy changed after binding")
    digest = hashlib.sha256((WEB / "release_manifest.json").read_bytes()).hexdigest()
    if digest != receipt["release_manifest_sha256"]:
        raise ValueError("Release manifest changed after binding")
    manifest = read_json(WEB / "release_manifest.json")
    committed = set(git("ls-tree", "-r", "--name-only", commit, "--", "web").splitlines())
    expected = {"web/" + record["path"] for record in manifest["artifacts"]} | {"web/release_manifest.json"}
    if committed != expected:
        raise ValueError("Committed Web file ownership differs from the candidate manifest")
    return manifest


def check_http(base, manifest, bypass=None):
    if urlsplit(base).scheme != "https" or not urlsplit(base).hostname.endswith(".vercel.app"):
        raise ValueError("Unexpected deployment host")
    paths = [record["path"] for record in manifest["artifacts"]] + ["release_manifest.json"]
    by_path = {record["path"]: record for record in manifest["artifacts"]}
    checked = []
    for relative in paths:
        local = (WEB / relative).read_bytes()
        request_path = "/" if relative == "index.html" else "/" + relative
        # Match runtime pack cache keys rather than testing an unrelated URL.
        pack = next((p for p in manifest["packs"] if urlsplit(p.get("url", "")).path == relative), None)
        if pack:
            request_path += "?" + urlsplit(pack["url"]).query
        headers = {"Accept-Encoding": "identity", "Cache-Control": "no-cache"}
        if bypass:
            headers["x-vercel-protection-bypass"] = bypass
        try:
            with HTTP.open(Request(base + request_path, headers=headers), timeout=120) as response:
                if response.status != 200:
                    raise ValueError(f"Unexpected HTTP status for {relative}: {response.status}")
                payload = response.read(len(local) + 1)
                encoding = response.headers.get("Content-Encoding", "").lower()
                mime = response.headers.get_content_type()
                cache = response.headers.get("Cache-Control", "").lower()
        except HTTPError as error:
            raise ValueError(f"HTTP delivery failed for {relative}: {error.code}") from None
        if payload != local:
            raise ValueError(f"HTTP byte/hash mismatch: {relative}")
        record = by_path.get(relative, {})
        if encoding != record.get("content_encoding", ""):
            raise ValueError(f"HTTP encoding mismatch: {relative} ({encoding})")
        if encoding == "gzip":
            decoded = gzip.decompress(payload)
            if len(decoded) != record["decoded_bytes"] or hashlib.sha256(decoded).hexdigest() != record["decoded_sha256"]:
                raise ValueError(f"HTTP decoded identity mismatch: {relative}")
        expected_mime = {".wasm": {"application/wasm"}, ".js": {"application/javascript", "text/javascript"},
                         ".html": {"text/html"}, ".json": {"application/json"}, ".png": {"image/png"},
                         ".pck": {"application/octet-stream"}}
        if mime not in expected_mime.get(Path(relative).suffix, {mime}):
            raise ValueError(f"HTTP MIME mismatch: {relative} ({mime})")
        if relative.startswith(("packs/", "engine/")):
            if "immutable" not in cache:
                raise ValueError(f"Missing content-addressed cache header: {relative}")
        elif relative in {"index.html", "index.pck"} and not ("no-cache" in cache or "must-revalidate" in cache):
            raise ValueError(f"Missing revalidation header: {relative}")
        checked.append({"path": relative, "bytes": len(payload), "sha256": hashlib.sha256(payload).hexdigest(),
                        "content_encoding": encoding, "content_type": mime, "cache_control": cache})
        print(f"HTTP identity: {relative}", flush=True)
    return {"url": base, "checked_at_utc": utc(), "files": checked}


def wait_deployment(client, receipt, environment, timeout):
    branch = "main" if environment == "production" else "codex/masterpiece-rebuild"
    deadline = time.monotonic() + timeout
    last_status = None
    while time.monotonic() < deadline:
        candidates = client.api("/v7/deployments", projectId=PROJECT_ID, branch=branch,
                                sha=receipt["package_commit"], limit=20).get("deployments", [])
        matches = [d for d in candidates if d.get("source") == "git"
                   and d.get("meta", {}).get("githubCommitSha") == receipt["package_commit"]
                   and d.get("meta", {}).get("githubCommitRef") == branch
                   and (d.get("target") == "production") == (environment == "production")]
        if matches:
            deployment = matches[0]
            state = deployment.get("state", deployment.get("readyState"))
            if state in {"ERROR", "CANCELED", "BLOCKED"}:
                detail = client.api("/v13/deployments/" + deployment["uid"])
                receipt[environment + "_failure"] = {"id": deployment["uid"], "state": state,
                    "error_code": detail.get("errorCode"), "error_message": detail.get("errorMessage")}
                raise ValueError(f"Git {environment} deployment {deployment['uid']} failed: {state}, {detail.get('errorCode')}")
            if state == "READY":
                return {"id": deployment["uid"], "url": "https://" + deployment["url"], "commit": receipt["package_commit"]}
        else:
            state = "waiting for Git webhook"
        if state != last_status:
            print(f"{environment}: {state}", flush=True)
            last_status = state
        time.sleep(10)
    raise TimeoutError(f"No ready Git {environment} deployment for this exact SHA within {timeout}s; production was not promoted")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["setup-auto", "setup", "bind", "preview", "production", "promote"])
    parser.add_argument("--receipt", required=True, type=Path)
    parser.add_argument("--timeout", type=int, default=900)
    args = parser.parse_args()
    path = args.receipt.resolve()
    if not path.is_relative_to(REPO / ".release-gate"):
        raise ValueError("Receipt must remain within the D: repository release directory")
    receipt = read_json(path)
    client = Vercel()
    try:
        project = client.project()
        client.assert_configuration(project)
        if args.action == "setup-auto":
            receipt.setdefault("previous_production_id", client.live_deployment())
            if project.get("autoAssignCustomDomains") is not True:
                client.api(f"/v9/projects/{PROJECT_ID}", "PATCH", {"autoAssignCustomDomains": True})
            if client.project().get("autoAssignCustomDomains") is not True:
                raise ValueError("Automatic production-domain assignment could not be enabled")
            receipt["deployment_method"] = "git_automatic_production"
            receipt["hosting_plan"] = "hobby"
            receipt["phase"] = "automatic_assignment_enabled"
        elif args.action == "setup":
            receipt.setdefault("previous_production_id", client.live_deployment())
            if project.get("autoAssignCustomDomains") is not False:
                client.api(f"/v9/projects/{PROJECT_ID}", "PATCH", {"autoAssignCustomDomains": False})
            project = client.project()
            if project.get("autoAssignCustomDomains") is not False:
                raise ValueError("Production staging could not be enabled")
            if not project.get("protectionBypass"):
                client.api(f"/v1/projects/{PROJECT_ID}/protection-bypass", "PATCH",
                           {"generate": {"note": "Ashen Oath release integrity"}})
                client.bypass()
            receipt["deployment_method"] = "git_staged_production"
            receipt["hosting_plan"] = "hobby"
            receipt["transfer_usage"] = {"included_fast_data_transfer_gb": 100, "used_bytes": None,
                "status": "not measured by packaging; consult Vercel usage", "independent_of_package_budget": True}
        elif args.action == "bind":
            if receipt.get("preview") or receipt.get("production"):
                raise ValueError("A deployed candidate cannot be rebound; preserve its receipt")
            receipt["package_commit"] = git("rev-parse", "HEAD")
            # Inspect all committed files, not only the currently uploaded artifacts.
            for line in git("ls-tree", "-r", "-l", "HEAD").splitlines():
                metadata, relative = line.split("\t", 1)
                size = metadata.split()[-1]
                if size != "-":
                    check_file_size(relative, int(size))
            receipt["package"] = inspect_packaged_export(WEB)
            receipt["release_manifest_sha256"] = hashlib.sha256((WEB / "release_manifest.json").read_bytes()).hexdigest()
            check_committed_package(receipt)
        else:
            manifest = check_committed_package(receipt)
            if project.get("autoAssignCustomDomains") is not False:
                raise ValueError("Auto-assignment is enabled; refusing unprotected publication")
            if args.action in {"preview", "production"}:
                deployment = wait_deployment(client, receipt, args.action, args.timeout)
                receipt[args.action] = deployment
                save_receipt(path, receipt)
                deployment["http_identity"] = check_http(deployment["url"], manifest, client.bypass())
                receipt["phase"] = args.action + "_verified"
            else:
                deployment = receipt["production"]
                if not deployment.get("http_identity") or not receipt.get("preview", {}).get("http_identity"):
                    raise ValueError("Preview and staged-production checks are required before promotion")
                detail = client.api("/v13/deployments/" + deployment["id"])
                if detail.get("readyState") != "READY" or detail.get("target") != "production" or detail.get("meta", {}).get("githubCommitSha") != receipt["package_commit"]:
                    raise ValueError("Staged deployment identity changed")
                current = client.live_deployment()
                if current not in {receipt["previous_production_id"], deployment["id"]}:
                    raise ValueError("Another release changed production; refusing to replace it")
                if current != deployment["id"]:
                    client.api(f"/v10/projects/{PROJECT_ID}/promote/{deployment['id']}", "POST")
                deadline = time.monotonic() + 120
                while client.live_deployment() != deployment["id"]:
                    if time.monotonic() >= deadline:
                        raise TimeoutError("Promotion did not complete; inspect the recorded deployment before retrying")
                    time.sleep(5)
                # Never send an automation secret to the public URL: verify actual public delivery.
                try:
                    receipt["live_identity"] = check_http(PRODUCTION, manifest)
                except Exception:
                    # Preserve the previous live bytes if public delivery differs
                    # from the staged artifact. Never reset Git to roll back hosting.
                    if client.live_deployment() == deployment["id"]:
                        client.api(f"/v1/projects/{PROJECT_ID}/rollback/{receipt['previous_production_id']}", "POST")
                        receipt["rollback_requested_to"] = receipt["previous_production_id"]
                        receipt["phase"] = "rollback_requested"
                        save_receipt(path, receipt)
                        deadline = time.monotonic() + 120
                        while client.live_deployment() != receipt["previous_production_id"]:
                            if time.monotonic() >= deadline:
                                raise TimeoutError("Rollback has not completed; inspect the retained release receipt")
                            time.sleep(5)
                        receipt["phase"] = "rolled_back_delivery_failure"
                    raise
                receipt["phase"] = "published_awaiting_user"
                receipt["larger_than_100mib_delivered"] = receipt["package"]["directory_bytes"] >= POLICY["max_git_file_bytes"]
                receipt["capacity_note"] = "Only this actual candidate size is verified; the 256 MiB ceiling is an internal policy, not a measured platform capacity."
        save_receipt(path, receipt)
        print(f"{args.action}: complete; receipt {path}", flush=True)
        return 0
    except Exception as error:
        receipt["last_error"] = str(error)
        receipt["failed_action"] = args.action
        save_receipt(path, receipt)
        print(f"RELEASE STOPPED: {error}", flush=True)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
