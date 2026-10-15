# Lifecycle and recovery

P08 adds an ordinary-user lifecycle service. Native verification is in progress;
see [the phase report](phases/P08_REPORT.md) for the current gate.

| Explicit action | Retention |
|---|---|
| Persistent | Keep contents and running workloads when the manager exits. |
| Disposable | Keep leftovers until the user chooses Resume, Export or Delete. No automatic cleanup or export is enabled. |
| Archive | Preserve definition, contents, application records and audit. Refuse new managed launches and imports. Allow inspection and explicit export. |
| Unarchive | Revalidate current ownership, roots, policy and entire-box activity before allowing managed work. |
| Reset | Clear verified contents through the original engine route. Keep the definition, host application records and audit. Advance the environment generation; old boxed executable and file references become unavailable. |
| Remove | Clear contents first, delete the original engine definition after readback, then remove owned application/definition records. Keep audit tombstones and the verified empty root. |

Archive is a manager state, not an engine access-control boundary. A separately
trusted original Sandboxie client can launch an archived box. Cleanup independently
requires complete all-session idle and fences original dispatch while sealing and
clearing the namespace. Unknown activity, changed roots, unsupported image roots,
configuration drift or automation hooks refuse destructive work.

The renderer supplies identifiers and intent. It cannot submit a confirmation
boolean, raw root path or backend plan capability. The backend prepares a private
60-second plan; an OS dialog names the affected environment and its UUID and
states exactly what the action retains. Cancel consumes the plan without dispatch.
Commit rechecks the generation, revision, engine, owner and root identities.

Cleanup uses the P02-proven native `NtIo_DeleteFolderRecursively` export from the
original QSbieAPI module. The module and its original local DLL dependencies must
match authenticated P02 hashes and valid signatures. No shell delete command,
hook execution, host fallback or generic recursive root deletion is used. The
supported protocol holds the exact root against deletion and retains that same
root identity after successful content removal; reset changes the environment
generation. Unexpected root recreation is never adopted automatically.

A private WAL/FULL SQLite journal records reservation before mutation, bounded
security-descriptor snapshots, dispatch uncertainty and checked postconditions.
A separate ordinary-user controller survives UI exit, bounds the executor with a
one-process 128 MiB job and retains preauthorized metadata handles for every
snapshotted object. It closes only handles already marked delete-pending by the
original upstream native routine; surviving objects retain restoration authority.
Bounded drain passes inside the active dispatch allow pending child handles to
close before the original routine removes their directories. Recovery never
re-enters those passes. The controller waits for the held executor, restores the
known ACLs and only then publishes COMPLETE. Native faults and ACL restoration must pass the phase's Windows tests before
this protocol can be described as complete.

On restart, Inspect reads the journal and current identities. It never replays a
cleanup or definition deletion. A verified completed reset can reconcile its
generation; an already absent verified definition can reconcile removal metadata.
An uncertain partial cleanup retains and archives remaining data and requires a
new explicit intent. Changed roots or unknown activity remain blocked. Recovery
must not adopt a changed ACL, erase a replacement object or delete a path merely
because its name resembles a temporary file.

Launch receipts keep UNKNOWN after interruption. Reset reconciles old reservations
without erasing that uncertainty; an old operation cannot dispatch in the new
generation. Published export files remain outside the box. A post-rename export
can be reconciled from verified identity, bytes and marker; after reset, stale
recovery/discard requests refuse before mutating its host artifact. Registered
boxed executables remain visible as unavailable until explicitly reimported and
registered from the new generation.

P08 does not add encrypted boxes, snapshots, root relocation, engine removal or
release packaging. Installed-candidate acceptance remains P12; T48 packaging
portions remain P11. Full machine/power loss can remove the live controller's
preauthorized restoration handle; such a case must remain visible and blocked
for explicit manual remediation if the known ACL cannot be safely restored.

To restore an archive, open Retention and recovery and Recheck the environment.
Stop its entire box, including other relevant sessions, then choose Unarchive and
review the native dialog's name and UUID. Current ownership, roots and policy must
validate before managed launch becomes available. Use Files for an explicit export
while the archive is retained; the manager performs no automatic host recovery.
