# Implementation and integration traceability

P10 internal review: DONE at `75b6c0bab24e7ea0edd86a3be2adea6648456a6b`.
The [formal manifest](evidence/p10/manifest.json) binds the complete passing native run. Original specification documents remain
unchanged. The installed acceptance catalog stays NOT_STARTED until P12.

| Requirement | Production implementation | Integrated scenario evidence and remaining scope |
|---|---|---|
| PR-01 Engine detection | adapter windows.rs/discover/observe; frontend engine health | P04/P06 T01/T02/T39/T46/T50/T58 |
| PR-02 Environments | provision.rs; windows/provisioning.rs; lifecycle.rs | P05/P08 T17/T28/T34/T48/T57/T60/T65; installed retention P11 |
| PR-03 Registration | control.rs; policies.rs selections; files.rs boxed references | P03/P06/P07 T03/T04/T43/T49/T50 |
| PR-04 Isolated launch | control::launch_application; original suspended RunSandboxed; durable Journal | P05/P06/P09 T01–T07/T14/T15/T39/T41/T50/T51/T55/T58/T59/T61 |
| PR-05 Processes | Api::processes/member; independent activity/eligibility views | P04/P06/P08 T05–T07/T36/T46/T56/T62 |
| PR-06 Scoped Stop | held-object stop_environment; stop_automation/control_scope | P06/P08 T19/T26/T33/T36/T54/T58/T62 |
| PR-07 Retention modes | lifecycle state/mode; disposable_pending persisted before dispatch | P08 T06/T25/T42/T48 |
| PR-08 Policy/network | policy compiler, mandatory layer, effective readback, actual fresh verification | P05 T08–T18/T31/T37–T40/T51/T53/T59/T60 |
| PR-09 Import/list/export | handle-bound transfer/list/register; native picker; inert UI | P07/P09 T20–T23/T42–T45/T63–T65 |
| PR-10 Reset/remove/archive | native confirmation, supervisor seal, original cleanup ABI | P08/P09 T24/T28/T33/T34/T48/T65; uninstall P11 |
| PR-11 Diagnostics | typed Product Event/Journal/Bundle; minimized errors and native reviewed Save | P03/P09 T45/T66 and P10-F01/T58 |
| PR-12 Recovery | persistent reservations/artifact/lifecycle journals and generation checks | P03/P07/P08 T18/T25/T28/T46/T48/T55/T56/T61/T64/T65 |
| PR-13 Drift/capabilities | pinned component/OS tuple, current global/template/effective checks | P04/P05 T14–T18/T34/T39/T59; optional features disabled |
| PR-14 Install/upgrade/uninstall | Reserved for P11 installed artifacts; engine remains separate | T29 and packaging portions T48/T57/T58 assigned P11; no P10 pass claimed |
| PR-15 Accessible EN/RU UI | React localization/themes/scaling, keyboard/UIA and full filename text | P09 native EN/RU/DPI96/144/192 and T63; limits documented in PRODUCT_UX |
| PR-16 Storage isolation | OS-derived private NTFS profile/root, engine mandatory namespaces | P05/P07 T22/T34/T35/T47/T52/T55/T57/T59/T60; helper-only T52 N/A |
| PR-17 Sessions | original all-session enumeration, completeness and held owner/birth checks | P04/P05/P06/P08 T19/T36/T46; no multi-user administration claim |
| PR-18 Bounds | worker framing/jobs/timeouts; bounded typed queues/history/pages; streaming transfer | P03/P07/P09 T45/T66 and actual complete-job measurements |

| Invariant | Code authority and integrated checks |
|---|---|
| SEC-01 | Only original suspended boxed dispatch; no ordinary host fallback. P06 T01–T07/T61. |
| SEC-02 | Current mandatory compile/readback/root/tuple validation before enabling and dispatch. P05 T15/T39/T55/T59; P06 current policy. |
| SEC-03 | asInvoker normal app, ordinary-user workers; no elevation/helper. P03/P05/P09 actual standard accounts. |
| SEC-04 | Typed ACL commands; no target-derived host hooks, shell, preview or automatic file open. P03 T49; P07 T23; P08 T33. |
| SEC-05 | Unknown/unsupported/paid controls remain unavailable; policy drift blocks. P04/P05 T14–T17/T39/T59. |
| SEC-06 | Current owner/root/marker and actual engine scope, not box-name prefix. P05/P06/P08 T19/T28/T34/T57. |
| SEC-07 | Compiler and bilingual UI distinguish read exclusion, virtualized changes and explicit host writes. P05 T08–T11/T31/T38. |
| SEC-08 | Explicit custom-command ACL plus origin and native selection authorization. P03/P07 T49; all 17 commands tested from both denied windows. |
| SEC-09 | Original installed component signatures/pins and ABI; no Windows security changes. P04/P06 T02/T50. |
| SEC-10 | No renderer-selected recursive delete; retained-root original ABI/seal. P08 T24/T33/T34/T65. |
| SEC-11 | Unknown trust/context/enforcement/completeness cannot report launchable/Idle. P04/P05 T01/T15/T36/T39/T46/T58. |
| SEC-12 | MOTW plus explicit destination and warning; no safety claim/auto-open. P07/P09 T21/T23/T44/T64. |
| SEC-13 | Per-action fresh owner/root/config/session/lifecycle checks and native confirmation. P06/P08 T19/T24/T33/T34/T36/T62/T65. |
| SEC-14 | Kernel WFP prerequisite and live loss refusal, no hooks-only fallback. P05 T12/T13/T39/T40 with positive/server observations. |
| SEC-15 | No metadata-derived privilege, immutable mandatory exclusions, self/parent context gates. P05 T57–T60; P10 diagnostic Save fix. |
| SEC-16 | Persistent reservation/Unknown plus identity-bound inspect-only recovery; no automatic replay/replacement. P03/P06/P07/P08 T61/T64/T65. |

R26–R35 are individually traced in [the security review](SECURITY_REVIEW.md).
The [complete P10 scenario report](P10_TEST_REPORT.md) enumerates T01–T66 with actual evidence,
explicit helper/optional exclusions and P11/P12 portions, rather than converting
phase test tags into complete installed-acceptance passes.
