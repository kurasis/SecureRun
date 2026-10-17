# P10 — Adversarial integration review

Status: **DONE**. Dependencies P01–P09 passed; P03–P09 were fully revalidated on
the exact P10 source before closing this gate. Next eligible phase: **P11**.

Exact runtime/lab source: `75b6c0bab24e7ea0edd86a3be2adea6648456a6b`. [Full integration run 39068949002](https://github.com/kurasis/SecureRun/actions/runs/39068949002) completed successfully: one portable job and all 14 native jobs.

Run window: 2026-10-17T20:58:22Z to 2026-10-17T22:02:38Z (UTC), including runner queues. Each scenario below inherits this run/source context and its linked target report. Native summaries bind manager/probe hashes and OS builds; engine components/policy fingerprints are retained in the matching phase proof.

## Findings, fixes and outputs

- P10-F01: diagnostic Save previously relied on a valid preview while native setup
  context could be Unknown. Fresh native manager/bridge context now gates the
  picker and the final file creation; refusal consumes the preview.
- P10-F02: both denied WebViews now attempt all 17 custom commands and must produce
  ACL-specific denials. A missing invocation API cannot count as success.
- P10-F03: actual boxed policy/control/file/lifecycle/history workers reject a
  valid claimed host parent before effects. No elevated helper was introduced.

Production changes: `src-tauri/src/product.rs`, `crates/sandboxie-adapter/src/product.rs`.
Regression changes: `ui/selftest.ts`, `src-tauri/src/ci.rs`, `tools/probe/p05_boxed.ps1`.
Integration/evidence tooling: `.github/workflows/p10.yml`, `retain_p10_evidence.py`,
repository validator, four negative evidence-gate tests and immutable raw-evidence attributes.

Required outputs: [security review](../SECURITY_REVIEW.md),
[complete scoped T01–T66 report](../P10_TEST_REPORT.md),
[PR-01–PR-18/SEC-01–SEC-16 traceability](../REQUIREMENT_TRACEABILITY.md),
[release blocker/prerequisite list](../RELEASE_BLOCKERS.md),
[dependency review](../DEPENDENCY_SECURITY_REVIEW.md) and
[formal integration manifest](../evidence/p10/manifest.json). R26–R35 are individually
closed against implementation and native proof in the security review.

## Actual validation

| Gate | Server 2025 x64 | Windows 11 ARM64 |
|---|---|---|
| P03 | 19 foundation, 4 app, 3 frontend; 36 native IPC cases | 19 foundation, 4 app, 3 frontend; 36 native IPC cases |
| P04 | 62 adapter tests + 19 native cases | 62 adapter tests + 19 native cases |
| P05 | 62 adapter tests + 45 native cases; 1 helper-only N/A | 62 adapter tests + 45 native cases; 1 helper-only N/A |
| P06 | 21 native cases; zero failures | 22 native cases; zero failures |
| P07 | 28 native cases; zero failures | 29 native cases; zero failures |
| P08 | 38 native cases; zero failures | 38 native cases; zero failures |
| P09 | 22 native + 101 UI; FULL release workload | 22 native + 101 UI; FULL release workload |

The complete normal release P09 path passed on both targets, including actual
native Save, import/export/collision hashes, queued policy application, confirmed
Archive/Unarchive/Reset, 10000-file traversal, UIA/keyboard/EN/RU/DPI96/144/192 and
real editor/archive/browser workflows with Firefox own sandbox level 9.
Network repeats used actual positive endpoints and server observations; cached
DNS was separate from observed egress. Command injection, cross-window IPC,
boxed clients, drift, service/driver failures, actual other sessions, unsafe
files/links, host-broker paths, dispatch/termination races and identity-bound
export/cleanup recovery passed their applicable production paths.

Portable validation: 19 foundation + 44 adapter tests, 3 + 4 frontend tests,
TypeScript/Vite build, Rust formatting/Clippy and 22 Python tooling/gate tests.
Windows adapter suites passed 62 tests and normal application suites 4 tests.
No Windows result is substituted by a mock or a P02 feasibility result.

Commands executed from the existing checkout:

```sh
python tools/lab/validate_repository.py
python -m unittest discover -s tests -q
cargo test --locked
cargo fmt --all -- --check
cargo clippy --locked --all-targets -- -D warnings
npm run build
npm test
npm run test:product
```

Actions ran `Invoke-P03.ps1` through `Invoke-P09.ps1` on both laboratories.
The corresponding `retain_p03_evidence.py` through `retain_p09_evidence.py` were
then run in dependency order with this exact commit/run, followed by
`retain_p10_evidence.py`. Source files and original artifact/Git blob bytes were
checked before publication; no tested-source list was reduced.

| Metric | Unchanged target | Server x64 | Windows 11 ARM64 |
|---|---:|---:|---:|
| Interactive startup ms | ≤3000 | 6120.0595 — DEVIATION | 2350.5837 — MET |
| Complete-job idle CPU % | <1 | 1.20385222183 — DEVIATION | 1.09853284926 — DEVIATION |
| Average working set bytes | <250000000 | 232934286 — MET | 244505374 — MET |
| Process update ms | ≤2000 | 684.6 — MET | 1281.3 — MET |
| Added launch ms | <1000 | 441 — MET | 504 — MET |

Original targets remain unchanged. Server startup/CPU and ARM CPU are measured
deviations, with user impact in the performance report. All complete-workload,
functional and security checks passed; mandatory_checks_waived=false.

Retained current completion proof: 904 original JSON files and 22
visually reviewed synthetic PNGs across P03–P09, plus the 66-row integration
catalog and reviewed advisory records. All manifests bind exact hashes and
matching native source. Historical raw proof remains immutable.

The laboratories use original Sandboxie Plus 1.18.6/core 5.73.6/ABI 0x57230,
upstream `cdba7096240b93d79c5373aa81a75a1c5c71b883`, on Server 2025 x64 build
26100 and Windows 11 ARM64 build 26200, including actual x86 and emulated x64
probes. They do not certify an installed Windows 11 x64 release, paid entitlement,
every plugin or future OS/engine/application update. No engine binaries are bundled.

All 26 original specification documents remain unchanged. No elevated product
helper, paid privacy preset or advertised clipboard/device restriction is enabled.
Helper-only subcases are N/A; applicable boxed-client/metadata/root checks passed.
Packaging is P11. Installed T01–T66 acceptance remains NOT_STARTED until P12.

## Exit gate and handoff

Zero unresolved mandatory containment findings remain in the reviewed implemented
scope. No mandatory failing scenario was waived. This is an internal review,
not an independent audit or a first-release security certification. P11 packaging
and P12 installed acceptance remain explicit release prerequisites.
