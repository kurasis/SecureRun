# Sandboxie Integration Contract

## Strategy and feasibility gate

Use the installed upstream engine and original signed binaries. Begin with the documented command-line utilities for supported operations. Add a minimal native API bridge only where CLI semantics cannot meet a requirement, notably effective configuration, reliable process identity or file mapping. Do not assume CLI coverage is complete or that exported DLL interfaces have a stable ABI.

P02 MUST produce a table for every adapter operation: exact upstream executable/API, pinned source location and signature, privilege requirement, output encoding, success/failure meaning, timeout behavior and a Windows test result. Unsupported operations are blockers for their mandatory feature, not placeholders to fake.

Sources: [Start command line](https://sandboxie-plus.github.io/sandboxie-docs/Content/StartCommandLine/), [SbieIni command line](https://sandboxie-plus.github.io/sandboxie-docs/Content/SbieIniCommandLine/), [DLL API](https://sandboxie-plus.github.io/sandboxie-docs/Content/SBIEDLLAPI/).

## Documented CLI anchors

These are syntax references, not a complete implementation. Resolve the verified absolute engine path instead of assuming this directory exists.

```text
"C:\Program Files\Sandboxie-Plus\Start.exe" /box:ExampleBox "C:\Apps\Example\Example.exe"
"C:\Program Files\Sandboxie-Plus\Start.exe" /box:ExampleBox /listpids
"C:\Program Files\Sandboxie-Plus\Start.exe" /box:ExampleBox /terminate
"C:\Program Files\Sandboxie-Plus\Start.exe" /box:ExampleBox delete_sandbox
"C:\Program Files\Sandboxie-Plus\Start.exe" /reload
```

`/listpids` reports a count followed by PIDs. Capture its redirected output correctly because Start.exe is a GUI-subsystem executable. `/reload` must not be treated as a universal refresh of every running-process restriction. Some current settings have live update paths; v1 conservatively restarts affected programs for security-policy changes. Use explicit box names for every box-scoped operation. Do not expose `/terminate_all`, `/dfp`, `/disable_force`, or target elevation. Avoid silent deletion commands that suppress failures. These behaviors are documented upstream; verify them again against the pinned release.

## Discovery and capability evidence

Resolve supported installed locations through verified installation metadata and explicit user selection; validate signatures and components before executing anything. Reject a user-writable impostor Start.exe. Do not download drivers automatically. Record the engine version and a tested compatibility range, service/driver state, restart-required state and executable architecture.

Each capability has `available`, `unavailable` or `unknown`, with reason, observed version and evidence timestamp. Availability requires engine support and, where relevant, valid entitlement and enforcement. An INI key being accepted, a file named like a certificate or a UI checkbox is insufficient evidence. Use an upstream status mechanism established in P02 plus benign enforcement tests. Unknown entitlement disables dependent profiles. Recheck after updates, configuration changes and entitlement changes.

Do not copy or display certificate contents, create substitute certificates or depend on a hardcoded paid-feature bypass. Certificates are managed by the original Sandboxie UI.

## Configuration ownership and transactions

Generate engine names using a conservative validated character set and the tested upstream length limit; keep editable Unicode display names separate. Record ownership independently of the prefix. Existing boxes are read-only in v1. Create only new manager-owned boxes and never edit global security settings by default.

Prefer the supported configuration interface. Preserve duplicate multi-value entries and their ordering where meaningful, encoding, inherited templates and unrelated settings. Never use a generic INI serializer that loses this information. Do not assume a whole-file replacement is a safe atomic engine transaction.

Mutation protocol:

1. Require the box stopped, acquire manager operation locks and read current configuration/revision.
2. Resolve applicable global settings and templates; reject unknown unsafe inheritance.
3. Generate and validate the complete intended owned-section change, with backup and operation journal.
4. Use a verified upstream locking/transaction facility if available. If unavailable, disable launch throughout the multi-step update, require external editors closed, detect conflicts before/after writes, and document the remaining external-writer race. Do not claim isolation against a trusted administrator concurrently editing engine configuration.
5. Reload and re-read configuration; obtain effective policy evidence. Retain launch blocking on partial writes or conflicts.
6. Commit the verified revision only after successful reconciliation. Roll back only owned changes whose baseline still matches; otherwise ask for conflict resolution.

Reject configuration hooks/triggers, direct host launch exceptions and unexpected security-reducing settings in managed boxes. Never silently remove an external change; show the diff and require a deliberate reset to the managed policy. Shared template changes invalidate dependent policy verification.

## Process launch

Before any mutation or cleanup, enumerate processes across all relevant Windows sessions and confirm that the returned data is complete. Upstream `SbieApi_EnumProcessEx` exposes session selection; verify its current ABI instead of treating `/listpids` as automatically machine-wide. Different users can resolve the same box name to different roots. Match owner SID, session and root identity, not box name alone. If another session is inaccessible or a box root changed unexpectedly, block destructive operations. Never elevate broad termination to hide an enumeration failure.

Treat box names as namespace identifiers, not durable engine object IDs. Record the creation/configuration marker and immutable managed root identity; a deleted-and-recreated box of the same name must not be silently adopted. Manager-created roots must not overlap one another or metadata/system directories. Root relocation is outside v1; detected relocation blocks launch and deletion until reconciled.

Use native process creation, explicit executable paths and separately modeled arguments. Do not run via cmd.exe, PowerShell, ShellExecute file associations or a shell-built command string. Windows command-line quoting still needs tests for the target and upstream parser; an argv array alone does not eliminate all quoting risk. Disallow embedded NUL and invalid control characters. Raw user arguments must never become Start.exe options.

Distinguish the engine utility's host-side working directory from the target's requested working directory. Start.exe, SbieIni, native bridges and helpers always start in a trusted directory with a minimal validated environment. Do not give them the selected target directory, boxed storage, a download folder or attacker-controlled PATH/DLL search locations as host CWD. Pass the target CWD only through a verified engine mechanism; if the chosen adapter cannot do so safely, reject custom CWD rather than changing the host utility CWD. Use an explicit application name when invoking Win32 CreateProcessW; test the engine's separate parsing of the target command. See S24.

Before launch verify ownership, engine health, target identity, environment revision and required capabilities. Start only through the confirmed fail-closed engine path. Never pass inherited privileged handles. Query membership using upstream mechanisms, including descendants. If membership cannot be confirmed, mark the result unknown, reconcile, and attempt box-scoped stop where justified; do not label the launch protected. Distinguish a short-lived successful target from a lost process.

Apply the dispatch reservation/idempotency protocol from the architecture document to launch. A UI timeout, duplicate IPC request or manager restart must not cause a second dispatch for the same operation. Empty process enumeration cannot prove that the original command never executed. Stop retry/reconciliation must also revalidate environment generation and scope; idempotent intent does not authorize acting on a recreated same-name box.

For environment Stop, P02 must trace the actual upstream termination handler, including ownership/session checks and process selection at dispatch. A PID-only interface is not made safe merely by checking a prior snapshot. Prefer a verified engine operation scoped to the intended environment, owner and supported sessions; if a process-handle route is needed, retain the validated object handle and minimal rights through completion. Do not silently fall back to killing a numeric PID. Verify exit through completed waits/current engine state, not just successful dispatch. Windows TerminateProcess is asynchronous when used on another process; see S26/S27 and the version-specific S07 interface review. Lack of a safe scoped route blocks mandatory Stop.

If native DLL calls are required, load only a validated absolute path using safe DLL search rules, match architecture and calling convention, validate buffers and bound all reads. Prefer an isolated narrow bridge process for fragile ABI interactions. Do not introduce Qt/QSbieAPI into the Rust application without a concrete need and dependency/license review.

## Policy evidence without circular launch checks

Separate three kinds of evidence: (1) release-level tests for a pinned OS/engine/adapter/preset tuple; (2) current configuration, root, health and entitlement observations; (3) optional safe local preflight probes. No generic API is assumed to prove every effective permission. `readEffectivePolicy` means an adapter-generated report with provenance and unknown fields, not an invented upstream enforcement oracle.

Before target launch, require valid release evidence plus fresh observations matching the approved fingerprint. Local probes use a trusted installed probe executable and synthetic canaries only, under an explicit diagnostic operation. Their launch is not permission to run the user's unverified target. Do not rehash all user documents or perform production network callbacks on each launch. Certificate enforcement remains upstream's responsibility; record observed availability, not a promise about future expiry or grace periods.

Release evidence covers a tested policy compiler, adapter and constrained policy family. A user-specific path grant changes the runtime fingerprint but does not require publishing a new application release for every path. Validate it with the tested compiler rules, check the applied result and require additional targeted tests for any previously untested rule interaction. Never relabel arbitrary raw policies as a tested family. Application-version compatibility evidence is separate from enforcement evidence; report an untested application version honestly without changing its isolation policy.

Run diagnostic probes in a freshly provisioned, throwaway diagnostic box using synthetic data and a safe policy equivalent for the property under test. Do not run a trusted probe in a previously used target box where its files, DLL dependencies or registry view can be shadowed by untrusted contents. Such tests establish adapter/policy-family behavior, not complete proof of every resource in an existing box. Validate that box's fingerprint/roots through read-only observations. Keep test evidence and runtime observations labeled separately.

Initial box provisioning may not have a materialized root yet. Record PendingRoot and block target launch until a controlled creation/probe step establishes the expected root, ACL and identity. This is a journaled provisioning operation, not automatic adoption of an arbitrary directory. Release evidence for the engine and provisional policy must precede this trusted diagnostic step; its role is to establish per-box storage prerequisites before any untrusted target runs.

## Configuration input and automation

Validate values against the actual INI grammar, including CR/LF, NUL, percent expansion, commas, process selectors and ambiguous wildcard syntax. Reject paths that cannot be represented literally without changing meaning. The file picker does not make a value safe for INI serialization. Preserve duplicate directives; verify `set` versus `append` behavior. Never pass a configuration password on the command line, in logs or in a stored profile. v1 may reject password-protected configuration mutations with a clear reason until a secure upstream interaction is implemented; never remove the protection.

Disable manager-owned box auto-recovery, automatic upstream deletion/removal and unapproved hooks through verified settings, so a concurrently open SandMan does not race manager lifecycle decisions. Confirm the actual consumer/inheritance rules for each setting; do not presume all switches inherit identically. No import of raw Sandboxie configurations or executable profile triggers in v1.

P02 bootstrap exception is limited to a disposable development lab: fixed trusted probes may run through a source-reviewed provisional engine path to produce the first release evidence. The lab must use synthetic data and cannot expose this provisional route as a product user-target launcher. Runtime production checks remain mandatory; the bootstrap exception does not waive them.

P02 also establishes an unboxed-context check for the manager, bridge and helper. Detection may perform only the minimal trusted read-only query necessary before context is known. No environment mutation or privileged request is allowed while that result is unknown. An engine install/update invalidates version-dependent evidence for this check along with the other adapter observations.
