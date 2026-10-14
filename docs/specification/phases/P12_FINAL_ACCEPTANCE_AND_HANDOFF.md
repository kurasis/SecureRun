# P12 — Final acceptance and developer/user handoff

Specification: 1.3 | Status on handoff: NOT_STARTED

## Goal and dependencies

Complete this phase's concrete outputs and exit gate. Dependencies: P11.

Requirement scope: PR-01–PR-18 and all applicable release gates.

Read the common [phase workflow](../09_DEVELOPMENT_STAGES.md) and:

- [00_README.md](../00_README.md)
- [08_TESTING_AND_ACCEPTANCE.md](../08_TESTING_AND_ACCEPTANCE.md)
- [13_TRACEABILITY_AND_GATES.md](../13_TRACEABILITY_AND_GATES.md)

## Implementation tasks

1. Validate the final source commit, installed build, hashes and exact supported platform/capability matrix.
2. Run the applicable T01–T66 suite on the final candidate; reuse evidence only for identical relevant code/build/environment, with justification.
3. Review every mandatory requirement, optional exclusion and known limitation. Do not erase Blocked results from the report.
4. Produce release notes, user setup/recovery help, test report and maintenance/revalidation instructions.
5. Finish STATUS and handoff with reproducible next steps. If any gate remains blocked, deliver a clearly incomplete/development result with exact blockers.

6. Confirm R26-R35 are implemented and verified, or list exact release blockers. Distinguish specification corrections from runtime evidence in the final handoff.

## Required outputs

- Final source/build artifacts, checksums and release/development notes.
- Complete evidence matrix, limitations and supported versions/capabilities.
- docs/HANDOFF.md and final docs/STATUS.md.

## Verification

All applicable T01–T66, UX/performance evidence and package validation. A static UI or source-only build cannot pass Windows containment gates.

Explicit scenario IDs: T01, T02, T03, T04, T05, T06, T07, T08, T09, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, T20, T21, T22, T23, T24, T25, T26, T27, T28, T29, T30, T31, T32, T33, T34, T35, T36, T37, T38, T39, T40, T41, T42, T43, T44, T45, T46, T47, T48, T49, T50, T51, T52, T53, T54, T55, T56, T57, T58, T59, T60, T61, T62, T63, T64, T65, T66.

Revision 1.3 checks owned here: T57, T58, T59, T60, T61, T62, T63, T64, T65, T66. In P02 these are feasibility probes only; in feature phases execute the applicable production paths. Report partial/blocked portions explicitly.

## Exit gate

Every mandatory criterion passes, or the outcome is explicitly classified as incomplete. No claims of production readiness without required evidence.

## Scope guard

Do not automatically publish, purchase services, or claim independent certification.

## Handoff and continuation

Update docs/STATUS.md and docs/phases/P12_REPORT.md with code commit, files changed, commands run, evidence, failed/blocked/not-applicable checks, unresolved risks and the next eligible phase. Mark this phase DONE only when the gate passes. P02 prototype evidence cannot stand in for production implementation evidence.

Continuation instruction: "Implement P12 from this specification. First verify its dependencies and existing evidence. Finish its tasks and tests, fix failures, then update the phase report and status. If a dependency is blocked, do only explicitly independent safe work and leave the phase provisional. Do not silently weaken security or drop mandatory scope."

