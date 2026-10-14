# P10 — Adversarial integration review and regression closure

Specification: 1.3 | Status on handoff: NOT_STARTED

## Goal and dependencies

Complete this phase's concrete outputs and exit gate. Dependencies: P09.

Requirement scope: All applicable security invariants and PR-01–PR-18 regression.

Read the common [phase workflow](../09_DEVELOPMENT_STAGES.md) and:

- [02_SECURITY_MODEL.md](../02_SECURITY_MODEL.md)
- [08_TESTING_AND_ACCEPTANCE.md](../08_TESTING_AND_ACCEPTANCE.md)
- [12_REVIEW_FINDINGS.md](../12_REVIEW_FINDINGS.md)
- [13_TRACEABILITY_AND_GATES.md](../13_TRACEABILITY_AND_GATES.md)

## Implementation tasks

1. Review the implemented trust boundaries and compare every requirement with actual code and test evidence.
2. Exercise command injection, cross-window IPC, same-SID boxed clients, configuration drift, engine failures, external sessions, unsafe links and host broker paths.
3. Repeat network tests with controlled positive endpoints and server observations; confirm cached DNS is not mistaken for egress.
4. Resolve integration regressions from combined launch/policy/file/lifecycle flows. Check bounds on logs, process events and transfers.
5. Mark optional exclusions with reasons; do not waive a mandatory failing scenario or report an internal review as an independent audit.

6. Close R26-R35 against actual implementation: helper authority, own context, mandatory policy rollout, dispatch/termination races, export publication, recovery identities and local diagnostic minimization.

## Required outputs

- docs/SECURITY_REVIEW.md with findings, fixes and residual limits.
- Updated complete test report and requirement traceability.
- Release-blocker list with zero unresolved mandatory containment issues.

## Verification

Run relevant T01–T66 against the integrated build; packaging-only portions remain assigned to P11. Do not postpone feature security tests until this phase: it is an integration closure pass.

Explicit scenario IDs: T01, T02, T03, T04, T05, T06, T07, T08, T09, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20, T21, T22, T23, T24, T25, T26, T27, T28, T29, T30, T31, T32, T33, T34, T35, T36, T37, T38, T39, T40, T41, T42, T43, T44, T45, T46, T47, T48, T49, T50, T51, T52, T53, T54, T55, T56, T57, T58, T59, T60, T61, T62, T63, T64, T65, T66.

Revision 1.3 checks owned here: T57, T58, T59, T60, T61, T62, T63, T64, T65, T66. In P02 these are feasibility probes only; in feature phases execute the applicable production paths. Report partial/blocked portions explicitly.

## Exit gate

All implemented mandatory security behaviors pass and no release-blocking finding remains unresolved.

## Scope guard

No feature expansion or replacement of real Windows evidence with mocks.

## Handoff and continuation

Update docs/STATUS.md and docs/phases/P10_REPORT.md with code commit, files changed, commands run, evidence, failed/blocked/not-applicable checks, unresolved risks and the next eligible phase. Mark this phase DONE only when the gate passes. P02 prototype evidence cannot stand in for production implementation evidence.

Continuation instruction: "Implement P10 from this specification. First verify its dependencies and existing evidence. Finish its tasks and tests, fix failures, then update the phase report and status. If a dependency is blocked, do only explicitly independent safe work and leave the phase provisional. Do not silently weaken security or drop mandatory scope."

