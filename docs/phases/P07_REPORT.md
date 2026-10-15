# P07 — Safe file workflows and boxed executable references

Status: IN_PROGRESS. Dependencies P01–P06 passed historically; matching current
P03–P06 regression is required before closing P07.

Implementation branch: `p07/safe-files`. Exact tested completion source/run will
be recorded after both native laboratories pass. Initial source `f550018` failed
closed before payload at MOTW stream creation; [raw investigation](../evidence/p07/manifest.json)
is retained, with no success claim. The protocol now shares DELETE correctly
with the held payload and verifies a read-only marker lease through publication.

Outputs: [safe file protocol and limits](../SAFE_FILE_WORKFLOWS.md), adapter
`files` contracts/journal and Windows safe-copy module, scoped Tauri command,
native picker tokens, EN/RU file UI, boxed-EXE registration and existing control
launch integration; P07 native workflow, ordinary-user actors, adversarial
fixtures and strict source-bound evidence retention.

Requirement scope: PR-09, PR-03 boxed references and PR-18 transfers.
Scenarios: T20–T23, T42–T45, T49, T63–T65. P07 owns import/launch portions of T43;
reset invalidation completes in P08. Final installed-candidate T01–T66 remain
NOT_STARTED until P12.

Current checks: portable adapter tests, UI type/build, x86 Windows metadata-only
strict clippy and repository/tooling checks pass. These do not establish Windows
file/engine behavior. Native Server 2025 x64 and Windows 11 ARM64 runs remain in
progress, including x86/x64 target processes where applicable. No Linux result
is labeled Windows containment proof.

No recursive folder import, arbitrary ADS, host launch fallback, preview,
automatic export, generic sandbox deletion, privileged product helper or engine
bundling was introduced. Current remaining work: native diagnosis and closure,
matching dependent regressions, reviewed checksummed evidence, final report and
normal GitHub merge. Next eligible phase after gate completion: P08.
