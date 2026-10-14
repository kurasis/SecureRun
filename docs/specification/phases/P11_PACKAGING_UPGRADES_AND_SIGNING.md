# P11 — Packaging, upgrades, signing and retention

Specification: 1.3 | Status on handoff: NOT_STARTED

## Goal and dependencies

Complete this phase's concrete outputs and exit gate. Dependencies: P10.

Requirement scope: PR-14; deployment trust and retention.

Read the common [phase workflow](../09_DEVELOPMENT_STAGES.md) and:

- [01_PRODUCT_REQUIREMENTS.md](../01_PRODUCT_REQUIREMENTS.md)
- [06_FILES_AND_LIFECYCLE.md](../06_FILES_AND_LIFECYCLE.md)
- [10_SOURCES_AND_LICENSING.md](../10_SOURCES_AND_LICENSING.md)

## Implementation tasks

1. Build the Windows manager installer and official WebView2 prerequisite flow. Keep Sandboxie separately installed and independently updated.
2. Choose and document production signing/trust checks; missing signing infrastructure yields a labeled development artifact, not a false signed release.
3. Test administrator-controlled code installation and different-account UAC where a helper exists.
4. Test clean install, upgrade, failed migration rollback and uninstall with retained environments; never blindly downgrade a database schema.
5. Produce dependency/license inventory, reproducible build instructions and an explicit engine/OS compatibility manifest. No automatic engine downgrade or uninstall.

6. Verify helper scope records and enrollment remain protected after install/upgrade and retained-data uninstall. The installed manager/helper context checks and trust paths must match the tested build.

## Required outputs

- Installer/development build with precise status and checksums.
- docs/BUILD.md, INSTALL.md, UPGRADE_AND_UNINSTALL.md and license inventory.
- Packaging/migration/retention evidence.

## Verification

T02, T27–T29, T47/T48/T52, plus clean-machine WebView2 and installer tests. Re-run T01/T05/T08/T12 smoke tests from the installed build.

Explicit scenario IDs: T01, T02, T05, T08, T12, T27, T28, T29, T47, T48, T52, T57, T58.

Revision 1.3 checks owned here: T57, T58. In P02 these are feasibility probes only; in feature phases execute the applicable production paths. Report partial/blocked portions explicitly.

## Exit gate

Installed artifacts preserve the proven boundaries and data retention. Production signing is satisfied or its exact development-build limitation remains visible for P12.

## Scope guard

Do not bundle original engine binaries or add silent updates without a separate approved design.

## Handoff and continuation

Update docs/STATUS.md and docs/phases/P11_REPORT.md with code commit, files changed, commands run, evidence, failed/blocked/not-applicable checks, unresolved risks and the next eligible phase. Mark this phase DONE only when the gate passes. P02 prototype evidence cannot stand in for production implementation evidence.

Continuation instruction: "Implement P11 from this specification. First verify its dependencies and existing evidence. Finish its tasks and tests, fix failures, then update the phase report and status. If a dependency is blocked, do only explicitly independent safe work and leave the phase provisional. Do not silently weaken security or drop mandatory scope."

