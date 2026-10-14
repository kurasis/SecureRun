# P04 — Trusted engine discovery and read-only observation

Specification: 1.3 | Status on handoff: NOT_STARTED

## Goal and dependencies

Complete this phase's concrete outputs and exit gate. Dependencies: P02, P03.

Requirement scope: PR-01, PR-05, PR-13, PR-17 observation foundations.

Read the common [phase workflow](../09_DEVELOPMENT_STAGES.md) and:

- [03_ARCHITECTURE_AND_DATA.md](../03_ARCHITECTURE_AND_DATA.md)
- [04_SANDBOXIE_INTEGRATION.md](../04_SANDBOXIE_INTEGRATION.md)

## Implementation tasks

1. Implement component trust and safe installed-path discovery without executing PATH/current-directory impostors.
2. Implement read-only box/root/configuration queries, process identity and all-session completeness reporting.
3. Separate engine connection generations, cached release evidence and fresh observations. Handle service restart, sleep/resume, untested versions and partial data.
4. Represent optional capability/entitlement availability with provenance and unknown status. Existing unowned boxes remain read-only.
5. Bound subprocess output and bridge responses. Keep host-side utilities in a trusted CWD/environment; validate any native DLL loading.

6. Gate control-plane availability on the manager/bridge own-process unboxed-context check. Unknown context allows only the minimum read-only detection needed for setup; test boxed manager startup.

## Required outputs

- Production read-only Sandboxie adapter and health/capability dashboard.
- Versioned engine compatibility manifest format.
- Windows observation and trust-test evidence.

## Verification

T01/T02/T07/T36/T46/T50/T56. Use fixtures created by P02 where needed; do not add production target launch early.

Explicit scenario IDs: T01, T02, T07, T36, T46, T50, T56, T58.

Revision 1.3 checks owned here: T58. In P02 these are feasibility probes only; in feature phases execute the applicable production paths. Report partial/blocked portions explicitly.

## Exit gate

Trust, identity and observation failures are explicit; incomplete enumeration is never Idle. Unrelated boxes are never mutated.

## Scope guard

No unrestricted configuration mutation, cleanup or production launch API.

## Handoff and continuation

Update docs/STATUS.md and docs/phases/P04_REPORT.md with code commit, files changed, commands run, evidence, failed/blocked/not-applicable checks, unresolved risks and the next eligible phase. Mark this phase DONE only when the gate passes. P02 prototype evidence cannot stand in for production implementation evidence.

Continuation instruction: "Implement P04 from this specification. First verify its dependencies and existing evidence. Finish its tasks and tests, fix failures, then update the phase report and status. If a dependency is blocked, do only explicitly independent safe work and leave the phase provisional. Do not silently weaken security or drop mandatory scope."

