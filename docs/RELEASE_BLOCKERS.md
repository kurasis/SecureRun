# Release blockers and remaining prerequisites

The current P11 implementation passed its native installed gate but the phase is
**BLOCKED by required P10 revalidation**. Historical successes do not certify the
changed runtime/engine source. This is not a production release or independent audit.

| Item | Actual state / requirement |
|---|---|
| Current full P10 integration | BLOCKED at ffdaeb6/run39087328157; ARM P09 failed both original and one controlled unchanged-source repeat |
| Unknown-reporter cleanup | Reproducible live WerFault after unchanged 60000 ms natural wait; source/cause undetermined, original reports retained; no trust/termination/hiding workaround |
| Server actual browser/Save observation | First P09 failed clipboard-busy; repeat observed effective sandbox level 9 but failed diagnostic Save filename readback before confirmation (20 native+93 UI passed); both failed reports retained |
| Duplicate PR rapid Launch/Stop | P06 initial ENGINE_DISPATCH_REFUSED and later uncertain-state assertions retained; no actual dispatch inferred from assertion labels |
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
