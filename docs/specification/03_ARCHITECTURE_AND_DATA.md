# Architecture and Data Contract

## Components

1. React/TypeScript UI: state presentation and user intent only.
2. Rust application service: validation, ownership checks, lifecycle operations and event subscriptions.
3. Policy compiler: translates a versioned product policy into validated engine settings; no UI-supplied raw directives.
4. Sandboxie adapter: all engine CLI/FFI interactions behind one typed interface.
5. Persistence layer: SQLite migrations, operation journal and manager metadata.
6. File transfer component: safe import/export under explicit user intent.
7. Optional short-lived elevated helper: narrowly scoped configuration changes, only if necessary.

Proposed workspace: `ui/`, `src-tauri/`, `crates/domain/`, `crates/sandboxie-adapter/`, `crates/policy/`, `crates/file-transfer/`, `tools/probe/`, `tests/windows/`, `docs/`. Adapt to an existing repository rather than imposing duplicate infrastructure.

## Logical adapter interface

The following are application interfaces, not names of upstream APIs:

```text
detectEngine() -> EngineInfo
queryCapabilities(engine) -> CapabilityReport
listBoxes() -> BoxSummary[]
readEffectivePolicy(boxId) -> EffectivePolicy
createBox(owner, generatedName, policy) -> BoxIdentity
applyPolicy(boxId, expectedRevision, policy) -> AppliedRevision
launch(boxId, expectedRevision, executable, argv, workingDirectory) -> LaunchReceipt
listProcesses(boxId) -> ProcessIdentity[]
terminateBox(boxId) -> OperationResult
queryRoots(boxId) -> VerifiedRoots
clearContents(boxId) -> OperationResult
removeDefinition(boxId) -> OperationResult
readDiagnostics(cursor) -> DiagnosticBatch
```

Use explicit timeouts, cancellation and typed error codes. A command timeout has an unknown outcome until reconciliation; do not blindly retry any operation with side effects, including launch. CLI startup success is not proof of completion.

This adapter interface is internal to Rust, not the frontend IPC contract. Exposed commands resolve registered IDs and backend-authorized selections before calling it. Use distinct readiness checks for launch, read-only inspection and content mutation. Stop must not require a currently valid optional certificate or successful network-policy verification; it still requires trustworthy engine identity, correct box/process scope and safe applicable lifecycle handling. If those minimal stop conditions fail, show the precise reason and retain Unknown/Running activity rather than falsely reporting success.

## Minimum data model

| Entity | Fields |
|---|---|
| Environment | UUID, owner SID, engine box name, display name, lifecycle mode, policy ID/version, desired revision, verified effective revision, created/updated times, lifecycle/activity/eligibility, verified roots and filesystem identities |
| Application | UUID, environment UUID, canonical EXE path, argument array, working directory, target kind (host EXE or validated boxed EXE reference), optional hash/publisher observations, display name |
| Policy | schema version, preset, network mode, path rules, required capabilities, approved template IDs, provenance |
| Operation | UUID/idempotency key, initiator SID/session, type, environment UUID, environment generation, requested revision, dispatch state, phase, timestamps, outcome, structured error, recovery action, identities of created artifacts |
| Engine observation | version, architecture, verified installation path, component versions, trust result, capability evidence time |
| Export record | operation ID, source identity, chosen destination, bytes, result; redact paths in shared diagnostics |

Do not persist raw process lists as authoritative. A process identity combines PID and creation time with engine box membership; PID reuse must not target an unrelated process. Diagnostics are bounded by size/retention, e.g. 20 MB or 30 days, configurable downward.

Identity comparison in a snapshot is not a race-free termination primitive. The dispatch path must remain bound to the authorized process object or have a source-reviewed engine guarantee that checks the correct scope at the actual action. Do not implement a fallback that validates PID/creation time and later submits only that PID to a different process/service. v1 exposes environment Stop, not an arbitrary PID-kill API; the integration contract defines its gate.

## Orthogonal state model

Do not encode runtime activity and launch eligibility in one enum. Store:

- Lifecycle: `Unconfigured`, `Active`, `Archived`, `Removed`.
- Activity: `Unknown`, `Idle`, `Starting`, `Running`, `Stopping`, `Cleaning`.
- Launch eligibility: `Unverified`, `Allowed`, `Blocked`, with structured reasons.
- Current operation: optional operation ID/type/phase/error, independent of activity.

A box can be Running and Blocked simultaneously. Missing engine access sets activity Unknown, never Idle. A launch requires Active lifecycle, Allowed eligibility and a compatible operation lock. Policy mutation, import, export and cleanup require proven Idle state and complete session coverage. Cleaning is never proof that data has been erased. Archived boxes retain their engine definition/data and are not launchable through the manager.

Process observations include owner SID, Windows session ID, PID and creation time. Root identity rebinding after a confirmed cleanup follows the journaled exception in the lifecycle document. Membership observations are transient. Short-lived process success needs an engine-backed receipt or test evidence; otherwise report Outcome unknown, not confirmed containment. No PID observation is required to prove the established pre-execution engine boundary anew.

Per-environment locks serialize launch, mutation, import, export, cleanup and removal. A global configuration coordinator handles shared engine configuration. Single-instance coordination must cover the same user's multiple logon sessions where supported. A second session that cannot coordinate is read-only. Manager locks do not lock SandMan or other upstream clients: external launches and edits require detection, reconciliation and the integration protocol.

Maintain an engine connection generation. Service restart, reboot, component update, resume from sleep and a lost observation stream invalidate cached health/runtime observations and require refresh. A healthy refreshed engine can reuse compatible release-test evidence; do not rerun the whole test suite on every UI refresh.

Use monotonic sequence numbers for backend events and operation receipts. A late process-list response or completed older operation cannot overwrite newer state. After reconnect, discard stale generations and take a fresh snapshot before processing incremental events. This applies to multiple UI windows and delayed worker tasks as well as engine reconnects.

## Persistence and recovery

Use parameterized SQL and transactional schema migrations. Journal intent before an external mutation and completion afterward. Engine operations and SQLite are not one transaction. Recovery reconciles actual engine state, configuration revision and journal state; never assumes rollback occurred. Backups must not overwrite unrelated external changes. Make cleanup and stop idempotent with explicit postconditions.

For launch, persist an operation ID and a dispatch reservation before contacting the engine. Repeated delivery of that operation returns its recorded status, never another launch. A crash between reservation and receipt leaves an uncertain outcome; restart must not dispatch it again merely because no PID remains. The target may already have executed and exited. Do not claim exactly-once engine execution unless the upstream protocol actually provides it. An explicit new launch after reconciliation is a new user action, with the previous outcome still visible.

An environment generation is distinct from the engine connection generation. Increment/invalidate it for reset, recreation and removal so old selections, boxed EXE references and operation tokens cannot act on new contents. Recovery rechecks current identity, revision and authorization. It must not repeat an irreversible request from an old generation, follow an untrusted journal path, or delete a file solely because its name resembles a temporary artifact.

Restarting the UI must not terminate persistent workloads. Disposable leftovers must remain recoverable and visible after crashes; do not silently delete them during startup. A deleted metadata database does not authorize adopting or removing every prefixed engine box.
