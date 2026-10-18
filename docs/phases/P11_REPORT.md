# P11 — Packaging, upgrades, signing and retention

Status: **Fixes IN_PROGRESS; gate BLOCKED**. P12 and all 66 final installed
acceptance entries remain **NOT_STARTED**.

Native Save uses checked foreground/owner-bound SendInput with unchanged exact
filename readback, one confirmation and saved-byte equality. Session readiness is
published only after complete JSON is written and atomically moved into place.
Fixture teardown skips only confirmed completion of the same retained object;
live ownership/birth/session/critical mismatches remain refused.


Latest diagnostic at 0d2600c/run 39119544472 failed in environment 09: 135 authenticated ProcDump requests exited 0 without a dump. Actual debugger attachment was not observed by that collector; these exits are not proof of fault-free execution. [Original diagnosis](../evidence/p11/investigation-0d2600c-debug/review.json) retains zero query/pin/scope errors and the live reporter association. The new diagnostic adds read-only actual debugger-presence checks, fixed-state/exception-code parsing without raw output, and an own native synthetic exception preflight. Full engine workload runs only after the preflight proves attachment and the exact expected exception dump. The full uninstrumented PR run 39119547942 separately passed Server 22+101 but failed ARM environment 06; [both original outcomes](../evidence/p11/investigation-0d2600c-pr-p09/review.json) are retained.

The [b1e2129 P05 snapshot](../evidence/p11/investigation-b1e2129-policy-passed/review.json) passed 45 native+62 adapter tests on each target, with one explicit N/A. The actual tested P05Lab source is byte-identical to current and includes reporter safeguards. The [7d77cd4 native preflight failure](../evidence/p11/investigation-7d77cd4-preflight/review.json) occurred before monitor launch because of the reserved Home parameter. c594c8e corrects it and adds an actual invocation regression; its native synthetic debugger/expected exception-dump preflight passed. Full original-engine diagnosis run 39122053169 remains in progress. These are individual/diagnostic facts, not P10/P11 closure.

The [c594c8e debugger-only run](../evidence/p11/investigation-c594c8e-debug-passed/review.json) passed 22 native+101 UI with 174 actually observed debugger connections, three owner-scope refusals, zero reporters and no original exception dump. This does not resolve the [separate ordinary b1e2129 ARM failure](../evidence/p11/investigation-b1e2129-pr-p09-arm/review.json) in environment 08. The next diagnostic uses the original SbieSvc private LogFile feature without attaching a debugger to the engine. A short independent native calibration must pass first. The signed-leader GetMessage restriction is preserved. Only the source-backed diagnostic LogFile registry value is temporarily changed and restored; Windows security, WER and containment policy are unchanged. Raw logs stay in an administrator/SYSTEM-only directory, and only fixed message IDs/source-shaped SXS status codes may be uploaded. Every such workflow remains excluded from phase closure.

| Source/run | Actual result | Scope |
|---|---|---|
| 0d2600c / 39119550715 | Server 49, ARM 62 passed; two explicit N/A each | Current P02 includes lab reporter safeguards |
| fdad6d7 / 39110907921 | Server 49, ARM 62 passed; two explicit N/A each | Historical original P02 inventories retained |
| fdad6d7 / 39111146590 | 45 native+62 adapter passed per target | [Actual session and teardown fixes](../evidence/p11/investigation-fdad6d7-policy-passed/review.json) |
| fa29a20 / 39109839082 | 22 native+101 UI passed per target | [Full uninstrumented snapshot](../evidence/p11/investigation-fa29a20-product-passed/review.json); real Save passed |
| 96483f3 / 39111501581 | Failed environment01; live RpcSs-named target birth matched | [Early reporter association](../evidence/p11/investigation-96483f3-observer/review.json), no original exception/module |
| 96483f3 PR / 39111504301 | ARM failed environment10; Server job succeeded | [Separate original failure](../evidence/p11/investigation-96483f3-pr-p09/review.json) |
| f374409 / 39113908733 | 21 native+101 UI passed; archive exit timed out | [Live metadata diagnosis](../evidence/p11/investigation-f374409-observer/review.json), no capacity/query failure |

Separately, [f374409 PR control/lifecycle originals](../evidence/p11/investigation-f374409-pr-control-lifecycle/review.json) retain ARM P06 (21 passed, one failed) and P08 (32 passed, six failed). Both first refusals were `DIAGNOSTIC_SYSTEM_IMAGE_UNREVIEWED`; the later P08 refusals were `OWNERSHIP_NOT_FOUND`. Both Server jobs succeeded. This is additional failed proof, with no source-equivalence or root-exception claim.

Server startup of 3477.3973 ms exceeded 3000 ms and ARM idle CPU of 1.2673191570845006%
exceeded <1% in the successful fa29a20 sample; other budgets met. Original
measurements and user-impact explanations remain unchanged. Successful snapshots
do not erase same-source failures or establish reporter-fault resolution.

The f374409 observer recorded 1028 known lifetimes and 1 reporter. Four live reads
found 4 plain roots and 0 candidate WER files; 1 existing channel was enabled but no
matching exception/module was obtained. Both RpcSs-named target and reporter were
eventually observed exit 4f; this is not the original exception and alone does not
identify the termination dispatcher. Reporter presence now causes a conservative
lab refusal before cleanup. Such refusal fails the case/run, preserves an earlier
failure, and never becomes successful Stop evidence. The product's normal Stop
ownership contract is unchanged; no name becomes process authority.

The next diagnostic uses original Microsoft ARM64 ProcDump, pinned by HTTPS ZIP
and payload SHA256/size plus valid Microsoft Authenticode. Its code and private
dump directories allow Administrators/SYSTEM only. Before the test actor exists,
the observer leases and authenticates the pinned original engine installer,
extracted/installed RpcSs match and compatibility-pinned driver API library.
Debug requests additionally require the exact protected image, noncritical live
kernel object, matching retained birth, original-driver owner/box/session and
managed marker, and the dedicated current synthetic account. No reporter or
unknown image is debugged or terminated; no target launch is replayed.

The observer temporarily enables only its already granted SeDebugPrivilege in its own disposable token for authenticated-target read-only debugger queries, then restores the prior state. This grants no new privilege and edits no machine policy. The synthetic preflight records restoration; failure aborts the engine workload.

The diagnostic workflow is dispatched explicitly so routine source/evidence pushes do not repeat the instrumented full workload. Required phase workflows retain their existing triggers. Tool pipes are drained with constant storage and only bounded character counts are kept; raw tool output is never returned.

Debugger mode explicitly changes fault delivery/timing and **cannot close any
phase or certify performance**. Raw dumps and tool output stay private inside the
disposable VM and are never uploaded. The bounded dump parser verifies target ID
and emits only exception code, an allowlisted public module/RVA, architecture and
a private-source digest. It suppresses absolute addresses, paths, IDs, arguments
and unknown names. Tool monitors receive only scoped graceful console cancellation;
no debugger/debuggee is killed for cleanup. Windows security, TLS, signatures,
checksums, browser sandbox and WER configuration remain enabled/unchanged.

Local validation: repository validator, 31 Python tests, 63 Linux Rust tests (not native containment proof), PowerShell/CSharp syntax,
XML privacy/UTF8+UTF16 DTD rejection, actual zero-sample Start-Job transport,
synthetic filesystem traversal, dump bounds/target binding/privacy, and lab
reporter-stop refusal/healthy dispatch checks passed. Synthetic checks are not
Windows containment evidence. All original 26 specification files are unchanged.
The [startup transport failure](../evidence/p11/investigation-9a98713-startup/review.json)
and every previous failed snapshot remain retained without relabeling.

Current protected inputs require fresh complete matching P10 and installed P11
proof after the actual compatibility correction. P02 was refreshed at 0d2600c/run 39119550715: Server 49 and ARM 62 passed, with two explicit N/A each; complete signed component inventories and OS tuples were unchanged. Automatic normal merge remains conditional on
the real gates; no source inventory, assertion, workload or mandatory feature is
removed. The separately successful older installed package below is historical.

The packaging implementation and its installed gate passed; the phase dependency did not.
P12 and all final installed T01–T66 acceptance remain **NOT_STARTED**.

## Actual installed outputs

Package/build/lab source: `dd447fec88de966fa839b03fc0fd4eb6b41776a4`.
[P11 run 39089078904](https://github.com/kurasis/SecureRun/actions/runs/39089078904)
completed successfully on both Server 2025 x64/build 26100 and Windows 11 ARM64/build 26200.
Each passed **28/28 installed cases and 81 production tests (1 library +18 integration +62 adapter)**.
The normal release-profile manager has no CI features. All four downloaded baseline/candidate
installer sizes and SHA-256 values match the original native build reports.

The additive `packaging/` implementation provides native product 0.3.0 development
installers, candidate revision 0.3.0.11 and same-runtime baseline revision 0.3.0.10.
Code is installed only into fixed native Program Files. A bounded native guard
checks privileged owner/DACL, no-reparse ancestry/tree and parent deletion/replacement
rights. Its exact hash-verified bytes are embedded in setup and the generated
uninstaller; installed writable code is never used to bootstrap uninstall trust.
Actual ordinary-user modification and junction/writable-code installation attempts fail.

Original Microsoft WebView2/C++ prerequisites and Inno 6.7.3 are pinned by HTTPS,
SHA-256, size and valid original signatures. Server exercises actual missing-runtime
installation using Microsoft's official bootstrapper. Windows 11 ARM64 preserves
and exercises its OS-preinstalled Microsoft-signed runtime. A manually stripped
ARM missing-runtime installation is not claimed. Shared prerequisites remain on uninstall.

Installed checks include a real locked-code failed upgrade with unchanged payload,
version and profile; successful revision 10→11 upgrade with the same runtime/schema 1;
older-package refusal; future/foreign database refusal with unchanged bytes; actual
production initial-migration transaction rollback; retained-data uninstall that removes
all owned payload/registration; and same-account reinstall with ownership/root
reconciliation and actual boxed launch. No schema 1→2 migration is invented and no
profile migration is performed as administrator.

Installed T01 smoke uses a stopped original service and a real registered target.
Missing-engine and unhealthy-driver installed variants remain final P12 scope.
T02 uses both a changed original component and a working native fake Start.exe
positive control in PATH/CWD at seed/upgrade/reinstall. It is a lab-only fixture,
never shipped. T05 proves real boxed targets with no host fallback. T12 retains
original installed parent/child/live-server probe observations tied to each actual
native/x86/emulated-x64 probe hash. Normal import/export is correctly tagged T21.
Actual boxed GUI exits 78; all four worker families reject a valid claimed host parent.
No persistent privileged product helper exists: helper enrollment/scope-record and
different-account helper UAC portions of T27/T47/T52/T57 are N/A. Applicable installed
context/ownership paths remain tested; no helper-only exclusion waives them.

Each actual target inventory contains 266 Cargo/npm/Microsoft SDK/Rust standard-library/
SQLite components, with original notices and source/license hashes. Build instructions
record actual Rust 1.90.0, Node 24.19.0/npm 11.17.0, MSVC 14.51.36231 and SDK 10.0.26100.0.
The installer and original manager components remain **UNSIGNED DEVELOPMENT ONLY**.
Organizational Authenticode with a non-exportable protected key and RFC3161 timestamp
is documented for production; no trust root/key is installed or invented. The owner
has not selected an original-manager license. Windows 11 x64 installed release is not certified.

Outputs: [BUILD](../BUILD.md), [INSTALL](../INSTALL.md),
[UPGRADE_AND_UNINSTALL](../UPGRADE_AND_UNINSTALL.md), [SIGNING](../SIGNING.md),
[LICENSE_INVENTORY](../LICENSE_INVENTORY.md), [28-case matrix](../P11_TEST_REPORT.md),
[downloads/checksums](../DEVELOPMENT_ARTIFACTS.md),
[downloaded-byte verification](../evidence/p11/installer-download-verification.json),
[compatibility manifest](../../packaging/compatibility.json) and
[hash-bound evidence](../evidence/p11/manifest.json).

## Historical security refresh and blocked integration

Original Plus 1.18.8/core 5.73.8/ABI0x57230, source
`bde0890108a563f5d72eb8e57085be2b37177218`, was manually authenticated after the
publisher's GUI-proxy MapWindowPoints request-buffer security fix. P02 run 39086050127
at source fa9b89f passed Server 49 and ARM 62 checks, with two explicit N/A items per
target (optional access-event stream; elevated helper). All installed components,
complete cleanup DLL graph and ABI remain bound to original signed publisher bytes.
This is not a product updater or proof that the reporter fault was fixed.
See [manual engine review](../P11_ENGINE_UPDATE.md).

Runtime diagnostic cleanup now authenticates every remaining image, including
same-owner tokens. Only the two exact protected signed original RPC companions
may be stopped after driver/birth/box/owner/session checks; benign canaries are
already completed. Unknown held objects receive only the original 60000 ms natural
completion wait, after independently authorized stops. That diagnostic cleanup route grants no stop authority to WerFault or unknown images. Protected OS UBR is included in verification
identity and the immutable compiled launch tuple; an OS revision change invalidates
cached proof. The first new-tuple mismatch failed closed and was corrected without
accepting an unreviewed OS. Both installed T05 paths passed with this correction.

Historical full integration source: `ffdaeb60bd8c9d707959435b910c6a1027ecb770`,
[run 39087328157](https://github.com/kurasis/SecureRun/actions/runs/39087328157).
All 155 protected runtime/workflow/lab inputs are byte-identical at the packaging-only
descendant dd447fe. None was removed to reuse old proof. Portable and all 12 P03–P08
native jobs passed; their 218 original JSON reports are retained as
[partial individual-job evidence](../evidence/p11/investigation-ffdaeb6-partial-integration/review.json).
Strict retainers require a successful full run, so current P03–P10 manifests remain BLOCKED.

Attempt 1 ARM P09 refused DIAGNOSTIC_SYSTEM_IMAGE_UNREVIEWED while seeding environment 09:
an unreviewed WerFault remained live after 60000 ms. Read-only metadata found no surviving
CIM target and no fixed-component WER report/event. Server passed 21/22 native and 101/101
UI checks but actual about:support observation failed P09_CLIPBOARD_BUSY; no effective
browser sandbox level was obtained or inferred. Both
[ARM](../evidence/p11/investigation-ffdaeb6-arm-p09-attempt-1/review.json) and
[Server](../evidence/p11/investigation-ffdaeb6-server-p09-attempt-1/review.json)
original failures remain intact.

One controlled unchanged-source repeat of only the two failed P09 jobs reproduced
the ARM refusal at environment 05. Its [original second failure](../evidence/p11/investigation-ffdaeb6-arm-p09-attempt-2/review.json)
is retained. Server's repeat passed 20 native and 93 UI checks but failed actual
diagnostic Save at VERIFYING_NATIVE_SAVE_FILENAME, before confirming Save. Its
[second original failure](../evidence/p11/investigation-ffdaeb6-server-p09-attempt-2/review.json)
is retained. Actual about:support raw-copy observation passed with effective
sandbox level 9 in this attempt; that does not erase the first clipboard failure.
Full integration finished **failure: 13 successful jobs, 2 failed P09 jobs**.
The reporter/initial dispatch causes remain undetermined. No third blind repeat is planned, no assertion,
workload, timeout or process authority changed, and no failed result became a pass.

Additional automatic PR checks at the same 155 protected inputs are supplementary:
[P09](../evidence/p11/investigation-d73e352-pr-p09/review.json) passed Server 22+101 but
ARM refused unknown-reporter cleanup at environment 08. Separate
[P06](../evidence/p11/investigation-dd447fe-pr-p06/review.json) passed 18 native cases,
then failed rapid-cycle launch with ENGINE_DISPATCH_REFUSED and later CWD/revision
assertions after an uncertain receipt. The label OLD_REVISION_DISPATCHED alone
does not establish dispatch; that raw report omits the actual receipt at the assertion.
Production checks unresolved launch state before revision conflict. Initial refusal
cause remains undetermined; no reconciliation/replay is silently added. Full mandatory
P06 separately passed both targets, but the duplicate failure remains failed.

Earlier retained investigations document original packaging fixture/reporter failures,
unknown-process refusals, the f26e6a3 strict-tuple mismatch and d73e352 lab fixture
relative-path failure. Original statuses remain unchanged; later installed successes
do not establish a fix for the reporter's fault cause. All are hash-bound by the manifest.

## Historical validation and current continuation

Actual commands: `packaging/Invoke-P11.ps1`, locked native Cargo production tests,
full P10 Actions matrix and `python tools/lab/validate_repository.py`. The earlier 29 Python tests passed; the current expanded set of 31 tests also passed as recorded above. All 26 original specification files remain byte-for-byte unchanged. Reviewed
original evidence is published without generated binaries, credentials, raw paths,
arguments or private inventories. Development EXEs remain expiring Actions artifacts.

The packaging implementation preserves its tested boundaries and retained data,
but **P11 is not DONE while its required P10 dependency is blocked**. Continue P11
with actual diagnosis/correction of reproducible ARM diagnostic cleanup and uncertain
launch/observation failures, then obtain fresh complete exact-source integration
and matching installed proof. Do not reduce workloads, trust/kill reporters, hide
unknown windows or manufacture a successful gate. P12 is not started or authorized
by this phase report. Production signing/licensing remain explicit release prerequisites.


## Source-backed original service logging diagnosis

This CI-only mode temporarily sets the existing `HKLM\SYSTEM\CurrentControlSet\Services\SbieSvc` `LogFile` value to version `1;` followed by an administrator/SYSTEM-only private log path. It preserves/restores the previous value and type, refuses concurrent changes, and restores immediately on collector failure. It changes no global sandbox policy, Windows protection, WER configuration or signed-leader registration. It never requests engine debugger attachment or memory dumps.

The original authenticated service performs its normal message collection and file writing. The wrapper uses only the pinned native `SbieApi_LogMsgEx(ULONG, ULONG, const WCHAR*, USHORT)` to send one explicitly synthetic calibration message before a test actor exists. This does not call the restricted GetMessage interface. A separate short native VM must prove delivery, the known message prefix, private parsing and restoration before the full workload is dispatched on a fresh VM. Raw UTF16 logs and secondary private log files are excluded from upload; only bounded fixed message counts and source-shaped RPCSS_SXS level/status pairs are retained, explicitly without target authentication. Repeated statuses are counted together so normal workloads cannot exhaust a per-event list.

The publisher source is fixed at `bde0890108a563f5d72eb8e57085be2b37177218`:

- [Service registry path and access](https://github.com/sandboxie-plus/Sandboxie/blob/bde0890108a563f5d72eb8e57085be2b37177218/Sandboxie/core/dll/support.c#L257).
- [LogFile version/path format and original writer](https://github.com/sandboxie-plus/Sandboxie/blob/bde0890108a563f5d72eb8e57085be2b37177218/Sandboxie/core/svc/DriverAssistLog.cpp#L142).
- [Native logging API signature](https://github.com/sandboxie-plus/Sandboxie/blob/bde0890108a563f5d72eb8e57085be2b37177218/Sandboxie/core/dll/sbieapi.h#L87).
- [Fixed RPCSS_SXS level/status formatter](https://github.com/sandboxie-plus/Sandboxie/blob/bde0890108a563f5d72eb8e57085be2b37177218/Sandboxie/apps/com/RpcSs/sxs.c#L144).

Local parser, incremental UTF16/BOM/partial-line, private-field suppression and PowerShell/CSharp checks pass. Native original-service calibration and the subsequent full no-debugger diagnosis are pending; neither can close P09/P10/P11. The existing debugger workflow also has a preflight-only option and now requires recognizable control output after NUL-tolerant parsing, in addition to independently verified debugger presence and the exact expected synthetic exception dump.


Native follow-up: [original service calibration](../evidence/p11/investigation-f6e1042-service-calibration/review.json) passed, including pre-actor delivery and registry restoration. [f6e1042 debugger preflight](../evidence/p11/investigation-f6e1042-debug-preflight/review.json) failed only the stronger process-header check after successfully reading the expected exception from NUL-interleaved output. [fd5fdcd native control](../evidence/p11/investigation-fd5fdcd-debug-preflight/review.json) passed the corrected pinned-binary header, actual debugger connection, expected exception dump and token restoration. These controls ran no engine workload. Full original-service diagnosis run 39126844625 at f6e1042 is running after its separate preflight passed. No original RpcSs fault resolution is claimed.


[Full original-service diagnosis f6e1042/run 39126844625](../evidence/p11/investigation-f6e1042-service-log-failed/review.json) failed at environment 04 with the original unknown-reporter refusal. The observer requested no engine debugger/dump; the calibrated collector completed and restored its prior registry value, reading 2986 private bytes. It recorded SBIE2329×20 (FFS sequence lookup warning/fallback), SBIE2224×1 (program crash report), and SBIE2204×2 (service startup failure). The catalog meaning and original source are known, but no causal relationship or original exception/module is inferred.

The follow-up parser admits only exact hook identifiers extracted from the pinned public upstream hook call sites, with original source-file hashes and a matching source commit. It adds fixed known crash image kinds and optional exception codes only in the publisher's exact crash format, plus publisher startup-status tokens whose decimal/hex radix is not guessed. Names and box identifiers remain private; all such fields are explicitly diagnostic and unauthenticated as target identity. This changes no workload, assertion, authority or containment policy.
