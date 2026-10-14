# Development status

Specification: 1.3. Current requested phase: P01 only. Updated: 2026-10-14 UTC.

| Phase | Status | Evidence / dependency |
|---|---|---|
| P01 | IN_PROGRESS | [phase report](phases/P01_REPORT.md); independent outputs implemented; CI pending |
| P02 | BLOCKED | Requires Windows 11 x64 runtime lab and completed P01 gate |
| P03–P12 | NOT_STARTED | Follow the canonical phase dependency table |

Completed source work: repository assessment, product/namespaces ADR, unchanged
full specification, official engine candidate pin and Linux provenance, lab setup,
initial operation/engine/test matrices, harmless native Windows probe, GitHub
Windows 11 ARM64 workflow and tooling tests. PR-01/PR-14 prerequisites only;
no product requirement or security scenario is accepted as complete.

Required remaining evidence: Windows smoke and installer trust CI results;
actual Windows 11 x64 engine-capable lab, exact OS/security/hypervisor observations,
synthetic fixture positive controls and observed engine components. ARM64 smoke is
an owner-requested tooling platform adjustment, not a validated kernel adapter.

No installer, production app, launcher, helper, policy or containment exists yet.
[TEST_REPORT](TEST_REPORT.md) distinguishes source checks, runtime blockers and
unrun acceptance scenarios. Next eligible action: finish P01 CI evidence and
provide an engine-capable lab; P02 source-only research may follow in a separate
requested phase, with runtime gate still blocked. P01 does not start P02.
