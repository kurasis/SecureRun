# P02 — Sandboxie integration feasibility

Specification: 1.3 | Status on handoff: NOT_STARTED

## Goal and dependencies

Complete this phase's concrete outputs and exit gate. Dependencies: P01.

Requirement scope: Feasibility for PR-01, PR-04, PR-08, PR-09, PR-10, PR-16, PR-17.

Read the common [phase workflow](../09_DEVELOPMENT_STAGES.md) and:

- [04_SANDBOXIE_INTEGRATION.md](../04_SANDBOXIE_INTEGRATION.md)
- [05_POLICIES_AND_PERMISSIONS.md](../05_POLICIES_AND_PERMISSIONS.md)
- [06_FILES_AND_LIFECYCLE.md](../06_FILES_AND_LIFECYCLE.md)
- [08_TESTING_AND_ACCEPTANCE.md](../08_TESTING_AND_ACCEPTANCE.md)

## Implementation tasks

1. Build a throwaway native probe/adapter spike separate from production UI commands. Resolve CLI/API signatures, success codes, output formats, privileges and ABI from pinned source.
2. Prove engine fail-closed target creation and membership, child processes, all-session enumeration and exact target-argument behavior.
3. Demonstrate baseline network denial through a verified kernel path, file write containment and selected read denial with positive controls.
4. Resolve configuration writes/inheritance, root creation and ACLs, private workspace mapping, boxed EXE identity and safe cleanup including DeleteCommand/trigger consumers.
5. Establish component trust, optional entitlement observation, WFP/global prerequisites and behavior with password-protected configuration.
6. Record each mandatory operation as Proven, Failed or Unresolved with a concrete implementation route. Prototype writes occur only in disposable fixtures.

7. Resolve the helper authority/enrollment design if needed, own-process sandbox detection, termination binding at dispatch and protection of future sibling roots. Prove these with synthetic lab fixtures; no assumptions based only on prior snapshots.

## Required outputs

- Completed feasibility section of docs/OPERATION_MAP.md with source permalinks.
- docs/FEASIBILITY_REPORT.md covering mandatory operations, limitations and selected bridge strategy.
- Raw Windows probe evidence and a candidate supported-capability matrix.

## Verification

Run representative smoke variants of T01, T05, T08, T09, T12, T33, T35, T36 and T55. These prove the proposed approach only; production implementation tests must run again in owning phases.

Explicit scenario IDs: T01, T05, T08, T09, T12, T33, T35, T36, T55, T57, T58, T60, T62.

Revision 1.3 checks owned here: T57, T58, T60, T62. In P02 these are feasibility probes only; in feature phases execute the applicable production paths. Report partial/blocked portions explicitly.

## Exit gate

Every mandatory operation has a tested viable route, or the gate is explicitly blocked with a proposed resolution. Hooks-only networking, guessed storage mappings or arbitrary cleanup commands cannot pass.

## Scope guard

No production user-target launch and no copying SandMan implementation.

## Handoff and continuation

Update docs/STATUS.md and docs/phases/P02_REPORT.md with code commit, files changed, commands run, evidence, failed/blocked/not-applicable checks, unresolved risks and the next eligible phase. Mark this phase DONE only when the gate passes. P02 prototype evidence cannot stand in for production implementation evidence.

Continuation instruction: "Implement P02 from this specification. First verify its dependencies and existing evidence. Finish its tasks and tests, fix failures, then update the phase report and status. If a dependency is blocked, do only explicitly independent safe work and leave the phase provisional. Do not silently weaken security or drop mandatory scope."

