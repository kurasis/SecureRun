# P03 schema and recovery

SQLite schema version 1 lives in
[001_initial.sql](../crates/foundation/migrations/001_initial.sql). Tables cover
manager generation/sequence, environments, operations, artifact identities,
policies, applications, engine observations, exports and bounded audit records.
Future-phase entities are typed data, not active engine-control implementations.
Normal production storage stays unopened while self-context is unverified.

The owner SID comes from the OS in the native host, never an IPC request. SQL uses
bound parameters, foreign keys, trusted_schema=OFF, FULL synchronization, WAL and
a two-second busy bound. Documents are strongly typed with unknown fields rejected;
environment IDs/owners/generations/revisions are cross-checked against their indexed
columns. Corruption is an error, never permission to replace the database or adopt
every prefixed engine box. A missing database begins with zero owned environments.

## Migration protocol

Read user_version before changing schema. Reject a future version and an unversioned
nonempty/foreign schema. Apply the compiled migration under BEGIN IMMEDIATE and
commit schema/version together. A named partial SQL failure rolls both back.
Validate quick_check before normal use. Failed migration preserves existing data;
there is no automatic delete/recreate, downgrade, unrelated repair or engine action.
Future released migrations must preserve data, verify a backup and add rollback
tests before activation. The original specification remains unchanged.

## Reservations and recovery

The persistent uniqueness key is (environment ID, environment generation,
idempotency UUID). Requested revision, initiator SID/session and operation kind
must agree on duplicate delivery. One noncompleted operation locks the environment;
an uncertain operation does not release it. SQLite serializes reservations and
the native host holds a file lock for the lifetime of the test profile. That OS
file lock works across sessions and a second writer is denied. Locks are not
authentication or privileged enrollment, and lock filenames are not deleted on
startup. Future production activation must retain this coordination boundary.

Persist Reserved before any external dispatch and Dispatched before invoking a
future adapter. A duplicate returns the stored operation and never calls dispatch
again. Opening the store after a crash changes incomplete Reserved/Dispatched
intent to OutcomeUnknown/AwaitingReconciliation/InspectOnly. It never automatically
dispatches again, even when no process remains or dispatch may have completed.
T61 foundation tests cover reservation-before-dispatch and accepted/lost-receipt
protocol states with a counter, not a real engine target. P06 must inject the
actual engine failures when its dispatcher exists.

Environment generation invalidation is independent of engine connection generation.
Old selections, executable references, artifacts and operation tokens cannot
mutate a newer environment. Reconnection transactionally invalidates runtime
observations. Neither missing observations nor a Cleaning state proves empty data.

## Artifact identity records

Record operation ID, environment generation, expected parent/leaf filesystem
identities, owner and artifact role. No general root path or recursive deletion
API is provided. Reconciliation compares current identity/generation to the record;
a replacement or stale generation remains unresolved. Matching identity only
permits later inspection, not deletion. Metadata records are observations and
cannot supply elevated authority. P07/P08 additionally enforce their actual
transfer/recovery ancestry, roles, journal and postconditions at use.

The Windows test creates an actual operation-owned file, records its NTFS identity,
replaces the path with a different object, checks refusal and confirms the
replacement canary still exists. A generation change also rejects the old record.
No real host files, generic staging-prefix sweep or sandbox-root cleanup are used.

## P07 transfer and file-reference journal

The private per-user `transfers.sqlite` journal has version 1, WAL/FULL writes,
foreign/future-schema rejection and an integrity check. File nodes contain
current environment/root/engine/revision generation, canonical physical object
identity and optional constrained logical workspace mapping. Their IDs bind
all fields. Persisted paths remain observations, not privileged authority.

Transfer records retain permanent request signatures, source/parent/staging/
payload identities, bounded normalized MOTW, logical size, digest, stage and
allowlisted reason. Payload, arguments and environment variables are not logged.
Recovery inspects actual current identities and exact provenance; it never
replays a copy or publishes a partial file. Explicit Discard can remove only
identity-verified staging in the current generation. See
[safe file workflows](SAFE_FILE_WORKFLOWS.md) for crash windows and limits.

## P08 lifecycle integration

See [Lifecycle and recovery](LIFECYCLE_AND_RECOVERY.md) for retention, native
confirmation, generation invalidation and inspect-only recovery. P08 passed on both owner-selected Windows targets; see
[the phase report](phases/P08_REPORT.md) for exact-source proof and limitations.

## P09 manager history and transient review state

Production `metadata/history.sqlite` has a separate owner-bound versioned schema,
private root checks, bounded single-writer access, a 30-day/512-event retention
policy and no arbitrary log-message field. Shared diagnostics remove local
environment IDs in addition to the already absent paths, arguments, environments,
certificate data and file contents. Its worker request is at most 2 KiB, runs with
a cleared environment and has a 15-second bound. This store supplements the
original policy/control/file/lifecycle journals and cannot authorize an action.

Policy draft selections and reviewed diagnostic bundles are in-memory backend
capabilities, expire after 60 seconds and are consumed before application/save.
They are never recovered, replayed or auto-applied after restart. Appearance,
language and whitelisted content scale are presentation preferences only.
Metadata renames use the existing policy operation tombstones, with current label,
revision and generation comparison; applied policy revisions remain unchanged.

Standard-user product history may attempt its native worker when a fresh trusted
unboxed observation has protected SCM status but an unavailable service process
identity. This does not mark that identity known or authorize persistence: every
history operation still independently authenticates the original components,
manager/worker context, owner and metadata ancestry in the native worker. A failure
keeps explicit session-only history. Theme/zoom and fixed official Help operations
do not open history merely to change presentation or follow their fixed link.
