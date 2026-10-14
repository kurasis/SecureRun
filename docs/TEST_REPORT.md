# P01 test report

Run: [38536438262](https://github.com/kurasis/SecureRun/actions/runs/38536438262),
2026-10-14 UTC. Source head: 3529b11d7657fb4520c1aa3b17aaa23f2ff33dfb.
Exact tested PR merge checkout: 795f167855acb46c65e8a1ef21967d7baa91e9fd.
[Structured summary and runtime hashes](evidence/p01/windows-arm64/run-summary.json).

| Check | Expected | Actual / status | Evidence |
|---|---|---|---|
| Repository integrity | 26 unchanged documents, links, pins and all outputs | PASSED locally and Actions | Repository job |
| Tooling regression | Valid hashes pass; tamper/wrong size fail | PASSED: 6 run, 6 passed, 0 failed | Repository job |
| Official source tag | Git and API agree on full commit | PASSED: cdba7096240b93d79c5373aa81a75a1c5c71b883 | [Linux JSON](evidence/p01/linux-provenance.json) |
| x64 EXE on selected lab | Actual Windows execution; native host correctly recorded | PASSED: x64 process on ARM64, Windows 11 26200.9457 | [probe](evidence/p01/windows-arm64/probe.json), [inventory](evidence/p01/windows-arm64/inventory.json) |
| x64 official installer | Expected size/hash, valid Windows signature | PASSED | [trust](evidence/p01/windows-arm64/installer-trust.json) |
| ARM64 official installer | Expected size/hash, valid Windows signature | PASSED | [trust](evidence/p01/windows-arm64/installer-trust-arm64.json) |
| Synthetic fixture | Unique run root, local fixed NTFS, marker/hash, disposable teardown | PASSED for preparation only | [fixture](evidence/p01/windows-arm64/fixtures.json) |
| Engine containment/installed components | Source-backed native driver, actual policy and membership | NOT_RUN: P02 | No installed engine |
| Original Windows 11 x64 tuple | Native OS/driver compatibility | NOT_RUN: selected ARM64 runner does not establish x64 kernel support | Platform limitation |
| Second account/session, endpoints and bounded volumes | Positive controls and actual access results | NOT_RUN: defined for P02 | [fixture contract](LAB_SETUP.md) |

Windows source evidence includes timestamps and exact OS/security/architecture.
Signatures report Valid under Windows trust policy, not a claim of independent
security certification or uniform online revocation evidence. Source versions are
candidate declarations; installed component versions and policy hashes do not yet
exist. Secure Boot is false in the hosted image; no security setting was changed.

The full [66-scenario catalog](test-catalog.json) preserves expected outcomes from
[the specification](specification/08_TESTING_AND_ACCEPTANCE.md). All T01–T66 are
NOT_STARTED. No acceptance scenario is passed or waived by setup. No expected
failure, skip or Not applicable result is used to hide missing runtime evidence.
