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

Current runtime/lab candidate: `4a98aa48e281064781cc43e21e751ccb355971a2`.
Documentation-only descendants do not replace the required tested source.

| Check | Actual result |
|---|---|
| Repository/specification/evidence validator | Passed locally; P01 run [38864957204](https://github.com/kurasis/SecureRun/actions/runs/38864957204) passed |
| Python tooling | 18 tests passed |
| TypeScript/frontend | Type check, 3 state/localization tests and 4 product tests passed |
| Windows-target Clippy and formatting | Passed after the inert path correction |
| Native product build at `f9b719d` | [38854501737](https://github.com/kurasis/SecureRun/actions/runs/38854501737): both targets passed, including 61 adapter tests, 4 native app tests with the independent COM-apartment regression, and the actual kernel-job measurement fixture |
| P03 historical `f4c4603` | [38865143592](https://github.com/kurasis/SecureRun/actions/runs/38865143592), both targets passed; final matching source pending |
| P04 historical `f4c4603` | [38865145944](https://github.com/kurasis/SecureRun/actions/runs/38865145944), both targets passed; final matching source pending |
| P05 historical `f4c4603` | [38865148521](https://github.com/kurasis/SecureRun/actions/runs/38865148521), both targets passed; final matching source pending |
| P06 historical `f4c4603` | [38865151731](https://github.com/kurasis/SecureRun/actions/runs/38865151731), both targets passed; final matching source pending |
| P07 historical `f4c4603` | [38865154061](https://github.com/kurasis/SecureRun/actions/runs/38865154061), both targets passed; final matching source pending |
| P08 historical `f4c4603` | [38865156468](https://github.com/kurasis/SecureRun/actions/runs/38865156468): Server 38 passed; ARM 30 passed, 8 failed after an unreviewed system image; final matching source pending |
| P09 full workload | [38870280695](https://github.com/kurasis/SecureRun/actions/runs/38870280695), pending |
| P09 layout diagnostic | [38858563331](https://github.com/kurasis/SecureRun/actions/runs/38858563331): Server passed 7 native and 76 UI cases; ARM failed physical keyboard ownership while passing 76 UI cases |
| P09 focused diagnostic | [38869199205](https://github.com/kurasis/SecureRun/actions/runs/38869199205) at `7e62fd9`: both completed 93 UI assertions, 10000 files/79 pages and the actual synthetic target secret-isolation proof. Native diagnostic save failed on both; ARM keyboard/editor and three browser continuations also failed. Diagnostic only; 220 original JSON files retained. |

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

Initial ARM shell surfaces obstructed physical input even in a separate synthetic
WinForms probe. Packed and structured native point calls agree. A fresh diagnostic
at `9c7a965`, run [38864772499](https://github.com/kurasis/SecureRun/actions/runs/38864772499),
positively verified native point ownership, actual foreground and exact keyboard
text on both native architectures. This fixture result cannot replace the real
manager keyboard or application gates, which remain pending at the final source.

Current preparation accepts only four fixed initial Microsoft component names,
protected installation paths, same-user ownership and exact PID/creation time.
The long-lived controller independently enrolls initial instances before product
startup; the temporary cleaner cannot transfer its identity set. Fixed immersive
window-class lookup supplements desktop/thread enumeration. Replacements are
never enrolled during product execution. Picker/web-host windows receive UIA
Close or scoped WM_CLOSE when unsupported. Ordinary minimization did not release
Start/search hit testing; the current fixture hides only those authenticated
initial surfaces and requires actual invisibility. No process is terminated.
Preparation has at most four passes and all enumeration is bounded. Actor requests
carry no path, PID or command. The intended product/app window, physical point and
focus must independently pass their original checks afterwards. Display setup
collapses its owned selection lists before leaving Settings. No security setting
or foreground policy is changed.

Server run [38859910487](https://github.com/kurasis/SecureRun/actions/runs/38859910487)
confirmed application selection could be enabled before environment metadata loaded.
The button now waits for that metadata. The real EXE picker and registration passed.
A later exact-dispatch check exposed `REVISION_CONFLICT`: the fixture selected the
first Run inside the containing environment article, rather than the named app row.
It now requires one exact app row. The production interface also used a stored
application revision for launch after policy changes. It now supplies the loaded
current environment revision, retaining backend CAS refusal and requiring loaded
metadata before enabling launch. No mutation is retried automatically.

At `7e62fd9`, both targets positively observed the corrected fresh launch,
its held-process exit code 41, its boxed marker and absent host marker. The
argument was received and the inherited environment secret was absent; local
history and captured manager errors remained minimized. Both completed all
10000 files over 79 pages and 93 frontend assertions. Native diagnostic Save
failed before the dependent import/export/archive/reset sequence. Its current
fixture waits for an enabled owned dialog, verifies the selected filename, and
uses verified native keyboard input if direct filename messaging is refused.
The saved output must still exactly match the reviewed minimized bytes.

A real visible Server screenshot at `7ccda2b` revealed the official Firefox
first-run Terms of Use/Privacy Notice modal above the loaded canary page. This
explains that run's blocked address/navigation controls; PrintWindow's earlier
branding-only surface did not establish browser readiness. A diagnostic now
recognizes the exact welcome heading, both notices and one enabled Continue
through the real UIA provider, observes available diagnostic choices off, then
requires the heading to disappear. It changes no browser sandbox setting and
cannot replace the mandatory child/protocol/effective-sandbox observations.

The synthetic target proof requires the newly observed dispatch in the exact
environment, its actual boxed marker, intended argument, absent inherited secret
and absent host marker. Typed refusal and held-process exit observations retain
actual failures without copying target arguments or raw target errors. The native
fixture explicitly creates its synthetic known-folder directory. All of this
still needs a complete passing final-source workflow.

Notepad++ editing and Save As passed on Server at `f9b719d`: the actual boxed
output was observed, exact bytes matched, and host input/output stayed unchanged.
Server repeated that exact save successfully in apps-only run [38858126567](https://github.com/kurasis/SecureRun/actions/runs/38858126567). That run also proved the controller cancelled two enrolled initial picker windows on ARM using scoped WM_CLOSE, but the subsequent editor/document point checks still failed. The ARM workflow remains pending. Both targets proved all 10,000 files on 79
pages with at most 128 entries and 127 DOM rows; all 88 UI assertions passed.
Firefox main-request/profile isolation and 7-Zip GUI round trips passed
historically on both targets. Neither SendKeys nor native scan-code navigation
produced the required browser continuation requests on Server. Run 38862241469
had no observed browser GUI and a live reporter associated with SandboxieRpcSs.exe;
no browser screenshot was produced. The current fixture reverts forced browser
accessibility and avoids optional cross-box COM/UIA interaction. It uses native
captions and real keyboard input, while retaining all actual HTTP, protocol and
sandbox-level requirements. Synthetic clipboard readback is diagnostic only; no
shared clipboard capability is assumed. ASCII URI keys use the browser thread's
existing keyboard layout when Unicode readback is absent. Manager UIA/screen-reader checks remain mandatory. The diagnostic
captures only a clean synthetic browser window, never raw about:support content.
The current diagnostic selects a captioned browser frame, records bounded native
responsiveness and places only that owned window inside the visible work area.
Browser-only mode uses one real online environment and four browser cases; it is
explicitly partial and cannot satisfy the full retainer. All 22 mandatory full
cases and native checks remain unchanged in the default workflow.

Server focused run 38862025457 ended its complete file-page observation with a
SocketException before the secret/export sequence; no UI assertion failed. The
observer now gives the bounded full traversal a separate deadline and records
socket kind and elapsed failure time. First-page measurement and original page/
DOM bounds remain unchanged. An extended observer deadline does not establish full-workload completion.

Final matching editor save, browser child/protocol/own
sandbox, ARM physical keyboard and the dependent
secret/export/transfer/lifecycle UI sequence remain mandatory. See the exact
[application matrix](../APPLICATION_COMPATIBILITY.md).

No numerical performance target is claimed met by compilation or a focused run.
No failed/cancelled run is relabelled successful. No browser sandbox, Windows
security setting, TLS/signature/checksum verification or broad engine exception
is weakened. No engine is bundled. Native incoming sockets explicitly restore
blocking mode on acceptance; delayed-request regression passed on both targets.

Read-only WER classification retains only fixed component/module labels, exception
codes and report kinds after actual failures. It reads bounded current-lab metadata
and supplies no authority to terminate or trust a process. Full reports, paths,
arguments and owner identities are excluded.

All project source, Markdown and reviewed evidence are published as authorized.
Generated binaries, credentials, raw support content and private machine
inventory stay excluded. Detailed superseded investigations are preserved in
[the investigation log](P09_INVESTIGATION_LOG.md). Next eligible phase: P10 only
after complete matching P09 proof, final reports and ordinary validated merge.
