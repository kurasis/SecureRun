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

Current runtime/lab candidate: `284db7030fcbb5e28712dd4b7cc209ab9f08953d`.
Documentation-only descendants do not replace the required tested source.

| Check | Actual result |
|---|---|
| Repository/specification/evidence validator | Passed locally and in P01 run [38851310872](https://github.com/kurasis/SecureRun/actions/runs/38851310872) |
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
| P09 full workload | [38858563360](https://github.com/kurasis/SecureRun/actions/runs/38858563360), pending |
| P09 focused diagnostic | [38858567312](https://github.com/kurasis/SecureRun/actions/runs/38858567312), pending; cannot close the full gate |

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

On ARM, Windows PickerHost obstructed physical input. The controller successfully
proved same-user protected Microsoft ownership and cancelled it with UIA; the
component later reappeared. The current fixture explicitly collapses the owned Settings selection lists and
checks same-user identity before any foreign process-birth
query so the standard user can delegate an inaccessible Windows picker. It
permits bounded cancellation only
of a PID/creation time enrolled before product GUIs exist, with fresh trust and
owner checks. It accepts no actor-supplied path, PID or command and must then
positively re-establish the intended window/point ownership. Product dialogs,
unknown/replacement processes and process termination are excluded. This recurring
path still needs actual passing proof.
The bounded z-order/foreground enumeration found a second surface omitted from
EnumWindows, whose advertised UIA Close threw NotImplementedException. Only that
unsupported-method case falls back to exact-window WM_CLOSE after fresh checks.
The result must actually disappear. Current display setup also collapses and
verifies both selection popups before minimizing Settings.

Notepad++ editing and Save As passed on Server at `f9b719d`: the actual boxed
output was observed, exact bytes matched, and host input/output stayed unchanged.
The ARM workflow remains pending. Both targets proved all 10,000 files on 79
pages with at most 128 entries and 127 DOM rows; all 88 UI assertions passed.
Firefox main-request/profile isolation and 7-Zip GUI round trips passed
historically on both targets. Final matching editor save, browser child/protocol/own
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
