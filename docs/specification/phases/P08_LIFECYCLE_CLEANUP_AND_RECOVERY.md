# P08 — Persistence, disposable lifecycle, cleanup and recovery

Specification: 1.3 | Status on handoff: NOT_STARTED

## Goal and dependencies

Complete this phase's concrete outputs and exit gate. Dependencies: P07.

Requirement scope: PR-02 removal, PR-07, PR-10, PR-12.

Read the common [phase workflow](../09_DEVELOPMENT_STAGES.md) and:

- [03_ARCHITECTURE_AND_DATA.md](../03_ARCHITECTURE_AND_DATA.md)
- [06_FILES_AND_LIFECYCLE.md](../06_FILES_AND_LIFECYCLE.md)

## Implementation tasks

1. Implement persistent/disposable behavior using entire-box process state, including other relevant sessions.
2. Implement reset, archive/unarchive and removal with exact retention semantics and explicit destructive confirmation.
3. Validate cleanup consumers/hooks and current roots before dispatch; use only the P02-proven upstream built-in route.
4. Implement operation journal recovery, root rebinding after known cleanup and invalidation of reset boxed-EXE references.
5. Disable conflicting upstream auto-recovery/delete behavior in owned boxes; detect external launches and configuration drift.
6. Preserve persistent workloads if the UI exits and make leftover disposable state visible after crashes.

7. Reconcile uncertain launch and post-rename export outcomes without replay. Reject stale-generation operations and substituted temporary files; recovery must not delete by stored path or filename pattern alone.

## Required outputs

- Complete lifecycle service and recovery UI.
- Failure-injection results for each destructive operation phase.
- Documented retention behavior and archive restoration steps.

## Verification

T06, T18, T24–T26, T28, T33/T34/T36/T42/T43/T48/T55/T56; T48 packaging-related portions finish in P11.

Explicit scenario IDs: T06, T18, T24, T25, T26, T28, T33, T34, T36, T42, T43, T48, T55, T56, T61, T64, T65.

Revision 1.3 checks owned here: T61, T64, T65. In P02 these are feasibility probes only; in feature phases execute the applicable production paths. Report partial/blocked portions explicitly.

## Exit gate

Uncertain identity/activity never authorizes cleanup. Failed operations remain recoverable and cannot silently orphan retained data.

## Scope guard

No encrypted boxes, snapshots, root relocation or engine uninstall.

## Handoff and continuation

Update docs/STATUS.md and docs/phases/P08_REPORT.md with code commit, files changed, commands run, evidence, failed/blocked/not-applicable checks, unresolved risks and the next eligible phase. Mark this phase DONE only when the gate passes. P02 prototype evidence cannot stand in for production implementation evidence.

Continuation instruction: "Implement P08 from this specification. First verify its dependencies and existing evidence. Finish its tasks and tests, fix failures, then update the phase report and status. If a dependency is blocked, do only explicitly independent safe work and leave the phase provisional. Do not silently weaken security or drop mandatory scope."

