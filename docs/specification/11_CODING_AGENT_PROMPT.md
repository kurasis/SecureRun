# Starting Prompt for the Coding Agent

Copy the following prompt into the development conversation and attach this specification package.

---

You are implementing a Windows Application Isolation Manager using the separately installed original Sandboxie engine. Read every Markdown file in this package before planning implementation. Follow the security invariants and phase gates; treat the package as the authoritative product specification unless I explicitly change it.

Use Tauri 2, React, TypeScript, Rust and SQLite by default, with a narrow Sandboxie adapter. Inspect the existing repository and its instructions first if one is provided. Do not create a parallel application beside an existing implementation without a concrete reason. Make routine engineering decisions autonomously and record material deviations.

Begin with P01 repository/lab assessment, then P02 feasibility: verify upstream interfaces, pin the engine version/source commit, establish a Windows test environment and prove the critical launch/configuration/process/file/network operations with harmless fixtures. Do not start by building a polished mock-only interface. Do not invent CLI arguments, INI options, DLL signatures, certificate detection or storage mappings. Resolve them from official documentation, source and actual behavior.

Build an original manager UI; do not copy SandMan or modify/rebuild the engine. Use installed official binaries. Do not bypass certificate restrictions. Keep optional paid capabilities disabled if unavailable; never silently substitute weaker protection. Do not download or purchase certificates or use my actual credentials for tests.

The most important invariants are: no fallback to host execution; policy applied before target execution; no persistent admin UI; no arbitrary shell IPC; no unrelated sandbox mutation; no automatic host file export; no unsafe recursive cleanup; no protection claims from INI writes alone.

Implement in the sequence from 09_DEVELOPMENT_STAGES.md. For each phase P01 through P12, write code, run meaningful tests, fix failures and update docs/STATUS.md with evidence and next steps. Use benign Windows probes and disposable fixtures. Linux tests and mocks do not prove Windows security behavior. If a required environment is unavailable, continue all useful safe work and report exact blocked gates without pretending they passed.

For Windows integration tests, use a disposable VM or dedicated test machine. Never use actual malware, real personal files, saved browser sessions or production secrets. Keep Windows security protections and the target browser sandbox enabled.

At completion provide working source, build instructions, installer/development build status, supported OS/engine matrix, supported/disabled capabilities, test report, limitations, release notes and checksums. A frontend demo is not task completion. Do not call the application production-ready if required containment tests remain unexecuted or failing.

Proceed with repository inspection and P01 and then the P02 feasibility report now.

This is reviewed specification version 1.3. Pay particular attention to 12_REVIEW_FINDINGS.md and 13_TRACEABILITY_AND_GATES.md. Do not equate blocked launches with stopped processes, hooks-only network rules with WFP enforcement, or Start.exe cleanup with an automatically safe operation. Mandatory features cannot be dropped merely by showing them as disabled. Keep root ACL/session checks, engine-policy isolation of manager metadata, no-replace export and source-backed cleanup in the first release gates.

---

Use the separate phases/P01_*.md through phases/P12_*.md files and the dependency table. Do not implement production target launch before P05 policies/provisioning have passed. Record per-phase reports and continue eligible work without routine confirmation pauses.

Revision 1.3 implementation priorities: treat user metadata as untrusted at the privilege boundary; refuse control operations from a boxed manager; keep mandatory manager/sibling protections outside editable grants; make launch dispatch replay-safe without promising exactly-once execution; prove termination scope at use; stage marked exports before publishing their names; and reconcile recovery artifacts by identity and environment generation. Implement T57-T66 in their owning phases rather than deferring them all to P10. Do not log raw arguments, environments or sensitive error payloads.
