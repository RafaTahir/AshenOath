import argparse
import re
from pathlib import Path


REQUIRED_ZONES = {
    "greyfen": "scripts/zones/greyfen_section.gd",
    "wychwood": "scripts/zones/wychwood_section.gd",
    "deep_wood": "scripts/zones/campaign_wilderness_section.gd",
    "old_mill": "scripts/zones/campaign_wilderness_section.gd",
    "burned_farmstead": "scripts/zones/campaign_wilderness_section.gd",
    "marsh_crossing": "scripts/zones/campaign_wilderness_section.gd",
    "bandit_road": "scripts/zones/bandit_road_section.gd",
    "vargan_approach": "scripts/zones/castle_vargan_section.gd",
    "vargan_court": "scripts/zones/castle_vargan_section.gd",
    "record_hall": "scripts/zones/castle_vargan_section.gd",
    "undercroft": "scripts/zones/campaign_finale_section.gd",
    "assembly": "scripts/zones/campaign_finale_section.gd",
    "hart_glade": "scripts/zones/campaign_finale_section.gd",
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("project", type=Path)
    args = parser.parse_args()
    project = args.project.resolve()
    preset = (project / "export_presets.cfg").read_text(encoding="utf-8")
    router = (project / "scripts" / "zone_composition_router.gd").read_text(encoding="utf-8")
    campaign_router = (project / "scripts" / "zones" / "campaign_section.gd").read_text(encoding="utf-8")
    hud = (project / "scripts" / "hud.gd").read_text(encoding="utf-8")
    failures: list[str] = []

    if len(re.findall(r"^\[preset\.\d+\]$", preset, re.MULTILINE)) != 2:
        failures.append("one production Web preset and one disposable QA Web preset are required")
    for zone, relative in REQUIRED_ZONES.items():
        resource = f'res://{relative}'
        if f'"{resource}"' not in preset:
            failures.append(f"export omits {resource}")
        if relative.endswith(("greyfen_section.gd", "wychwood_section.gd")) and resource not in router:
            failures.append(f"zone router does not preload {relative}")
        if relative not in ("scripts/zones/greyfen_section.gd", "scripts/zones/wychwood_section.gd"):
            if f'"{zone}"' not in campaign_router:
                failures.append(f"campaign router does not register {zone}")
            if resource not in campaign_router:
                failures.append(f"campaign router does not preload {relative}")
    for runtime in (
        "scripts/qa_browser_telemetry.gd",
        "scripts/save_manager.gd",
        "scripts/story_state.gd",
        "scripts/input_router.gd",
        "scripts/mobile_touch_controls.gd",
        "data/quests.json",
        "data/dialogue.json",
        "data/campaign_dialogue.json",
        "data/enemies.json",
    ):
        if not (project / runtime).exists():
            failures.append(f"runtime resource missing: {runtime}")
    if "data/*.json" not in preset:
        failures.append("campaign data wildcard is absent from the Web preset")
    label = re.search(r'const MENU_BUILD_LABEL = "([^"]+)"', hud)
    release_identity = label.group(1) if label else ""
    if (
        not label
        or not any(ticket in release_identity for ticket in ("WEB-002", "RELEASE-001", "RELEASE-003"))
        or "ASHENOATH.VERCEL.APP" not in release_identity
    ):
        failures.append("visible WEB-002/RELEASE-001/RELEASE-003 identity is missing")

    if failures:
        for failure in failures:
            print(f"WEB-002: FAIL - {failure}")
        return 1
    print(f"WEB-002: PASS - {len(REQUIRED_ZONES)} released campaign zones and browser runtime resources are exportable")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
