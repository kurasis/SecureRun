"""Negative evidence-gate tests; synthetic records never prove Windows containment."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('p10', ROOT / 'tools/lab/retain_p10_evidence.py')
p10 = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(p10)


class IntegrationGateTests(unittest.TestCase):
    def test_stale_successful_phase_cannot_close_integration(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            folder = root / 'docs/evidence/p03'
            folder.mkdir(parents=True)
            (folder / 'manifest.json').write_text(json.dumps({
                'result': 'DONE', 'tested_commit': 'a' * 40}))
            with self.assertRaisesRegex(ValueError, 'same exact source'):
                p10.check_integrated(root, 'b' * 40)

    def test_one_native_target_cannot_close_mandatory_scenario(self):
        proof = {'windows-2025': {3: (ROOT / 'docs/evidence/p03', [
            {'id': f'T{i:02}', 'name': 'synthetic_gate_test', 'passed': True}
            for i in range(1, 67)])}}
        with self.assertRaisesRegex(ValueError, 'both native targets: T01'):
            p10.catalog(proof)

    def test_missing_security_scenario_is_not_an_optional_exclusion(self):
        cases = [{'id': f'T{i:02}', 'name': 'synthetic_gate_test', 'passed': True}
                 for i in range(1, 67) if i != 59]
        proof = {runner: {3: (ROOT / 'docs/evidence/p03', cases)} for runner in p10.RUNNERS}
        with self.assertRaisesRegex(ValueError, 'both native targets: T59'):
            p10.catalog(proof)

    def test_installed_acceptance_and_packaging_remain_separate(self):
        cases = [{'id': f'T{i:02}', 'name': 'synthetic_gate_test', 'passed': True}
                 for i in range(1, 67)]
        proof = {runner: {3: (ROOT / 'docs/evidence/p03', cases)} for runner in p10.RUNNERS}
        rows = p10.catalog(proof)
        self.assertEqual(len(rows), 66)
        self.assertTrue(all(row['installed_acceptance'] == 'NOT_STARTED' for row in rows))
        self.assertEqual(rows[28]['status'], 'ASSIGNED_P11')
        self.assertEqual(rows[31]['status'], 'NOT_APPLICABLE_NOT_ADVERTISED')
        self.assertEqual(rows[51]['status'], 'NOT_APPLICABLE_NO_HELPER')
        self.assertIn('P11/P12', rows[47]['scope'])


if __name__ == '__main__':
    unittest.main()
