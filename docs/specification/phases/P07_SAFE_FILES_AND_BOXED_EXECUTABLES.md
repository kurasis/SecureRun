# P07 — Safe file workflows and boxed executable references

Specification: 1.3 | Status on handoff: NOT_STARTED

## Goal and dependencies

Complete this phase's concrete outputs and exit gate. Dependencies: P06.

Requirement scope: PR-09, PR-03 boxed references, PR-18 transfer behavior.

Read the common [phase workflow](../09_DEVELOPMENT_STAGES.md) and:

- [06_FILES_AND_LIFECYCLE.md](../06_FILES_AND_LIFECYCLE.md)
- [07_UX_SPECIFICATION.md](../07_UX_SPECIFICATION.md)

## Implementation tasks

1. Implement metadata-only file browsing with verified engine mappings and bounded lazy enumeration; no host previews or executable icons.
2. Implement shared safe-copy primitives, backend-mediated selections and import of explicit regular files into a private workspace.
3. Implement BoxExecutableRef mapping and launch validation, never treating a physical sandbox storage path as a host executable.
4. Implement stopped-box export to fixed local NTFS with no-replace completion, safe handles, hard-link/reparse rejection and validated provenance.
5. Handle >4 GiB files, sparse growth, cancellation, disk-full, collisions and operation recovery without loading whole files into memory.

6. Validate destination leaf names and visible extensions, mark staging before copying payload, and test each crash window. Bind all rollback/staging cleanup to verified artifact identities and environment generation.

## Required outputs

- File list/import/export and boxed-EXE registration workflows.
- Safe-copy module with adversarial path fixtures.
- Transfer/provenance evidence and user-visible partial-operation states.

## Verification

T20–T23, T42–T45 and T49. Run T43 import/launch cases now; the reset-invalidates-reference case finishes in P08.

Explicit scenario IDs: T20, T21, T22, T23, T42, T43, T44, T45, T49, T63, T64, T65.

Revision 1.3 checks owned here: T63, T64, T65. In P02 these are feasibility probes only; in feature phases execute the applicable production paths. Report partial/blocked portions explicitly.

## Exit gate

Host files cannot be overwritten through export and unsafe source/destination identities are rejected. No transfer operation runs untrusted host content.

## Scope guard

No recursive directory import, arbitrary alternate streams, automatic export or content previews.

## Handoff and continuation

Update docs/STATUS.md and docs/phases/P07_REPORT.md with code commit, files changed, commands run, evidence, failed/blocked/not-applicable checks, unresolved risks and the next eligible phase. Mark this phase DONE only when the gate passes. P02 prototype evidence cannot stand in for production implementation evidence.

Continuation instruction: "Implement P07 from this specification. First verify its dependencies and existing evidence. Finish its tasks and tests, fix failures, then update the phase report and status. If a dependency is blocked, do only explicitly independent safe work and leave the phase provisional. Do not silently weaken security or drop mandatory scope."

