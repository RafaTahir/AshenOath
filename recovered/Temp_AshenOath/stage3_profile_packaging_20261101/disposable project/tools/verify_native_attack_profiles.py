import sys,json
from pathlib import Path
Path(__file__).with_name("profile-args.json").write_text(json.dumps(sys.argv[1:]))
raise SystemExit(47)
