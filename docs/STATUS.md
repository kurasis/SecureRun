# Development status

Specification: 1.3. Updated: 2026-10-14 UTC. Requested scope: full P02.

P02 continuation is in progress on `p02/complete-feasibility`. The retained
`2eb5fd0` evidence is historical for interfaces changed by this continuation;
new ordinary-user, same-SID session and sealed-cleanup results must be retained
before the gate can change. Every source and Markdown change is published.

| Phase | Status | Evidence / dependency |
|---|---|---|
| P01 | DONE (owner-selected Windows 11 ARM64 lab) | [P01 report](phases/P01_REPORT.md), retained provenance |
| P02 | BLOCKED (spike and research implemented) | [P02 report](phases/P02_REPORT.md), [feasibility](FEASIBILITY_REPORT.md), [operation map](OPERATION_MAP.md) |
| P03–P12 | NOT_STARTED | P02 exit gate has unresolved mandatory variants |

The full 26-document specification remains unchanged. P02 adds disposable Actions
labs on Windows Server 2025 x64 (genuine x86/x64 target probes) and Windows 11 ARM64
(native ARM64 plus emulated x86/x64 targets), as the owner requested. No supported
production tuple or production acceptance scenario is declared. All T01–T66 remain
NOT_STARTED; smoke evidence is separate and must be repeated in owning phases.

Implemented: source-pinned original DLL adapter, authenticated engine install and
component inventory, explicit PE targets, fresh-box native configuration/readback,
representative kernel WFP controls, virtual write/read exclusion tests, ACL tests
with a second standard account, bounded all-session enumeration, held-object stop,
boxed-context refusal, future-sibling direct/junction denial, private workspace
mapping and narrow original-library cleanup research. Exact current outcomes and
failed/blocked cases are retained in [Windows evidence](evidence/p02/manifest.json).

P02 remains BLOCKED on same-SID second interactive session, ordinary-user
provisioning, parent/descendant replacement and concurrent external-launch safety,
termination fault variants, signed engine-log reader integration and complete
baseline release coverage. Cleanup smoke
success does not prove hostile race containment. No broad Start.exe phase2,
arbitrary DeleteCommand, generic root deleter, permanent privileged manager or
security-setting bypass is used. Concrete resolutions are recorded in the report.

No production app/helper/launcher/installer is implemented. No SandMan code or
engine binary is copied/bundled. Original installed QSbieAPI native cleanup adds
an explicit runtime licensing/dependency decision before production distribution.
The hosted security observations and Windows 11 x64 compatibility gap remain
visible in [the candidate matrix](ENGINE_MATRIX.md). Next eligible work: remaining
P02 gates; P03 is not automatically started after a green artifact-collection job.
