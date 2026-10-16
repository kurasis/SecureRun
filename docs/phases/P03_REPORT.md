# P03 phase report

Current P09 dependency regression: DONE at
`f9a9755a4e32bac27ef65ad9e4b5fdca32f7a67f`,
[run 38893325430](https://github.com/kurasis/SecureRun/actions/runs/38893325430).
Each target passed 19 foundation tests, 4 native app tests, 3 frontend tests and
32 actual Windows command-boundary cases with zero engine operations. Both actual
Windows architectures and the portable job passed. The [manifest](../evidence/p03/manifest.json)
binds original reports and every protected source, including current lab tools.
This closes P03 only; complete matching P04–P09 proof is still pending.
The sections below preserve the original completion and historical regressions.


Status: DONE. Requested scope: full P03. P01/P02 remain DONE with their original
retained evidence. All 26 specification documents remain byte-for-byte unchanged.
This historical report describes the original P03 scope; P04 observation is documented separately.

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

## Historical regression after P04

The P04 application/IPC changes supersede the original runtime hashes. Current
source 682c3a346a46bca4fb4dfbbe07cf538d2afa8adb passed the full P03 suite in
[run 38586144696](https://github.com/kurasis/SecureRun/actions/runs/38586144696):
19 foundation, two normal-configuration, three UI and 21 real command cases on
both native Windows targets. The current manifest retains those exact sources;
original proof remains historical. P03 does not claim P04 engine evidence, which
is retained in the [P04 report](P04_REPORT.md).

## Historical regression after P05

Current source `a6cdbd1d8c5f3630d7a0b2c1d2426fdd042f5636` passes
[run 38649287239](https://github.com/kurasis/SecureRun/actions/runs/38649287239)
on both native Windows targets: 19 foundation, 2 normal-configuration, 3 UI and
23 real command-boundary cases. The added cases reject renderer-supplied policy
paths and forged native-picker IDs. Generated ACLs, actual outcomes and the full
current runtime hashes are retained in the manifest. Historical P03/P04-era proof
remains immutable. Foundation tests execute no engine operations; P05 production
mutation evidence is recorded separately in the P05 report.

## Historical P06 regression

Runtime `c8d135da5ce403148e3e903036951ab9c947d8c1`,
[run 38705476301](https://github.com/kurasis/SecureRun/actions/runs/38705476301),
passed on Server 2025 x64 and Windows 11 ARM64: 19 foundation, 2 normal native,
3 UI and 25 actual WebView2/native-picker command-boundary cases per target.
The new control command is explicitly scoped to the main origin/window; raw
renderer executable paths and forged application selection tokens are refused.
This regression executes no engine target; P06 containment proof is separate.
[Current immutable evidence](../evidence/p03/manifest.json) binds the tested runtime
sources. Later P06 production commands do not expand the P03 fixture protocol.

## Current P07 dependency regression

Runtime `bec50c8fa7d0b47c4f05aa6662eeeb24faa18f68` passes
[run 38729076831](https://github.com/kurasis/SecureRun/actions/runs/38729076831)
on Server 2025 x64 and Windows 11 ARM64. Each target passed 19 foundation,
2 normal native, 3 UI and 27 actual command-boundary cases. The expanded boundary
includes the P07 files command, untrusted local/remote requests, forged selection
and renderer raw-path rejection. No engine target runs in this foundation gate.
The [manifest](../evidence/p03/manifest.json) binds the current sources and immutable
reports; the sections above retain historical phase results.

## P08 integration regression

The current P08 runtime `74d86db6dc883e692dfc04c8185eee790bdcf0a9` passed this phase on both owner-selected
laboratories in [run 38763953821](https://github.com/kurasis/SecureRun/actions/runs/38763953821): 19 foundation, 2 normal native, 3 UI and 29 actual command-boundary cases passed.
The [manifest](../evidence/p03/manifest.json) binds the current source and
original structured evidence; earlier results above remain historical.

## P09 product regression

Both Windows Server 2025 x64 and Windows 11 ARM64 passed the production regression
on `ce6098f1cad4cc36aa1dacaf96aaeb0628c94bae`. The immutable structured results
are retained in the phase manifest. This confirms this phase only; the P09
product exit gate remains pending.

Run: https://github.com/kurasis/SecureRun/actions/runs/38793638963

P09 regression at `83985827bfb1cb55b1ebdd2071bc0fa8332a83da` passed both targets
in run `38800451929`. Current production Rust/UI bytes match this validation;
later P09 diagnostic scripts do not constitute final matching P09 dependency proof.


P09 observer/UI regression at `eaab83c8a8a39e2b6ea293d6972b3e0d33b15096`
passed both targets in Actions `38811673054`: 19 foundation, three normal native,
three frontend and 32 actual command-boundary cases on each. This covers the
current production sources. It does not close P09's app or performance gate.
