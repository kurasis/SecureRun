# Development status

Specification: 1.3. Updated: 2026-10-17 UTC. Current scope: full P10 (in progress).

| Phase | Status | Evidence |
|---|---|---|
| P01 | DONE | [Report](phases/P01_REPORT.md) |
| P02 | DONE | [Report](phases/P02_REPORT.md) |
| P03 | DONE | [Report](phases/P03_REPORT.md), [manifest](evidence/p03/manifest.json) |
| P04 | DONE | [Report](phases/P04_REPORT.md), [manifest](evidence/p04/manifest.json) |
| P05 | DONE | [Report](phases/P05_REPORT.md), [manifest](evidence/p05/manifest.json) |
| P06 | DONE | [Report](phases/P06_REPORT.md), [manifest](evidence/p06/manifest.json) |
| P07 | DONE | [Report](phases/P07_REPORT.md), [manifest](evidence/p07/manifest.json) |
| P08 | DONE | [Report](phases/P08_REPORT.md), [manifest](evidence/p08/manifest.json) |
| P09 | DONE | [Report](phases/P09_REPORT.md), [manifest](evidence/p09/manifest.json) |
| P10 | IN_PROGRESS | Internal adversarial review and exact-source P03–P09 revalidation |
| P11–P12 | NOT_STARTED | Packaging and installed acceptance follow P10 |

Previous verified runtime/lab source: `f9a9755a4e32bac27ef65ad9e4b5fdca32f7a67f`.
All P03–P09 gates previously passed on this exact commit; historical documentation/evidence descendants
preserve its protected source bytes. [PR #10](https://github.com/kurasis/SecureRun/pull/10)
contains the implementation and all reviewed project documents/evidence.

Current P10 source changes invalidate the formal P03–P09 manifests pending rerun.
The following table records historical P09 completion, not current P10 validation.

## Historical matching native proof

| Gate | Actions run | Actual result on owner-selected targets |
|---|---|---|
| P03 | [38893325430](https://github.com/kurasis/SecureRun/actions/runs/38893325430) | Each: 19 foundation, 4 app, 3 frontend, 32 command cases; portable job passed |
| P04 | [38893328564](https://github.com/kurasis/SecureRun/actions/runs/38893328564) | Each: 61 adapter tests, 19 native observation/trust cases |
| P05 | [38893332061](https://github.com/kurasis/SecureRun/actions/runs/38893332061) | Each: 61 adapter tests, 45 applicable native cases; T52 N/A because no elevation/helper route exists |
| P06 | [38893334893](https://github.com/kurasis/SecureRun/actions/runs/38893334893) | Server 21 / ARM 22 native launch/control cases |
| P07 | [38893338017](https://github.com/kurasis/SecureRun/actions/runs/38893338017) | Server 28 / ARM 29 native file/boxed-EXE cases; zero actor failures |
| P08 | [38893340716](https://github.com/kurasis/SecureRun/actions/runs/38893340716) | Each: 38 native lifecycle/recovery cases; zero actor failures |
| P09 | [38894071449](https://github.com/kurasis/SecureRun/actions/runs/38894071449) | Each: all 22 native scenarios and 101 UI assertions; zero failures |

P09 includes real native Save of exact reviewed diagnostics, import/export and
collision hashes, Archive/Unarchive/Reset confirmations and postconditions,
keyboard/UIA, English/Russian themes/content/Windows DPI, complete inert filenames,
queued policy review and official editor/archive/browser workflows. Firefox's
observed effective content sandbox level was 9 on both targets.

Both final reference samples contain ten actual idle environments, 10000 files
and more than 60 seconds of complete kernel-job CPU including exited workers and
WebViews. Original targets remain unchanged: Server startup/CPU and ARM CPU/average
memory exceeded budgets, with actual flags and user impact in
[the performance report](PRODUCT_PERFORMANCE_AND_DIAGNOSTICS.md). Measurement
exceptions waive no mandatory functional/security or reference-workload check.

Laboratories: Windows Server 2025 x64 build 26100 and Windows 11 ARM64 build 26200,
including actual x86 and emulated x64 target binaries. Original Sandboxie Plus
1.18.6 / core 5.73.6 / ABI 0x57230, upstream source
`cdba7096240b93d79c5373aa81a75a1c5c71b883`.
These labs do not certify an installed Windows 11 x64 release tuple, paid
entitlement, every plugin or future app/engine update.

Formal manifests retain original JSON, binary provenance, reviewed synthetic
screenshots and exact hashes. Failed/cancelled investigations remain history;
no reporter is killed/trusted/exempted, unknown window hidden, engine bundled or
Windows security/TLS/signature/checksum/browser sandbox check weakened.

All 26 original specification documents are unchanged. Installed T01–T66 final
acceptance remains NOT_STARTED until P12; T48 packaging completes in P11. P09
phase proof does not complete release acceptance. P10 currently revalidates all affected source manifests; previous DONE results are historical until the new exact-source run passes.

The owner authorizes automatic push of all project files, including Markdown and
reviewed structured evidence, followed by ordinary validated merge. Credentials,
private inventories and generated binaries remain excluded.
