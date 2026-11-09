"""Apply the retained curve/provenance checks to the two stowed-only idles."""
import hashlib
import json
from pathlib import Path

from verify_living_cast_stage2_sources import verify

ROOT = Path(__file__).resolve().parents[1]
MODELS = ROOT/'models/living_assets_stage3_20261107/player'


def main():
    receipt = json.loads((MODELS/'P01/authoring.json').read_text())
    if not receipt.get('idle_only') or receipt['profile'].get('contact_required', True):
        raise ValueError('Player source must explicitly be idle-only without work contacts')
    recipe = next(row for row in receipt['recipe_snapshot']['files'] if row['name'] == 'author_living_player.py')
    if recipe['sha256'] != receipt.get('player_author_tool_sha256'):
        raise ValueError('Player pose author is not bound to its archived recipe')
    if hashlib.sha256((ROOT/recipe['path']).read_bytes()).hexdigest() != recipe['sha256']:
        raise ValueError('Player archived pose recipe changed')
    verify('P01', MODELS, {'Life_Idle_A': 6.0, 'Life_Idle_B': 8.0})


if __name__ == '__main__':
    main()
