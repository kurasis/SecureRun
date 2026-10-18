# P11 — Packaging, upgrades, signing and retention

Status: **Fixes IN_PROGRESS; gate BLOCKED**, 2026-10-18 UTC.

Current changes use foreground/owner-checked native SendInput for Save filename
selection/typing while retaining exact filename readback, one confirmation and
actual output-byte assertions. A disposable diagnostic observer records known
process lifetimes and early reporter associations using query/synchronize handles
only, without terminate/debug/VM rights. Names are not authentication. Raw IDs,
paths and arguments stay in memory. Its instrumented run cannot close a phase or
certify performance. Fresh full uninstrumented gates remain mandatory.

The source-specific evidence below predates these fixes.
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

## Runtime security refresh and blocked dependency

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
completion wait, after independently authorized stops. No WerFault/unknown image
is trusted, terminated or hidden. Protected OS UBR is included in verification
identity and the immutable compiled launch tuple; an OS revision change invalidates
cached proof. The first new-tuple mismatch failed closed and was corrected without
accepting an unreviewed OS. Both installed T05 paths passed with this correction.

Current full integration source: `ffdaeb60bd8c9d707959435b910c6a1027ecb770`,
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

## Validation and continuation

Actual commands: `packaging/Invoke-P11.ps1`, locked native Cargo production tests,
full P10 Actions matrix, `python tools/lab/validate_repository.py`, existing 22 Python
tooling tests and 7 packaging gate tests. Repository validation and all 29 Python tests
passed. All 26 original specification files remain byte-for-byte unchanged. Reviewed
original evidence is published without generated binaries, credentials, raw paths,
arguments or private inventories. Development EXEs remain expiring Actions artifacts.

The packaging implementation preserves its tested boundaries and retained data,
but **P11 is not DONE while its required P10 dependency is blocked**. Continue P11
with actual diagnosis/correction of reproducible ARM diagnostic cleanup and uncertain
launch/observation failures, then obtain fresh complete exact-source integration
and matching installed proof. Do not reduce workloads, trust/kill reporters, hide
unknown windows or manufacture a successful gate. P12 is not started or authorized
by this phase report. Production signing/licensing remain explicit release prerequisites.
