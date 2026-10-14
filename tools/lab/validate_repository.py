"""Validate phase evidence provenance and the untouched specification (stdlib only)."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]


def verify_file(path: Path, expected_hash: str, expected_size: int | None = None) -> None:
    if not re.fullmatch(r'[0-9a-f]{64}', expected_hash):
        raise ValueError('Invalid SHA256 declaration')
    digest = hashlib.sha256()
    with path.open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(block)
    if digest.hexdigest() != expected_hash:
        raise ValueError(f'Checksum mismatch: {path.name}')
    if expected_size is not None and path.stat().st_size != expected_size:
        raise ValueError(f'Size mismatch: {path.name}')


def validate(root: Path) -> None:
    spec = root / 'docs/specification'
    entries = (spec / 'SHA256SUMS').read_text().splitlines()
    recorded = set()
    for line in entries:
        digest, name = line.split('  ', 1)
        path = (spec / name).resolve()
        if not path.is_relative_to(spec.resolve()) or name in recorded:
            raise ValueError('Unsafe or duplicate specification path')
        recorded.add(name)
        verify_file(path, digest)
    actual = {p.relative_to(spec).as_posix() for p in spec.rglob('*.md')}
    if actual != recorded or len(recorded) != 26:
        raise ValueError('Specification must contain the original 26 documents')
    for page in root.rglob('*.md'):
        if any(part in {'.git', 'artifacts'} for part in page.parts):
            continue
        for target in re.findall(r'\[[^\]]*\]\(([^\s)]+)\)', page.read_text(encoding='utf-8')):
            if '://' in target or target.startswith('#'):
                continue
            file_part = target.split('#', 1)[0]
            if file_part and not (page.parent / file_part).exists():
                raise ValueError(f'Broken relative link in {page.relative_to(root)}: {target}')
    pin = json.loads((root / 'docs/engine-candidate.json').read_text())
    if not re.fullmatch(r'[0-9a-f]{40}', pin['source_commit']):
        raise ValueError('Candidate needs a full source commit')
    if pin['support_status'] != 'UNTESTED_CANDIDATE':
        raise ValueError('An unresolved feasibility gate cannot declare a supported engine')
    for installer in (pin['installer'], pin['lab_installer']):
        prefix = f"https://github.com/{pin['repository']}/releases/download/{pin['tag']}/"
        if installer['url'] != prefix + installer['name'] or not re.fullmatch(r'[0-9a-f]{64}', installer['sha256']):
            raise ValueError('Candidate installer must use the pinned official release')
    results = json.loads((root / 'docs/test-catalog.json').read_text())
    if [test['id'] for test in results] != [f'T{i:02}' for i in range(1, 67)]:
        raise ValueError('Acceptance catalog must contain T01–T66 exactly once')
    if any(test['status'] != 'NOT_STARTED' for test in results):
        raise ValueError('Lab feasibility cannot pass a production acceptance scenario')
    for name in ('STATUS', 'REPOSITORY_ASSESSMENT', 'LAB_SETUP', 'ENGINE_MATRIX', 'OPERATION_MAP', 'TEST_REPORT'):
        if not (root / f'docs/{name}.md').is_file():
            raise ValueError(f'Missing P01 output: {name}')
    if not (root / 'docs/phases/P01_REPORT.md').is_file():
        raise ValueError('Missing phase report')
    manifest_path = root / 'docs/evidence/p02/manifest.json'
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text())
        if manifest['phase'] != 'P02' or manifest['result'] != 'BLOCKED':
            raise ValueError('P02 unresolved gate must stay explicit')
        for name in ('FEASIBILITY_REPORT', 'OPERATION_MAP', 'ENGINE_MATRIX'):
            if not (root / f'docs/{name}.md').is_file():
                raise ValueError(f'Missing P02 output: {name}')
        seen = set()
        for entry in manifest['files']:
            name = entry['path']
            path = (manifest_path.parent / name).resolve()
            if name in seen or not path.is_relative_to(manifest_path.parent.resolve()):
                raise ValueError('Unsafe or duplicate evidence path')
            seen.add(name)
            verify_file(path, entry['sha256'], entry['size'])
        for run in manifest['runs']:
            if not re.fullmatch(r'[0-9a-f]{40}', run['tested_commit']):
                raise ValueError('Evidence needs exact tested commit')
            if run['url'] != f"https://github.com/kurasis/SecureRun/actions/runs/{run['id']}":
                raise ValueError('Invalid evidence run provenance')


if __name__ == '__main__':
    try:
        validate(ROOT)
    except (ValueError, OSError, KeyError, json.JSONDecodeError) as error:
        print(f'FAIL: {error}', file=sys.stderr)
        sys.exit(1)
    print('PASS: original specification, links, candidate pin, phase evidence and 66 unrun acceptance entries')
