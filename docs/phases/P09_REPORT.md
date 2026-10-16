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

Current runtime/lab candidate: `2aef3c7e895418c1af11c055bee35e4113b76b19`.
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
| P09 Server reference workload | [38872735865](https://github.com/kurasis/SecureRun/actions/runs/38872735865), `be0b4c7`: ten environments, 10000 files, 60200 ms/234 samples, 93 UI assertions. Startup 5210.3185 ms and CPU 1.090117483% deviated; average working set 228568370 bytes met target. Four mandatory cases failed; ARM cancelled. |
| P09 latest Server full workload | [38879931585](https://github.com/kurasis/SecureRun/actions/runs/38879931585), `aa5b8f5`: 21 native cases and 95 UI assertions passed, including exact reviewed Save and all editor/archive/browser cases. Only the dependent transfer/lifecycle case failed: ProgramData export was correctly refused. Ten environments/10000 files/60118 ms; startup 4008.2433 ms and CPU 1.2475397684% deviated, average working set 230728418 bytes met target. ARM completed its full measurement and 95 UI assertions but failed sensitive export and browser welcome under Shell_SystemDialog. |
| P09 browser diagnostic | [38878700124](https://github.com/kurasis/SecureRun/actions/runs/38878700124), `784a4c9`: all four real cases passed on both targets; effective own-sandbox level 9. ARM exercised two bounded clipboard-busy waits. Diagnostic only; normal manager/workload gates remain. |
| P09 historical full workload | [38870280695](https://github.com/kurasis/SecureRun/actions/runs/38870280695): ARM completed ten environments, 10000 files, 60135 ms/223 samples of complete-job measurement and 93 UI assertions. Startup 2616.9734 ms and average working set 243431929 bytes met targets; CPU 1.143244435% deviated. Six mandatory cases failed; Server cancelled. Final matching full run pending. |
| P09 layout diagnostic | [38858563331](https://github.com/kurasis/SecureRun/actions/runs/38858563331): Server passed 7 native and 76 UI cases; ARM failed physical keyboard ownership while passing 76 UI cases |
| P09 focused diagnostic | [38869199205](https://github.com/kurasis/SecureRun/actions/runs/38869199205) at `7e62fd9`: both completed 93 UI assertions, 10000 files/79 pages and the actual synthetic target secret-isolation proof. Native diagnostic save failed on both; ARM keyboard/editor and three browser continuations also failed. Diagnostic only; 220 original JSON files retained. |

Targets are owner-selected Windows Server 2025 x64 and Windows 11 ARM64. Matching
regressions include actual x86 targets and emulated x64 on ARM. This is not final
installed Windows 11 x64 acceptance or certification of other engine/app versions.

GitHub credentials temporarily expired after dispatch of `8cc5e26`; public
artifacts remained readable anonymously. Authenticated API and Git access later
recovered, and all prepared reports/evidence were pushed. The phase is blocked
by actual final-source verification, not by an assumed successful result.

The `8cc5e26` full pin run 38877810087 was cancelled after newer native Save
and file-panel assertion corrections superseded it. Current source waits for
complete functional proof before final P03–P08 dispatch and formal P09 retention.
No protected source list is reduced, and cancelled runs cannot close a gate.

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
initial surfaces and requires actual invisibility. The observed `Shell_SystemDim` PickerHost overlay is also discovered explicitly
and hidden only after those same initial-process guards. ARM browser run
38873055280 identified that exact foreign surface at the physical point; the
fixture must still prove target ownership afterwards. No process is terminated.
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
The original failure was the post-acceptance close assertion, not a failed
filename write. Save dialogs now select Save explicitly rather than preferring
any descendant Open button; this correction awaits the Windows result.
Server full run 38872735865 confirmed an enabled native Save dialog and exact
filename write/readback, but NATIVE_IDOK did not close it. The current fixture
focuses the actual filename field, types and verifies the exact path, then uses
real Enter. The saved output must still exactly match the reviewed minimized
bytes; ARM focused run 38876095323 did positively save and compare the exact reviewed
bytes; Server still failed the older native keyboard preparation. The current
Save fixture uses the already-passing editor SendKeys sequence, with no preliminary
WM_SETTEXT, exact field focus/path verification and one Enter. Its final-source
result remains pending.

Reviewed real visible screenshots on both targets at `7ccda2b` reveal the
same official Firefox first-run Terms of Use/Privacy Notice modal above the
loaded canary page. The screenshots and original diagnostic JSON are retained.
PrintWindow's earlier branding-only surface did not establish readiness. At
`7a4000a`, neither target's UIA provider exposed the heading/notices/Continue;
no click was dispatched and the three continuation cases still failed.
The current fallback uses native Windows OCR over a freshly captured owned
synthetic window in memory, recognizes the exact heading, both notices and one
Continue, checks physical point ownership, clicks and positively observes the
heading disappear. OCR text and raw support content are never persisted.
The first Server OCR attempt reached result handling but failed a PowerShell
projection/property access before any click; the typed task result and bounded
projected collections are now handled explicitly. The welcome implementation
passed on Server at `9111127`: the exact heading/notices/unique Continue
were observed, the owned native click was dispatched and the welcome disappeared.
Actual main and child HTTP attribution and the browser-reachable boxed protocol
handler then passed; the effective own-sandbox level remained unobserved. A
current fallback recognizes the official about:support raw-copy button through
Windows OCR and reads its JSON transiently. Only the effective positive level
can pass; configured preferences cannot replace that observation. Server at `1dabb77` then positively read effective sandbox level 9 through
the exact official raw-copy control. Its separate protocol attempt failed during
clipboard Clear with ExternalException; this is not protocol escape evidence.
The current fixture waits at most two seconds only for the exact clipboard-busy
HRESULT, without replaying any browser action. ARM at `1dabb77` also passed the recognized welcome and actual main/child/
protocol containment, but failed its own-sandbox clipboard operation. Server at `8cc5e26`, run 38876817338, passed all four browser cases in one
diagnostic trial, including effective level 9. ARM and the final matching full
run remain pending. No browser sandbox
setting is changed. All child/protocol/effective-sandbox observations remain mandatory.

The synthetic target proof requires the newly observed dispatch in the exact
environment, its actual boxed marker, intended argument, absent inherited secret
and absent host marker. Typed refusal and held-process exit observations retain
actual failures without copying target arguments or raw target errors. The native
fixture explicitly creates its synthetic known-folder directory. All of this
still needs a complete passing final-source workflow.

Notepad++ editing and Save As passed on Server at `f9b719d`: the actual boxed
output was observed, exact bytes matched, and host input/output stayed unchanged.
Server repeated that exact save successfully in apps-only run [38858126567](https://github.com/kurasis/SecureRun/actions/runs/38858126567). That run also proved the controller cancelled two enrolled initial picker windows on ARM using scoped WM_CLOSE, but the subsequent editor/document point checks still failed. At `9df8149`, run 38874505825, ARM positively passed real manager keyboard/
UIA navigation and official editor edit/Save As, with actual target point/focus
ownership; Server passed those cases too. Final matching full results remain
pending. Both targets proved all 10,000 files on 79
pages with at most 128 entries and 127 DOM rows; all 88 UI assertions passed.
Firefox main-request/profile isolation and 7-Zip GUI round trips passed
historically on both targets. Neither SendKeys nor native scan-code navigation
produced the required browser continuation requests on Server. Run 38862241469
had no observed browser GUI and a live reporter associated with SandboxieRpcSs.exe;
no browser screenshot was produced. The current fixture reverts forced browser
accessibility. Its first-run UIA attempt and guarded OCR fallback are described
above; navigation uses native input. It uses native
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

ARM focused run 38876095323 reached import after its successful minimized Save.
The imported filename appeared, but the fixture checked the outer action-scope
legend (Files) instead of the selected file legend. The assertion now scopes the
actual file section, waits for an enabled exact filename and requires that
section's exact selected-file legend. Export/collision/archive/reset still need
complete actual results; this is not a waived assertion.

Server full run 38876095712 at `96159c8` passed 20 native cases, including all
four browser workflows, and 93 UI assertions. Its complete ten-environment/
10000-file/60227-ms workload measured startup 7028.298 ms (deviation), CPU
0.7393844823% and average working set 233778657 bytes (both targets met). Native
diagnostic Save failed and the dependent UI sequence was not reached. ARM
refused environment five with DIAGNOSTIC_SYSTEM_IMAGE_UNREVIEWED and a read-only
reporter association with SandboxieRpcSs.exe; no complete ARM sample exists for
that run. No fault reporter is terminated or trusted.

ARM browser-only `8cc5e26` passed main/child/protocol cases but native TypeText
declined during about:support entry. Current native metadata distinguishes the
pre-send foreground guard from incomplete SendInput. Only explicit zero-input
foreground rejection can reacquire focus before typing; no partial input,
Enter or protocol action is replayed. Both targets subsequently passed all four in the same diagnostic matrix at
`784a4c9`, run 38878700124, including effective level 9. The complete final-source
manager/workload gate remains pending.

At `aa5b8f5`, Server passed the native reviewed diagnostic Save in both focused
38879930769 and full 38879931585 runs. Both passed 95 UI assertions, including
actual imported-file selection. The full run also passed all official editor,
archive and four browser cases. The only failed case was the UI transfer/lifecycle
sequence: its folder picker selected the private ProgramData fixture, and the
production export guard correctly returned DESTINATION_SENSITIVE_SCOPE. No output
or downstream lifecycle success is inferred. The current lab selects a unique
ordinary owner-profile output folder, as the proven P07 lab does; the production
sensitive-destination guard is unchanged. It also checks the actual UI Complete /
OBSERVED state without an error before requiring a real file and matching SHA-256.
Both runners' 889 original reviewed JSON files are retained with exact hashes.

ARM at the same source also positively saved the exact reviewed diagnostic bytes
and passed all 95 UI assertions in both runs. The full run completed ten
environments/10000 files/60100 ms/223 complete-job samples: startup 2872.8287 ms
and average working set 239241041 bytes met target; CPU 1.2869004001% deviated.
It passed 16 native cases before the same sensitive export refusal and a separate
browser welcome failure: the physical point belonged to PickerHost's exact
Shell_SystemDialog surface. The owner controller acknowledged preparation but
found no eligible visible window through its existing lookups. The current
fixture adds this exact class to bounded discovery and the existing scoped Hide
branch. Same-user ownership, protected Microsoft installation/signature, exact
initial PID/creation time, no replacement enrollment, actual invisibility and
subsequent target point ownership remain required. No process is terminated.
The focused ARM run also failed startup UIA navigation; full startup UIA passed.
Neither failure is waived or inferred corrected without a fresh result.

Final matching editor save, all browser cases, actual manager keyboard and the
complete diagnostic/export/transfer/lifecycle UI sequence remain mandatory.
Historical successful constituent cases cannot replace that complete run. See the exact
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

The implementation is reviewable in [draft PR #10](https://github.com/kurasis/SecureRun/pull/10).
All project source, Markdown and reviewed evidence are published as authorized.
Generated binaries, credentials, raw support content and private machine
inventory stay excluded. Detailed superseded investigations are preserved in
[the investigation log](P09_INVESTIGATION_LOG.md). Next eligible phase: P10 only
after complete matching P09 proof, final reports and ordinary validated merge.
