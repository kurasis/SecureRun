# P03 — Application foundation, persistence and IPC boundary

Specification: 1.3 | Status on handoff: NOT_STARTED

## Goal and dependencies

Complete this phase's concrete outputs and exit gate. Dependencies: P01, P02.

Requirement scope: PR-11, PR-12, PR-15 foundations.

Read the common [phase workflow](../09_DEVELOPMENT_STAGES.md) and:

- [02_SECURITY_MODEL.md](../02_SECURITY_MODEL.md)
- [03_ARCHITECTURE_AND_DATA.md](../03_ARCHITECTURE_AND_DATA.md)
- [07_UX_SPECIFICATION.md](../07_UX_SPECIFICATION.md)

## Implementation tasks

1. Create or adapt the Tauri/React/TypeScript/Rust workspace with pinned dependencies and minimal navigation.
2. Implement domain types, typed errors, SQLite migrations, journal, orthogonal state model and generation-tagged events.
3. Explicitly configure custom Tauri command permissions, trusted windows/origins and backend authorization. Do not expose raw host shell or filesystem primitives.
4. Implement backend-mediated file selection/operation binding and ID-based commands with independent Rust validation.
5. Add local logs/redaction, English/Russian string infrastructure and backend-driven UI state. Keep mock adapter mode clearly marked and unable to launch real targets.

6. Implement persistent dispatch reservations/idempotency keys, independent environment generations and artifact-identity recovery records. Minimize secrets before local logging and reject control-character log injection.

## Required outputs

- Runnable application shell and domain/persistence modules.
- docs/IPC_CONTRACT.md and documented schema migration/recovery behavior.
- Unit tests for authorization, stale events, journal replay and migration failures.

## Verification

Run T28 pure-data cases, T49 and T56 using the real command boundary where available; verify no remote content can invoke commands. Linux-only portions remain explicitly separated from Windows results.

Explicit scenario IDs: T28, T49, T56, T61, T65, T66.

Revision 1.3 checks owned here: T61, T65, T66. In P02 these are feasibility probes only; in feature phases execute the applicable production paths. Report partial/blocked portions explicitly.

## Exit gate

Typed data flow and custom-command ACLs are enforced; state cannot be corrupted by stale generations. No unscoped command is reachable from the renderer.

## Scope guard

When P02 is blocked, only independent pure-code/scaffolding tasks may proceed provisionally; no engine-dependent production claims.

## Handoff and continuation

Update docs/STATUS.md and docs/phases/P03_REPORT.md with code commit, files changed, commands run, evidence, failed/blocked/not-applicable checks, unresolved risks and the next eligible phase. Mark this phase DONE only when the gate passes. P02 prototype evidence cannot stand in for production implementation evidence.

Continuation instruction: "Implement P03 from this specification. First verify its dependencies and existing evidence. Finish its tasks and tests, fix failures, then update the phase report and status. If a dependency is blocked, do only explicitly independent safe work and leave the phase provisional. Do not silently weaken security or drop mandatory scope."

