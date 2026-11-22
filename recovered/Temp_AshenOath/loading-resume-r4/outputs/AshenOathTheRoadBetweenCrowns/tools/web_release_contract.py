"""Static contracts for the current HUD and checked-in Vercel route patterns."""

import re
from pathlib import Path
from urllib.parse import urlsplit


def effective_headers(config: dict, path: str) -> dict[str, str]:
    """Merge every matching rule in order, as opposed to selecting one rule."""
    headers = {}
    path = urlsplit(path).path
    for rule in config.get("headers", []):
        # Repository routes use literal paths and explicit regex groups. Escape
        # literals outside groups; preserve the configured group expressions.
        expression, depth = [], 0
        for char in rule["source"]:
            if char == "(":
                depth += 1
                expression.append(char)
            elif char == ")":
                depth -= 1
                expression.append(char)
            else:
                expression.append(char if depth else re.escape(char))
        if re.fullmatch("".join(expression), path):
            for header in rule.get("headers", []):
                headers[header["key"].lower()] = str(header["value"]).lower()
    return headers


def hosting_errors(config: dict) -> list[str]:
    errors = []
    for path in ["/index.html", "/index.pck", "/index.js", "/index.wasm"]:
        headers = effective_headers(config, path)
        cache = headers.get("cache-control", "")
        if "no-cache" not in cache or "must-revalidate" not in cache:
            errors.append(f"{path}: effective headers must use no-cache, must-revalidate")
        if path.endswith((".pck", ".wasm")) and headers.get("content-encoding") != "gzip":
            errors.append(f"{path}: effective headers must declare gzip transport")
    for path in ["/engine/" + "a" * 24 + "/index.js", "/engine/" + "a" * 24 + "/index.wasm", "/packs/opening.pck"]:
        headers = effective_headers(config, path)
        cache = headers.get("cache-control", "")
        if "immutable" not in cache or "max-age=31536000" not in cache:
            errors.append(f"{path}: content-addressed transport must use immutable one-year caching")
        if headers.get("content-encoding") != "gzip":
            errors.append(f"{path}: effective headers must declare gzip transport")
    if config.get("outputDirectory") != "web":
        errors.append("Vercel production output must remain tracked web/")
    return errors


def hud_identity_errors(project: Path) -> list[str]:
    labels, errors = {}, []
    for name in ["hud_state.gd", "hud_api.gd", "hud_component.gd"]:
        text = (project / "scripts/hud" / name).read_text(encoding="utf-8")
        match = re.search(r'^const MENU_BUILD_LABEL\s*=\s*"([^"\n]*)"', text, re.MULTILINE)
        if not match or not match[1].strip() or "ASHEN OATH" not in match[1].upper():
            errors.append(f"{name}: current menu product identity is missing")
        else:
            labels[name] = match[1]
    if len(set(labels.values())) > 1:
        errors.append("HUD menu product identities disagree")
    panel = (project / "scripts/hud/menu_panel.gd").read_text(encoding="utf-8")
    if not re.search(r'\bbuild\.text\s*=\s*MENU_BUILD_LABEL\b', panel):
        errors.append("Menu does not render its declared product identity")
    # Release IDs belong to runtime/release manifests and the injected shell;
    # player-facing product text does not need developer tickets or hostnames.
    return errors
