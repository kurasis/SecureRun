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
| policy_request | List/Create/Apply/Inspect/Repair; bounded PolicyReply | Actual main origin; OS-derived owner/root/code authority; one-use selected grants, current revision, immutable operation signature, current-baseline repair and independent verification; no raw INI, password, global mutation, PID stop or user-target arguments |
| select_policy_path | Operation UUID, optional owned environment UUID/revision, directory/file kind; SelectionView | Actual main origin; current native policy observation, native picker, fixed NTFS/canonical path and retained handles; one use and 60-second operation/environment/revision binding |
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
come from the isolated backend worker, never mocks. P05 exposes constrained
user-owned provisioning separately through policy_request. P06 adds registered
host-EXE dispatch and scoped Stop through control_request. P07 adds constrained
file_request operations; P08 adds lifecycle_request with native confirmation and
inspect-only recovery.
See [observation contract](ENGINE_OBSERVATION.md) and
[policy contract](POLICY_PROVISIONING.md).

HealthView contains private root/configuration/process identity observations for
the authorized local UI only. These fields do not enter diagnostic_summary or
shared evidence. Its generation/sequence ordering and 15-second freshness are
independent from each environment's lifetime generation.

Policy requests use an isolated same-executable worker with an OS-captured parent
PID/birth, a private bounded inherited pipe, job containment established before
request release, 16 KiB request/2 MiB response limits and a 600-second deadline
for complete multi-box, multi-architecture policy verification. Individual
observation, launch/control and file-worker bounds remain separate.
Worker context and original owner are independently checked before profile access.
Only the fixed protected diagnostic executable can be dispatched, in a fresh
generated diagnostic scope. Current manager/probe and engine identities bind the
stored verification. Returned Verified records are reconciled even for retries
and inspection. The policy UI ignores older request completions, expires a viewed
observation after 30 seconds and refreshes on visibility resumption. These UI
checks do not replace native revision/root/configuration verification.

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


## P06 production application and control commands

`control_request` is granted only to the bundled main WebView, with the same
backend exact-origin/label check as policy commands. Register accepts one-use
`executable_selection` and optional `directory_selection` IDs from the native
picker, never raw renderer paths. Launch accepts application/environment IDs,
expected revision and operation UUID. Stop accepts an environment ID/operation;
Stop managed resolves explicit journaled ownership, never a box-name prefix.
List and Reconcile return bounded application/process/receipt views without
stored argument arrays or executable/CWD paths. Process FILETIMEs are decimal
strings. Console worker framing has a fixed 16 KiB request, 2 MiB response and
120-second external bound; unknown outcomes must be reconciled without replay.

The P03 foundation `reserve_operation` command stays restricted to its existing
fixture protocol. It cannot authorize production execution. Normal production
launch/Stop uses the separate durable P06 journal and current adapter checks
outlined in [Launch and process control](LAUNCH_AND_PROCESS_CONTROL.md).

Control responses include the backend engine generation and a monotonically
increasing control request sequence. A response from an old engine generation
or superseded request is rejected before returning to the renderer; its durable
operation receipt remains available for reconciliation. The UI additionally
ignores older local request tickets and expires runtime views after 15 seconds.

## P07 file commands

`files_request` is separately ACL-scoped to the trusted main WebView, with
exact native label/origin authorization. Import/Export renderer schemas accept
one-use source/destination selection IDs; List/Register/Export use opaque
backend file IDs. Native paths exist only in the internal worker request, never
as a renderer override. Cancel, Recover and Discard are explicit operation-ID
actions. Current environment/revision and worker root/engine generation are
revalidated before mutation; a stale result cannot replace current UI state.

The native file worker uses bounded JSON (16 KiB request, 2 MiB reply), a 128 MiB
OS job memory ceiling and a one-hour cancellable transfer bound. It cannot launch
content. Boxed registration creates a typed reference consumed by the existing
launch-reservation path. See [safe file workflows](SAFE_FILE_WORKFLOWS.md).

## P08 lifecycle integration

See [Lifecycle and recovery](LIFECYCLE_AND_RECOVERY.md) for retention, native
confirmation, generation invalidation and inspect-only recovery. P08 passed on both owner-selected Windows targets; see
[the phase report](phases/P08_REPORT.md) for exact-source proof and limitations.

## P09 product integration

`product_request` is a normal main-window permission with independent backend
origin/label authorization. List returns bounded typed manager history and an
advisory free-volume observation. Preview returns an immutable minimized bundle
and backend-issued, single-use 60-second ID. Save accepts only that ID and an
EN/RU picker-language enum; a native picker chooses a new JSON file and the backend
writes the exact reviewed body. Cancel consumes the preview. No renderer path,
free-form record/body, executable, URL or filesystem operation is accepted.
Scale accepts only 100/150/200; Help accepts two fixed official topic enums.

`policy_request` additionally supports Queue/ApplyQueued/DiscardQueued and
metadata Rename. Queued drafts hold original native selections, current engine
generation, environment revision/generation and a monotonic deadline. Apply
consumes the draft before dispatch and revalidates identity and complete stopped
scope. Rename uses a current display-name/revision/generation comparison and a
permanent operation tombstone; it changes neither applied permissions nor data.

The native policy/control/file/lifecycle entry points share a bounded, serialized
request gate. Picker completion is reauthorized after its asynchronous dialog.
Transfer cancellation remains independent so it can interrupt a held transfer.
Normal request replies carry generated diagnostic IDs used by the typed history.
Original operation journals remain authoritative for uncertain outcomes; logging
failure never converts an unknown action into success. Session-only or unconfirmed
history persistence is explicitly identified in the product UI.

See [product UX](PRODUCT_UX.md) and
[minimized diagnostics](PRODUCT_PERFORMANCE_AND_DIAGNOSTICS.md). P09 native proof
remains pending until its evidence gate and matching regressions pass.


`get_engine_health` accepts an optional unsigned `afterSequence` argument. With
the current sequence, one outstanding main-window request can wait for a complete
new observation, bounded to three seconds. Missing/different sequences return
the same current HealthView immediately; the fixture remains immediate. The
reservation is bounded before scheduling and released by its guard, and the
main-window origin is checked again after waiting. It creates no event-emission,
generic event-listening, path, shell or operation capability.
