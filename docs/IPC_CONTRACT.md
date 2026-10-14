# P03 IPC contract

The renderer is a lower-trust client. Only bundled local assets in the main
WebView receive the explicit application permissions. AppManifest command ACLs
are generated in build.rs; registering a handler alone is never the permission
policy. The normal configuration selects only the main capability, with no remote
origin grant. Every handler independently checks the actual injected WebView
label and current URL in Rust. Renderer-supplied labels/PIDs/SIDs are not evidence.

| Command | Typed request / result | Independent backend constraints |
|---|---|---|
| get_snapshot | No input; Snapshot | Main local origin; no private paths/SIDs; actual backend state and generations |
| create_draft | display_name; EnvironmentView | Valid bounded inert label, metadata gate, generated UUID, Unconfigured/Unknown/Unverified; no engine definition |
| reserve_operation | environment ID, expected generation/revision, UUID idempotency key, Import/Export kind; OperationView | Owned current environment, revision, per-environment operation lock, persistent reservation; Launch and other kinds unavailable |
| select_file | Reserved operation ID and purpose; optional SelectionView | Backend native picker, owning session, actual file/ancestor handles and identity, reauthorization after asynchronous completion |
| prepare_transfer | Operation ID, selection ID and purpose | One use, matching operation/environment/generation/revision/caller/purpose, monotonic expiry, retained identity; actual copy remains unavailable until P07 |
| get_operation | Operation ID; minimized OperationView | Stored owner, current generation/revision; no authority supplied by client |
| diagnostic_summary | No input; bounded AuditEntry array | Allowlisted manager records; no raw errors/paths/argv/environment/certificate data |
| ci_report | Fixed test-case data | Permission absent from normal capability; compiled test harness requires its fresh fixture and main origin |

Request structs reject unknown fields. A path or boolean named confirmed cannot
replace native selection authority. Backend-issued selection IDs are scoped grants,
not an arbitrary filesystem API. Paths and retained handles remain in backend
memory; selections expire after 60 monotonic seconds, are never restored on restart,
and are limited to 32. Stale generation/revision, mismatched purpose/caller, reuse,
unknown ID or changed identity fail closed. No shell/process/fs/opener plugin is
installed. Popup windows and external main-window navigation are denied.

## Context and phase boundary

The ordinary P03 shell is read-only setup. Trusted engine/self-context observation
belongs to P04: until it exists, no persistent production profile is opened or
migrated and metadata mutations are unavailable. A small in-memory store supplies
static setup state; it does not fake an installed or verified engine. Production
engine operations, target dispatch, import/export and cleanup are absent.

The separate foundation-ci feature/configuration runs an explicitly marked
synthetic metadata fixture. A fresh private test directory, native Windows standard
account and real WebView2/native picker exercise the boundary. Its metadata gate
cannot be enabled through IPC. This is a test adapter for foundation data only,
never a mock containment result or a real target launcher. The ordinary build does
not load the test frontend chunk or select its additional report capability.

## State, events and errors

Lifecycle, activity, launch eligibility and current operation are separate fields.
Unknown activity is never converted into Idle and an Unconfigured draft never
becomes launchable. Engine connection generation differs from each environment's
generation. Environment reset/recreation/removal invalidation increments the
environment generation; reconnection increments the engine generation and clears
cached runtime/eligibility observations. These are internal foundation primitives,
not exposed production reset commands.

Backend manager-state events carry environment ID/generation, engine generation,
expected revision, operation ID and a persisted monotonic sequence. Only main is
targeted; the renderer lacks event-emission permission. Rust and the UI discard
older generations/revisions/sequences and older operation results. A delayed
snapshot cannot overwrite newer event state. Command results originate in Rust;
frontend state does not confer backend authority.

Errors contain an allowlisted stable code and generated diagnostic ID. Native,
SQLite and parser details are not copied into local diagnostic records. Control
and bidi characters in user labels are rejected; display remains text-only.
Panic reporting is minimized before output. Local and shared diagnostic records
use the same already-minimized schema, capped at 4,096 entries/30 days and 1 MiB
serialized output. No automatic crash/telemetry upload is configured.

See [schema/recovery behavior](PERSISTENCE.md) and [P03 report](phases/P03_REPORT.md).
