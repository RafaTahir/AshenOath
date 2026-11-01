import argparse
import json
import re
from pathlib import Path
from web_release_contract import hosting_errors, hud_identity_errors
from verify_web_preset_parity import validate as validate_preset_parity


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

    preset_names = re.findall(r'^name="([^"]+)"$', preset, re.MULTILINE)
    if preset_names.count("Web Browser") != 1 or preset_names.count("Web QA Browser") != 1:
        fail("exactly one production Web preset and one disposable QA Web preset are required", failures)
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
    if '"res://scripts/world_vfx_controller.gd"' not in preset:
        fail("export omits the runtime world VFX controller", failures)
    # The prepared catalog owns current runtime actors. A retired source name
    # appearing only in an exclusion is not proof of exported actor coverage.
    try:
        validate_preset_parity(project / "export_presets.cfg")
    except (OSError, ValueError, KeyError) as error:
        fail(f"runtime ownership: {error}", failures)
    if 'renderer/rendering_method="gl_compatibility"' not in project_settings:
        fail("project is not using the Compatibility renderer", failures)
    if 'viewport_width=1280' not in project_settings or 'viewport_height=720' not in project_settings:
        fail("gameplay viewport is not native 1280x720", failures)
    vercel = json.loads((root / "vercel.json").read_text(encoding="utf-8"))
    for error in hud_identity_errors(project) + hosting_errors(vercel):
        fail(error, failures)

    if failures:
        return 1
    print("WEB-001: PASS - preset, renderer, payload filters, menu identity, and effective hosting headers")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
