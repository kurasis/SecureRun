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

## P02 feasibility probes

Authoritative run: [38550922299](https://github.com/kurasis/SecureRun/actions/runs/38550922299),
code `2eb5fd0bb6e93921fd3ffdd415990633a79aabc0`, 2026-10-14 UTC.
[Original JSON and SHA256/size manifest](evidence/p02/manifest.json).

| Actual lab | Passed smoke | Failed | Blocked | Helper NA | Pending/skip/not-run declared smoke |
|---|---:|---:|---:|---:|---:|
| Windows Server 2025 x64; x86/x64 target PEs | 43 | 0 | 2 | 1 | 0 |
| Windows 11 ARM64; ARM64/x86/x64 target PEs | 56 | 0 | 2 | 1 | 0 |

These counts cover explicitly declared representative probes only. Untested
mandatory protocol variants below remain blocked; zero not-run declared cases
does not imply complete acceptance coverage. Job success means evidence collection
completed, while phase-result is BLOCKED. The 66 production scenarios remain
NOT_STARTED and must execute again with production feature paths.

| Scenario | Observed prototype result | Remaining scope |
|---|---|---|
| T01 | Missing box rejected; host execution marker absent | Other missing/stopped/updated engine failure variants and launch journal |
| T05 | Native/emulated parent, child and grandchild verify selected membership | Production target/browser/broker types |
| T04 | Exact fixed argument equality including quotes, slash, option-like value and Unicode | Complete target parser/length matrix |
| T08 | Boxed writes/read view change; host canary hash unchanged; actual handle mapping boxed | Hostile application/alias/write-path suite |
| T09 | Selected host secret and manager metadata read denied (5), unboxed controls read successfully | Wider inheritance/permission matrix |
| T12 | Source-backed WFP enabled in fresh engine; unboxed/online socket controls succeed and offline TCP/UDP v4/v6 deny | DNS/LAN/SMB/broker/raw/inbound and full release tuple |
| T33 | Each of four automation settings blocks dispatch; synthetic settings removed before real cleanup | All inherited templates and every host-side consumer |
| T35 | Same-user sibling storage denied; second standard account has public read success and root/metadata access denied | Other aliases, writes and host-actor races |
| T36 | Actual successful capacity-one truncation rejected; session-zero SYSTEM target included by all-session query and excluded by current-session query | BLOCKED same-SID second interactive session and adversarial concurrent clients |
| T55 | Absent root observed, fixed host initializer applies NTFS DACL and captures identity before target | BLOCKED parent/root substitution at named provisioning steps |
| T57 | Windows-root redirection rejected before config mutation | Helper enrollment/path-swap tests NA while helper absent; normal-user authority unresolved |
| T58 | Native guard and actual managed bridge return refusal when boxed, without mutation/elevation | Query-failure injection and future manager/helper entrypoints |
| T60 | Affected running box defers materialization; stopped policy readback precedes data; direct and junction alias read denied | Additional aliases and external client creation races |
| T62 | Actual held-handle birth/box/SID validation, object completion and fresh membership; no numeric kill fallback | Scope-change/PID-churn fault injection and standard-user permissions |
| T16 | Missing/wrong synthetic password C000006A, unchanged key; correct private-IPC mutation read back and fixture restored | Production secret memory lifecycle/user interaction |
| T19 | Physical private copy mapped by original API/hash checked; trusted boxed Start stage launches logical EXE with actual membership | P07/P09 safe transfers, retained ancestry and reset/reference invalidation |
| T24 | Original QSbieAPI native clears selected contents, retains root identity, returns expected final unlink sharing denial, host/sibling hashes unchanged | BLOCKED hostile descendant replacement/external launch exclusion; no broader status acceptance |
| T25 | Fresh never-materialized owned definition removed via native '*' route and absence read back | Used definition removal blocked until cleanup gate passes |
| T02 | Installed component/health/config/entitlement query succeeds; no paid profile enabled | BLOCKED internal engine message reader: C0000022, signed session-leader requirement |

Linux tooling: validator and six regression tests pass. Windows compilation keeps
/W4 /WX; PE machine values 014c/8664/aa64 prove actual targets rather than filenames.
The unchanged specification's 26 hashes pass on Linux and Windows. Native engine
version and ABI must both match the pin. Security observations/limitations are in
[ENGINE_MATRIX](ENGINE_MATRIX.md); no security bypass or production support claim.

Historical failing runs diagnosed probe mistakes before the final run: wrong
BOOLEAN width, uninitialized PROCESS_INFORMATION, expanded config comparison,
PowerShell empty-string removal, x86 alias/calling convention, reused compiler
target, unboxed GetHandlePath, invalid NT dot-name and process exit races. They
are not final evidence. An internal engine log denial is a confirmed integration
limitation, not an error made to pass by changing signing/security settings.
