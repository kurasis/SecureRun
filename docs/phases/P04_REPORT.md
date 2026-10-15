# P04 phase report

Status: DONE. Requested scope: full P04. Dependencies: P02 feasibility and P03
foundation/IPC, with current P03 native regression for the same final source.
This historical section describes original P04 scope; current P05 regression is
recorded below.

## Implementation and evidence

Original P04 runtime/test source: 682c3a346a46bca4fb4dfbbe07cf538d2afa8adb.
P04 [run 38586140093](https://github.com/kurasis/SecureRun/actions/runs/38586140093).
P03 regression [run 38586144696](https://github.com/kurasis/SecureRun/actions/runs/38586144696).
[P04 retained results/source hashes](../evidence/p04/manifest.json) and
[P03 regression provenance](../evidence/p03/manifest.json) bind the actual outcomes.

Outputs: production Rust read-only adapter; protected installed-component discovery;
Windows Authenticode/exact-payload/architecture/ACL validation; bounded same-image
worker; independent own-process context gates; all-session process identity,
configuration and root observations; versioned compatibility manifest; cache,
generation and freshness rules; English/Russian health/capability dashboard.

Primary implementation: crates/sandboxie-adapter, src-tauri bootstrap/IPC and ui.
Reproduction: P04 workflow and Invoke-P04.ps1; fixed P02 fixture producers only.
[Observation contract](../ENGINE_OBSERVATION.md) and [IPC contract](../IPC_CONTRACT.md)
describe trust boundaries, response limits and private/local data handling.

## Gate results

| Check | Server 2025 x64 | Windows 11 ARM64 |
|---|---:|---:|
| Adapter tests, including two real native pipe/job-bound tests | 12 passed | 12 passed |
| Production observation/trust/context scenarios | 19 passed | 19 passed |
| P03 foundation / normal configuration / UI regression | 19 / 2 / 3 passed | 19 / 2 / 3 passed |
| Real P03 WebView2/native-picker command cases | 21 passed | 21 passed |
| Required failed / blocked / skipped cases | 0 | 0 |
| Product target launches / engine mutations | 0 / 0 | 0 / 0 |

Native manager/bridge PE machines are 8664/aa64. The independent x86 diagnostic
fixture is a genuine 014c PE on both hosts. P04 uses original Plus 1.18.6, core
5.73.6, ABI 0x57230, source cdba7096240b93d79c5373aa81a75a1c5c71b883.
OS bases are 10.0.26100/10.0.26200; exact runs/architectures/binary hashes are
retained. Rust 1.90.0, Node 24.19.0 and frozen dependency locks remain pinned.
No Windows boot, Defender, certificate, TLS or signing setting is relaxed.

Scenario coverage is component-phase evidence:

- T01: missing engine, stopped service and unavailable driver fail closed.
  The disposable harness uses authenticated original KmdUtil's source-reviewed
  unload protocol; the product never exposes driver stop/install/control.
- T02: original component trust; modified binary rejection before loading;
  writable install/false service path refusal; read-only unowned configuration and
  real root identity; explicit unavailable/unknown entitlement provenance.
- T07: real held-object birth, wrong-birth refusal and a genuinely exited object.
  A retained exited object is not a live manager. Forced PID reuse and production
  termination belong to later dispatch/control acceptance.
- T36: native/x86 identities plus one actual standard-user SID simultaneously in
  Windows sessions 0 and 2, four observed processes, complete native enumeration.
  Successful truncation, races/unknown data and stale generations cannot prove Idle.
- T46: actual service restart through the same production manager observer,
  generation 1→2→3 and preserved cached route evidence; controlled suspend-delta,
  expiry and root-replacement tests. Physical VM suspension/terminal desktop stress
  is not claimed; the Windows bias-counter hook is implemented and sampled natively.
- T50: hostile target CWD/PATH/SbieDll fixtures cannot change the worker's host
  CWD/environment or absolute component loading.
- T56: older tickets/generations, expired data and precision-loss identity values
  are refused; FILETIME identities serialize exactly as decimal strings.
- T58: actual manager diagnostic child remains boxed/unknown and cannot enumerate
  or control; the normal desktop entrypoint exits 78 before metadata/WebView
  creation. No elevation, self-relaunch or host escape occurs.

Linux validates 19 foundation tests, 10 portable adapter tests, three UI tests,
frontend build, formatting, strict Clippy and seven repository/tooling tests.
These are portable checks, not Windows containment or GUI claims.

## Explicit unknowns and phase boundary

The original service protects its process object from a standard user. Readable
SCM status/PID remains separate from Unknown service image/birth identity; no fake
birth or privileged fallback is used. Standard-user native read-only observations
are proven, while control-plane safety remains false for incomplete service identity.
Every existing box remains unowned/read-only. Roots are current-caller observations,
not cross-SID enrollment. The ordered 24-key configuration view is not a complete
revision/enforcement oracle. Snapshot completeness does not lock external clients.

Normal mode stays observation-only and does not open/migrate a persistent production
profile. Provisioning, policy compiler, privileged enrollment if ever needed,
launch, stop, transfer, cleanup and production recovery remain in their owning
phases. Paid profiles are disabled without verified entitlement/enforcement.
No SandMan implementation or original engine binary is copied/bundled.
All 26 specification files remain byte-exact; all 66 final acceptance scenarios
remain NOT_STARTED. Neither this phase nor the Server/ARM laboratories declares
a hardened Windows 11 x64 production tuple or a completed release.

All source, Markdown and reviewed JSON evidence are published by
[PR #5](https://github.com/kurasis/SecureRun/pull/5) under the owner's standing
push/normal-merge authorization. Generated binaries, raw private observations and
credentials remain excluded. Reusable cloud install/start instructions were saved
as a draft; publishing a cloud snapshot is a separate environment-settings action.
Next eligible phase: P05, not started here.

## Historical regression after P05

Current source `a6cdbd1d8c5f3630d7a0b2c1d2426fdd042f5636` passes
[run 38649290153](https://github.com/kurasis/SecureRun/actions/runs/38649290153)
on both native targets: 28 adapter tests and all 19 production observation cases,
zero failures/blocked/skipped, zero product target launches or mutations in this
read-only suite. The same source passes the complete P03 regression in
[run 38649287239](https://github.com/kurasis/SecureRun/actions/runs/38649287239).
Current manifests bind the actual reports and unchanged runtime sources; earlier
proof remains historical. Ordinary-user service-process birth remains Unknown
where access is denied, and boxed startup still exits before metadata/WebView.
The separate P05 suite validates user-owned policy/provisioning mutation.

## Historical P06 regression

Runtime `c8d135da5ce403148e3e903036951ab9c947d8c1`,
[run 38705479692](https://github.com/kurasis/SecureRun/actions/runs/38705479692),
passed both owner-selected targets: 31 adapter tests and all 19 production
observation scenarios per target. Current [source-bound evidence](../evidence/p04/manifest.json)
preserves all prior raw reports. This observation protocol stays read-only and
cannot authorize launch; the separate P06 service independently checks its
current owner/root/policy and action-specific prerequisites. Ordinary-user
service-process identity uncertainty remains explicit rather than fabricated.

## Current P07 dependency regression

Runtime `bec50c8fa7d0b47c4f05aa6662eeeb24faa18f68` passes
[run 38729079754](https://github.com/kurasis/SecureRun/actions/runs/38729079754)
on Server 2025 x64 and Windows 11 ARM64. Each target passed 38 native adapter
tests and all 19 observation cases, including the actual boxed normal desktop
entrypoint refusing before metadata. The [manifest](../evidence/p04/manifest.json)
binds current source hashes and immutable reports. An earlier ARM desktop-startup
30-second timeout is retained as failed investigation; its cause was not
established. The fresh complete run passed the unchanged refusal condition.
