# P09 — Product UX and application compatibility

Status: IN_PROGRESS. The [P09 manifest](../evidence/p09/manifest.json) is BLOCKED.
Requested scope is full P09 only; P10–P12 remain NOT_STARTED. Final installed
T01–T66 acceptance is reserved for P12 and remains unrun.

Current runtime/lab candidate: `f9a9755a4e32bac27ef65ad9e4b5fdca32f7a67f`.
Documentation-only descendants do not replace the tested source. The implementation
and reviewed evidence are published in [draft PR #10](https://github.com/kurasis/SecureRun/pull/10).

## Implemented behavior and principal files

The original native interface presents Applications, Processes, Files, Permissions,
Activity and Retention/recovery using real backend state. Activity and launch
eligibility are independent. Onboarding explains engine availability/trust,
restart requirements, enforcement verification and Standard-user service-identity
limits. Mandatory rules are read-only. Uncertain outcomes require inspection of
recorded state before another action. English/Russian resources, keyboard access,
visible focus, themes and 100/150/200 percent scaling are implemented in
[the interface](../../ui/main.tsx), [resources](../../ui/strings.ts) and
[product presentation](../../ui/product.ts).

[Application controls](../../ui/controls.tsx) require loaded environment metadata
and supply its current revision for launch; backend CAS refusal remains mandatory.
[File views](../../ui/files.tsx) show complete inert escaped filenames, bounded
pages, explicit imports/exports and rename-or-skip collisions. Metadata rename
preserves policy/generation and stores a replay tombstone. Running policy changes
require a reviewed diff, explicit queue, whole-environment Stop and independently
verified stopped Apply. Archive/reset use native scoped confirmation.

[Native product commands](../../src-tauri/src/product.rs) and
[adapter product state](../../crates/sandboxie-adapter/src/windows/provisioning/product.rs)
provide bounded history, observation and diagnostics. Private history accepts typed
fields, retains at most 512 events for 30 days and labels unavailable persistence.
Shared diagnostics remove environment identities, limit events/bytes, require exact
preview and an expiring one-use Save token, create new files only and never
open/upload output. [Native pickers](../../src-tauri/src/native.rs) use a fresh
thread with the actual parent window. Synthetic argv/environment/error canaries
are checked against saved output, local history and UTF-8/UTF-16 captures.

The read-only observer holds authenticated immutable objects for at most 60 seconds,
independently checking fresh driver/process/configuration/root state each frame.
Mutations repeat their own guards. WebView2 uses its public low-memory target and
normal rendering defaults. Complete kernel-job accounting includes exited manager
workers/WebViews and excludes targets/engine. Completed enforcement diagnostics
retire definitions only after verified idle, retaining data and bounded evidence;
failed diagnostics remain fenced.

The [native lab](../../tools/lab/Invoke-P09.ps1),
[actor](../../tools/probe/p09_standard.ps1),
[UI workflows](../../tools/probe/p09_ui.js),
[accessibility/input fixture](../../tools/probe/p09_accessibility.ps1) and
[Windows OCR fixture](../../tools/probe/p09_ocr.ps1) exercise the real release
application. Diagnostic modes are explicitly partial. The
[formal retainer](../../tools/lab/retain_p09_evidence.py) requires a complete
successful run on both targets and matching P03–P08 evidence; all protected source
lists include the current tools.

## Actual validation

| Check | Result |
|---|---|
| Original specification, links, evidence and 66 unrun acceptance entries | Repository validator passed locally; current P01 [38884409654](https://github.com/kurasis/SecureRun/actions/runs/38884409654) passed |
| Python tooling | 18 tests passed |
| Frontend | Type check, 3 state/localization tests and 4 product tests passed after the launch revision correction |
| Latest fixture changes | JavaScript syntax, PowerShell parser and native C# compilation passed locally; these are not Windows execution proof |
| Native product build | Both targets passed 61 adapter and 4 app tests at `f9b719d`, [38854501737](https://github.com/kurasis/SecureRun/actions/runs/38854501737); fresh STA regression included |
| Browser-only `784a4c9` | [38878700124](https://github.com/kurasis/SecureRun/actions/runs/38878700124): all four actual cases passed on both, effective content sandbox level 9; diagnostic only |
| Full `aa5b8f5` | [38879931585](https://github.com/kurasis/SecureRun/actions/runs/38879931585): Server 21 native/95 UI passed, one failed case; ARM 16 native/95 UI passed before two failed cases and abort |
| Focused `aa5b8f5` | [38879930769](https://github.com/kurasis/SecureRun/actions/runs/38879930769): Server 20 native/95 UI passed; ARM 14 native/95 UI passed, with startup UIA, export destination and browser welcome failures |
| First full `217f550` | [38885567690](https://github.com/kurasis/SecureRun/actions/runs/38885567690): ARM refused environment four with DIAGNOSTIC_SYSTEM_IMAGE_UNREVIEWED; no full sample. Server later cancelled after the confirmed confirmation-fixture correction. |
| Latest focused `217f550` | [38885566833](https://github.com/kurasis/SecureRun/actions/runs/38885566833): ARM passed 20 native cases and 98 UI assertions, including export/collision rename and all four browser cases. Only native Archive confirmation failed; superseded Server cancelled after 88 UI assertions before transfers. |
| Full `0071e2c` | [38887959409](https://github.com/kurasis/SecureRun/actions/runs/38887959409): both completed reference measurements. Server 21 native/99 UI passed; next confirmation not observed. ARM completed the real transfer/lifecycle chain and all 101 UI assertions, but archive exit timed out and browser welcome hit an unidentified foreign surface. |
| First full `f9a9755` | [38891751077](https://github.com/kurasis/SecureRun/actions/runs/38891751077): ARM refused environment eight with DIAGNOSTIC_SYSTEM_IMAGE_UNREVIEWED and unassociated WerFault; no full sample. Server pending. |
| Fresh full `f9a9755` | [38894071449](https://github.com/kurasis/SecureRun/actions/runs/38894071449): unchanged exact source on a fresh matrix, pending. |
| P03 exact-source regression | [38893325430](https://github.com/kurasis/SecureRun/actions/runs/38893325430): both native targets and portable job passed; each native target passed 19 foundation/4 app/3 frontend/32 command cases. Formal original evidence retained. |
| P04 exact-source regression | [38893328564](https://github.com/kurasis/SecureRun/actions/runs/38893328564): both targets passed 61 adapter tests and 19 native observation/trust cases; original formal evidence retained. |
| P05–P08 exact-source regressions | Running at the same immutable candidate; final matching success remains required |

Both `aa5b8f5` runners positively saved the exact reviewed diagnostic JSON through
the real native picker and observed the actual imported file. Server also passed
the official editor/archive and all four browser workflows in the full run.
The transfer/lifecycle case selected the lab-private ProgramData export folder;
the product correctly refused DESTINATION_SENSITIVE_SCOPE. No export or downstream
lifecycle success is inferred. The current fixture selects a unique ordinary
owner-profile folder and requires actual UI Complete/TRANSFER_COMPLETED_UNTRUSTED without an error,
then verifies real output hashes and unchanged original data.

ARM browser welcome failed a real physical point guard: the hit belonged to an
initial PickerHost Shell_SystemDialog surface. The controller acknowledged cleanup
but existing lookups did not discover that window. The current lab adds the exact
class to bounded discovery and scoped Hide after the same user, protected Microsoft
image/signature and enrolled PID/creation-time checks. Replacements are never
enrolled during product execution. Actual invisibility and subsequent target point
ownership remain required. No process is terminated. The focused startup UIA
failure remains recorded; full startup UIA passed. Fresh results are mandatory.

All 889 original reviewed JSON files from these two matrix runs are retained with
exact committed-byte hashes. Detailed earlier findings, failed trials, cancellation
reasons and the prior report snapshot remain in the
[investigation log](P09_INVESTIGATION_LOG.md) and manifest history. No failed,
cancelled, diagnostic-only or earlier-source result closes the final gate.

The latest focused ARM `217f550` run positively passed exact diagnostic Save,
import, exported SHA-256, collision rename preserving original bytes, real keyboard/
DPI, editor/archive workflows and all four browser cases. All 98 UI assertions passed.
Only the transfer/lifecycle case failed at its first Archive confirmation: the
exact environment and retention text were available, but the immediate UIA OK
lookup was absent/disabled. The current fixture uses the P08-proven rfd
MessageBoxW IDOK notification after bounded exact-text, direct owner, native
class, parent/button identity and enabled/visible checks. It dispatches once and
requires actual closure before the independent backend state check. No native
confirmation or destructive backend guard is bypassed. Original JSON is retained.

The first full `217f550` ARM attempt refused environment four before the reference
workload. Read-only CIM observed WerFault without a verified component association;
no cause is inferred. No reporter is killed, trusted or exempted. Its original
JSON is retained. That run's remaining Server job and the fresh matrix
38887488001 on `verify/p09-217f550` were cancelled after the actual confirmation
failure required a fixture correction. The pin is superseded and cannot close a
gate. Current full/focused runs use `0071e2c`; final matching P03–P08 regressions
remain required.

Full `0071e2c` positively completed import/export SHA-256, collision rename,
Archive/Unarchive/Reset with native UUID/retention confirmation, generation change,
empty reset root and unchanged host data on ARM. All 101 UI assertions passed.
Server passed 99 assertions and actual Archive, but the next native confirmation
was not observed. Its fixture checked button.disabled, which does not include an
ancestor disabled fieldset. It now waits on actual :disabled state for both click
and completion, requiring both expected lifecycle actions to exist. Confirmation
lookup accepts only the exact known title and records separate found/title flags.
This fixes a definite fixture predicate defect; fresh results must establish the
complete Server workflow.

ARM's separate official archive case timed out, then browser welcome encountered
an unidentified foreign window at the physical point. The archive's saved exit
record belonged to its earlier successful step; the current fixture records
create/extract separately and saves the current typed failure before rethrowing.
Its 45-second held-process wait, actual output/hash requirements and browser point
ownership guards remain unchanged. No cause is inferred for the unknown owner,
no unknown window is hidden and no new process exception is accepted. All 680
original reviewed JSON files from the failed full matrix are retained.

## Measured budgets and remaining risks

Both full `aa5b8f5` and `0071e2c` matrices completed ten actual idle environments, 10,000 files and
more than 60 seconds of complete kernel-job CPU accounting, including exited
workers/WebViews. Targets remain unchanged.

| Runner | Startup ms / target ≤3000 | CPU % / target <1 | Average working set bytes / target <250000000 |
|---|---:|---:|---:|
| Server x64 | 4008.2433 — deviation | 1.2475397684 — deviation | 230728418 — met |
| Windows 11 ARM64 | 2872.8287 — met | 1.2869004001 — deviation | 239241041 — met |
| Server x64, `0071e2c` | 5848.2869 — deviation | 0.7398902124 — met | 230532884 — met |
| Windows 11 ARM64, `0071e2c` | 2411.0373 — met | 1.2273387172 — deviation | 244125310 — met |

Slower startup delays interactive controls. Higher idle CPU can increase power use.
These are measured deviations under specification acceptance gate 7; they do not
waive a mandatory workflow or missing workload. See
[performance and diagnostic limits](../PRODUCT_PERFORMANCE_AND_DIAGNOSTICS.md),
[application matrix](../APPLICATION_COMPATIBILITY.md) and
[accessibility report](../PRODUCT_UX.md).

Targets are owner-selected Windows Server 2025 x64 and Windows 11 ARM64. Matching
regressions include actual x86 targets and emulated x64 on ARM. This does not
certify an installed Windows 11 x64 release tuple, other engine/application
versions, paid entitlement, plugins or future updates. No browser sandbox, Windows
security setting, TLS, signature or checksum check is weakened; no engine is bundled.
GitHub authentication recovered after temporary expiry; publication is working.

## Remaining exit gate

Complete actual export/collision/archive/reset and every application/accessibility
case on both targets at the final source. Freeze that source, execute P03–P08 on
the same commit, retain evidence in dependency order and complete the full P09
retainer. Then update the final reports/status and perform ordinary validated
merge. No protected source list is reduced to reuse stale results.

Commands used include `python tools/lab/validate_repository.py`,
`python -m unittest discover -s tests -q`, `npm run check`, `npm test`,
`npm run test:product`, `node --check tools/probe/p09_ui.js`, native fixture
parser/compiler checks and the linked Windows Actions workflows. Only actual
Windows runs establish native behavior. Next eligible phase is P10 after P09;
P10 implementation is outside the current request.
