# Development status

Specification: 1.3. Updated: 2026-10-18 UTC. P11 security refresh is IN_PROGRESS; P03–P10 require fresh exact-source Windows proof on the reviewed 1.18.8 engine.

| Phase | Status | Evidence |
|---|---|---|
| P01 | DONE | [Report](phases/P01_REPORT.md) |
| P02 | DONE | [Report](phases/P02_REPORT.md) |
| P03 | BLOCKED | [Report](phases/P03_REPORT.md), [manifest](evidence/p03/manifest.json) |
| P04 | BLOCKED | [Report](phases/P04_REPORT.md), [manifest](evidence/p04/manifest.json) |
| P05 | BLOCKED | [Report](phases/P05_REPORT.md), [manifest](evidence/p05/manifest.json) |
| P06 | BLOCKED | [Report](phases/P06_REPORT.md), [manifest](evidence/p06/manifest.json) |
| P07 | BLOCKED | [Report](phases/P07_REPORT.md), [manifest](evidence/p07/manifest.json) |
| P08 | BLOCKED | [Report](phases/P08_REPORT.md), [manifest](evidence/p08/manifest.json) |
| P09 | BLOCKED | [Report](phases/P09_REPORT.md), [manifest](evidence/p09/manifest.json) |
| P10 | BLOCKED | [Report](phases/P10_REPORT.md), [manifest](evidence/p10/manifest.json) |
| P11 | IN_PROGRESS | Protected development installer and installed Windows checks in progress |
| P12 | NOT_STARTED | Final installed acceptance |

Historical 1.18.6 baseline below; current engine review is [documented separately](P11_ENGINE_UPDATE.md).

Historical runtime/lab source: `75b6c0bab24e7ea0edd86a3be2adea6648456a6b`. [Full integration run 39068949002](https://github.com/kurasis/SecureRun/actions/runs/39068949002) completed successfully: one portable job and all 14 native jobs.

Run window: 2026-10-17T20:58:22Z to 2026-10-17T22:02:38Z (UTC), including runner queues. Each scenario below inherits this run/source context and its linked target report. Native summaries bind manager/probe hashes and OS builds; engine components/policy fingerprints are retained in the matching phase proof.

| Gate | Server 2025 x64 | Windows 11 ARM64 |
|---|---|---|
| P03 | 19 foundation, 4 app, 3 frontend; 36 native IPC cases | 19 foundation, 4 app, 3 frontend; 36 native IPC cases |
| P04 | 62 adapter tests + 19 native cases | 62 adapter tests + 19 native cases |
| P05 | 62 adapter tests + 45 native cases; 1 helper-only N/A | 62 adapter tests + 45 native cases; 1 helper-only N/A |
| P06 | 21 native cases; zero failures | 22 native cases; zero failures |
| P07 | 28 native cases; zero failures | 29 native cases; zero failures |
| P08 | 38 native cases; zero failures | 38 native cases; zero failures |
| P09 | 22 native + 101 UI; FULL release workload | 22 native + 101 UI; FULL release workload |

P10 closed the diagnostic Save self-context gap and expanded actual denied-origin
coverage to all 17 commands and same-SID boxed attacks to every worker family.
Fresh native checks run before the picker and before file creation; a refused
preview is consumed. All implemented mandatory security behaviors passed; zero
unresolved mandatory containment findings remain in the reviewed scope. This is
an internal review, not an independent audit.

Original reviewed completion proof: 904 JSON files and 22 synthetic PNGs.
Every PNG was visually reviewed, JSON privacy-scanned and raw bytes/hash-bound.
Documentation/evidence descendants preserve all 152 protected P10 source files.

| Metric | Unchanged target | Server x64 | Windows 11 ARM64 |
|---|---:|---:|---:|
| Interactive startup ms | ≤3000 | 6120.0595 — DEVIATION | 2350.5837 — MET |
| Complete-job idle CPU % | <1 | 1.20385222183 — DEVIATION | 1.09853284926 — DEVIATION |
| Average working set bytes | <250000000 | 232934286 — MET | 244505374 — MET |
| Process update ms | ≤2000 | 684.6 — MET | 1281.3 — MET |
| Added launch ms | <1000 | 441 — MET | 504 — MET |

Both samples contain ten real idle environments, 10000 files, more than 60 seconds
of complete kernel-job accounting and no inspector. Server startup/CPU and ARM
CPU exceed original targets; memory, update and added-launch targets were met.
See [measured budgets](PRODUCT_PERFORMANCE_AND_DIAGNOSTICS.md) for actual flags
and user impact; no mandatory function or workload was waived.

The laboratories use original Sandboxie Plus 1.18.6/core 5.73.6/ABI 0x57230,
upstream `cdba7096240b93d79c5373aa81a75a1c5c71b883`, on Server 2025 x64 build
26100 and Windows 11 ARM64 build 26200, including actual x86 and emulated x64
probes. They do not certify an installed Windows 11 x64 release, paid entitlement,
every plugin or future OS/engine/application update. No engine binaries are bundled.

All 26 original specification documents remain unchanged. No elevated product
helper, paid privacy preset or advertised clipboard/device restriction is enabled.
Helper-only subcases are N/A; applicable boxed-client/metadata/root checks passed.
Packaging is P11. Installed T01–T66 acceptance remains NOT_STARTED until P12.

See [security review](SECURITY_REVIEW.md), [complete scoped test report](P10_TEST_REPORT.md),
[requirement traceability](REQUIREMENT_TRACEABILITY.md), [release prerequisites](RELEASE_BLOCKERS.md)
and [dependency advisory review](DEPENDENCY_SECURITY_REVIEW.md).

P10 historical runtime checks passed; new packaging workflow and attribute inputs require a fresh integrated regression run before P11 closes.

Current phase: **P11**. The owner authorizes automatic publication of all
project files, including Markdown/reviewed evidence, and ordinary validated merge.
Credentials, generated binaries and private inventories remain excluded.
