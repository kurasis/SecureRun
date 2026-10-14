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
cannot supply elevated authority. P07/P08 must additionally enforce their actual
transfer/recovery ancestry, roles, journal and postconditions at use.

The Windows test creates an actual operation-owned file, records its NTFS identity,
replaces the path with a different object, checks refusal and confirms the
replacement canary still exists. A generation change also rejects the old record.
No real host files, generic staging-prefix sweep or sandbox-root cleanup are used.
