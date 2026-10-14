# P01 — Repository assessment and Windows test lab

Specification: 1.3 | Status on handoff: NOT_STARTED

## Goal and dependencies

Complete this phase's concrete outputs and exit gate. Dependencies: none.

Requirement scope: PR-01, PR-14; prerequisites for all requirements.

Read the common [phase workflow](../09_DEVELOPMENT_STAGES.md) and:

- [00_README.md](../00_README.md)
- [02_SECURITY_MODEL.md](../02_SECURITY_MODEL.md)
- [10_SOURCES_AND_LICENSING.md](../10_SOURCES_AND_LICENSING.md)

## Implementation tasks

1. Inspect existing code, AGENTS.md, build scripts and dependencies. Record reuse versus new modules; preserve unrelated work.
2. Identify a disposable Windows 11 x64 runner and the exact OS build, virtualization and security settings. If unavailable, record the blocker and continue source-only investigation.
3. Choose an official candidate Sandboxie release and collect source commit, provenance, component versions and applicable licenses. Do not call the candidate supported until P02 and later tests pass.
4. Define synthetic canary locations, controlled network endpoints, second test user/session and bounded resource fixtures. No personal files or credentials.
5. Create the initial status, engine matrix, operation map and test-report documents. Choose original product identity and reserve manager-owned namespaces.

## Required outputs

- docs/REPOSITORY_ASSESSMENT.md and architectural decisions.
- docs/LAB_SETUP.md with reproducible setup/teardown and safety limits.
- Initial docs/STATUS.md, ENGINE_MATRIX.md, OPERATION_MAP.md and TEST_REPORT.md.

## Verification

Verify the lab can run a harmless Windows executable and report OS/architecture; verify official engine provenance. No containment test is marked Passed merely because installation succeeded.

No security acceptance scenario is passed merely by finishing this setup phase.

## Exit gate

Repository and lab availability are documented, candidate sources are pinned, and fixtures are isolated. An unavailable lab is a recorded blocker for P02, not permission to fake its evidence.

## Scope guard

No production launcher, kernel code or feature-complete UI.

## Handoff and continuation

Update docs/STATUS.md and docs/phases/P01_REPORT.md with code commit, files changed, commands run, evidence, failed/blocked/not-applicable checks, unresolved risks and the next eligible phase. Mark this phase DONE only when the gate passes. P02 prototype evidence cannot stand in for production implementation evidence.

Continuation instruction: "Implement P01 from this specification. First verify its dependencies and existing evidence. Finish its tasks and tests, fix failures, then update the phase report and status. If a dependency is blocked, do only explicitly independent safe work and leave the phase provisional. Do not silently weaken security or drop mandatory scope."

