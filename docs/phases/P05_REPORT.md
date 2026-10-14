# P05 — policy and safe provisioning report

Status: IN_PROGRESS. Dependencies: historical P04 observation gate and P02 routes.
Current P03/P04 runtime evidence is explicitly stale during implementation.

The constrained Standard policy compiler, durable SQLite intent journal, user-level
NT-relative root creation and native diagnostic path are under validation. No
production user-target launcher, elevation helper, global mutation or raw INI
editor is exposed. Every native outcome remains provisional until both Windows
laboratories finish, reviewed structured evidence is retained, and current
P03/P04 regression succeeds on the same runtime source.

The implemented English/Russian editor uses native path-picker tokens, displays
desired/current configurations and revision conflicts, expires old observations,
and requires explicit acknowledgement before a Read only repair. The compiler
supports schema 1 Standard offline/online and a bounded path-rule family. The
native service derives owner/profile/root authority from Windows, creates roots
with their protected DACL supplied at creation, checks file/volume identity and
pins original SDK/template/injected-library bytes. All old siblings must be
stopped and reconciled before a new root is materialized.

SQLite records immutable operation signatures and partial mutation stages.
Duplicate requests do not redispatch, stale revisions fail, and restart recovery
leaves incomplete work in an inspect-only conflict. A CI-only checkpoint feature
parks after durable commits; the lab kills the actual held worker and restores
the exact normal binary before testing recovery. It is absent from normal builds.
The production route uses the original user's token and no UAC/helper route.

See the [policy contract](../POLICY_PROVISIONING.md) and
[helper decision](../HELPER_DECISION.md). No target launcher is introduced in P05.

## Investigation and actual checks

The first six native iterations exposed incorrect effective-path handling,
reviewed default-template inheritance, raw template-metadata enumeration, and
diagnostic initialization failure. These were treated as failures, not passing
configuration readback. SDK behavior is reviewed against the pinned upstream
commit. Original NT-to-DOS translation and the complete pinned inheritance
fingerprint now distinguish driver observations from unexpanded INI data.

Run [38613754577](https://github.com/kurasis/SecureRun/actions/runs/38613754577),
source `6cfbe442e7a6cca217d88d19077c32b4d221c012`, retained the numeric diagnostic
exit status `ffffffff`. Original `File_InitUsers` expands ProfileList paths using
`%SystemDrive%`; the minimized worker environment omitted that OS-derived value.
The correction derives SystemDrive from `GetSystemDirectoryW` and keeps inherited
credentials removed. The next run reached a different prerequisite failure.

Run [38615378604](https://github.com/kurasis/SecureRun/actions/runs/38615378604),
source `dbf3206e3dec25e56fc4e30b4fc0bb21b5f422b9`, passed 27 native adapter/unit
checks on Server. Its controlled host DNS positive control failed before target
dispatch. Consequently provisioning, standard-user verification and interruption
coverage did not pass. The [failed structured reports](../evidence/p05/manifest.json)
preserve that result and source instead of implying a completed phase. Subsequent
work accepts Windows EDNS OPT records, adds exact DNS status diagnostics, and
records native reasons when a journal checkpoint is not reached.

Current local checks pass 25 portable adapter tests, strict portable and Windows
MSVC metadata Clippy, the TypeScript/UI build, 3 UI state tests, the repository
validator and 8 tooling tests. Linux Windows metadata checks use host SQLite
declarations for type/lint checking only; they are not Windows executable proof.
The real Actions jobs build bundled SQLite and run actual native binaries.

Run [38635235915](https://github.com/kurasis/SecureRun/actions/runs/38635235915),
source `7050529a2a41ed7c723fd8d6a0ba9ee11c9c27cd`, identifies the remaining
diagnostic companion as SandboxieDcomLaunch.exe in the installed engine directory.
The pinned original `apps/com/DcomLaunch/dcomlaunch.c` and `apps/com/common.h`
implement this service alongside RpcSs. Private diagnostic shutdown now accepts
only these two exact installed paths, with protected ACLs and Authenticode checks,
held process birth, driver-owned box SID and immediate membership revalidation.
The original restricted anonymous primary token remains enabled. Six actual
kill/restart checkpoints already pass in failed runs; the Fenced checkpoint still
depends on successful initial provisioning. These partial results do not close
the native gate.

The lab now builds actual x86 probes alongside the native binary, plus emulated
x64 probes on ARM. Each architecture gets a fresh diagnostic box. Controlled
checks include IPv4/IPv6 TCP/UDP, DNS API/broker requests with distinct cached
answers, ICMP with an independent host counter, a synthetic SMB share and mapped
drive, a local network-interface address and a genuine child process. The share
and drive are disposable host fixtures; the product never creates shares or
changes resolver/firewall settings. This implementation still requires successful
native evidence before any containment claim is made.

## Required scenario scope

| Scenarios | Implemented coverage / outstanding native work |
|---|---|
| T08–T11, T31 | Fixed benign file/registry canaries and host visibility; native pass and reviewed reports pending |
| T09, T35, T59 | Mandatory metadata/root denials, second standard-user ACL checks and rejected grant aliases; full mandatory alias/descendant proof pending |
| T12–T13, T39–T40 | Controlled sockets/DNS/ICMP/share/interface/child checks and WFP-loss invalidation; positive controls and both-platform proof pending |
| T14–T15 | Paid profiles rejected; accepted writes without enforcement remain unverified; native failure case and complete labels pending |
| T16–T17, T53 | Stopped mutation, revision/current-fingerprint drift, unknown inheritance and reusable path family; native pass pending |
| T18 | Portable recovery across seven stages passes; six actual Windows checkpoints pass, Fenced baseline and complete both-platform gate pending |
| T27, T47, T58 | No helper exists; applicable boxed manager/worker and OS caller-identity production tests remain required |
| T37 | Literal grammar, password/global/template rejection and minimized records; native password and injection cases pending |
| T38 | Read only acknowledgement implemented; populated-overlay host view and reversal proof pending |
| T51 | Fresh throwaway diagnostics implemented; malicious-shadow and dependency proof pending |
| T52 | Different-administrator UAC route is Not applicable because the product has no elevation/helper route |
| T55, T57 | PendingRoot/OS-derived authority and forged-metadata portable refusal; real substitution/interruption proof pending |
| T60 | Stop-before-rollout and explicit future-root rules implemented; native running/all-session and future-sibling access proof pending |

P03/P04 evidence remains historical and checksum-preserved. Both complete native
regressions must be rerun on the final P05 runtime source and rebound before P05
can be DONE. Full phase scenarios, policy/effective reports and reviewed evidence
retention are still being completed. P06 is not eligible. All final T01–T66
acceptance entries remain NOT_STARTED; these phase checks are not release acceptance.
