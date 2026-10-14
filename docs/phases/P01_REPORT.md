# P01 report — Repository and Windows lab

- Phase: P01. Specification: 1.3.
- Status: DONE for the explicitly owner-selected Windows 11 ARM64 lab.
- Dependencies: none. All 26 documents read before implementation.
- Platform adjustment: the owner requested GitHub Actions, then Windows 11 ARM64
  instead of Windows Server. This explicitly replaces P01's x64 lab default;
  it does not validate a product platform or waive containment requirements.
- Implementation head: 3529b11d7657fb4520c1aa3b17aaa23f2ff33dfb.
- Tested PR merge checkout: 795f167855acb46c65e8a1ef21967d7baa91e9fd.
- Requirement IDs: PR-01, PR-14 prerequisites; no product requirement accepted.
- Windows: 11 Enterprise, native ARM64, 10.0.26200.9457; Microsoft virtual machine.
- Engine: official Plus 1.18.6/core 5.73.6, source
  cdba7096240b93d79c5373aa81a75a1c5c71b883; candidates only, not installed.

## Outputs and architectural decisions

[Assessment](../REPOSITORY_ASSESSMENT.md),
[ADR](../decisions/0001-p01-scope-and-identity.md),
[lab setup/teardown and bounds](../LAB_SETUP.md), [status](../STATUS.md),
[engine matrix](../ENGINE_MATRIX.md), [operation map](../OPERATION_MAP.md),
[test report](../TEST_REPORT.md), engine pin, full unchanged specification/checksums,
66-entry test catalog, C smoke probe, PowerShell lab scripts, pinned Actions and
6 tooling tests. Original identity SecureRun, reserved namespaces SecureRun,
SecureRunLab and SR_ (not ownership authority). Tauri/Rust architecture retained
for P03. No production launcher, UI, driver, helper or copied engine implementation.

## Verification

- Repository validator and 6/6 tooling tests: PASSED locally and Linux Actions.
- Source tag resolution through Git and GitHub API: matching full commit.
- Official installer TLS/size/hash: PASSED; Windows Authenticode Valid for x64
  and ARM64 distributions. Installed-component trust is not established.
- `./tools/lab/Invoke-P01.ps1 -PrepareFixtures`: PASSED on Windows 11 ARM64,
  executing the actual compiled x64 EXE through built-in Windows emulation.
- OS/architecture/security and unique NTFS synthetic canary: captured successfully.
- T01–T66: NOT_STARTED; zero Windows containment scenarios executed.

[Run 38536438262](https://github.com/kurasis/SecureRun/actions/runs/38536438262)
and [durable JSON evidence](../evidence/p01/windows-arm64/run-summary.json).
The initial smoke run was superseded: GetNativeSystemInfo exposed an emulated
x64 view. IsWow64Process2 now reports native ARM64, and the script requires it to
agree with CIM inventory. Final evidence uses the corrected probe only.
Documentation/evidence commits after this run do not change the tested runtime
source hashes; any later runtime change requires a new run.

## Exit gate and remaining limitations

Repository availability, candidate sources, actual selected lab execution,
provenance, isolated fixtures and bounded teardown contract are documented and
verified for P01's adjusted platform. The hosted VM is discarded after the job.
No engine behavior is inferred from installation/signature success.

P02 must prove the official native ARM64 engine and x64-emulated targets, or
record a blocker with a source-backed alternative. x64 kernel-driver support
cannot come from ARM emulation. The original x64 product tuple needs separate
native x64 evidence. Hosted Secure Boot is false (unchanged); VBS/code integrity
and Defender are active, nested virtualization is not exposed. Normal production
security parity remains unresolved. Second-account/session, endpoints and bounded
volumes are defined, not runtime-tested. No production signing/license is chosen.

Next eligible task: P02 feasibility; not executed during this P01-only request.
