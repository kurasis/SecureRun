# Development status

Specification 1.3. Updated 2026-10-18 UTC. Current phase: **P11 fixes IN_PROGRESS; exit gate BLOCKED**.
P12 and all 66 final installed acceptance entries remain **NOT_STARTED**.

Checked native Save input, atomic session-ready publication and retained-object
fixture cleanup are implemented. Fresh P02 passed on both Windows targets at
0d2600c/run 39119550715 (Server 49, ARM 62; two N/A each), with complete signed
component inventories and strict OS tuples unchanged. P05 including the reporter
safeguards passed 45 native+62 adapter tests on both targets at
b1e2129 PR/run 39120204407, with one explicit N/A each.

Ordinary full P09 still passed Server but failed ARM while seeding environments
06 and 08. An unreviewed WerFault remained; the original exception/module is still
undetermined. All original success/failure bytes are retained separately.

[Debugger-only c594c8e/run 39122053169](evidence/p11/investigation-c594c8e-debug-passed/review.json)
passed 22 native+101 UI with 174 actually observed debugger connections, three
owner-scope refusals, no reporter and no original exception dump. Instrumented
success is excluded from phase closure and does not resolve ordinary failures.
[Native debugger calibration](evidence/p11/investigation-fd5fdcd-debug-preflight/review.json)
now also proves readable expected output, the exact synthetic exception dump and
privilege restoration; previous native parser failures remain failed.

[Original service-log calibration](evidence/p11/investigation-f6e1042-service-calibration/review.json)
passed on a separate ARM VM. The source-backed SbieSvc LogFile value is temporarily
set to a protected private path and its prior value/type restored. No Windows
security, WER, containment policy or signed-leader setting changes. Raw logs remain
private; only bounded fixed message IDs and source-shaped SXS status codes may be
retained, explicitly without target authentication. Full diagnosis without an
engine debugger failed at f6e1042/run 39126844625 in environment 04. The collector
restored its setting and reported SBIE2329×20, SBIE2224×1 and SBIE2204×2. These
messages do not establish the exception/module or a causal link.

The [cff58d4 follow-up/run 39129208572](evidence/p11/investigation-cff58d4-service-log-passed/review.json)
passed the full 22 native+101 UI checks and 10,000-file workload. No reporter was
observed; the collector completed and restored its prior registry value. It retained
112 public `NtCreateLowBoxToken` FFS warnings, two SBIE2312 messages, and no crash or
service-startup report. Thus the FFS warning alone does not establish the earlier
failure's cause. The successful diagnostic sample does not prove a correction or
close a phase. Its original 1.1844013497178307% idle CPU deviation is retained;
diagnostic timing cannot certify performance. No blind repeat is planned without
a concrete new finding or correction.

The next experiment uses the original source-backed in-process crash filter in
separate disposable original-engine scopes. Production correctly rejects the
`EnableMiniDump` setting; that allowlist and all manager assertions stay intact.
A native synthetic exception control must prove the original filter and dump
parser before a bounded 24 fresh-scope ARM64/x86/emulated-x64 parent/child test.
It is an isolated reproduction experiment, not full P09 or phase proof. No
debugger, WER/security change, global Sandboxie setting or original binary patch
is involved. Only reviewed exception/module metadata may be uploaded. Native
control at 264d96f/run 39135251485 passed: the exact synthetic `e0424242` exception
and KERNELBASE module/RVA were read from an actual original-filter ARM64 dump;
the prior LogFile value was restored. The owner cancelled the reproduction before
dispatch; it is **NOT_RUN**, with no success inferred. At the owner's
request, dispatch uses one VM with calibration first, eight rounds across all
three architectures, no automatic repeat and no duplicate full UI run. This
smaller diagnostic sample changes no mandatory phase workload or exit gate.
No new Actions run is scheduled. Further analysis currently uses retained evidence
and pinned source only. New Windows test targets require both a disposable VM and
a Sandboxie box; mandatory unboxed controls are pending where incompatible.

Retained observer traces contain four original `SandboxieRpcSs.exe` faults: 3 of
393 RpcSs starts under x86/emulated-x64 policy probes, 0 of 197 under ARM64 probes,
and one product 7-Zip launch. Each fault occurred about 220 ms after RpcSs start and
before DcomLaunch. At roughly 0.5-0.8% per start, the cancelled 24-pair sample would
usually miss it. On 2026-10-18 the owner authorized one bounded single-VM stress
reproduction instead: up to 200 rounds of fresh ARM64/x64/x86 scopes (600 starts,
40-minute budget) with the calibrated original crash filter, parent and child both
requesting COM. It is diagnostic only and closes no gate.

[Static ARM source review](P11_ARM_SOURCE_REVIEW.md) confirms the known 1.15.5 ARM
fixes remain in pinned 1.18.8. No newer core fix was found at checked upstream
tip 596bfa8. Three retained reporter observations overlap emulated probes, but an
additional archive timeout used the ARM64 7-Zip distribution; a universal
emulation-only cause is not established. Original exception/module remain unknown.
No new Actions or test program was started for this review.

Current matching full P10 and installed P11 proof remain pending. PR #12 is draft;
normal merge requires the actual gates. Code, reports and reviewed evidence are
published as authorized; credentials, private logs/dumps and generated binaries
are excluded from Git.

| Phase | Current source validation | Evidence |
|---|---|---|
| P01 | DONE | [Report](phases/P01_REPORT.md) |
| P02 | DONE | 0d2600c/run 39119550715: Server 49, ARM 62 passed; two N/A each |
| P03 | BLOCKED revalidation | Applicable native jobs passed; full integrated retainer pending |
| P04 | BLOCKED revalidation | Applicable native jobs passed; full integrated retainer pending |
| P05 | BLOCKED revalidation | b1e2129 PR/run 39120204407 passed 45+62 per target; matching full integration pending |
| P06 | BLOCKED revalidation | Full-matrix jobs passed; separate PR rapid-cycle failure retained |
| P07 | BLOCKED revalidation | Applicable native jobs passed; full integrated retainer pending |
| P08 | BLOCKED revalidation | Applicable native jobs passed; full integrated retainer pending |
| P09 | BLOCKED revalidation | fa29a20/run 39109839082 passed 22+101 per target; intermittent ARM reporter fault remains |
| P10 | BLOCKED | Full current exact-source integration did not pass |
| P11 | BLOCKED by P10 | 28 installed+81 production tests passed per target; [report](phases/P11_REPORT.md) |
| P12 | NOT_STARTED | All 66 final installed T01–T66 acceptance entries remain unrun |

P03–P10 implementations and historical successful proof are retained. Their current
revalidation is blocked after the engine/runtime security refresh; this does not
mean the successful individual native jobs were failed or the implementations removed.
Strict retainers are unchanged and will not promote individual-job proof from a
failed full integration run into a completed phase gate.

Installed source: `dd447fec88de966fa839b03fc0fd4eb6b41776a4`,
[successful P11 run 39089078904](https://github.com/kurasis/SecureRun/actions/runs/39089078904).
Both Server 2025 x64/build 26100 and Windows 11 ARM64/build 26200 passed **28/28 actual
installed cases and 81 production tests (1+18+62)**. All 47 original installed JSON
reports are retained; four downloaded baseline/candidate EXEs match original
size/SHA256 reports. See [test matrix](P11_TEST_REPORT.md) and
[development artifacts/checksums](DEVELOPMENT_ARTIFACTS.md).

Historical integration source: `ffdaeb60bd8c9d707959435b910c6a1027ecb770`,
[run 39087328157](https://github.com/kurasis/SecureRun/actions/runs/39087328157).
All 155 protected runtime/workflow/lab files are byte-identical at the packaging-only
descendant. Portable and all 12 P03–P08 native jobs passed; their 218 original JSON
reports are retained as [partial proof](evidence/p11/investigation-ffdaeb6-partial-integration/review.json).

Attempt 1 ARM P09 refused DIAGNOSTIC_SYSTEM_IMAGE_UNREVIEWED during environment 09;
unknown WerFault remained alive after the unchanged 60000 ms natural wait. One controlled
unchanged-source repeat reproduced it at environment 05. Read-only diagnostics found
no surviving target or fixed-component WER report/event; cause remains undetermined.
No third blind repeat is planned. Diagnostic cleanup granted no stop authority to reporters; no unknown window was hidden and no scenario, workload, assertion, timeout or source list was reduced.

Server attempt 1 passed 21/22 native and 101 UI checks, but actual Firefox about:support
observation failed clipboard-busy. Its controlled repeat passed 20 native and 93 UI
checks but failed actual diagnostic Save filename readback before Save confirmation.
The repeat did observe Firefox effective content sandbox level 9, without disabling
security; this does not erase the failed first observation. Full integration is
**failure: 13 successful jobs and 2 failed P09 jobs**.
Supplementary PR P09 passed Server 22+101 but failed ARM environment 08; separate PR
P06 failed rapid-cycle engine dispatch and subsequent uncertain-state assertions.
Original success/failure bytes remain separate; no blanket reproducibility is claimed.

Original Plus 1.18.8/core 5.73.8/ABI0x57230 is separately installed,
source `bde0890108a563f5d72eb8e57085be2b37177218`. Authenticated P02 refresh passed
49 Server/62 ARM checks with two explicit N/A items each (optional native event
stream; privileged helper). Actual x86 and ARM emulated-x64 probes are included.
OS UBR/type/base and engine pins remain strict. See [manual security refresh](P11_ENGINE_UPDATE.md).

Artifacts are **UNSIGNED DEVELOPMENT ONLY**. Original-manager licensing is not
selected; Windows 11 x64 installed production release is not certified. No engine,
persistent elevated helper or silent updater is bundled. Server tests actual
missing-WebView2 installation; ARM preserves its OS-preinstalled signed runtime.
All 26 original specification files remain byte-for-byte unchanged; Windows security,
TLS, original signatures/hashes and browser sandbox settings remain enabled.

Repository validator and all 31 Python tooling/gate tests passed. Generated binaries,
credentials, raw paths, arguments and private inventories remain excluded from Git.
All project Markdown and reviewed structured evidence are published as authorized.
PR #12 remains draft; normal merge requires completing the actual gate, not bypassing it.

Continue **P11 dependency diagnosis/correction**, then repeat complete exact-source
integration and matching installed proof. P12 is not started. See
[release blockers](RELEASE_BLOCKERS.md), [build](BUILD.md), [install](INSTALL.md),
[retention](UPGRADE_AND_UNINSTALL.md) and [signing](SIGNING.md).
