# Release blockers and remaining prerequisites

The current P11 implementation passed its native installed gate but the phase is
**BLOCKED by required P10 revalidation**. Historical successes do not certify the
changed runtime/engine source. This is not a production release or independent audit.

| Item | Actual state / requirement |
|---|---|
| Current full P10 integration | No complete passing current-source matrix; historical ffdaeb6/run39087328157 failed. Current matching installed P11 proof is also pending |
| Unknown-reporter cleanup | Ordinary ARM P09 still failed at environments 06/08 in runs 39119547942/39120204559. The original exception/module remain undetermined; reporter names grant no trust/termination/hiding authority |
| Server actual browser/Save observation | Checked native Save input passed in full fa29a20/run39109839082 on both targets; later ordinary Server jobs also passed 22+101. Original clipboard/Save failures remain historical failures |
| Session and fixture teardown races | Atomic session-ready JSON and retained-object completion handling passed actual P05 b1e2129/run39120204407 on both targets (45 native+62 adapter each); no engine-fault resolution inferred |
| ARM original-service diagnosis | f6e1042/run39126844625 failed environment 04. cff58d4/run 39129208572 passed 22+101 with no reporter and 112 NtCreateLowBoxToken FFS warnings. Diagnostic success is excluded from phase closure and does not establish a cause/correction |
| Duplicate PR rapid Launch/Stop | Later P06/P08 ARM jobs first refused DIAGNOSTIC_SYSTEM_IMAGE_UNREVIEWED; historical ENGINE_DISPATCH_REFUSED and uncertain-state assertions retained. No actual dispatch inferred from assertion labels |
| P11 installed deployment/retention | 28/28 actual installed cases plus 81 production tests passed on each target; does not waive P10 dependency |
| Production Authenticode infrastructure | Unavailable; all original artifacts explicitly UNSIGNED DEVELOPMENT ONLY; see signing policy |
| Original manager license | Not selected by owner; production/commercial redistribution clearance not claimed |
| P12 final installed acceptance | NOT_STARTED; all 66 T01–T66 entries remain unrun |
| Windows 11 x64 installed release tuple | Not certified by owner-selected Server x64/Windows 11 ARM64 laboratories |
| Stripped-OS missing-runtime ARM variant | Not claimed; actual missing runtime tested on Server, Windows 11 preinstalled runtime preserved on ARM |

No mandatory check, workload or original performance target is waived. Historical
performance reports remain source-specific; failed-attempt samples are not completion
proof. No engine, persistent elevated helper or silent updater is bundled.
Windows TLS/signatures/hashes, certificate policy and browser sandbox remain active.
See [P11 phase report](phases/P11_REPORT.md), [installed checks](P11_TEST_REPORT.md),
[artifact status](DEVELOPMENT_ARTIFACTS.md), [signing](SIGNING.md) and [status](STATUS.md).
