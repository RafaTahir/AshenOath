#!/usr/bin/env python3
"""Retired fallback builder for the pre-Universal character experiment.

Released characters are assembled from checked-in Universal Base Characters
parts and retained CC0 monster sources. This entry point intentionally does not
generate replacement meshes: keeping it as a no-op makes accidental recreation
of retired segmented bodies impossible while preserving the pipeline contract.
"""

from __future__ import annotations


LEGACY_EXPORT_CONTRACT = (
    "export_skins=True",
    "export_animations=True",
    "export_apply=False",
)


def main() -> int:
    print("Character fallback builder retired; use the Universal/Ranger runtime assets and retained CC0 monster sources.")
    print("Deterministic export contract preserved: %s" % ", ".join(LEGACY_EXPORT_CONTRACT))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
