# Safe file workflows

P07 implements regular-file import/export and private-workspace executable
references. Phase evidence is in [the manifest](evidence/p07/manifest.json);
[the phase report](phases/P07_REPORT.md) records the actual current gate.

The application uses the ordinary initiating Windows user. No privileged file
helper, host shell, recovery hook, content preview, executable icon extractor,
association lookup, automatic export or automatic opening is exposed.

## Native boundary and mappings

`files_request` has an explicit generated Tauri command permission, the main
WebView label and exact origin check. Renderer requests contain environment,
revision, opaque file or native-picker IDs, operation UUID and validated output
leaf. They cannot supply a physical source, destination path or a confirmation
boolean as authorization. Picker entries are one-use, operation/environment/
revision-bound, expire after 60 seconds and retain their selected OS object.
Engine-generation changes invalidate a returned UI result; durable transfer
records remain inspectable. Native workers independently establish both their
own and the parent's held, unboxed process identity, trusted engine and scope.

The list is an inert view of physical stored metadata, rather than a merged
filesystem or change audit. It exposes directories below the engine-resolved
`drive`, `user` and `share` branches, hiding root internal files and transfer
staging directories. Every listed object is opened without reparse traversal,
validated against held ancestry and recorded root/file identity. Enumeration is
lazy: 128 directory entries inspected per page, at most 4096 skipped entries,
with bounded depth/path grammar and a bounded native response. Unsafe entries
are omitted; a failed directory observation is an error. Sizes and timestamps
cross JSON as decimal strings. Complete suffixes remain visible; controls and
bidirectional formatting characters are escaped in displayed names.

The private import workspace uses the installed engine's resolved root and the
pinned upstream `CSbieAPI::GetBoxedPath` ordinary fixed-drive branch, source
`SandboxiePlus/QSbieAPI/SbieAPI.cpp:2064–2106` at
`cdba7096240b93d79c5373aa81a75a1c5c71b883`. The logical namespace is
`<system-drive>:\SecureRunWorkspace\<environment UUID>`; it must be absent on
the host. The adapter supports neither user-folder remapping, UNC/substituted
volumes, volume-serial layout, snapshots nor images for this workspace. It
checks the current setting, root/owner/ACL, NTFS volume and canonical held
ancestry each time; new directories receive protected owner/SYSTEM/admin ACLs.
Ordinary data filenames may contain literal percent/comma and Unicode; file I/O
grammar is independent of INI grammar. Output names still reject bidi and controls.
Production-path probes verify the actual mapping through original
`SbieDll_GetHandlePath(HANDLE,WCHAR[4096],BOOLEAN*)` and
`SbieDll_TranslateNtToDosPath`, rather than treating the source-derived layout
alone as Windows proof. No Qt library or engine binary is copied into SecureRun.

## Copy and publication protocol

Import takes explicitly selected regular local files, separately journaled.
Directories, reparse points, device/network/short/SUBST aliases, multiple hard
links, case-sensitive ancestry and alternate streams other than the default
stream and bounded `Zone.Identifier` are refused. Export additionally resolves
an opaque boxed file ID into its current root/generation/file identity. Both
operations require a completely stopped owned environment and share the policy/
launch namespace writer lock. Other manager launches cannot interleave. The
adapter rechecks driver activity, parent context and root during streaming and
performs current scope/policy checks again before publication. External engine
activity aborts preparation/copy; held source/parent objects prevent replacing
the leased data or namespace during that operation.

Export destinations must be ordinary canonical local fixed NTFS directories.
Windows, program, startup, application-data, manager/engine and all managed
storage scopes, including a selected ancestor containing them, are refused.
Source ACLs and arbitrary alternate streams are never exported.

1. Validate one output leaf without normalization. Reject separators, colon,
   controls/bidi, DOS devices including extensions and superscript variants,
   trailing spaces/dots, dot components and more than 180 UTF-16 code units.
2. Record intent, request signature, owner-root/revision generation, source and
   destination-parent identities in a WAL/FULL journal.
3. Create a new operation-specific private `.securerun-<UUID>` directory and
   `payload.part` with no replacement; journal both immutable file identities.
4. Before payload, create and flush a bounded canonical Internet-zone MOTW,
   preserving a valid Restricted zone (4). Never propagate URLs. Reopen and
   verify the marker under a read-only lease held through final rename. Failure
   before this point copies zero payload bytes.
5. Copy through a 1 MiB buffer, SHA-256 hashing incrementally. Check logical
   free space even for sparse sources. Bound the total to the preflight logical
   size and 1 TiB; detect growth, shrink or source metadata/identity drift. A
   write error, exhausted disk, cancellation or lost scope leaves visible staging.
6. Flush payload, journal its digest and ready state, revalidate scope and
   identities and publish with native handle-based `FileRenameInformation`, replacement false,
   relative to the held destination directory. Filesystem collision authority
   includes case/short-name aliases. Rename or Skip are the only collision actions.
7. Commit completion only after successful publication. No output is opened.

Debug builds optimize the pinned SHA-256 implementation for large transfers;
the algorithm, copy bounds and cancellation checks are identical.
The worker has a 128 MiB OS job memory ceiling, bounded 16 KiB input/2 MiB output
and one-hour transfer timeout. A size above 4 GiB is handled with 64-bit counters,
never whole-file allocation. PE registration retains the existing bounded PE
validation separately from generic large-file copying.

## Restart, cancellation and artifact removal

The journal persists intent, unmarked, marked incomplete, ready, complete,
reconciled complete, retained incomplete and explicitly discarded states.
Operation signatures are permanent: repeating a request never recopies, even
when the recorded outcome is incomplete. Cancellation uses a separate narrowly
named signal so it remains available while the transfer holds the writer lock.
It never labels a partial file complete or opens it.

Recovery first revalidates environment generation, owner, root, destination
parent and artifact identities. A final file is complete only when the recorded
identity, exact marker, size and digest match. A missing or invalid marker is
not synthesized into proof. A matching incomplete staging file remains visibly
incomplete; it is never automatically resumed or published. A substituted final
or staging file stays unresolved and untouched.

Explicit Discard removes only the held, identity-matched payload and the recorded
empty staging directory, through `FileDispositionInfo`. It checks the generation,
parent, derived operation-directory name and directory identity first; never
recursively walks, deletes a completed export or rolls back by path alone.
An old-generation journal cannot mutate a recreated root. Full reset generation
advancement and reset-invalidates-reference acceptance finish in P08.

Flushes and atomic namespace publication do not promise durability under every
power loss or storage failure. Actual state is revalidated after restart.

## BoxExecutableRef

A boxed executable registration stores environment ID, current generation,
logical path, physical volume/file identity and content hash. Its view explicitly
identifies it as boxed. Launch re-resolves the private mapping, rejects a host
shadow or changed identity/generation, retains physical safe handles, and runs
the protected `securerun-box-launcher.exe` stage through
`SbieDll_RunSandboxed`. Its protected file identity and hash are bound into the
reference and held through dispatch. The stage is created suspended, driver
membership is verified before resume, and it creates the exact logical EXE
using `CreateProcessW` with explicit application name, separately quoted argv,
no inherited handles and no shell, associations or environment expansion.
It verifies the suspended child's box/session before resuming target code.
The stage has no host manager commands or elevation route.
Receipts explicitly identify BOXED_STAGE_RUNNING/EXITED and leave the registered
target outcome unobserved; they never infer target completion from stage exit.
The driver process view remains authoritative for current members. Physical
sandbox storage never becomes a host executable. The same policy, architecture,
argv, dispatch-reservation and safe Stop gates as P06 remain applicable.

The completion rename uses `NtSetInformationFile(FileRenameInformation=10)`
with a relative leaf and held target directory (`FILE_TRAVERSE` plus read
attributes), following Microsoft's
[FILE_RENAME_INFORMATION contract](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/ntifs/ns-ntifs-_file_rename_information).
Transfer directory leases share read/write while excluding DELETE, permitting
the kernel's rename-target directory open. Provisioning retains its previous
stricter directory-sharing mode; payload/source data leases continue to deny
writers. Replacement, POSIX overwrite and ignore-read-only flags are absent.

## P08 lifecycle integration

See [Lifecycle and recovery](LIFECYCLE_AND_RECOVERY.md) for retention, native
confirmation, generation invalidation and inspect-only recovery. P08 native
verification is in progress; the phase report retains the current gate status.
