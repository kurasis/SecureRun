# P05 — Policy compiler, transactions and safe provisioning

Specification: 1.3 | Status on handoff: NOT_STARTED

## Goal and dependencies

Complete this phase's concrete outputs and exit gate. Dependencies: P04.

Requirement scope: PR-02 creation, PR-08, PR-13, PR-16.

Read the common [phase workflow](../09_DEVELOPMENT_STAGES.md) and:

- [02_SECURITY_MODEL.md](../02_SECURITY_MODEL.md)
- [04_SANDBOXIE_INTEGRATION.md](../04_SANDBOXIE_INTEGRATION.md)
- [05_POLICIES_AND_PERMISSIONS.md](../05_POLICIES_AND_PERMISSIONS.md)
- [06_FILES_AND_LIFECYCLE.md](../06_FILES_AND_LIFECYCLE.md)

## Implementation tasks

1. Implement constrained policy schema/compiler, inheritance analysis, fingerprints and Standard offline/online presets.
2. Implement ownership records, PendingRoot provisioning, nonoverlapping roots, root ACL checks and engine restrictions protecting other boxes/manager metadata.
3. Implement journaled configuration mutation with revision/conflict checks, stop-before-apply, readback and independent enforcement evidence.
4. Resolve WFP prerequisites explicitly; reject hooks-only fallback, network-share exceptions and unauthorized lifecycle automation.
5. Implement safe diagnostic probes in fresh throwaway boxes. Path-specific policy validation must not require publishing a new release for each user grant.
6. If a privileged helper is necessary, implement and validate its narrow protocol now before depending on it. Optional paid presets remain disabled unless legitimately testable.

7. Keep mandatory isolation rules outside editable grants; prove new-sibling protection before writing private data. If elevation exists, derive its resource authority independently of user-writable metadata and test helper self-context/enrollment/path substitution.

## Required outputs

- Policy compiler, provisioning service and verified owned environments.
- Policy/effective-observation reports and conflict-recovery UI.
- Windows policy/ACL/entitlement test evidence and helper decision record.

## Verification

T08–T18, T27, T31, T35, T37–T40, T47, T51–T53, T55. Use trusted diagnostic probes; product target launch is still disabled. Helper-specific tests may be Not applicable only when no helper exists.

Explicit scenario IDs: T08, T09, T10, T11, T12, T13, T14, T15, T16, T17, T18, T27, T31, T35, T37, T38, T39, T40, T47, T51, T52, T53, T55, T57, T58, T59, T60.

Revision 1.3 checks owned here: T57, T58, T59, T60. In P02 these are feasibility probes only; in feature phases execute the applicable production paths. Report partial/blocked portions explicitly.

## Exit gate

Policies and ownership/storage prerequisites are verified before production target launch is implemented. Mandatory baseline controls pass; optional features are accurately excluded when unavailable.

## Scope guard

Do not introduce a raw INI editor or silently remove user protection to make provisioning succeed.

## Handoff and continuation

Update docs/STATUS.md and docs/phases/P05_REPORT.md with code commit, files changed, commands run, evidence, failed/blocked/not-applicable checks, unresolved risks and the next eligible phase. Mark this phase DONE only when the gate passes. P02 prototype evidence cannot stand in for production implementation evidence.

Continuation instruction: "Implement P05 from this specification. First verify its dependencies and existing evidence. Finish its tasks and tests, fix failures, then update the phase report and status. If a dependency is blocked, do only explicitly independent safe work and leave the phase provisional. Do not silently weaken security or drop mandatory scope."

