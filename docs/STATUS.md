# Development status

Specification 1.3. Updated 2026-10-18 UTC. Current phase: **P11 fixes IN_PROGRESS; exit gate BLOCKED**.
The earlier native installed packaging implementation passed; required P10 revalidation did not.
Checked native Save and atomic session readiness passed both full fa29a20 P09
(22 native+101 UI per target) and P05. Held-object teardown passed fdad6d7 P05
(45 native+62 adapter per target). Those successful source snapshots are retained.

ARM diagnostics still report a live RpcSs-named target before cleanup. Latest
f374409 diagnosis passed 21 native+101 UI but archive exit timed out; four live WER
reads produced no exception/module. Target and reporter were eventually observed
exit 4f. New lab safeguards refuse cleanup while reporters are present and require
fresh P02 proof, now passed on both targets. Current diagnosis uses authenticated original RpcSs and pinned,
Microsoft-signed ProcDump, with private dumps and minimized scalar output only.
Debugger runs cannot close phases. Current complete matching P10/P11 remain pending.


Latest diagnostic at 0d2600c/run 39119544472 failed in environment 09: 135 authenticated ProcDump requests exited 0 without a dump. Actual debugger attachment was not observed by that collector; these exits are not proof of fault-free execution. [Original diagnosis](evidence/p11/investigation-0d2600c-debug/review.json) retains zero query/pin/scope errors and the live reporter association. The new diagnostic adds read-only actual debugger-presence checks, fixed-state/exception-code parsing without raw output, and an own native synthetic exception preflight. Full engine workload runs only after the preflight proves attachment and the exact expected exception dump. The full uninstrumented PR run 39119547942 separately passed Server 22+101 but failed ARM environment 06; [both original outcomes](evidence/p11/investigation-0d2600c-pr-p09/review.json) are retained.

| Phase | Current source validation | Evidence |
|---|---|---|
| P01 | DONE | [Report](phases/P01_REPORT.md) |
| P02 | DONE | 0d2600c/run 39119550715: Server 49, ARM 62 passed; two N/A each |
| P03 | BLOCKED revalidation | Applicable native jobs passed; full integrated retainer pending |
| P04 | BLOCKED revalidation | Applicable native jobs passed; full integrated retainer pending |
| P05 | BLOCKED revalidation | fdad6d7/run 39111146590 passed 45+62 per target; matching full integration pending |
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
