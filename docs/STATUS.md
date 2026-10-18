# Development status

Specification 1.3. Updated 2026-10-18 UTC. Current phase: **P11 fixes IN_PROGRESS; exit gate BLOCKED**.
The earlier native installed packaging implementation passed; required P10 revalidation did not.
Current work replaces asynchronous Save filename input with checked native keyboard
input and observes reporter lifetimes during a diagnostic-only ARM workload. New
lab/workflow inputs require fresh full integration and matching installed proof.
The source-specific reports below remain historical snapshots, not proof for these fixes.

| Phase | Current source validation | Evidence |
|---|---|---|
| P01 | DONE | [Report](phases/P01_REPORT.md) |
| P02 | BLOCKED revalidation | Protected lab scripts changed; fresh exact-source native feasibility required |
| P03 | BLOCKED revalidation | Applicable native jobs passed; full integrated retainer pending |
| P04 | BLOCKED revalidation | Applicable native jobs passed; full integrated retainer pending |
| P05 | BLOCKED revalidation | Applicable native jobs passed; full integrated retainer pending |
| P06 | BLOCKED revalidation | Full-matrix jobs passed; separate PR rapid-cycle failure retained |
| P07 | BLOCKED revalidation | Applicable native jobs passed; full integrated retainer pending |
| P08 | BLOCKED revalidation | Applicable native jobs passed; full integrated retainer pending |
| P09 | BLOCKED | ARM diagnostic cleanup failed both attempts; Server first browser observation failed |
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

Current integration source: `ffdaeb60bd8c9d707959435b910c6a1027ecb770`,
[run 39087328157](https://github.com/kurasis/SecureRun/actions/runs/39087328157).
All 155 protected runtime/workflow/lab files are byte-identical at the packaging-only
descendant. Portable and all 12 P03–P08 native jobs passed; their 218 original JSON
reports are retained as [partial proof](evidence/p11/investigation-ffdaeb6-partial-integration/review.json).

Attempt 1 ARM P09 refused DIAGNOSTIC_SYSTEM_IMAGE_UNREVIEWED during environment 09;
unknown WerFault remained alive after the unchanged 60000 ms natural wait. One controlled
unchanged-source repeat reproduced it at environment 05. Read-only diagnostics found
no surviving target or fixed-component WER report/event; cause remains undetermined.
No third blind repeat is planned. No reporter was trusted/terminated, no unknown
window hidden, no scenario/workload/assertion/timeout or source list reduced.

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

Repository validator and all 29 Python tooling/gate tests passed. Generated binaries,
credentials, raw paths, arguments and private inventories remain excluded from Git.
All project Markdown and reviewed structured evidence are published as authorized.
PR #12 remains draft; normal merge requires completing the actual gate, not bypassing it.

Continue **P11 dependency diagnosis/correction**, then repeat complete exact-source
integration and matching installed proof. P12 is not started. See
[release blockers](RELEASE_BLOCKERS.md), [build](BUILD.md), [install](INSTALL.md),
[retention](UPGRADE_AND_UNINSTALL.md) and [signing](SIGNING.md).
