import argparse
import configparser
import fnmatch
import json
import os
import re
from collections import defaultdict
from pathlib import Path


parser = argparse.ArgumentParser()
parser.add_argument('project', type=Path)
parser.add_argument('report', type=Path)
args = parser.parse_args()
project = args.project.resolve()
roots = [project / 'assets', project / 'assets_external']
models = sorted(p for root in roots for p in root.rglob('*') if p.is_file() and p.suffix.lower() in {'.fbx', '.obj'})
by_name = defaultdict(list)
for model in models:
    by_name[model.name.lower()].append(model)
pattern = re.compile('|'.join(re.escape(name) for name in sorted(by_name, key=len, reverse=True)), re.I)
references = defaultdict(set)
direct = defaultdict(set)
text_types = {'.gd', '.tscn', '.tres', '.json', '.gltf', '.py', '.ps1', '.cfg', '.import'}
binary_types = {'.res', '.scn'}
ignored = {'.git', '.godot', '.release-gate', '.verification-cache', 'node_modules', 'release_reports', 'verification_screenshots', 'Development_Gallery', '__pycache__'}
for folder, dirs, files in os.walk(project):
    dirs[:] = [d for d in dirs if d not in ignored]
    for name in files:
        source = Path(folder) / name
        if source == project / 'asset_manifest.json' or source.suffix.lower() not in text_types | binary_types:
            continue
        # The export preset is handled per section below, including exclusions.
        if source.name == 'export_presets.cfg':
            continue
        content = source.read_bytes().decode('latin1') if source.suffix.lower() in binary_types else source.read_text(encoding='utf-8-sig', errors='replace')
        lower = content.lower()
        if '.fbx' not in lower and '.obj' not in lower:
            continue
        found = {match.group(0).lower() for match in pattern.finditer(content)}
        relative = source.relative_to(project).as_posix()
        for found_name in found:
            for model in by_name[found_name]:
                if source == Path(str(model) + '.import'):
                    continue
                # Basename matches retain every ambiguous duplicate. This is
                # deliberately conservative about dynamically composed paths.
                references[model].add(relative)
                if source.suffix.lower() in {'.gd', '.tscn'}:
                    direct[model].add(relative)

presets = configparser.RawConfigParser(strict=False)
presets.read(project / 'export_presets.cfg', encoding='utf-8')
for section in presets.sections():
    name = presets.get(section, 'name', fallback='').strip('"')
    if name not in {'Web Browser', 'Web QA Browser'} and not name.startswith('Runtime Pack '):
        continue
    values = lambda key: re.findall(r'"([^"]*)"', presets.get(section, key, fallback=''))
    includes = values('export_files') + [p for value in values('include_filter') for p in value.split(',')]
    excludes = [p for value in values('exclude_filter') for p in value.split(',')]
    for model in models:
        relative = model.relative_to(project).as_posix()
        if any(fnmatch.fnmatchcase(relative, rule.removeprefix('res://')) for rule in includes) and not any(fnmatch.fnmatchcase(relative, rule.removeprefix('res://')) for rule in excludes):
            references[model].add('export_presets.cfg:' + name)

records = []
for model in models:
    records.append({
        'path': model.relative_to(project).as_posix(),
        'bytes': model.stat().st_size,
        'direct_gd_tscn_owners': sorted(direct[model]),
        'all_owners': sorted(references[model]),
        'disposition': 'retain' if references[model] else 'remove_unused',
    })
unused = [record for record in records if record['disposition'] == 'remove_unused']
report = {
    'policy': 'Remove only FBX/OBJ without code, scene, catalog, import, tool, binary-resource or enabled export ownership; ambiguous basename matches retain all duplicates. Raw inventory entries are not runtime owners.',
    'project': str(project),
    'models_audited': len(records),
    'models_retained': len(records) - len(unused),
    'models_unused': len(unused),
    'unused_source_bytes': sum(record['bytes'] for record in unused),
    'web_savings': 'Not measured. Excluded authoring-source removal does not imply smaller Web transport.',
    'models': records,
}
args.report.parent.mkdir(parents=True, exist_ok=True)
args.report.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps({key: value for key, value in report.items() if key != 'models'}, indent=2))
