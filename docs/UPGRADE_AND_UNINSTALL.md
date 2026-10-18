# Upgrade, schema safety and retained-data uninstall

PR-14 defaults to retaining data. Setup owns only administrator-controlled manager
code, one Start menu shortcut and its own uninstall/version registration. It never
opens user databases, guesses sandbox roots, executes engine cleanup or removes
engine definitions. All profiles, metadata/ownership records, journals, archived
and active environment data, the engine and Microsoft WebView2/C++ shared runtimes are retained.

Before an upgrade, finish or reconcile operations and close the manager. Setup
does not forcibly terminate isolated applications, unrelated processes or running
manager instances. In-use code can make installation fail; close it and inspect
the reported state before a deliberate retry. An uncertain installer outcome is
not permission to replay a target launch or destructive operation.

Use the same native-architecture installer and fixed protected code directory.
P11 tests revision0.3.0.10 → revision0.3.0.11 with the **same reviewed runtime and
schema1**. This tests packaging upgrade/rollback and profile retention, not a
fabricated migration to a schema the application does not implement. A real
locked-code installation failure must retain the old payload/version and exact
profile digest; the successful upgrade must also leave the profile bytes alone.

All current production databases use schema1. Initial schema creation is
transactional. Existing foreign schema0 databases and future schemas are refused;
the installed application must leave their bytes unchanged. A failed production
initial-migration transaction is tested separately by the actual foundation
migration unit test. Installed worker tests exercise foreign/future refusal and
then restore only their lab-owned synthetic fixture backup. The product does not
restore a user database automatically or downgrade a future schema.

No 1→2 migration exists in this release. Before implementing a future migration:
stop all writers, take a consistent owner-controlled SQLite backup (including a
consistent WAL checkpoint or SQLite backup API), verify its integrity and bind
the schema/engine/root identities. Migrate as the ordinary owning user in a
transaction, with a tested rollback path. Never copy a live main database alone
while ignoring its WAL. Never restore an old metadata backup over changed box
contents or engine state: metadata backup is not an environment snapshot. After
failure, retain the original and backup, show the error and reconcile actual
state; do not replay operations or silently start targets.

The installer refuses an older registered package revision. Removing/replacing
registration manually is not a supported downgrade; production database version
checks still refuse newer schemas. Reinstalling the same package version is
supported and does not erase or migrate profiles as administrator.

To uninstall, close the manager and use Windows Installed Apps → SecureRun
Development, or the installed uninstaller. The uninstaller checks its protected
code path before removing code. It has no user-data deletion option, never stops
boxes, never uninstalls the engine/runtime and never follows configurable box
paths. This is retention, not forensic secure erasure. Running box applications
and retained storage can remain after manager removal.

If you want to delete an environment, first review/export its files and use the
manager's explicit Remove flow, which requires stopped state, ownership checks,
confirmation, the tested original cleanup route and postcondition verification.
Use Archive to retain its definition/data. Do this before uninstalling; do not
use recursive filesystem deletion as a substitute for managed cleanup.

Reinstall under the **same Windows account** to reopen retained ownership records.
The manager revalidates the original root identity and engine policy before
launch. A new Windows account or a copied profile does not inherit authority.
Unknown ownership, changed root identity or foreign schemas stay blocked.

No privileged helper exists. Helper enrollment, helper scope records and
different-account helper UAC tests are explicitly N/A; this does not waive the
applicable boxed-manager, forged-parent or ordinary-user code protection checks.
See [actual P11 results](phases/P11_REPORT.md).
