# P01 test report

Run: [38536438262](https://github.com/kurasis/SecureRun/actions/runs/38536438262),
2026-10-14 UTC. Source head: 3529b11d7657fb4520c1aa3b17aaa23f2ff33dfb.
Exact tested PR merge checkout: 795f167855acb46c65e8a1ef21967d7baa91e9fd.
[Structured summary and runtime hashes](evidence/p01/windows-arm64/run-summary.json).

| Check | Expected | Actual / status | Evidence |
|---|---|---|---|
| Repository integrity | 26 unchanged documents, links, pins and all outputs | PASSED locally and Actions | Repository job |
| Tooling regression | Valid hashes pass; tamper/wrong size fail | PASSED: 6 run, 6 passed, 0 failed | Repository job |
| Official source tag | Git and API agree on full commit | PASSED: cdba7096240b93d79c5373aa81a75a1c5c71b883 | [Linux JSON](evidence/p01/linux-provenance.json) |
| x64 EXE on selected lab | Actual Windows execution; native host correctly recorded | PASSED: x64 process on ARM64, Windows 11 26200.9457 | [probe](evidence/p01/windows-arm64/probe.json), [inventory](evidence/p01/windows-arm64/inventory.json) |
| x64 official installer | Expected size/hash, valid Windows signature | PASSED | [trust](evidence/p01/windows-arm64/installer-trust.json) |
| ARM64 official installer | Expected size/hash, valid Windows signature | PASSED | [trust](evidence/p01/windows-arm64/installer-trust-arm64.json) |
| Synthetic fixture | Unique run root, local fixed NTFS, marker/hash, disposable teardown | PASSED for preparation only | [fixture](evidence/p01/windows-arm64/fixtures.json) |
| Engine containment/installed components | Source-backed native driver, actual policy and membership | NOT_RUN: P02 | No installed engine |
| Original Windows 11 x64 tuple | Native OS/driver compatibility | NOT_RUN: selected ARM64 runner does not establish x64 kernel support | Platform limitation |
| Second account/session, endpoints and bounded volumes | Positive controls and actual access results | NOT_RUN: defined for P02 | [fixture contract](LAB_SETUP.md) |

Windows source evidence includes timestamps and exact OS/security/architecture.
Signatures report Valid under Windows trust policy, not a claim of independent
security certification or uniform online revocation evidence. Source versions are
candidate declarations; installed component versions and policy hashes do not yet
exist. Secure Boot is false in the hosted image; no security setting was changed.

The full [66-scenario catalog](test-catalog.json) preserves expected outcomes from
[the specification](specification/08_TESTING_AND_ACCEPTANCE.md). All T01–T66 are
NOT_STARTED. No acceptance scenario is passed or waived by setup. No expected
failure, skip or Not applicable result is used to hide missing runtime evidence.

## P02 completed feasibility probes

Authoritative run: [38557903464](https://github.com/kurasis/SecureRun/actions/runs/38557903464),
source 0cf59a67041364209d6f42ac393db3ecaa73e044, 2026-10-14 UTC.
[Original JSON, exact runtime source hashes and SHA256/size manifest](evidence/p02/manifest.json).

| Actual lab | Passed smoke | Failed | Blocked | NA | Not-run/pending |
|---|---:|---:|---:|---:|---:|
| Server 2025 x64; genuine x86/x64 target PEs | 49 | 0 | 0 | 2 | 0 |
| Windows 11 ARM64; native ARM64 and emulated x86/x64 PEs | 62 | 0 | 0 | 2 | 0 |

Both computed phase-result files are DONE with no gate blockers. CI now fails
if a declared mandatory smoke fails, is blocked/incomplete or a required scenario
ID has no passing variant. Only optional engine access-event streaming and absent
product helper checks are NA. They do not supply mandatory passing evidence.

| Scenario | Actual representative result | Production work still required |
|---|---|---|
| T01 | Missing box rejected; forbidden host marker absent | Complete engine-unavailable/update and launch journal matrix |
| T05 | Native/emulated parent, child and grandchild membership | Production target/browser/broker paths |
| T04 | Exact synthetic argv including quotes, slash, Unicode and option-like value | Full parser/length/target matrix |
| T08 | Virtual writes/read view; host hash unchanged; boxed mapping | Hostile application and complete write/alias suite |
| T09 | Selected secret/metadata/sibling reads denied, positive unboxed reads | Complete inherited permission matrix |
| T12 | Kernel WFP path/flags; online/unboxed v4/v6 TCP/UDP succeed, offline deny | Controlled DNS/LAN/SMB/broker/raw/inbound release tests |
| T33 | Four automation settings block dispatch; source consumer/inheritance resolved | Product configuration conflict/consumer matrix |
| T35 | Same-user sibling deny and second-account public read success/root-metadata deny | Further aliases and write variants |
| T36 | Actual same SID concurrently in sessions 0/2; all/current-session contrast; SUCCESS truncation refused; foreign SYSTEM owner observed | Desktop/UI and high-churn production concurrency |
| T55 | Standard-user native relative FILE_CREATE, DACL before lease release, identity from created handle | Durable provisioning journal/ownership and failure recovery |
| T57 | Actual parent junction rejected before create; pinned rename blocked; changed root identity and Windows-root redirection refused | Enrollment/spoof tests if a product helper is introduced |
| T58 | Native and actual managed bridge refuse controls while boxed | Production manager/helper entrypoints and unknown-context faults |
| T60 | Running box defers future materialization; stopped policy readback precedes data; direct/junction alias denial | Complete production sibling/policy matrix |
| T62 | Actual dispatch checks held birth/box/SID; wrong live scope untouched, naturally exited object not redispatched; standard-user all-session stop | Stress/PID-churn and full production failure handling |
| T16 | Missing/wrong password C000006A leaves key unchanged; correct private-IPC change/readback/restoration | Product secret memory/user interaction |
| T19 | Original physical mapping and hash; trusted boxed Start stage executes logical boxed EXE with membership | Safe import/export, stream/collision/ancestry/journal rules |
| T24 | Standard-user and elevated original cleanup with launch fence, sealed namespace, empty contents and retained identity; outside/sibling canaries unchanged | Full product reset/recovery/cancellation/stress paths |
| T25 | Fresh section removal and used section removal only after verified cleanup | Durable archive/removal reconciliation |
| T02 | Original health/config/entitlement observation and redacted MANAGER_OBSERVATION diagnostics | Optional upstream native events unavailable; paid profiles remain disabled |

The sealed cleanup tests attempt new entry creation, WRITE_DAC and an
attribute-only junction substitution before native dispatch. Those attempts are
denied and the seal remains held through dispatch; this is not a claim of an
executed concurrent stress harness. Existing reparse/hardlink fixtures are rejected
before calling the original cleanup export. The retained root intentionally blocks
final unlink (C0000043); empty contents and exact identity are required.

Seven Linux tooling tests and validator pass. The historical P01 section above
records its original six-test run, not today's suite size. Windows /W4 /WX,
explicit compiler/library selection and PE 014c/8664/aa64 prove actual architectures.
All 26 specification hashes remain unchanged. All 66 product acceptance entries
stay NOT_STARTED and must run again on the production paths in owning phases.

The manifest preserves the earlier BLOCKED research run from PR #2 as historical.
Its two blockers and limited cleanup proof are superseded by the current run, not
relabeled. Source hashes prevent stale prototype evidence being used for changed
runtime code. [Security observations and native Windows 11 x64 gap](ENGINE_MATRIX.md)
remain explicit; no Windows security setting was changed.

## P03 foundation and actual IPC

Exact source 742c2ab3ac39a7146005ca1f540a93ec592ddc0a,
[run 38568549251](https://github.com/kurasis/SecureRun/actions/runs/38568549251).
[Original Windows JSON, generated ACL/capability manifests and source hashes](evidence/p03/manifest.json).

Both Windows Server x64 and Windows 11 ARM64 pass 19 foundation tests, 2 tests of
the normal configuration without its test feature, 3 UI tests and 21 real
WebView2/native-picker command cases. Zero required failures/blocks/skips remain.
Actual PE machines are 8664/aa64; both native apps run under a standard token.

T28: migration rollback after named partial SQL failure; foreign/future/corrupt
metadata preserved; missing metadata never adopts engine boxes. T49: actual
custom-command ACL denial for ungranted local/remote windows, main-window positive
controls, Rust ID/revision/owner checks and native one-use selections. T56: backend
event generation/revision/sequence tags, denied renderer emission and stale
event/snapshot refusal in Rust/UI. T61: persistent duplicate/restart reservations
and no automatic dispatch replay (logical counter; no actual engine launch).
T65: actual Windows file replacement refused by identity, canary retained and
old-generation recovery blocked. T66: minimized local/shared records and rejected
control-character input; no secret canary or forged event in diagnostics.

The normal shell remains read-only while P04 self-context observation is absent.
Only the explicit foundation fixture enables synthetic metadata operations; no
engine target, host shell primitive, import/export or sandbox cleanup is executed.
These close P03's component gate and do not pass the complete production scenarios.
All 66 acceptance entries remain NOT_STARTED. Seven Python tooling tests, portable
Rust/UI checks, strict core Clippy, formatting and dependency-lock validation pass.
