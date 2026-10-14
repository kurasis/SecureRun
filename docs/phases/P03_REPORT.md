# P03 phase report

Status: DONE. Requested scope: full P03. P01/P02 remain DONE with their original
retained evidence. All 26 specification documents remain byte-for-byte unchanged.
No P04 implementation is included in this request.

## Outputs

- Native Tauri 2.12.3 application shell, React 19.3.0/TypeScript 6.0.2 UI,
  Rust 1.90.0 workspace and frozen Cargo/npm dependency locks.
- Domain/persistence foundation: orthogonal lifecycle/activity/eligibility, owner
  identity, independent engine/environment generations, monotonic events, typed
  errors, future-phase entities and transactional SQLite schema version 1.
- Persistent dispatch reservations/idempotency keys, uncertain-outcome recovery,
  serialized operation intent and operation-owned artifact identity records.
- Explicit custom application-command ACLs, main local WebView/origin constraints,
  independent Rust ID/revision/owner authorization and no shell/fs/opener plugin.
- Backend-mediated native selection, retained file/ancestor identities and bounded
  one-use operation/purpose/generation/caller tokens with monotonic expiry.
- Already-minimized local/shared diagnostics, control/bidi injection rejection,
  bounded retention and English/Russian UI strings with semantic controls.
- [IPC contract](../IPC_CONTRACT.md), [schema/recovery](../PERSISTENCE.md),
  [workflow](../../.github/workflows/p03.yml), [reusable cloud setup](../../tools/setup-cloud.sh)
  and [original evidence/source hashes](../evidence/p03/manifest.json).

## Validation and gate

Exact tested source: 333e59cb6641fbcb3577c50f651fb9568df82140.
[Actions run 38571221105](https://github.com/kurasis/SecureRun/actions/runs/38571221105),
2026-10-14 UTC, completed successfully on both selected native Windows targets.

| Check | Server 2025 x64 | Windows 11 ARM64 |
|---|---:|---:|
| Foundation tests, including migration rollback/restart replay | 19 passed | 19 passed |
| Normal configuration/context tests, without test feature | 2 passed | 2 passed |
| Frontend state/localization tests | 3 passed | 3 passed |
| Real WebView2/native-picker command cases | 21 passed | 21 passed |
| Failed/blocked/ignored required checks | 0 | 0 |
| Engine operations executed | 0 | 0 |

The command cases observe a real standard token; a trusted main window; denied
ungranted local/remote calls with actual ACL errors; forged IDs/path/confirmation
and stale generations; persistent duplicate delivery; one-use native selection;
backend typed-channel event tags; denied renderer event emission; actual replaced Windows
artifact identity refusal; and absence of secret/injection canaries in diagnostics.
Both normal/native PE architectures are checked (8664/aa64), not inferred from
filenames. OS bases: 10.0.26100 and 10.0.26200; Node 24.19.0, Rust 1.90.0 and
pinned Tauri/WebView interfaces. WebView2 is the installed hosted runtime. No
Windows boot, Defender, signing or logon security setting is changed.

Linux: 19 foundation tests, 3 UI tests, strict core Clippy, formatting and frontend
build pass. Repository validator and seven tooling tests pass. Linux results are
pure data/build tooling, not native Windows or containment evidence.

T28/T49/T56/T61/T65/T66 are exercised on the foundation paths. T61's accepted/lost
receipt states use a logical dispatch counter, not an engine target. T65 includes
actual NTFS replacement plus old-generation refusal, with no deletion. Full
production engine/transfer/recovery and final acceptance variants remain in their
owning phases. All 66 production acceptance entries remain NOT_STARTED.

The exit gate is closed with typed IPC channels registered atomically in Rust
before returning the initial snapshot. The earlier global event-listener ACK could
precede its asynchronous JavaScript registration; historical evidence is retained
but is superseded for the revised transport. Gate: typed data flow, custom-command ACL and independent
backend authorization are enforced; stale events/snapshots cannot overwrite newer
state and no unscoped renderer command is available. Compiled ACL manifests and
capability definitions are retained alongside actual command outcomes, with raw
byte sizes/SHA256 and runtime source hashes.

## Phase boundary and publication

The ordinary shell offers read-only setup until P04 provides trusted self-context
observation. It does not open/migrate the production profile while context is
unknown. The separately compiled test configuration is visibly marked, uses a
fresh private synthetic profile and cannot execute engine operations/user targets.
No mock readiness, production launch/transfer/cleanup or supported release tuple
is claimed. No SandMan code or engine binary is copied/bundled.

Reusable install/start instructions were saved in the cloud configuration draft;
setup-cloud.sh was executed in the current Linux environment. Saving a draft
does not publish a new cloud snapshot. No persistent service is needed for the
selected portable checks; native execution stays in Windows Actions.

[PR #4](https://github.com/kurasis/SecureRun/pull/4) publishes all project source,
Markdown and reviewed JSON evidence. Normal merge follows successful checks under
the owner's standing authorization. Generated executables and credentials are
excluded. Next eligible phase: P04, not started by this request.
