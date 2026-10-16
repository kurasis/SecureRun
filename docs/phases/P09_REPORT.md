# P09 — Product UX and application compatibility

Status: IN_PROGRESS. Requested scope: full P09 only. P10–P12 are NOT_STARTED.
The P09 exit gate has not passed. [The manifest](../evidence/p09/manifest.json)
remains BLOCKED; final installed T01–T66 acceptance remains unrun until P12.

## Implemented behavior

The original product interface groups real environment state into Applications,
Processes, Files, Permissions, Activity and Retention/recovery. Activity and launch
eligibility are independent. Onboarding distinguishes missing, untrusted,
unavailable, restart-required, untested and verified engines, and explains
Standard-user service identity limitations. Mandatory rules are read-only;
uncertain outcomes direct the user to inspect recorded state before acting again.

English/Russian resources, light/dark/system themes, keyboard navigation, visible
focus and native WebView scaling at 100/150/200 percent are implemented. Lab
checks also change actual Windows DPI and inspect the live Windows accessibility
provider and Chromium accessibility tree. Complete filenames are shown inertly
with direction/control characters escaped; listing and selection never execute a
file. Metadata-only rename preserves identity, policy and generation and retains
an operation replay tombstone. Running policy changes require a reviewed diff,
explicit queue, whole-environment Stop and independently verified stopped Apply.

Private manager history accepts typed actions/outcomes and diagnostic IDs, keeps
at most 512 events for 30 days and labels unavailable persistence explicitly.
Shared diagnostics remove environment identities, accept no arbitrary renderer
body, require exact preview and an expiring one-use native Save selection, create
new files only, and never open/upload output. Completed enforcement diagnostics
retire definitions only after verified idle while retaining data and evidence;
failed diagnostics remain fenced. See [performance and diagnostics](../PRODUCT_PERFORMANCE_AND_DIAGNOSTICS.md).

The bounded read-only native observer holds authenticated immutable objects for
at most 60 seconds while independently checking fresh process/configuration/root
state on each frame. Mutation checks remain independent. WebView2 uses its public
low-memory target. The full reference measurement includes ten actual idle
environments, 10,000 files and at least 60 seconds of complete kernel-job CPU,
including exited workers and WebViews. Budget targets remain unchanged; measured
deviations require explicit user-impact explanations under specification
acceptance gate 7. Missing workloads and mandatory functional/security failures
still prevent completion.

## Current validation

Current runtime/lab candidate: `ace372e0cf3ff9e2a3f137d09d2ec27d2208eb66`.
Documentation-only descendants do not replace the required tested source.

| Check | Actual result |
|---|---|
| Repository/specification/evidence validator | Passed locally; current P01 run [38862141344](https://github.com/kurasis/SecureRun/actions/runs/38862141344) queued |
| Python tooling | 18 tests passed |
| TypeScript/frontend | Type check, 3 state/localization tests and 4 product tests passed |
| Windows-target Clippy and formatting | Passed after the inert path correction |
| Native product build at `f9b719d` | [38854501737](https://github.com/kurasis/SecureRun/actions/runs/38854501737): both targets passed, including 61 adapter tests, 4 native app tests with the independent COM-apartment regression, and the actual kernel-job measurement fixture |
| P03 historical `b04a766` | [38852271708](https://github.com/kurasis/SecureRun/actions/runs/38852271708), passed both; final matching source pending |
| P04 historical `b04a766` | [38852853178](https://github.com/kurasis/SecureRun/actions/runs/38852853178), passed both; final matching source pending |
| P05 historical `b04a766` | [38852275909](https://github.com/kurasis/SecureRun/actions/runs/38852275909), passed both; final matching source pending |
| P06 historical `b04a766` | [38852277993](https://github.com/kurasis/SecureRun/actions/runs/38852277993), passed both; final matching source pending |
| P07 historical `b04a766` | [38852280456](https://github.com/kurasis/SecureRun/actions/runs/38852280456), passed both; final matching source pending |
| P08 historical `b04a766` | [38852282413](https://github.com/kurasis/SecureRun/actions/runs/38852282413), passed both; final matching source pending |
| P09 full workload | [38862141330](https://github.com/kurasis/SecureRun/actions/runs/38862141330), queued |
| P09 layout diagnostic | [38858563331](https://github.com/kurasis/SecureRun/actions/runs/38858563331): Server passed 7 native and 76 UI cases; ARM failed physical keyboard ownership while passing 76 UI cases |
| P09 focused diagnostic | [38862025457](https://github.com/kurasis/SecureRun/actions/runs/38862025457) at `2570dc6`, queued; cannot close the full gate |

Targets are owner-selected Windows Server 2025 x64 and Windows 11 ARM64. Matching
regressions include actual x86 targets and emulated x64 on ARM. This is not final
installed Windows 11 x64 acceptance or certification of other engine/app versions.

## Findings and remaining exit gate

All six P03–P08 regressions passed on both targets at `ec2a16b`, `cf6edad`, `4956792` and `b04a766` (P04 via unchanged-source
repeat 38852853178).
Reviewed immutable JSON and hashes retain those results as historical evidence;
they cannot replace final matching-source checks after subsequent changes.

The T63 omission was a real inert-I/O defect: final/long filename buffers used the
strict engine/INI text decoder and skipped names containing direction controls.
Only the validated inert source-path branch now decodes those bounded UTF-16
buffers directly. Exact native path equality, fixed NTFS, root ownership,
reparse/hardlink refusal and held identity checks remain. A real Windows test
passed on both architectures, including strict engine/output-name refusal.

Initial ARM shell surfaces obstruct physical input even in a separate synthetic
WinForms probe. Packed and structured native point calls agree, while UIA finds
the intended control. Neither COM apartment isolation nor temporary native input
queue attachment supplied passing ARM input proof. Closing authenticated
`WWAHost` revealed Start/search surfaces; `SearchHost` ignored WM_CLOSE.

Current preparation accepts only four fixed initial Microsoft component names,
protected installation paths, same-user ownership and exact PID/creation time.
Before product startup it also authenticates hidden instances for later bounded
cancellation; replacements are never enrolled during product execution. Picker
and web-host windows receive UIA Close or scoped WM_CLOSE when unsupported. Initial
Start/search surfaces receive ordinary window minimization with actual
hidden/iconic-state verification. Preparation has at most four passes and each
z-order scan is cycle-checked and bounded. Actor requests carry no path, PID or
command. The intended product/app window and physical point must independently
pass their original ownership/focus checks afterwards. Actual final proof is
pending; no foreign input surface is accepted. No process is terminated by this
preparation. Display setup collapses both owned selection lists before leaving
Settings.

Server run [38859910487](https://github.com/kurasis/SecureRun/actions/runs/38859910487)
confirmed a real UI race: application selection was enabled before the selected
environment had loaded. The button now waits for the loaded environment. The
actual EXE picker and registration passed; the synthetic target marker remained
absent. Current fixture proof requires the newly observed dispatch in the exact
environment, waits for its output, and explicitly creates the target's own
synthetic known-folder directory rather than assuming host-to-box folder mapping.
Original byte/inheritance/host-output checks remain mandatory.

Notepad++ editing and Save As passed on Server at `f9b719d`: the actual boxed
output was observed, exact bytes matched, and host input/output stayed unchanged.
Server repeated that exact save successfully in apps-only run [38858126567](https://github.com/kurasis/SecureRun/actions/runs/38858126567). That run also proved the controller cancelled two enrolled initial picker windows on ARM using scoped WM_CLOSE, but the subsequent editor/document point checks still failed. The ARM workflow remains pending. Both targets proved all 10,000 files on 79
pages with at most 128 entries and 127 DOM rows; all 88 UI assertions passed.
Firefox main-request/profile isolation and 7-Zip GUI round trips passed
historically on both targets. Neither Windows SendKeys nor native scan-code
navigation produced the required browser continuation requests on Server. Current
diagnostics capture only the clean synthetic browser window, never raw about:support
content, to inspect the actual chrome and focus. Final matching editor save, browser child/protocol/own
sandbox, ARM physical keyboard and the dependent
secret/export/transfer/lifecycle UI sequence remain mandatory. See the exact
[application matrix](../APPLICATION_COMPATIBILITY.md).

No numerical performance target is claimed met by compilation or a focused run.
No failed/cancelled run is relabelled successful. No browser sandbox, Windows
security setting, TLS/signature/checksum verification or broad engine exception
is weakened. No engine is bundled. Native incoming sockets explicitly restore
blocking mode on acceptance; delayed-request regression passed on both targets.

All project source, Markdown and reviewed evidence are published as authorized.
Generated binaries, credentials, raw support content and private machine
inventory stay excluded. Detailed superseded investigations are preserved in
[the investigation log](P09_INVESTIGATION_LOG.md). Next eligible phase: P10 only
after complete matching P09 proof, final reports and ordinary validated merge.
