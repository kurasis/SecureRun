# P01 report — Repository and Windows lab

- Phase: P01. Specification: 1.3.
- Status: IN_PROGRESS (final CI evidence pending; x64 engine lab unavailable).
- Dependencies: none. All 26 specification documents read before implementation.
- Implementation commit: the exact commit is emitted in CI inventory; initial
  repository was unborn. Final run references are recorded below after validation.
- Requirement IDs: PR-01, PR-14 prerequisites; none accepted as product-complete.
- Windows/engine tuple: Windows 11 ARM64 Actions for x64 emulated smoke;
  official Plus 1.18.6/core 5.73.6 candidate, source
  cdba7096240b93d79c5373aa81a75a1c5c71b883, not installed or supported.

## Outputs

[Assessment](../REPOSITORY_ASSESSMENT.md),
[ADR](../decisions/0001-p01-scope-and-identity.md),
[lab](../LAB_SETUP.md), [status](../STATUS.md),
[engine matrix](../ENGINE_MATRIX.md), [operation map](../OPERATION_MAP.md),
[test report](../TEST_REPORT.md), engine pin, unchanged specification and checksums,
66-entry test catalog, lab scripts/probe, pinned Actions workflow and tooling tests.
No production code, engine source copying, privileged helper or target launcher.

## Evidence and commands

- Git remote read: succeeded, initially no branches; main lookup exit 2.
- Official source Git tag and GitHub commit lookup: agreed on full source SHA.
- Verified HTTPS installer download, size and SHA256: PASSED on Linux.
  [Provenance](../evidence/p01/linux-provenance.json).
- `python tools/lab/validate_repository.py`: pending final run.
- `python -m unittest discover -s tests -v`: pending final run.
- `./tools/lab/Invoke-P01.ps1`: pending Windows 11 ARM64 workflow run.
- T01–T66: NOT_STARTED. No containment tests executed or waived.

## Limitations and exit gate

Independent P01 files are implemented. The requested Actions lab can validate
native tool execution and installer provenance. User-mode x64 emulation does not
supply an x64 driver platform. Mandatory runtime lab/fixtures cannot be called
verified from documentation. P01 must remain provisional/BLOCKED if no x64 lab is
available. Do not declare DONE merely because source checks and ARM64 smoke pass.
No production signing or manager redistribution license exists (later-phase work).

Next action: collect CI evidence, then obtain an engine-capable Windows 11 x64 lab.
Do not begin P02 runtime or later product phases during this P01-only request.
