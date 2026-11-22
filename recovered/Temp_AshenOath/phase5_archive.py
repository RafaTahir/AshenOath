from pathlib import Path, PurePosixPath
import hashlib
import json
import shutil
import subprocess
import sys

REPO = Path('D:/Temp/AshenOath/phase-0-architecture-ratchet-and-ci').resolve()
PROJECT = 'outputs/AshenOathTheRoadBetweenCrowns/'
ARCHIVE = PROJECT + 'docs/archive/phase5/'
files = subprocess.check_output(['git', 'ls-files'], cwd=REPO, text=True).splitlines()
extensions = ('.gd', '.py', '.ps1', '.mjs', '.js')
candidates = [name for name in files if name.startswith(PROJECT + 'tools/verify_') and name.endswith(extensions)]
candidates += [name for name in files if PurePosixPath(name).parent.as_posix() == PROJECT[:-1]
               and name.endswith(('_REPORT.json', '_MATRIX.md', '_CHECKLIST.md'))]
patterns = sorted({PurePosixPath(name).stem for name in candidates})
scopes = ['*.ps1', '*.py', '*.mjs', '*.js', '*.gd', '*.tscn', '*.yml', '*.yaml',
          'CODEX_WORKFLOW.md', 'DEPLOYMENT_POLICY.md', 'DEPLOYMENT_WORKFLOW.md']
grep = subprocess.run(['git', 'grep', '--cached', '-n', '-I', '-F', '-f', '-', '--', *scopes],
                      cwd=REPO, input='\n'.join(patterns), capture_output=True, text=True)
if grep.returncode not in (0, 1):
    raise RuntimeError(grep.stderr)
references = {stem: set() for stem in patterns}
for line in grep.stdout.splitlines():
    filename, _, body = line.split(':', 2)
    for stem in patterns:
        if stem in body:
            references[stem].add(filename)
protected = [{'path':name, 'referenced_by':sorted(references[PurePosixPath(name).stem])}
             for name in candidates if references[PurePosixPath(name).stem]]
movable = [name for name in candidates if not references[PurePosixPath(name).stem]]
print(f'ARCHIVE PLAN: {len(candidates)} candidates; {len(protected)} referenced and retained; {len(movable)} safe moves')
if '--apply' not in sys.argv:
    print('\n'.join(movable[:12]))
    raise SystemExit(0)
records = []
for name in movable:
    original = (REPO / name).resolve()
    relative = PurePosixPath(name).relative_to(PROJECT.rstrip('/')).as_posix()
    destination = (REPO / ARCHIVE / relative).resolve()
    original.relative_to(REPO)
    destination.relative_to((REPO / ARCHIVE).resolve())
    if not original.is_file() or destination.exists():
        raise RuntimeError(f'Unsafe archive source/destination: {name}')
    digest = hashlib.sha256(original.read_bytes()).hexdigest()
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(original), str(destination))
    if hashlib.sha256(destination.read_bytes()).hexdigest() != digest:
        raise RuntimeError(f'Archive integrity failure: {name}')
    records.append({'original_path':name, 'archived_path':destination.relative_to(REPO).as_posix(),
                    'sha256':digest})
manifest = {'schema_version':1, 'phase':'phase-5-replay-benchmarks-and-repo-cleanup',
            'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=REPO,text=True).strip(),
            'policy':'Only unreferenced historical verifiers/root reports; bytes preserved. Any script/workflow reference protects the original path.',
            'moved':records, 'retained_referenced':protected,
            'not_moved':'No loose project-root REPORT/MATRIX/CHECKLIST files exist in this baseline. Current plans, result links and runtime assets remain in place.'}
target = REPO / PROJECT / 'docs/archive/phase5-index.json'
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
print(f'ARCHIVE COMPLETE: {len(records)} byte-identical files; reverse lookup and SHA-256 recorded in {target.relative_to(REPO)}')
