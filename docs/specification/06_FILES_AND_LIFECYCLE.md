# Files, Recovery and Environment Lifecycle

## File view

Treat stored sandbox files as untrusted. v1 lists metadata and storage paths; it does not promise a complete merged view of the host filesystem or a complete audit of changed files. Existing engine storage layouts may contain registry hives and internal files. Hide internal implementation files from normal export and never interpret hives as ordinary documents.

Use engine-resolved roots and mappings established in P02. Do not reconstruct physical paths from display names or a guessed `C:\Sandbox` convention. Do not execute previews, macros, shell extensions or icons supplied by boxed executables in the host UI. Use generic file-type icons.

## Import

v1 managed roots and transfer destinations must use local fixed NTFS volumes. Reject UNC/removable roots, junction-containing roots and unsupported filesystems; do not imply their semantics were tested. Resolve and record volume/file identity, owner and effective DACL, and reject overlapping roots. Root ACLs must exclude unrelated standard users while preserving required owner, SYSTEM and administration access. Test this with a second standard Windows account. Per-user naming alone is not an ACL. The upstream LockBoxToUser option is relevant but its documented scope is global; prefer validated owned-root ACL enforcement where possible, and never silently change a global option. A root that cannot satisfy the mandatory protection is unusable.

Cross-box isolation additionally requires an engine-policy test: a boxed application must not read/write another managed box's physical storage or manager metadata through host paths. Same-user filesystem ACLs alone cannot enforce this. If the baseline engine cannot enforce this with tested rules, mark the affected release gate blocked instead of calling all boxes mutually private.

User selects regular local files. Require the target environment stopped for v1, obtain its operation lock, copy to an adapter-verified private workspace and preserve provenance metadata where applicable. Never create direct host-write grants. Reject symlinks/reparse points, device files and unsupported streams; refuse recursive folder import in v1 to keep semantics bounded. Support multiple explicit files, collisions, cancellation, disk-full errors and transactional cleanup of incomplete copies.

Do not inject files into guessed engine paths. If mapping cannot be verified, disable import until the adapter supports it. Imported executables may run only through an explicit sandbox launch action.

Represent executables as either a verified host EXE path or a `BoxExecutableRef` (environment ID plus validated logical boxed path and physical identity). Never launch the physical storage path of an imported EXE as a host EXE. Verify virtual-to-physical mapping on each launch; a reset invalidates the reference. Multi-file portable application installation remains outside v1 import support; host-installed applications can still run with boxed state.

## Export

1. User selects files and a destination. Show that exported files remain untrusted.
2. Require the environment stopped and block new manager launches. Recheck process state before and during preparation.
3. Resolve the source using engine identity and safe file handles. Prove containment inside an owned root, reject reparse traversals, links escaping containment, device paths and ambiguous aliases. Account for hard links and path replacement races.
4. Validate the destination outside sandbox/manager/Windows/program/startup-sensitive locations. v1 exports only to a user-selected ordinary local NTFS folder and always creates new files; collisions require Rename or Skip, never replacement of an existing host file.
5. Create a new, uniquely named staging file with a non-document temporary suffix in an operation-owned staging directory on the destination volume, with restrictive ACLs and verified parent identities. Before copying payload bytes, write and verify a bounded, validated Mark-of-the-Web marker: preserve a valid zone at least as restrictive as Internet, otherwise use a minimal Internet-zone marker. Do not invent a source URL or copy arbitrary alternate streams. Stream bytes with bounds, verify source stability, flush as required by the documented completion protocol and finalize using an atomic no-replace rename. The final name is published only after the marker and content checks pass. If provenance cannot be written, fail before copying the payload. Mark-of-the-Web is provenance, not a universal execution blocker.
6. Show result, size and destination; never automatically open or execute it.

Use Windows handle-based final-path and file-identity checks; string prefix checks are insufficient. Environment stop is helpful but does not alone eliminate races from other host actors. Do not export source ACLs, arbitrary alternate streams or links. Never run upstream recovery hooks in the manager's host security context. Optional Defender scanning can be added later; it must not label files safe or upload them silently.

For regular file export, reject a source with multiple hard links in v1 instead of trying to enumerate every possible external alias. Hold handles that deny mutation/deletion where supported throughout validation/copy, and retain verified parent/root identities. Use the same safe-copy primitive for imports. Bound path length, traversal depth, metadata reads, list size and byte count; sparse/compressed files need logical-size free-space checks. Do not trust preflight size as a promise that a mutable file cannot grow. Host file pickers and same-user mutable directories do not remove race conditions.

Treat an output name as one validated leaf component, never a relative path. Reject separators, drive/device prefixes, colon/stream syntax, dot components, reserved DOS device names even with extensions, trailing spaces/periods, invalid/control characters and unsupported lengths. Do not silently normalize an unsafe name into a different target. Require a safe explicit rename or skip, and revalidate the rename. Use filesystem no-replace creation as the authority for collisions, including case/short-name aliases. v1 rejects transfer locations with unsupported case-sensitive-directory behavior rather than assuming all NTFS directories are case-insensitive. See S28 for Windows naming rules.

Display full extensions and escape bidirectional/control characters in untrusted names so a filename cannot hide its actual suffix or forge adjacent UI text. The source filename is metadata; it is never a command or a destination authorization token. Manager file lists must not use shell preview/icon handlers. Backend-mediated host pickers are selection mechanisms, not proof that the selected data or path is safe; avoid navigating them into boxed storage and use the inert in-app list for boxed sources.

Test interruption before marking, during copy, before final rename and after rename but before journal commit. A pre-mark failure leaves no payload; interrupted marked payload stays an explicitly incomplete staging artifact. A post-rename journal failure is reconciled using the recorded file identity and verified marker, without overwriting, recopying or deleting an unrelated final file. Atomic namespace publication is not a promise of durability under every power-loss/storage failure. Revalidate actual state on restart.

## Disposable mode

Each disposable environment uses a unique box identity and private state. Closing the launcher process is not the same as the environment being empty: wait for all descendants and background processes reported by the engine. On final process exit, offer pending export and cleanup. Automatic cleanup may be explicitly enabled per environment after a clear retention choice; never automatically recover files to the host.

If the manager crashes, data may remain. On restart, show leftover disposable environments with Resume, Export, or Delete choices. Do not claim guaranteed deletion after power failure or forensic secure erasure.

## Reset and remove

Reset clears contents but retains the definition and application records. Boxed executable references invalidated by reset become unavailable until reimported. Remove requires clearing contents before definition deletion. To keep data, use Archive: retain the engine definition and ownership records, disable manager launch and keep export/reset available. Do not remove the definition and silently orphan unexported state. Require stopped state and a visible confirmation listing the affected environment. Use the tested upstream cleanup operation and verify completion, including pending deletion directories. Never use generic recursive deletion against a configurable root.

Deletion failure leaves an operation error with activity Cleaning or Unknown until reconciled. Do not mark clean because the utility exited successfully. Do not restore old backups over files the user has changed. The manager uninstaller retains environment data by default and never uninstalls the separately installed engine. Any optional manager-data removal requires an explicit retention choice.

## Cleanup is an execution-sensitive operation

`Start.exe delete_sandbox` can consume legacy `DeleteCommand`; SandMan's `OnBoxDelete`, `OnBoxTerminate` and `OnFileRecovery` are separate host-side automation. Before launch, stop and cleanup inspect the applicable settings and reject unapproved automation. Before deletion revalidate the current resolved root against the recorded identity and ensure no snapshots/images or untracked root relocation are involved.

Permit only the pinned upstream built-in deletion path, with its preparation, root containment and exit/postcondition behavior verified in P02. A built-in upstream cleanup implementation may internally invoke an OS deletion utility; this is not permission for the manager to construct an arbitrary shell command or accept a user-defined DeleteCommand. If a custom/inherited command could run, block cleanup until it is explicitly removed through a reviewed configuration repair. If no safe upstream deletion route is available, cleanup is a release blocker; do not substitute generic recursive deletion.

Source references: [Deletion lifecycle](https://sandboxie-plus.github.io/sandboxie-docs/Content/SandboxRemoval.html), [Triggers](https://sandboxie-plus.github.io/sandboxie-docs/Content/SandManTriggers.html), [DeleteCommand](https://sandboxie-plus.github.io/sandboxie-docs/Content/DeleteCommand/), [Root ACLs](https://sandboxie-plus.github.io/sandboxie-docs/Content/LockBoxToUser.html).

## Operational journal

Track operation intent, engine identity, phase, timestamps and postconditions. A restart reconciles incomplete imports, exports, policy updates and deletion. Keep partial exports visibly incomplete and separate from successful files. Clear cancellation semantics: a stop request can be canceled only before dispatch; a dispatched destructive engine operation may require waiting for reconciliation.

Record the environment generation, operation-owned staging directory and file identities before they become recovery candidates. Reopening a staging artifact requires matching its volume/file identity, safe ancestry, owner and expected role. Never enumerate and delete all matching temporary filenames. If a recorded artifact was replaced, or the journal/root identity is untrusted, block automatic cleanup and show the unresolved item. Apply this rule to import rollback as well as export recovery. Staging removal may delete only individually verified operation-owned artifacts; it does not authorize generic recursive deletion of sandbox roots.

Successful cleanup may remove/recreate the root and therefore change its filesystem ID. Only a journaled, confirmed manager cleanup/recreation may rebind that ID after checking the expected path, safe parents, owner and DACL. Unexpected replacements remain blocked. An absent root after confirmed cleanup is a known empty state, not permission to bind any future directory placed there. Unarchive revalidates engine, ownership, roots and policy before enabling launch. Archive controls this manager only; it cannot stop a trusted external engine client from requesting a launch.

A fresh environment without materialized storage uses the PendingRoot provisioning protocol in the integration document. A fixed trusted initializer may materialize that fresh, verified-empty managed box before any user target runs. This narrowly scoped initialization is distinct from diagnosing previously used box contents; do not run general diagnostic probes in a polluted existing box.
