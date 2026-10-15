# P05 — policy and safe provisioning report

Status: DONE. All required P05 outputs and applicable native exit gates passed.
Dependencies: current P03 and P04 regressions on the same runtime source.
Implementation source: `a6cdbd1d8c5f3630d7a0b2c1d2426fdd042f5636`.

P05 implements constrained Standard offline/online policies, user-owned storage,
journaled provisioning and stopped revision-aware mutation, independent fresh
containment probes, and explicit conflict inspection/repair. The ordinary desktop
includes an English/Russian native-picker editor. Production user-target launch,
installation, general Stop and cleanup remain unavailable until their owning
phases. No privileged product helper is required or implemented.

## Outputs and behavior

The schema 1 compiler supports Block, Read only and Isolated changes on a bounded
literal local path family. Native canonicalization and held objects reject
unsupported aliases, reparse ancestry, streams, selectors, namespace indirection,
wildcards and overlapping grants. Renderer grants use one-use native-picker tokens
bound to operation, environment, revision and expiry. Mandatory metadata, manager
code and sibling protections cannot be edited as user grants. Standard reads
ordinary nonexcluded host data; online permits network access and local resources
while retaining network-share denial. Paid presets remain disabled without
verified entitlement; no substitute certificate or bypass exists.

Names/root locations derive from backend UUIDs and the original Windows user.
Fresh relative NTFS creation supplies a protected owner/SYSTEM/Administrators DACL
at creation, rejects existing-directory adoption and records volume/file identity.
All affected siblings must be stopped across every accessible Windows session and
have their future-root denials applied/read back/verified before a new root is
materialized. Actual old-box access to a new sibling is independently denied.

SQLite WAL/FULL commits immutable operation signatures and Intent, Fenced,
Writing, Readback, PendingRoot, RootBound and Verifying stages. Duplicate delivery
never redispatches. Stale revision, changed configuration/root/inheritance or
unknown health blocks mutation/verification. Actual worker interruption and restart
leave inspect-only conflicts with no automatic replay, valid fingerprint or
launch permission. Repair requires the current raw fingerprint, actual ownership
marker/root identity and explicit view-change acknowledgement. Read only bypasses
the boxed overlay; the editor discloses that change and the native test proves the
original overlay survives and returns after policy reversal. File export belongs
to P07; no production target data is created by this phase.

The original SDK is signature/hash/ABI checked and loaded from protected absolute
paths. Original default template bytes/list/inheritance are pinned. ConfigLevel 10
precedes Enabled to prevent the original GUI's migration from adding unwanted
recovery/templates. The supported configuration API is not a whole-section atomic
transaction: the journal fences definitions and detects external writes before/
after each step. External editors must remain closed during mutation; no isolation
against a concurrent trusted administrator is claimed.

Every architecture uses a different fresh diagnostic box/root with synthetic
canaries and the protected paired probe. Used target storage never hosts product
probes or dependencies. Original RpcSs/DcomLaunch companions are stopped only
through held objects after exact scope, owner, birth, critical-state and protected
signed-image checks. Anonymous Logon restrictions remain enabled. Child probes are
windowless. A bounded worker job/input/output and a 64-diagnostic retention quota
limit failures without introducing generic recursive deletion.

Offline requires the explicitly reviewed original-engine WFP prerequisite, BFE and
the driver feature flag. Product code never enables WFP globally, relaxes Windows
security or substitutes hooks-only enforcement. Controlled outgoing/incoming
IPv4/IPv6 TCP/UDP, interface-address traffic, DNS cache/egress, parent/child ICMP,
raw ICMP and SMB/mapped-drive probes have actual positive controls. ICMP uses exact
unique payload observations; machine-wide statistics are explicitly unattributed
and cannot decide containment. Ordinary users require broker refusal before ICMP
sending and a refused raw send without elevation. The pinned BITS COM class is
actually refused with E_ACCESSDENIED; host COM activation occurs only in the clean
lab positive control. Online TCP availability retries only the fixed controlled
endpoint within a bounded window; offline keeps one attempt and independent
observations reject any target-caused traffic.

Cached verification binds actual Windows kernel/product/architecture, original
engine, manager and every probe binary. Updates invalidate it. Every returned
Verified record is reconciled against current native state. No configuration
readback, synthetic fixture result or stale frontend response is treated as an
independent containment oracle.

See [policy contract](../POLICY_PROVISIONING.md), [helper decision](../HELPER_DECISION.md)
and [IPC contract](../IPC_CONTRACT.md). Main implementation files are
`crates/sandboxie-adapter/src/policy.rs`, `provision.rs`, `windows/provisioning.rs`
and its bounded network/alias modules; `src-tauri/src/policies.rs` and
`ui/policies.tsx`. Lab probes, interruption/metadata/boxed/session fixtures and
strict evidence retention are under `tools/`; they are not installed product
helpers or a general user-target launcher.

## Native verification

P05 [run 38648135812](https://github.com/kurasis/SecureRun/actions/runs/38648135812),
P03 [run 38649287239](https://github.com/kurasis/SecureRun/actions/runs/38649287239),
and P04 [run 38649290153](https://github.com/kurasis/SecureRun/actions/runs/38649290153)
execute the same source commit above.

| Check | Server 2025 x64 | Windows 11 ARM64 |
|---|---:|---:|
| P05 adapter tests | 28 passed | 28 passed |
| P05 applicable native scenarios | 45 passed | 45 passed |
| Required failed / blocked / skipped | 0 | 0 |
| Different-administrator UAC route | 1 Not applicable | 1 Not applicable |
| Fresh probe architectures | x64, genuine x86 | ARM64, emulated x86/x64 |
| Actual ordinary-user architecture receipts | 2 | 3 |
| Real interruption checkpoints | 7 passed | 7 passed |
| P03 foundation / normal / UI / command cases | 19 / 2 / 3 / 23 passed | 19 / 2 / 3 / 23 passed |
| P04 adapter / observation cases | 28 / 19 passed | 28 / 19 passed |
| Production user-target launches / helpers | 0 / 0 | 0 / 0 |

Original Plus 1.18.6/core 5.73.6/ABI 0x57230, pinned source
`cdba7096240b93d79c5373aa81a75a1c5c71b883`; OS builds 26100/26200; manager PE
8664/aa64. Rust 1.90.0, Node 24.19.0 and frozen locks are retained. No boot,
Defender, firewall, certificate, TLS, signing or logon policy is relaxed.
Binary hashes, actual architecture reports, minimized outcomes and raw byte
checksums are retained in the [P05 manifest](../evidence/p05/manifest.json) and
current P03/P04 manifests. Every original specification document is unchanged.

| Required scope | Actual production-path phase checks |
|---|---|
| T08–T11, T31 | File write/delete and registry virtualization; Block/Read only; ordinary host reads; host unchanged |
| T09, T35, T59 | Metadata/root denials; case/short/junction aliases; actual second-user ACL denial; unsafe grants refused |
| T12–T13, T39–T40 | Offline and online sockets/incoming/DNS/raw/ICMP/child/interface; share denial; BITS refusal; WFP-loss invalidation |
| T14–T15 | Paid profiles refused; accepted engine writes without independent proof stay conflicted |
| T16–T17, T53 | Running/current-other-session mutation refusal; immutable idempotency; stale revisions/drift; supported path family |
| T18 | Seven actual standard-user worker kill/restart checkpoints; no automatic replay |
| T27, T47, T58 | Real boxed manager/worker and forged-parent refusal; no privileged dispatch/host escape |
| T37 | Grammar/password/unknown-template refusal; no password transport or unreviewed values in diagnostics |
| T38 | Populated overlay, explicit acknowledgement, host view and preserved overlay reversal |
| T51 | Actual executable shadow remains in used storage; product diagnostics use fresh independent roots |
| T52 | Not applicable: no product elevation or different-administrator UAC route exists |
| T55, T57 | PendingRoot/identity/ACL binding; same-path replacement and forged foreign-root/mandatory metadata refusal |
| T60 | Running/all-session rollout deferred without new storage; old-box access to a newly created sibling denied |

Portable checks: 19 foundation tests, 25 adapter tests, 8 tooling tests, 3 UI tests,
frontend build, formatting, repository validator and strict portable/Windows MSVC
metadata Clippy pass. Linux Windows metadata checks use host SQLite declarations
only for type/lint validation; actual Actions builds use bundled SQLite and real
Windows executables. Commands include `cargo test --locked`, strict Clippy,
`npm test`, `npm run build`, repository/tooling validation and
`tools/lab/Invoke-P03.ps1`, `Invoke-P04.ps1`, `Invoke-P05.ps1` on both native hosts.

## Investigation, limits and handoff

Earlier failed/partial reports remain immutable in the manifest. Source review
and actual failures corrected NT/DOS effective paths, ordered default inheritance,
SystemDrive scrubbing, DNS EDNS/API address layout, interface UDP binding, Win32
stdcall/basic exports, ConfigLevel migration, restricted service tokens, private
held-object cleanup, ICMP attribution and bounded online availability. Standard
profile receipts exposed cleanup uncertainty; child probes now avoid console
creation instead of expanding termination authority. Those failed runs are not
passing phase or production acceptance evidence.

No elevated product helper is needed; boxed-caller, spoofing, metadata authority
and ordinary-user ACL tests remain applicable and passed. Only the absent
administrative UAC route is excluded. The Server/ARM laboratories do not declare a
Windows 11 x64 production tuple or certify the final release. Full application,
transfer/lifecycle, stress and release matrices remain in P06–P12. Retained fresh
diagnostics stay disabled and quota-bound until lifecycle work defines cleanup.
All T01–T66 final acceptance entries remain NOT_STARTED. Next eligible phase: P06;
it is not implemented by this request.

All project source, Markdown and reviewed JSON are published by
[PR #6](https://github.com/kurasis/SecureRun/pull/6) under the owner's standing
push/normal-merge authorization; credentials, private paths, raw target arguments
and generated binaries remain excluded.


## Historical P06 dependency regression

Runtime `c8d135da5ce403148e3e903036951ab9c947d8c1`,
[run 38705482872](https://github.com/kurasis/SecureRun/actions/runs/38705482872),
passed both owner-selected targets: 31 adapter tests and all 45 applicable native
policy/provisioning cases; zero failed/blocked/skipped, with one accurately
Not applicable absent different-administrator UAC route per target. Seven real
interruption checkpoints and ordinary-user/security-boundary reports pass.
The private diagnostic Stop confirms completion by waiting on the same retained
object, including natural exit racing termination dispatch; a live/incomplete
object remains refused. Root/owner/membership and original-helper guards are
unchanged. Minimized historical failures remain retained; no case was excluded.
[Current evidence](../evidence/p05/manifest.json) binds this same runtime as P03,
P04 and P06. This regression executes the policy protocol; production application
launch and scoped Stop are independently verified by P06.


## Current P07 dependency regression

Runtime `bec50c8fa7d0b47c4f05aa6662eeeb24faa18f68` passes
[run 38730156869](https://github.com/kurasis/SecureRun/actions/runs/38730156869)
on Server 2025 x64 and Windows 11 ARM64. Each target passed 38 adapter tests and 45 applicable native policy/provisioning cases. One absent different-admin UAC route remains accurately Not applicable.
The [manifest](../evidence/p05/manifest.json) binds this same source as P03/P04/P05/P06/P07.
Earlier sections describe historical phase scope; P07 adds the separately verified
safe-file and boxed-reference services. Current status and the next eligible P08
are recorded in [the P07 report](P07_REPORT.md).

## P08 integration regression

The current P08 runtime `74d86db6dc883e692dfc04c8185eee790bdcf0a9` passed this phase on both owner-selected
laboratories in [run 38763825315](https://github.com/kurasis/SecureRun/actions/runs/38763825315): 48 adapter tests and 45 applicable native cases passed; one absent different-admin UAC route is Not applicable.
The [manifest](../evidence/p05/manifest.json) binds the current source and
original structured evidence; earlier results above remain historical.
