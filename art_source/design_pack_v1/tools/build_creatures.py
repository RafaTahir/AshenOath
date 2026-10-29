"""Build selected design-pack creatures without launching the game."""
import argparse
import sys
from pathlib import Path

sys.path.insert(0,str(Path(__file__).resolve().parent))
import build_cursed

if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--ids",nargs="+",required=True)
    parser.add_argument("--render",action="store_true")
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    for asset in args.ids:
        if asset in build_cursed.PROFILES:
            build_cursed.build(asset,args.render)
        else:
            import build_wildlife
            build_wildlife.build(asset,args.render)
