"""Instrumented observations cannot certify the product performance gate."""
import importlib.util
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('p09_provenance', ROOT / 'tools/lab/retain_p09_evidence.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)
COMMIT = 'a' * 40


class RunProvenanceTests(unittest.TestCase):
    def test_only_the_full_gate_workflows_are_eligible(self):
        run = {'head_sha': COMMIT, 'status': 'completed', 'conclusion': 'success'}
        for path in ('.github/workflows/p09.yml', '.github/workflows/p10.yml'):
            with self.subTest(path=path):
                MODULE.check_run({**run, 'path': path}, COMMIT)
        for path in ('.github/workflows/p11-diagnostics.yml', None, '.github/workflows/p09-build.yml'):
            with self.subTest(path=path), self.assertRaises(ValueError):
                MODULE.check_run({**run, 'path': path}, COMMIT)

    def test_workflow_name_does_not_override_failed_or_different_source(self):
        run = {'head_sha': COMMIT, 'status': 'completed', 'conclusion': 'success',
               'path': '.github/workflows/p10.yml'}
        for change in ({'head_sha': 'b' * 40}, {'status': 'in_progress'},
                       {'conclusion': 'failure'}, {'conclusion': 'cancelled'}):
            with self.subTest(change=change), self.assertRaises(ValueError):
                MODULE.check_run({**run, **change}, COMMIT)
