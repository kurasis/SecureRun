"""A failed or partial installed run must never close the packaging gate."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('p11_gate', ROOT / 'packaging/retain.py')
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


class PackagingGate(unittest.TestCase):
    def test_failed_installed_run_cannot_close_gate(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            (folder / 'run-summary.json').write_text(json.dumps({
                'phase': 'P11', 'result': 'FAILED', 'tested_commit': 'a' * 40,
                'target': 'x86_64-pc-windows-msvc', 'os_build': 26100}))
            with self.assertRaises(ValueError):
                gate.check_target(folder, 'windows-2025', 'a' * 40)

    def test_wrong_architecture_cannot_close_gate(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            (folder / 'run-summary.json').write_text(json.dumps({
                'phase': 'P11', 'result': 'PASSED', 'tested_commit': 'a' * 40,
                'target': 'x86_64-pc-windows-msvc', 'os_build': 26100}))
            with self.assertRaises(ValueError):
                gate.check_target(folder, 'windows-11-arm', 'a' * 40)

    def test_installed_evidence_cannot_waive_final_acceptance(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            folder = root / 'docs/evidence/p11'
            folder.mkdir(parents=True)
            (folder / 'manifest.json').write_text(json.dumps({
                'phase': 'P11', 'result': 'DONE', 'final_acceptance_scenarios_passed': 1}))
            with self.assertRaises(ValueError):
                gate.validate(root)

    def test_required_cases_include_actual_missing_prerequisite_and_data_retention(self):
        self.assertEqual(len(gate.MANDATORY), 25)
        self.assertIn('clean_runtime_prerequisite_uses_original_microsoft_installer', gate.MANDATORY)
        self.assertIn('uninstall_removes_only_code_and_retains_profile_engine_runtime', gate.MANDATORY)
        self.assertIn('future_schema_is_refused_without_downgrade', gate.MANDATORY)


if __name__ == '__main__':
    unittest.main()
