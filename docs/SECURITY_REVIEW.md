# P10 internal security and integration review

Review source: `75b6c0bab24e7ea0edd86a3be2adea6648456a6b`.
Status: DONE; [all exact-source native gates passed](https://github.com/kurasis/SecureRun/actions/runs/39068949002).
This is an internal implementation review, not an independent audit, driver
audit, penetration-test certification or guarantee against every attack.

## Scope and method

The review compares SEC-01–SEC-16, PR-01–PR-18 and R01–R35 with the actual Rust,
Tauri ACL/CSP, renderer, durable journals, original-engine adapter and native
laboratory paths. Packaging-only PR-14/T29 and installed migration/retention
portions of T48 belong to P11. P12 owns final installed T01–T66 acceptance.
P02 prototype results are historical feasibility material, not production proof.

The selected execution targets remain Windows Server 2025 x64 and Windows 11
ARM64, including actual x86 and emulated x64 targets. The trusted engine is the
separately installed, original Sandboxie Plus 1.18.6/core 5.73.6, pinned source
`cdba7096240b93d79c5373aa81a75a1c5c71b883`. No engine code or binaries are bundled.

Review steps:

1. Trace renderer input through generated command ACLs, actual-origin checks,
   native selection grants, serialization and independently authenticated workers.
2. Trace engine trust, self/parent context, OS-derived owner, mandatory policy,
   dispatch reservation and suspended target membership before execution.
3. Inspect the actual termination handles, file publication and lifecycle/recovery
   protocols at named mutation and crash boundaries.
4. Repeat P03–P09 production regressions on both laboratories at one source commit.
   Require controls that can fail, actual observed outcomes and original artifacts.
5. Bind all product, lab, test and workflow source bytes and the dependent manifests;
   preserve failed investigations and distinguish phase checks from release tests.

## Findings and changes

| ID | Severity | Finding | Resolution and verification |
|---|---|---|---|
| P10-F01 | Medium; SEC-15/T58 context requirement | Diagnostic Save consumed an authentic preview but could write its minimized JSON while the ordinary setup context was Unknown. History's session-only fallback was not write authority. No elevated operation, arbitrary renderer path, secret contents or host target execution was demonstrated. | Require a fresh trusted native unboxed manager and bridge before the native picker and again after selection, before file creation. Consume the preview on refusal. P03 exercises a real valid preview in an engine-absent native fixture and its refused reuse; the portable context test checks boxed/unknown/service/restart states; P09 repeats successful native Save. Closed by matching native evidence on both laboratories. |
| P10-F02 | Assurance gap; T49 | The forbidden-window probes omitted six registered application commands. The remote fixture could also appear denied if no internal invocation API existed, without attempting a command. | Both forbidden windows attempt all 17 registered commands. The native harness requires 17 actual attempts and ACL-specific denials per window. A missing invocation API cannot pass. P10's gate checks coverage against the build manifest. Closed by matching native evidence on both laboratories. |
| P10-F03 | Assurance gap; T47/T58 | Same-SID boxed policy-worker evidence did not directly exercise every later worker family with a claimed unboxed parent. Shared authorization code alone was insufficient new integration evidence. | The actual boxed process invokes policy, control StopManaged, file Cancel, lifecycle Commit and product Record workers. All must return MANAGER_CONTEXT_UNSAFE before metadata or effects. The claimed host PID/birth is deliberately valid; it cannot establish the worker's own context. Closed by matching native evidence on both laboratories. |

The changes add no helper, target launch path, permission exception or retry.
Unknown-context diagnostic Preview may still show minimized session information;
it cannot authorize a host file write. Diagnostic Save retains native selection,
safe `.json` names, held ancestors, create-new/no-replace and exact reviewed bytes.

## Reviewed boundaries

| Boundary | Actual implementation and refusal conditions | Production regression |
|---|---|---|
| Bundled WebView → Rust | Explicit AppManifest permissions and main-only local capability; every handler checks injected label/current origin. CSP blocks remote executable content, frames and objects; external navigation/new windows are denied. No generic shell, filesystem, opener or spawn plugin. Typed requests reject unknown fields. | P03 T49: both denied windows, forged IDs/paths/confirmation, one-use selections; normal capability excludes ci_report. |
| Picker → operation | Native picker, parent window, held object/ancestors, fixed local NTFS, non-reparse/case/long-name checks. IDs bind operation/environment/revision/generation/purpose, expire and are consumed once; renderer booleans confer no authority. | P03/P05/P07 T49/T53/T59/T63, P09 actual native transfer/confirmation. |
| Manager → worker | Current protected same executable, controlled host CWD and environment, inherited bounded pipe/job, actual parent birth, OS user, current self and parent driver contexts. No named-pipe product helper exists. Caller PID alone is not authority. | P04/P05 T47/T50/T58, P10 additional boxed worker families. |
| Worker → installed engine | Protected SCM configuration and component paths/identities, original signatures or authenticated payload pins, ABI/version/OS tuple. No PATH/current-directory discovery, unsigned substitute, TLS bypass or disabled code integrity. Service/driver/context failures refuse controls. | P04/P06 T01/T02/T39/T46/T50. |
| User metadata → engine scope | OS owner plus derived UUID root, original engine marker/root identities and current configuration; writable records cannot authorize administrator effects. No product elevation route. Missing/foreign/corrupt metadata never adopts unrelated boxes. | P03/P05/P08 T28/T34/T35/T47/T55/T57/T65. |
| Editable grant → mandatory policy | Compiler-generated manager/code/sibling exclusions cannot be deleted or overlapped by grants. Effective/default inheritance and aliases are audited. New siblings require stopped namespace-wide rollout before private data. | P05 T09/T16/T17/T37/T38/T53/T59/T60; actual other-session and future-sibling probes. |
| Launch → target | Durable request reservation precedes dispatch. Exact registered PE/object/CWD identity and current policy are checked. Original RunSandboxed returns suspended process handles; intended-box membership is checked before ResumeThread. Failure has no host fallback. Unknown acceptance never triggers replay, including after restart/empty scope. | P06 T01–T07/T50/T54/T56/T61, P08 reset/recovery interaction, P09 real application paths. |
| Observation → Stop | Complete all-session engine enumeration, root/owner checks, fence and current automation audit. Hold PROCESS_TERMINATE/query/synchronize handles; compare birth and driver scope again at use, reject critical/unknown objects, wait on those objects. Numeric PID is never reopened for termination. | P06 T07/T19/T36/T54/T62; actual scope change at StopHeld and naturally exited retained object. |
| Boxed file → host publication | Inert metadata only; no previews/associations/auto-open. Bound source/destination handles reject hard links, streams/reparse escapes, sensitive roots and namespace aliases. Write verified MOTW before payload into private staging; bounded copy/hash, no-replace handle-relative publication, durable receipt. | P07 T20–T23/T42–T45/T63–T65; original canaries and existing destination preserved. |
| Cleanup → retained root | Native confirmation plus current owner/root/parent/config/session/lifecycle checks. Original pinned cleanup ABI receives retained root handle; namespace seal and live supervisor retain restoration authority. Hooks/DeleteCommand/automation drift refuse mutation. | P08 T24/T26/T33/T34/T36/T42/T48/T65; seven cleanup and eight removal interruptions. |
| Recovery → filesystem | Inspect known operation/generation, held parent/artifact identities, provenance/hash; never delete by glob or replay uncertain dispatch. Old generation/replaced artifact stays unresolved. | P03/P07/P08 T61/T64/T65; both pre/post publication and reset/recreation cases. |
| Target text → UI/logs | React text rendering, escaped controls and visible extensions; typed allowlisted error/event fields contain no argv, environment, raw engine text or paths. Minimization occurs locally before persistence; shared preview is separately bounded. No automatic uploads. | P03/P07/P09 T23/T45/T63/T66; UTF-8/UTF-16 local scans and exact diagnostic Save. |

## Network review

Standard Offline requires the original kernel WFP path and current BFE/engine
prerequisites. Unknown/failed WFP cannot become a hooks-only offline status.
Online remains an explicit choice with the same mandatory file exclusions.

P05 repeats the production verifier on each native/x86/emulated architecture.
Each unique fixture first obtains real responses from its controlled IPv4/IPv6
TCP/UDP loopback and LAN endpoints; server counters establish a baseline before
the boxed parent/child dispatch. Later target packets count as egress even after
retried controls. Incoming socket listeners and server observations are separate.
The DNS fixture uses unique queries against its controlled server, with a separate
cache-only observation; a cached answer alone is never counted as network egress.
SMB/mapped-drive tests require successful host reads before boxed denial. BITS
activation must return E_ACCESSDENIED; ICMP/raw tests preserve ordinary-token
refusal and server observations without requesting elevation. A failed control
blocks the gate. P09 additionally checks actual browser-owned child traffic,
host-instance attribution, protocol request and the browser's own sandbox.

This evidence covers the declared original-engine paths and tuple. It does not
prove every possible network broker, driver exploit or permitted user export
channel cannot disclose information. No normal product launch gains unsolicited
network calls from these disposable lab fixtures.

## R26–R35 closure map

| Finding | Actual implementation | Required P10 evidence |
|---|---|---|
| R26 | No elevated helper/enrollment path; OS owner and engine/root scope independently checked; forged database cannot grant privilege. | P05 forged metadata, standard/second-user ACL checks. Helper enrollment/UAC replay is N/A, not a synthetic pass. |
| R27 | Adapter NativeEngine::new and mutation_context check own/parent context before control/profile access; desktop boxed startup exits. Diagnostic Save now has its own fresh use-time checks. | P04 boxed desktop/bridge; P05 all boxed worker families; P03 valid-preview Unknown refusal. |
| R28 | Immutable mandatory compiler layer, effective readback and alias rejection. | P05 overlapping grant/forged compiled record/template/drift tests. |
| R29 | Namespace writer serialization and complete stopped rollout precede new sibling materialization. | P05 running/other-session deferral and actual future-sibling direct/junction denial. |
| R30 | Persistent operation signature/reservation; Unknown survives restart/empty scope; never automatic redispatch. | P03/P06 reserved/accepted receipt loss; P08 reset reconciliation. |
| R31 | Held process-object termination with birth/driver scope checks immediately before TerminateProcess; wait for completion. | P06 StopHeld scope mutation, exited retained object and two actual sessions. |
| R32 | Destination leaf grammar, reserved/device/stream/alias/case checks, Rename/Skip, inert escaped name with full extension. | P07 malicious/deceptive names and no-replace race; P09 actual bilingual file display. |
| R33 | MOTW before first payload; private staging, bounded verified copy, handle-relative no-replace rename, explicit post-rename reconciliation. | P07 five actual interrupted copy stages, marker failure and collision; P08 reset interaction. |
| R34 | Environment generation plus parent/artifact identities on recover/discard; no pattern cleanup. | P03 replaced artifact; P07 replaced stage/old generation; P08 stale export/reset. |
| R35 | Typed minimized local history/errors, no target text interpolation; bounded events and shared preview; no upload. | P03 forged/control text; P09 actual argv/environment/local/error/bundle scans. |

R01–R25 remain mapped through the complete scenario/requirement traceability.
An optional exclusion never waives an applicable mandatory boundary.

## Bounds and denial-of-service limits

[Dependency advisory review](DEPENDENCY_SECURITY_REVIEW.md) found zero known
vulnerabilities in npm's full/production graphs and the full Cargo.lock scan.
Five Rust informational warnings remain preserved; none of their package/version
pairs occurs in either actual production Windows graph. No advisory is ignored.
The recorded database commit and exact JSON are review evidence, not a source or
dependency security certification.

The review inspected actual caps: 16 KiB worker requests (2 KiB history), 2 MiB
worker replies, complete bounded enumeration (128 boxes/1024 process capacity),
128 file entries/page with a 16384 offset limit, 1 MiB streaming buffer, 1 TiB transfer ceiling, 64 transfer
receipts/reply, 512 history rows/30 days, 64 shared rows/32 KiB bundle, four queued
product requests/previews, four subscriptions and 32 foundation selections.
Worker jobs/deadlines and current single-operation/namespace locks bound execution;
cancellation remains independent of the held transfer gate. P07 exercises a
greater-than-4-GiB transfer and disk-full on an isolated limited NTFS volume;
P09 traverses all 10000 files across 79 pages and samples the whole manager job.
Caps may refuse unusually large scopes; refusal is explicit, never false Idle.

Permanent operation tombstones intentionally preserve at-most-once history. They
are not promised constant-size indefinite storage; larger/changed databases hit
documented journal bounds and require explicit maintenance/review. Process/engine
access-event streaming unavailable in the pinned adapter remains disabled, not
presented as a complete monitor. Bounded queues do not guarantee UI responsiveness
under every hostile workload.

## Exclusions, residual limits and release prerequisites

- Shared Windows kernel, original driver/service and approved dependencies remain
  trusted. A compromised administrator/unboxed same-user host, kernel exploits,
  physical access and all side channels are outside baseline claims.
- Ordinary desktop use does not promise complete clipboard/input/screenshot or
  every COM/protocol isolation. No clipboard/device restriction or paid privacy
  preset is advertised. Unsupported capabilities stay disabled with reasons.
- No product helper exists, so helper-only UAC/enrollment/different-administrator
  cases are N/A. Same-SID boxed attacks and metadata/root checks remain mandatory.
- The owner-selected labs do not certify an installed Windows 11 x64 release,
  every engine/app update, plugins or paid entitlement. Changes require revalidation.
- Standard mode retains documented non-blocked host visibility; virtualization,
  read protection and direct write grants remain distinct. Export is user-approved
  transfer of untrusted content and does not assert safety.
- Performance targets remain unchanged. Actual full-job deviations and user
  impact are recorded in the final P10 measurements; no workload/security waiver.
- P11 must close packaging, dependency/license inventory, reproducible installed
  build, upgrade/uninstall/retention and signing status. P12 must run the complete
  installed acceptance matrix. Neither is silently completed by this review.

P10 unresolved mandatory containment findings: **0** in the reviewed implemented
scope on the selected tuples. All applicable native gates passed. P11/P12 remain
release prerequisites; this closure is not an independent security certification.
