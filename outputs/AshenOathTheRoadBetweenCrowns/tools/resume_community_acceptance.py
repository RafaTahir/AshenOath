"""Run one unchanged --prepare-only receipt on the isolated background desktop."""
import argparse
from pathlib import Path

import run_community_acceptance as common


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--receipt", type=Path, required=True)
    args = parser.parse_args()
    try:
        receipt = common.load_prepared(args.receipt)
        validator = None
        if receipt["seed_contract"].get("suite"):
            from run_full_campaign_acceptance import validate_report
            validator = validate_report
        return common.run(receipt, args.receipt.resolve(), validator)
    except (OSError, ValueError, KeyError) as error:
        parser.exit(2, f"prepared acceptance cannot resume: {error}\n")


if __name__ == "__main__":
    raise SystemExit(main())
