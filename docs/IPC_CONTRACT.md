# Application IPC contract

The renderer is a lower-trust client. Only bundled local assets in the main
WebView receive the explicit application permissions. AppManifest command ACLs
are generated in build.rs; registering a handler alone is never the permission
policy. The normal configuration selects only the main capability, with no remote
origin grant. Every handler independently checks the actual injected WebView
label and current URL in Rust. Renderer-supplied labels/PIDs/SIDs are not evidence.

| Command | Typed request / result | Independent backend constraints |
|---|---|---|
| get_snapshot | No input; Snapshot | Main local origin; no private paths/SIDs; actual backend state and generations |
| get_engine_health | No input; HealthView | Actual main origin; deduplicated bounded production read-only observation; native manager/bridge context, connection generation, sequence and freshness; no path/box/command supplied by renderer |
| subscribe_state / unsubscribe_state | Native typed Channel and backend-issued subscription ID / initial Snapshot | Actual main WebView, maximum four subscriptions, callback binding registered before snapshot; no renderer emission |
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

P04 adds trusted production observation to the ordinary shell. It remains
observation-only: no persistent production profile is opened/migrated and metadata
mutations stay unavailable until provisioning is implemented in P05. A positively
boxed normal desktop startup exits before metadata/WebView creation. Unknown
context exposes minimum read-only setup; no control/elevation or self-escape is
available. A small in-memory store supplies setup state; real engine observations
come from the isolated backend worker, never mocks. Target dispatch, import/export,
cleanup and engine writes are absent. See [observation contract](ENGINE_OBSERVATION.md).

HealthView contains private root/configuration/process identity observations for
the authorized local UI only. These fields do not enter diagnostic_summary or
shared evidence. Its generation/sequence ordering and 15-second freshness are
independent from each environment's lifetime generation.

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

Backend typed-channel state events carry environment ID/generation, engine generation,
expected revision, operation ID and a persisted monotonic sequence. Channels bind to the invoking main WebView; the renderer lacks event-emission
permission. Channel callbacks exist before registration; registration and initial
snapshot are serialized in Rust, with pre-snapshot messages buffered in the UI.
The asynchronous global event-listener startup route is not used. Rust and the UI discard
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
