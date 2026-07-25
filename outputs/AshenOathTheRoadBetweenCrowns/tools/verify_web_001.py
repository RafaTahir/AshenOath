import argparse
import json
import re
from pathlib import Path


def fail(message: str, failures: list[str]) -> None:
    failures.append(message)
    print(f"WEB-001: FAIL - {message}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("project", type=Path)
    parser.add_argument("repo_root", type=Path)
    args = parser.parse_args()

    project = args.project.resolve()
    root = args.repo_root.resolve()
    failures: list[str] = []
    preset = (project / "export_presets.cfg").read_text(encoding="utf-8")
    project_settings = (project / "project.godot").read_text(encoding="utf-8")
    hud = (project / "scripts" / "hud.gd").read_text(encoding="utf-8")

    if len(re.findall(r"^\[preset\.\d+\]$", preset, re.MULTILINE)) != 1:
        fail("exactly one Web export preset is required", failures)
    required_preset = {
        'name="Web Browser"': "production preset name",
        'platform="Web"': "Web platform",
        'variant/thread_support=false': "single-threaded export",
        'progressive_web_app/enabled=false': "PWA disabled",
        'export_path="../AshenOath_Web/index.html"': "single candidate output",
        'exclude_filter="': "explicit exclusion filter",
    }
    for needle, label in required_preset.items():
        if needle not in preset:
            fail(f"missing {label}: {needle}", failures)
    for excluded in ("tools/*", "Development_Gallery/*", "assets_external/downloads/*"):
        if excluded not in preset:
            fail(f"export does not exclude {excluded}", failures)
    if 'renderer/rendering_method="gl_compatibility"' not in project_settings:
        fail("project is not using the Compatibility renderer", failures)
    if 'viewport_width=1280' not in project_settings or 'viewport_height=720' not in project_settings:
        fail("gameplay viewport is not native 1280x720", failures)
    build_label = re.search(r'const MENU_BUILD_LABEL = "([^"]+)"', hud)
    label_text = build_label.group(1) if build_label else ""
    has_release_identity = "CANDIDATE" in label_text or "ROADMAP MILESTONE" in label_text
    if not build_label or not has_release_identity or "ASHENOATH.VERCEL.APP" not in label_text:
        fail("visible menu build identifier is missing candidate/milestone and production identity", failures)

    vercel = json.loads((root / "vercel.json").read_text(encoding="utf-8"))
    header_rules = vercel.get("headers", [])
    runtime_rule = next(
        (rule for rule in header_rules if "index.pck" in rule.get("source", "")), None
    )
    if not runtime_rule:
        fail("Vercel has no stable-runtime cache rule", failures)
    else:
        cache = next(
            (
                item.get("value", "").lower()
                for item in runtime_rule.get("headers", [])
                if item.get("key", "").lower() == "cache-control"
            ),
            "",
        )
        if "no-cache" not in cache or "must-revalidate" not in cache:
            fail("Godot runtime files must use no-cache, must-revalidate", failures)
    if vercel.get("outputDirectory") != "web":
        fail("Vercel production output must remain tracked web/", failures)

    if failures:
        return 1
    print("WEB-001: PASS - preset, renderer, payload filters, build ID, and hosting headers")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
