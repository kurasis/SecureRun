# P09 — Product UX, localization and application compatibility

Specification: 1.3 | Status on handoff: NOT_STARTED

## Goal and dependencies

Complete this phase's concrete outputs and exit gate. Dependencies: P08.

Requirement scope: PR-11, PR-15, PR-18 UI; real-app validation.

Read the common [phase workflow](../09_DEVELOPMENT_STAGES.md) and:

- [01_PRODUCT_REQUIREMENTS.md](../01_PRODUCT_REQUIREMENTS.md)
- [07_UX_SPECIFICATION.md](../07_UX_SPECIFICATION.md)

## Implementation tasks

1. Complete the original restrained interface, onboarding, environment views, settings and errors using real backend state.
2. Show activity separately from launch eligibility; expose exact unavailable-capability reasons and Standard read-access limitations.
3. Finish English/Russian text, keyboard/screen-reader behavior, themes and 100/150/200 percent scaling.
4. Validate official editor/archive/browser versions with clean profiles and an existing host browser instance.
5. Measure documented startup/idle/list workloads across manager WebView processes; keep diagnostic export redacted and explicitly selected.

6. Show mandatory rules as read-only, unknown launch outcomes honestly, and complete/escaped filenames. Verify local and exported diagnostics contain no synthetic secret canaries.

## Required outputs

- Complete product UI and localization resources.
- Application compatibility matrix and UX/accessibility report.
- Measured performance report and diagnostic redaction examples.

## Verification

T30/T32/T41, plus workflow-level checks of import/export, policy diffs and archive/reset. Record exact app versions; no disabling the browser sandbox to pass.

Explicit scenario IDs: T30, T32, T41, T63, T66.

Revision 1.3 checks owned here: T63, T66. In P02 these are feasibility probes only; in feature phases execute the applicable production paths. Report partial/blocked portions explicitly.

## Exit gate

Supported app workflows remain boxed, UI claims match backend evidence, and usability/accessibility checks have real results.

## Scope guard

No fake security score, claims of perfect safety or broad compatibility exceptions.

## Handoff and continuation

Update docs/STATUS.md and docs/phases/P09_REPORT.md with code commit, files changed, commands run, evidence, failed/blocked/not-applicable checks, unresolved risks and the next eligible phase. Mark this phase DONE only when the gate passes. P02 prototype evidence cannot stand in for production implementation evidence.

Continuation instruction: "Implement P09 from this specification. First verify its dependencies and existing evidence. Finish its tasks and tests, fix failures, then update the phase report and status. If a dependency is blocked, do only explicitly independent safe work and leave the phase provisional. Do not silently weaken security or drop mandatory scope."

