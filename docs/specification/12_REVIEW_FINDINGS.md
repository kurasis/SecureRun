# Review Findings — Revisions 1.1, 1.2 and 1.3

Reviewed: 2026-10-14 Asia/Dubai. Baseline: specification 1.0 from this conversation. Method: full document review, cross-document consistency checks, and targeted reading of upstream Sandboxie and Microsoft documentation. No Windows execution, driver audit or application penetration test was performed.

“Corrected” below means corrected in the specification. It does not mean a future implementation has passed its test gate. Severity describes the potential impact of implementing the original ambiguity literally.

| ID | Severity / type | Finding | Correction | Evidence/gate |
|---|---|---|---|---|
| R01 | High / unsafe assumption | Calling the upstream cleanup utility was treated as sufficient protection against arbitrary host commands | Explicit DeleteCommand/trigger inspection, pinned built-in route and root revalidation | S18–S20; T33/T34 |
| R02 | High / missing requirement | Private-looking per-user paths were not backed by explicit sandbox root ACL checks | Required NTFS root DACL validation, second-user and cross-box tests | S17; T35 |
| R03 | High / incomplete process scope | Empty process enumeration could refer only to one session | Require session coverage and ownership; incomplete coverage blocks content actions | S07; T36 |
| R04 | High / underspecified enforcement | “Network blocked” did not require a kernel enforcement path | WFP default, global-prerequisite review, no hooks-only fallback | S14/S15; T39 |
| R05 | High / missing network paths | DNS brokers and network files were not separated from direct sockets | Egress-based DNS checks, share denial, broker/raw-path tests | S16; T40 |
| R06 | Medium / incorrect generalization | Reload behavior was stated as uniformly ineffective for running processes | Distinguish upstream live update paths from the manager's conservative restart policy | S05/S14; T16 |
| R07 | High / contradictory state model | Blocked/Error mixed launch permission with whether processes still run | Orthogonal lifecycle, activity, eligibility and operation state | Design review; T46 |
| R08 | High / incomplete IPC identity | User/session matching did not explain why same-SID sandbox clients remain untrusted | Explicit pipe DACL, OS peer identity, sandbox membership, mutual binding and replay limits | S21/S22; T47 |
| R09 | Medium / impossible evidence expectation | “Effective policy” could be interpreted as an undocumented API proving all permissions | Separate release tests, fresh observations and safe diagnostics; define unknown fields | S07; T15 |
| R10 | High / incomplete data retention | Removing a definition while keeping state could orphan files; export overwrite enlarged risk | Archive retains definition; Remove clears first; v1 export uses no-replace creation | Design review; T44/T48 |
| R11 | Medium / omitted view semantics | Read-only access could hide existing boxed changes without explanation | View-change disclosure and reversible policy test | S11; T38 |
| R12 | High / trust/input gaps | Signed distribution was equated with individually signed files; INI expansion and config password handling were vague | Component trust model, safe INI grammar, no password CLI exposure | S06 plus design review; T02/T37 |
| R13 | High / identity and path gaps | Same box name, shifted root or imported physical EXE path could select the wrong object | Record roots and file identities; typed boxed EXE references; block root relocation | S07/S20; T34/T43 |
| R14 | Medium / compatibility blind spot | Browser process membership did not cover handoff to existing host instances | Test single-instance IPC, brokers and protocol integrations | Design review; T41 |
| R15 | Medium / incomplete failure budgets | Large files, growing output and multi-process WebView cost lacked concrete evaluation | Bounded queues/transfers, 64-bit size tests, explicit performance workload and advisory limits | Design review; T45 |
| R16 | Medium / scope and stage ambiguity | “Disable unsupported features” could quietly remove mandatory scope; new tests lacked owners | Explicit mandatory/optional distinction and requirement-to-test/stage matrix | 13_TRACEABILITY_AND_GATES.md |

## Existing sound decisions retained

Original UI over the separately installed engine; no custom kernel driver; no ordinary host-launch fallback; optional certificate-dependent presets; independent read/write semantics; no automatic export; original signed driver; no real malware or personal-data test fixtures; and real Windows evidence before release.

## Remaining implementation decisions

The exact engine release and ABI, active enforcement/entitlement query path, safe cleanup route, root ACL integration and import/export mapping require the P02 experiment. Current documentation was sufficient to correct requirements but not to claim those integrations already work. Optional certificate features can be excluded from the release capability matrix; mandatory baseline requirements remain release gates.

Revision 1.1 contained 14 Markdown documents and 48 explicitly identified acceptance scenarios. This historical count is superseded by the revision 1.2 summary below. It retains the original stack and project scope. New restrictions such as NTFS-only roots, no-replace export and Archive are deliberate v1 scope choices to make behavior testable.

## Second review — revision 1.2

The second review focused on implementation order and requirements that could be interpreted unsafely or create circular dependencies. These are specification corrections, not discovered vulnerabilities in a working application.

| ID | Type | Finding and correction | Phase / evidence |
|---|---|---|---|
| R17 | Dependency error | Production launch previously appeared before the completed policy implementation. P05 policies/provisioning now precede P06 launch; P02 is a separate prototype feasibility gate. | P01-P12 dependency validation |
| R18 | IPC scope omission | Plugin capabilities alone do not constrain all custom Tauri commands. Require application-command ACLs and backend ID/selection authorization. | P03/P10; S23; T49 |
| R19 | Host CWD ambiguity | Target working directory could be reused for host-side engine utilities. Separate both contexts and use trusted host utility CWD/environment. | P04/P06; S24; T50 |
| R20 | Probe contamination | Running a trusted probe inside previously used boxed state could load shadowed dependencies and give misleading evidence. Use fresh diagnostic boxes and explicitly limit the conclusion. | P02/P05; T51 |
| R21 | Evidence deadlock | Requiring a release for every exact policy fingerprint would block ordinary path grants. Separate tested policy-family evidence from validated user-specific observations. | P05; T53 |
| R22 | Provisioning deadlock | Requiring an already-bound root before creating a new environment was underspecified. Add journaled PendingRoot provisioning before untrusted launch. | P05/P08; T55 |
| R23 | Elevated identity ambiguity | UAC with a different administrator could resolve the wrong profile/owner. Bind helper operations to the verified original initiating SID/session. | P05/P11; T52 |
| R24 | Stop availability ambiguity | Launch eligibility could accidentally disable Stop on certificate expiry. Use action-specific preconditions while retaining ownership/lifecycle checks. | P06; T54 |
| R25 | Stale event race | An old process query could overwrite new activity/eligibility. Add connection generations and monotonic event/receipt ordering. | P03/P04/P08; T56 |

Revision 1.2 contained 26 English Markdown documents, including 12 separate phase files, and 56 named acceptance scenarios. All normative references use P01-P12. The source-backed facts were rechecked where new technical detail was introduced; no Windows runtime validation was performed during this specification review.

## Security and failure-mode review — revision 1.3

Baseline: revision 1.2 in this conversation. Reviewed on 2026-10-14 UTC using the complete package, targeted Microsoft/Sandboxie references and cross-document checks. The review identified missing constraints and ambiguous protocols; no implementation, engine vulnerability or exploit was demonstrated. Severity rates the possible impact if an implementer follows the incomplete requirement literally. All corrections below are normative in the linked subject documents and acceptance catalog; all Windows scenarios remain unexecuted.

| ID | Severity / type | Finding | Specification correction | Owning phase / evidence |
|---|---|---|---|---|
| R26 | High / privilege authority | Helper ownership checks could be derived solely from user-writable records or marker files | Protected operation scope, independently verified enrollment, no caller-selected privileged paths/ACLs, validation through use | P02/P05/P11; T57; security model |
| R27 | High / execution context | The helper checked its caller, but the manager/bridge/helper's own boxed context was not explicitly gated | Refuse control operations or elevation in boxed/unknown context; no self-escape or host relaunch | P04/P05; T58 |
| R28 | High / conflicting requirements | Editable exclusions included manager metadata and could conflict with required isolation | Separate immutable mandatory layer; reject conflicting grants and unsupported alias semantics | P05; T59 |
| R29 | High / creation-order gap | Cross-box tests covered existing siblings without requiring protection for a newly added root | Prove namespace-wide future protection or stop/reconfigure affected boxes before storing new private data | P02/P05; T60 |
| R30 | High / ambiguous retry | The timeout rule prohibited destructive retries but did not explicitly cover already-executed launch | Persistent dispatch reservation, request deduplication and honest uncertain outcome; no automatic replay after restart | P03/P06/P08; T61 |
| R31 | High / process race | PID plus creation-time snapshots could be mistaken for binding the eventual termination action | Trace the real scoped engine handler or hold verified process handles; no PID-only fallback; wait for completion | P02/P06; S26/S27; T62 |
| R32 | Medium / filename ambiguity | Generic path validation did not define a safe destination leaf name or deceptive-name presentation | Explicit naming contract, safe rename/skip, no-replace collision authority and visible extensions/control escaping | P07/P09; S28; T63 |
| R33 | High / interrupted export | Provenance was required only before final success, leaving staging order and crash windows unspecified | Write verified marker before payload, stage privately, publish final name after checks and reconcile post-rename failures | P07/P08; T64 |
| R34 | High / stale recovery authority | Temporary cleanup and journal replay lacked explicit artifact identity and environment-generation binding | Match file identities; reject replaced artifacts and old-generation operations; no filename-pattern cleanup | P03/P07/P08; T65 |
| R35 | Medium / diagnostic leakage | Shared-bundle redaction could leave secrets in local logs and raw engine error captures | Minimize before logging, use bounded structured fields, escape controls and test synthetic secret canaries | P03/P09; T66 |

### Package verification and remaining gates

Revision 1.3 contains 26 English Markdown documents, 12 development phases P01-P12, 18 product requirements, 16 security invariants and 66 named acceptance scenarios. The new tests have feature owners and integrated/final review coverage. Historical counts above are intentionally retained as history.

P02 still must choose and verify a real engine version, native interfaces, helper authority design if needed, safe scoped stop, future-sibling protection and file mapping. No required control is assumed to exist because a document mentions it. If the engine cannot meet a mandatory property, record a blocker and a concrete architecture/scope proposal; do not hide the gap behind a green UI or a disabled mandatory feature.

The review preserves the original manager architecture and phase ordering. It does not claim an independent security audit, a secure application build, exhaustive threat coverage or passing Windows tests.
