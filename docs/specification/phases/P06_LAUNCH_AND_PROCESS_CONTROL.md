# P06 — Isolated launch and scoped process control

Specification: 1.3 | Status on handoff: NOT_STARTED

## Goal and dependencies

Complete this phase's concrete outputs and exit gate. Dependencies: P05.

Requirement scope: PR-03, PR-04, PR-05, PR-06.

Read the common [phase workflow](../09_DEVELOPMENT_STAGES.md) and:

- [02_SECURITY_MODEL.md](../02_SECURITY_MODEL.md)
- [03_ARCHITECTURE_AND_DATA.md](../03_ARCHITECTURE_AND_DATA.md)
- [04_SANDBOXIE_INTEGRATION.md](../04_SANDBOXIE_INTEGRATION.md)

## Implementation tasks

1. Implement application registration and host-EXE launch through the proven engine path, using prevalidated policy and stable ownership.
2. Separate target arguments/CWD from upstream utility arguments/CWD and inheritance. No normal host-execution recovery path.
3. Implement launch receipts, descendant tracking, short-lived outcomes and PID-reuse handling.
4. Implement Stop selected/Stop managed with independent stop prerequisites; expired optional entitlement must not itself disable safe stopping.
5. Handle rapid launch/stop requests, unknown outcomes, request deduplication/reconciliation and background children. Never derive all-process scope from a prefix alone or replay an uncertain launch automatically.

6. Enforce one dispatch reservation per launch operation across duplicate IPC delivery and restart. Bind Stop to the authorized engine scope/process objects at dispatch and wait for completion; never fall back to numeric-PID killing.

## Required outputs

- Production launch/stop service and basic application/process UI.
- Regression evidence for the actual production adapter.
- Documented action-specific prerequisites and launch failure semantics.

## Verification

T01–T07, T19, T26, T36, T50, T54 and T56. Verify every tested failure leaves no unsandboxed target and does not terminate unrelated workloads.

Explicit scenario IDs: T01, T02, T03, T04, T05, T06, T07, T19, T26, T36, T50, T54, T56, T61, T62.

Revision 1.3 checks owned here: T61, T62. In P02 these are feasibility probes only; in feature phases execute the applicable production paths. Report partial/blocked portions explicitly.

## Exit gate

No target starts before policy/storage prerequisites pass; all failure paths remain fail-closed and scoped stopping works independently from launch eligibility.

## Scope guard

Imported/boxed EXE launching is completed in P07 after its mapping is implemented.

## Handoff and continuation

Update docs/STATUS.md and docs/phases/P06_REPORT.md with code commit, files changed, commands run, evidence, failed/blocked/not-applicable checks, unresolved risks and the next eligible phase. Mark this phase DONE only when the gate passes. P02 prototype evidence cannot stand in for production implementation evidence.

Continuation instruction: "Implement P06 from this specification. First verify its dependencies and existing evidence. Finish its tasks and tests, fix failures, then update the phase report and status. If a dependency is blocked, do only explicitly independent safe work and leave the phase provisional. Do not silently weaken security or drop mandatory scope."

