# Development status

Specification: 1.3. Updated: 2026-10-16 UTC. Requested scope: full P09.

| Phase | Status | Evidence |
|---|---|---|
| P01 | DONE | [Report](phases/P01_REPORT.md) |
| P02 | DONE | [Report](phases/P02_REPORT.md) |
| P03 | DONE — matching P09 regression passed | [Report](phases/P03_REPORT.md), [manifest](evidence/p03/manifest.json) |
| P04 | DONE — matching P09 regression passed | [Report](phases/P04_REPORT.md), [manifest](evidence/p04/manifest.json) |
| P05 | BLOCKED — final P09 runtime regression pending | [Report](phases/P05_REPORT.md), [manifest](evidence/p05/manifest.json) |
| P06 | BLOCKED — final P09 runtime regression pending | [Report](phases/P06_REPORT.md), [manifest](evidence/p06/manifest.json) |
| P07 | BLOCKED — P09 regression pending | [Report](phases/P07_REPORT.md), [manifest](evidence/p07/manifest.json) |
| P08 | BLOCKED — P09 regression pending | [Report](phases/P08_REPORT.md), [manifest](evidence/p08/manifest.json) |
| P09 | IN_PROGRESS — final native product gate pending | [Report](phases/P09_REPORT.md), [manifest](evidence/p09/manifest.json) |
| P10–P12 | NOT_STARTED | Depend on P09 |

Current P09 source candidate: `f9a9755a4e32bac27ef65ad9e4b5fdca32f7a67f`,
[draft PR #10](https://github.com/kurasis/SecureRun/pull/10).
Fresh full run [38894071449](https://github.com/kurasis/SecureRun/actions/runs/38894071449)
is pending. P09 remains IN_PROGRESS; P03 and P04 passed at this exact source; matching P05–P08 regressions are running.

First full `f9a9755` ARM attempt 38891751077 refused environment eight with
DIAGNOSTIC_SYSTEM_IMAGE_UNREVIEWED and an unassociated WerFault; no full sample
exists. Server passed all 22 native cases and 101 UI assertions, and every independent
formal target check. Fresh matrix 38894071449 and the P03–P08
regressions use the same immutable `verify/p09-f9a9755` source. No reporter is
killed/trusted/exempted and no failed attempt is relabelled successful.

Historical full `0071e2c`, run 38887959409, completed ten environments, 10000 files and
at least 60 seconds of complete-job measurement on both targets. ARM passed all
101 UI assertions and the complete real import/export/collision/Archive/Unarchive/
Reset workflow with native confirmations, generation/root and host-integrity
checks. Its separate archive GUI exit and browser point ownership failed.
Server passed 21 native cases and 99 UI assertions, including exact reviewed Save,
transfers, actual Archive and every editor/archive/browser case; the next lifecycle
confirmation was not observed. The fixture now waits for actual inherited
fieldset availability and logs archive create/extract outcomes separately.
Native waits, scoped confirmation, file hashes and browser guards are unchanged.

Both targets have positively saved exact reviewed minimized diagnostics. Historical
browser/editor/archive constituents do not replace complete final-source proof.
All reviewed original JSON, hashes, failures and cancellation reasons are retained
and published. Earlier full ARM setup refusals with unassociated WerFault have no
complete sample; no reporter is killed/trusted/exempted and no unknown window is
hidden. Performance targets remain unchanged; measured startup/CPU deviations and
user impact are recorded explicitly. GitHub authentication and publication work.

Historical P08 tested runtime: `74d86db6dc883e692dfc04c8185eee790bdcf0a9`. P03–P08 passed on this exact commit.
Reviewed original JSON and binary provenance are retained with checksums. Failed
investigations remain historical and never count as successful phase proof.

## Historical P08 verification

| Gate | Actions run | Result on each owner-selected target |
|---|---|---|
| P03 | [38763953821](https://github.com/kurasis/SecureRun/actions/runs/38763953821) | 19 foundation, 2 normal native, 3 UI and 29 actual command-boundary cases passed |
| P04 | [38763957687](https://github.com/kurasis/SecureRun/actions/runs/38763957687) | 48 adapter tests and 19 native observation cases passed |
| P05 | [38763825315](https://github.com/kurasis/SecureRun/actions/runs/38763825315) | 48 adapter tests and 45 applicable native cases passed; one absent different-admin UAC route is Not applicable |
| P06 | [38763961970](https://github.com/kurasis/SecureRun/actions/runs/38763961970) | 21 Server / 22 ARM launch/control cases passed; zero failures |
| P07 | [38763966380](https://github.com/kurasis/SecureRun/actions/runs/38763966380) | 28 Server / 29 ARM file/boxed-EXE cases passed; zero failures or actor failures |
| P08 | [38763860037](https://github.com/kurasis/SecureRun/actions/runs/38763860037) | 38/38 native lifecycle and recovery cases passed on each target; zero failures or actor failures |

Laboratories: Windows Server 2025 x64, build 26100, with actual x64/x86 target PEs;
Windows 11 ARM64, build 26200, with ARM64 and emulated x86/x64 target PEs.
Original Sandboxie Plus 1.18.6 / core 5.73.6 / ABI `0x57230`, pinned upstream
`cdba7096240b93d79c5373aa81a75a1c5c71b883`.

P08 supplies persistent/disposable retention, archive restoration, native confirmed
Reset/Remove, generation invalidation and inspect-only journal recovery. Actual
proof includes seven Reset and eight Remove executor interruptions, UI exit/crash,
real native confirmation and cancellation, all-session idle, current unsafe hooks,
locked files, replaced roots and old-generation operations. See
[lifecycle and recovery](LIFECYCLE_AND_RECOVERY.md) for exact retention and limits.
No Windows security setting is weakened and no engine binary is bundled.

The original 26-document specification is unchanged. All T01–T66 final installed-
candidate acceptance entries remain NOT_STARTED until P12. Phase proof does not
complete release acceptance. T48 packaging finishes in P11. No Windows 11 x64
release tuple, paid entitlement or release certification is claimed by these labs.

The owner authorizes publication of every project change, including Markdown and
reviewed JSON evidence, followed by normal merge after validation. Credentials,
private inventories and generated binaries remain excluded.
