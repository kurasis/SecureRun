# Development Plan — P01 through P12

Specification revision 1.3. The canonical phase identifiers are P01–P12. Each phase has its own Markdown file. The old numeric stage scheme is superseded; do not maintain two competing plans.

## Phase index

| Phase | Outcome | Dependencies |
|---|---|---|
| [P01](phases/P01_REPOSITORY_AND_WINDOWS_LAB.md) | Repository assessment and Windows test lab | None |
| [P02](phases/P02_SANDBOXIE_FEASIBILITY.md) | Sandboxie integration feasibility | P01 |
| [P03](phases/P03_FOUNDATION_AND_IPC.md) | Application foundation, persistence and IPC boundary | P01, P02 |
| [P04](phases/P04_ENGINE_DISCOVERY_AND_OBSERVATION.md) | Trusted engine discovery and read-only observation | P02, P03 |
| [P05](phases/P05_POLICY_AND_SAFE_PROVISIONING.md) | Policy compiler, transactions and safe provisioning | P04 |
| [P06](phases/P06_LAUNCH_AND_PROCESS_CONTROL.md) | Isolated launch and scoped process control | P05 |
| [P07](phases/P07_SAFE_FILES_AND_BOXED_EXECUTABLES.md) | Safe file workflows and boxed executable references | P06 |
| [P08](phases/P08_LIFECYCLE_CLEANUP_AND_RECOVERY.md) | Persistence, disposable lifecycle, cleanup and recovery | P07 |
| [P09](phases/P09_PRODUCT_UX_AND_COMPATIBILITY.md) | Product UX, localization and application compatibility | P08 |
| [P10](phases/P10_ADVERSARIAL_INTEGRATION_REVIEW.md) | Adversarial integration review and regression closure | P09 |
| [P11](phases/P11_PACKAGING_UPGRADES_AND_SIGNING.md) | Packaging, upgrades, signing and retention | P10 |
| [P12](phases/P12_FINAL_ACCEPTANCE_AND_HANDOFF.md) | Final acceptance and developer/user handoff | P11 |

## Execution order

Follow the dependencies. P01 assesses the workspace and lab; P02 proves integration feasibility with disposable prototypes. Production observation is implemented in P04, policies/provisioning in P05, and only then target launch in P06. File and lifecycle operations follow in P07/P08. This order prevents launch from depending on security code planned for a later phase.

P03 pure-code scaffolding may proceed provisionally if the Windows lab blocks P02, but it cannot pass engine-dependent acceptance. Other independent documentation/UI work may also proceed without claiming its dependent phase DONE. A blocked prerequisite stays visible. Never treat a mock result as a Windows result.

## Common completion rules

- Status values: NOT_STARTED, IN_PROGRESS, BLOCKED, DONE. Optional feature exclusions are recorded separately; they do not erase a mandatory phase.
- DONE requires the named outputs, applicable tests and exit gate, with code/build/environment evidence.
- For each phase write docs/phases/Pxx_REPORT.md and update docs/STATUS.md. Record source commit, engine/OS tuple, commands, results, artifact paths, unresolved issues and the next eligible task.
- If code or a dependency changes after a phase passed, mark affected evidence stale and rerun the relevant checks. Later review does not retroactively validate missing earlier gates.
- A phase can contain smaller tasks P05.1, P05.2 and so on. Keep the phase ID stable and do not renumber on every revision.
- Default to continuing through eligible phases under the development request. Do not stop merely to ask whether to proceed. If the user asks for one named phase, complete that scope and report its handoff.
- At each checkpoint keep the repository buildable where possible. Never leave a security switch defaulting to an unsafe temporary bypass.

## Phase report template

```text
Phase: Pxx
Status: NOT_STARTED | IN_PROGRESS | BLOCKED | DONE
Dependencies and their evidence:
Implementation commit/build:
Outputs and changed files:
Requirement IDs:
Tests: Passed / Failed / Blocked / Not applicable (with reasons)
Windows/engine/component versions:
Evidence paths:
Limitations and release blockers:
Next eligible phase/task:
```

## Security validation cadence

P02 prototype tests establish feasibility only. P04–P08 verify their production components while implementing them; do not defer all security testing to P10. P10 checks combined behavior and adversarial regressions. P11 validates installed artifacts and migrations. P12 closes the whole acceptance matrix on the final candidate. The canonical test catalog is 08_TESTING_AND_ACCEPTANCE.md; the traceability matrix maps requirements to phases.

## Continuing in a fresh development chat

Attach this entire package and the current repository/status report. Ask: "Continue with Pxx. Verify dependencies and previous evidence, implement the phase, run its tests, and update STATUS and the phase report." Read the common security/integration documents as well as the named phase; a phase file does not replace the overall specification.

## Maintenance after P12

Engine/OS/security dependency changes trigger proportionate adapter and enforcement revalidation. Keep the compatibility manifest current; do not silently downgrade the engine to restore compatibility. Back up before database migrations and never blindly downgrade schemas. No automatic engine bundling, replacement or uninstall is authorized by this plan.

