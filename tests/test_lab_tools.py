"""Repository integrity and evidence gates, never Windows containment."""
import hashlib
import json
import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('validator', ROOT / 'tools/lab/validate_repository.py')
validator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(validator)


class IntegrityTests(unittest.TestCase):
    def test_official_candidate_structure_and_all_outputs(self):
        validator.validate(ROOT)

    def test_streamed_checksum(self):
        with tempfile.TemporaryDirectory() as tmp:
            file = Path(tmp) / 'fixture'
            data = b'synthetic' * 400000
            file.write_bytes(data)
            validator.verify_file(file, hashlib.sha256(data).hexdigest(), len(data))

    def test_tampering_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            file = Path(tmp) / 'fixture'
            file.write_bytes(b'changed')
            with self.assertRaisesRegex(ValueError, 'Checksum mismatch'):
                validator.verify_file(file, hashlib.sha256(b'original').hexdigest())

    def test_wrong_size_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            file = Path(tmp) / 'fixture'
            file.write_bytes(b'original')
            with self.assertRaisesRegex(ValueError, 'Size mismatch'):
                validator.verify_file(file, hashlib.sha256(b'original').hexdigest(), 1)

    def test_invalid_hash_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Invalid SHA256'):
            validator.verify_file(Path('unused'), 'skip')

    def test_modified_specification_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            copy = Path(tmp)
            shutil.copytree(ROOT / 'docs', copy / 'docs')
            with (copy / 'docs/specification/00_README.md').open('a') as out:
                out.write('\nUnapproved change\n')
            with self.assertRaisesRegex(ValueError, 'Checksum mismatch'):
                validator.validate(copy)

    def test_done_gate_cannot_relabel_historical_evidence(self):
        with tempfile.TemporaryDirectory() as tmp:
            copy = Path(tmp) / 'repo'
            shutil.copytree(ROOT, copy, ignore=shutil.ignore_patterns('.git', 'artifacts', '__pycache__', 'node_modules', 'target', 'dist', 'gen'))
            path = copy / 'docs/evidence/p02/manifest.json'
            manifest = json.loads(path.read_text())
            manifest['result'] = 'DONE'
            for run in manifest['runs']:
                run['role'] = 'historical'
            path.write_text(json.dumps(manifest))
            with self.assertRaisesRegex(ValueError, 'successful current evidence run'):
                validator.validate(copy)

    def test_p05_cannot_close_with_failed_proof_and_stale_dependencies(self):
        with tempfile.TemporaryDirectory() as tmp:
            copy = Path(tmp) / 'repo'
            shutil.copytree(ROOT, copy, ignore=shutil.ignore_patterns('.git', 'artifacts', '__pycache__', 'node_modules', 'target', 'dist', 'gen'))
            path = copy / 'docs/evidence/p05/manifest.json'
            manifest = json.loads(path.read_text())
            manifest['result'] = 'DONE'
            path.write_text(json.dumps(manifest))
            dependency = copy / 'docs/evidence/p04/manifest.json'
            stale = json.loads(dependency.read_text())
            stale['result'] = 'BLOCKED'
            dependency.write_text(json.dumps(stale))
            with self.assertRaisesRegex(ValueError, 'P05 DONE requires current P03/P04 regression'):
                validator.validate(copy)

    def test_p06_cannot_close_without_current_policy_regression(self):
        with tempfile.TemporaryDirectory() as tmp:
            copy = Path(tmp) / 'repo'
            shutil.copytree(ROOT, copy, ignore=shutil.ignore_patterns('.git', 'artifacts', '__pycache__', 'node_modules', 'target', 'dist', 'gen'))
            path = copy / 'docs/evidence/p06/manifest.json'
            manifest = json.loads(path.read_text())
            manifest['result'] = 'DONE'
            path.write_text(json.dumps(manifest))
            dependency = copy / 'docs/evidence/p05/manifest.json'
            stale = json.loads(dependency.read_text())
            stale['result'] = 'BLOCKED'
            dependency.write_text(json.dumps(stale))
            with self.assertRaisesRegex(ValueError, 'P06 DONE requires matching current P03/P04/P05 regression'):
                validator.validate(copy)


if __name__ == '__main__':
    unittest.main()
