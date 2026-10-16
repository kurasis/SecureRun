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
    def test_focused_p09_run_cannot_claim_a_full_gate_even_with_passed_status(self):
        spec = importlib.util.spec_from_file_location('p09_retainer', ROOT / 'tools/lab/retain_p09_evidence.py')
        retainer = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(retainer)
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            (folder / 'run-summary.json').write_text(json.dumps({
                'phase': 'P09', 'result': 'PASSED', 'workload_mode': 'DIAGNOSTIC_ONLY',
            }))
            for name, data in [('product-cases.json', []), ('ui-cases.json', []), ('standard-product.json', {})]:
                (folder / name).write_text(json.dumps(data))
            with self.assertRaisesRegex(ValueError, 'native architecture/source/result'):
                retainer.check_target(folder, 'a' * 40, '8664')

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


    def test_p07_cannot_close_without_current_launch_regression(self):
        with tempfile.TemporaryDirectory() as tmp:
            copy = Path(tmp) / 'repo'
            shutil.copytree(ROOT, copy, ignore=shutil.ignore_patterns('.git', 'artifacts', '__pycache__', 'node_modules', 'target', 'dist', 'gen'))
            path = copy / 'docs/evidence/p07/manifest.json'
            manifest = json.loads(path.read_text())
            manifest['result'] = 'DONE'
            path.write_text(json.dumps(manifest))
            dependency = copy / 'docs/evidence/p06/manifest.json'
            stale = json.loads(dependency.read_text())
            stale['result'] = 'BLOCKED'
            dependency.write_text(json.dumps(stale))
            with self.assertRaisesRegex(ValueError, 'P07 DONE requires matching current P03/P04/P05/P06 regression'):
                validator.validate(copy)

    def test_p08_cannot_close_without_current_file_regression(self):
        with tempfile.TemporaryDirectory() as tmp:
            copy = Path(tmp) / 'repo'
            shutil.copytree(ROOT, copy, ignore=shutil.ignore_patterns('.git', 'artifacts', '__pycache__', 'node_modules', 'target', 'dist', 'gen'))
            path = copy / 'docs/evidence/p08/manifest.json'
            manifest = json.loads(path.read_text())
            manifest['result'] = 'DONE'
            path.write_text(json.dumps(manifest))
            dependency = copy / 'docs/evidence/p07/manifest.json'
            stale = json.loads(dependency.read_text())
            stale['result'] = 'BLOCKED'
            dependency.write_text(json.dumps(stale))
            with self.assertRaisesRegex(ValueError, 'P08 DONE requires matching current P03/P04/P05/P06/P07 regression'):
                validator.validate(copy)

    def test_p08_cleanup_component_pins_cannot_be_substituted(self):
        with tempfile.TemporaryDirectory() as tmp:
            copy = Path(tmp) / 'repo'
            shutil.copytree(ROOT, copy, ignore=shutil.ignore_patterns('.git', 'artifacts', '__pycache__', 'node_modules', 'target', 'dist', 'gen'))
            path = copy / 'crates/sandboxie-adapter/cleanup-compatibility-v1.json'
            pins = json.loads(path.read_text())
            pins['targets'][0]['components'][0]['sha256'] = '0' * 64
            path.write_text(json.dumps(pins))
            # Even self-consistent source checksum edits cannot replace the
            # independent authenticated P02 installation inventory.
            data = path.read_bytes()
            for phase in range(3, 9):
                evidence = copy / f'docs/evidence/p{phase:02}/manifest.json'
                manifest = json.loads(evidence.read_text())
                for source in manifest.get('tested_sources', []):
                    if source['path'] == path.relative_to(copy).as_posix():
                        source.update(sha256=hashlib.sha256(data).hexdigest(), size=len(data))
                evidence.write_text(json.dumps(manifest))
            with self.assertRaisesRegex(ValueError, 'P08 cleanup component pins differ'):
                validator.validate(copy)

    def test_p09_cannot_close_without_current_lifecycle_regression(self):
        with tempfile.TemporaryDirectory() as tmp:
            copy=Path(tmp)/'repo'
            shutil.copytree(ROOT,copy,ignore=shutil.ignore_patterns('.git','artifacts','__pycache__','node_modules','target','dist','gen'))
            path=copy/'docs/evidence/p09/manifest.json';manifest=json.loads(path.read_text());manifest['result']='DONE';path.write_text(json.dumps(manifest))
            dependency=copy/'docs/evidence/p08/manifest.json';stale=json.loads(dependency.read_text());stale['result']='BLOCKED';dependency.write_text(json.dumps(stale))
            with self.assertRaisesRegex(ValueError,'P09 DONE requires matching current P03 through P08 regressions'):
                validator.validate(copy)

if __name__ == '__main__':
    unittest.main()
