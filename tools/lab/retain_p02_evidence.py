"""Retain completed Actions JSON byte-for-byte; never generate containment results."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
REQUIRED = {'T01', 'T05', 'T08', 'T09', 'T12', 'T33', 'T35', 'T36', 'T55', 'T57', 'T58', 'T60', 'T62'}


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def record(path, relative):
    data = path.read_bytes()
    return {'path': relative, 'sha256': hashlib.sha256(data).hexdigest(), 'size': len(data)}


def retain(download, commit, run_id):
    if not re.fullmatch('[0-9a-f]{40}', commit) or run_id <= 0:
        raise ValueError('Full tested commit and actual Actions run ID are required')
    run = json.loads(subprocess.check_output(['gh', 'run', 'view', str(run_id), '--json', 'databaseId,headSha,conclusion,status'], cwd=ROOT))
    if run['databaseId'] != run_id or run['headSha'] != commit or run['status'] != 'completed' or run['conclusion'] != 'success':
        raise ValueError('Actions provenance does not match the completed successful checkout')
    evidence = ROOT / 'docs/evidence/p02'
    manifest_path = evidence / 'manifest.json'
    manifest = read(manifest_path)
    targets, copies = [], []
    for runner in ('windows-2025', 'windows-11-arm'):
        source = download / f'p02-{runner}-{commit}'
        phase, cases = read(source / 'phase-result.json'), read(source / 'feasibility-cases.json')
        worker = read(source / 'standard-user-result.json')['worker']
        counts = dict(Counter(case['status'] for case in cases))
        if phase['result'] != 'DONE' or phase['gate_blockers'] or set(counts) - {'PASSED', 'NOT_APPLICABLE'}:
            raise ValueError(f'{runner}: actual feasibility gate is not complete')
        if not REQUIRED.issubset({case['id'] for case in cases if case['status'] == 'PASSED'}):
            raise ValueError(f'{runner}: required representative evidence is missing')
        if worker['status'] != 'PASSED' or not worker['standard_user'] or worker['elevated_helper']:
            raise ValueError(f'{runner}: standard-user route is not proven')
        installation = read(source / 'installation.json')
        if installation['manager_commit'] != commit:
            raise ValueError('Installed lab evidence belongs to another checkout')
        relative = f'completion-{commit[:7]}/{runner}'
        for path in sorted(source.glob('*.json')):
            destination = evidence / relative / path.name
            if destination.exists() and destination.read_bytes() != path.read_bytes():
                raise ValueError('Existing evidence cannot be silently overwritten')
            copies.append((path, destination, record(path, f'{relative}/{path.name}')))
        targets.append({'runner': runner, 'tested_commit': commit, 'evidence_directory': relative,
                        'gate_result': phase['result'], 'smoke_counts': counts,
                        'os': installation['os'], 'ubr': installation['os_update_build_revision']})
    sources = []
    paths = ['docs/engine-candidate.json', '.github/workflows/p02.yml', 'tools/lab/Build-P02.ps1',
             'tools/lab/Initialize-P02.ps1', 'tools/lab/Invoke-P02.ps1'] + [
             path.relative_to(ROOT).as_posix() for path in sorted((ROOT / 'tools/probe').glob('*'))
             if path.is_file() and path.name != 'lab_probe.c' and path.suffix in {'.ps1', '.cs', '.c'}]
    for path in paths:
        data = subprocess.check_output(['git', 'show', f'{commit}:{path}'], cwd=ROOT)
        if (ROOT / path).read_bytes() != data:
            raise ValueError(f'Tested source differs from current checkout: {path}')
        sources.append({'path': path, 'sha256': hashlib.sha256(data).hexdigest(), 'size': len(data)})
    # Validation precedes any mutation; downloaded result files are the sole source.
    for source, destination, _ in copies:
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)
    for run in manifest['runs']:
        run['role'] = 'historical'
    manifest['runs'].append({'id': run_id, 'url': f'https://github.com/kurasis/SecureRun/actions/runs/{run_id}',
                             'tested_commit': commit, 'role': 'current',
                             'job_collection_conclusion': 'success', 'targets': targets})
    known = {entry['path']: entry for entry in manifest['files']}
    known.update({entry['path']: entry for _, _, entry in copies})
    manifest.update(result='DONE', tested_sources=sources, files=sorted(known.values(), key=lambda entry: entry['path']),
                    note='Completed representative P02 feasibility only. Historical blocked evidence is preserved; no production acceptance or supported release tuple.')
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(targets, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--download-directory', type=Path, required=True)
    parser.add_argument('--tested-commit', required=True)
    parser.add_argument('--run-id', type=int, required=True)
    args = parser.parse_args()
    retain(args.download_directory, args.tested_commit, args.run_id)
