# P06 — Isolated launch and scoped process control

Status: DONE.
Specification: 1.3. Requested scope: complete P06 only.

Implementation/runtime commit: `c8d135da5ce403148e3e903036951ab9c947d8c1`.
[P06 native run 38705476091](https://github.com/kurasis/SecureRun/actions/runs/38705476091)
completed successfully on both owner-selected laboratories. The retainers
independently checked every mandatory case, exact runtime source, raw report
checksum and matching P03/P04/P05 dependency. No gate remains blocked.
Reviewed reports are in the
[evidence manifest](../evidence/p06/manifest.json).

## Outputs

- `crates/sandboxie-adapter/src/control.rs`: private, identity-bound application
  registration; structured argv/CWD; WAL/FULL durable dispatch reservations,
  permanent operation/scope signatures, immutable receipts and explicit
  reconciliation without automatic replay.
- `crates/sandboxie-adapter/src/windows/provisioning/control.rs`: trusted original
  SDK dispatch, suspended pre-execution membership checks, fresh policy/storage
  prerequisites, complete all-session observations and held-object environment
  Stop/Stop managed with completed waits.
- `src-tauri/src/policies.rs`, `main.rs`, application ACL/build registration:
  authorized main-window commands, one-use native picker capabilities, bounded
  normal worker/CLI framing and backend generation/sequence rejection.
- `ui/controls.tsx`: English/Russian application registration, optional target CWD,
  argument editor, launch, current process views, Stop and explicit reconciliation.
  Background polling cannot supersede an active user operation; stale views age
  to Unknown and old async responses cannot restore them.
- `tools/lab/Invoke-P06.ps1`, `retain_p06_evidence.py`, fixed launch probe and
  disposable-only scripts: production-path native proof, real process interruption,
  genuine/emulated PE coverage and strict source/checksum/dependency retention.
- [Launch/control contract](../LAUNCH_AND_PROCESS_CONTROL.md), updated
  [IPC contract](../IPC_CONTRACT.md), phase status and immutable reviewed evidence.

No imported/boxed EXE mapping, target elevation, general PID-kill command, host
fallback, cleanup implementation, product privileged helper or engine bundling
was introduced.

## Requirements and action gates

PR-03 through PR-06 are implemented through normal production services.
Registration accepts canonical local host EXEs and structured arguments/CWD;
renderer paths cannot bypass the native selection book. The original SDK receives
target command/CWD separately, while host workers start in System32 with a minimal
OS-derived environment. CRT quoting is tested through the actual engine parser.

Launch requires verified ownership, immutable root/ACL, current revision and
configuration/inheritance fingerprint, supported constrained policy family,
matching actual kernel/product/engine tuple and current manager/verifier binding.
Complete owner-matched session enumeration precedes the launch fence. The original
service creates the target suspended; driver membership and held OS birth are
verified before resuming its primary thread. Short-lived confirmed boxed receipts
remain distinct from lost outcomes; children keep environment activity Running.

Each launch reserves durable intent before dispatch. A crash before dispatch or
a lost accepted receipt stays Unknown even when enumeration is empty. Duplicate
IPC/restart delivery never dispatches that operation again. Unknown launches
block a new operation until explicit reconciliation; reconciliation preserves
Unknown and does not imply nonexecution.

Stop requires its own trusted context, current owned marker/root and complete
all-session scope. It does not depend on launch eligibility, network enforcement,
registration or optional entitlement. It retains authorized noncritical process
objects through dispatch and completed waits, rechecking membership/scope at use.
Membership retirement during natural exit is reconciled by waiting on the same
held object; a live mismatch remains refused. No numeric-PID fallback exists.
Stop managed resolves explicit journaled identities, never a box-name prefix.

## Native verification

Original Sandboxie Plus 1.18.6 / core 5.73.6 / ABI `0x57230`, pinned upstream
`cdba7096240b93d79c5373aa81a75a1c5c71b883`.

| Laboratory | Actual target PEs | P06 passed | Failed / blocked / skipped |
|---|---|---:|---:|
| Windows Server 2025 x64, build 26100 | x64 and genuine x86 | 21 | 0 / 0 / 0 |
| Windows 11 ARM64, build 26200 | ARM64 and emulated x86/x64 | 22 | 0 / 0 / 0 |

Every applicable P06 scenario is present on both targets: T01–T07, T19, T26,
T36, T50, T54, T56, T61 and T62. Proof includes missing engine, stopped service,
actual original-driver unload, changed signed component, exact Unicode paths/argv,
invalid/replaced EXEs, child/grandchild and background activity, unmanaged box/host
process survival, competing managers, hostile target CWD/PATH/DLL fixtures,
current-policy-ineligible Stop and stale application revision refusal.

Five actual standard-user actors per target exercise normal control, reservation
interruption, accepted-dispatch interruption, held-object races and real Windows
sessions 0/2. The missing-engine bootstrap check and disposable engine setup are
separate lab administration. No Windows security setting is relaxed.

T61 kills real workers at Reserved and Accepted checkpoints. Three duplicate
restart deliveries execute zero and one target respectively; a separate normal
operation delivered five times executes once. Explicit reconciliation retains
Unknown. T62 changes real scope after retaining handles and proves the target
survives refusal. The natural-exit case retains a live primary until it exits,
confirms scoped completion and preserves an unrelated host process.

The normal manager has no checkpoint activation. A separately compiled
`policy-ci` binary is used only for disposable Actions interruption/race fixtures;
its distinct binary hash is retained. Fixed original `KmdUtil` administration
and a narrow disposable logon fixture are not product helpers.

## Dependencies and checks

P05 was complete before P06 began, with runtime `a6cdbd1` and matching P03/P04
proof. Changes require current regression evidence for the final P06 source.

| Check | Current result |
|---|---|
| Portable Rust | 19 foundation and 28 adapter tests passed |
| Windows metadata-only strict i686 clippy | Passed; not Windows execution evidence |
| Tooling integrity | 9 tests passed |
| UI | 3 state/localization tests and production asset build passed |
| P03, run 38705476301 | Both targets: 19 foundation, 2 normal native, 3 UI, 25 actual command-boundary cases passed |
| P04, run 38705479692 | Both targets: 31 adapter tests and 19 native observation cases passed |
| P05, run 38705482872 | Both targets: 31 adapter tests and 45 applicable native policy/provisioning cases passed; one accurate Not applicable UAC route |
| P06, run 38705476091 | Both targets passed; complete source/checksum-bound retention |

Commands executed include `cargo test --locked`, strict adapter clippy for native
Windows and metadata-only i686, `npm test`, `npm run build`,
`python3 tools/lab/validate_repository.py`,
`python3 -m unittest discover -s tests -p 'test_*.py'`, and the P03–P06 Actions
workflows on this branch. Retainers require successful exact-source runs,
matching P03/P04/P05 dependency commits, every named native case and immutable raw
report checksums. Reports contain no raw arguments, environments, credentials,
private paths or SIDs.

## Scope, limitations and investigation history

T26 import/export/reset portions belong to P07/P08. P06 covers launch/Stop
serialization, duplicate/conflicting operations and competing managers. T54's
actual paid-certificate-expiry subcase is Not applicable: no paid preset or
entitlement-dependent launch route is enabled. Baseline Stop while launch is
ineligible is proven; no substitute certificate or expiry bypass is fabricated.

The manager lock does not serialize a trusted administrator/SandMan. External
scope/policy changes are detected and refused; atomic protection against a
concurrently editing trusted administrator is not claimed. Registration must be
renewed after its policy revision changes. Root relocation remains unsupported.

Minimized historical failures remain in the P06 manifest: initial SMB/account
setup, optional-CWD/UTF-8/scenario-variable/PATH/session fixture defects and the
natural-exit Stop race. They were corrected without exclusions or relaxed gates.
P03/P04 regression evidence for the intermediate source is preserved separately.

All 26 original specification documents are unchanged. All 66 final installed-
candidate acceptance entries remain NOT_STARTED. No Windows 11 x64 release tuple,
paid feature, production file workflow, installer or release certification is
claimed. The next eligible phase is P07. The requested P06 scope is complete.


Final dependency investigation: P05 run 38703112142 passed 44 applicable Server
cases and failed one future-sibling provisioning case on diagnostic stop
completion; one absent UAC route was accurately Not applicable. The existing
private P05 diagnostic stop still rejected a failed termination dispatch even
when its retained process had naturally exited. Its postcondition now requires
the completed wait on that same object. Numeric status-only diagnostics distinguish
dispatch failure from incomplete exit. All current phase gates have been revalidated for this shared dependency
correction; no earlier source is relabeled DONE. The final source passes the
complete P03–P06 gates on both owner-selected laboratories.
