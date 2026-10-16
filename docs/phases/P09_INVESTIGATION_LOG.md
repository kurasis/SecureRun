# P09 investigation history

This chronological log preserves earlier findings and superseded approaches.
The current phase result is [P09_REPORT.md](P09_REPORT.md). Failed or cancelled
runs do not supply completion proof.

# P09 — Product UX and application compatibility

Status: IN_PROGRESS. Requested scope: full P09 only.
Dependency: P08 passed on both owner-selected Windows targets; its exact-source
proof remains historical while P09 changes are validated.

## Current gate result (2026-10-16)

P09 is not complete. All source changes are published for Windows validation;
reviewed investigation files are retained with exact byte hashes. Native build
`38837984419` passed on both owner-selected targets at `8b3cfeb`, including the
delayed incoming-socket regression after the Winsock mode correction.

Full run `38839426236` at `f2ebba3` completed ten actual idle environments and
10,000 files on both targets. Server measured 5503.9137 ms startup, 0.753328196%
CPU and 229493149-byte average aggregate working set. ARM measured 2362.7337 ms,
1.220673525% and 245477794 bytes. Server startup and ARM CPU are engineering
budget deviations, with user impact in the performance report. The original
acceptance gate requires complete measurements and explained deviations; the
next lab revision records these separately from functional/security case results.

Both targets passed the actual picker, running policy diff/queue, explicit Stop
and independently verified stopped Apply. Both then reached a 126-row file page;
the fixture incorrectly demanded exactly 128 instead of at most 128. The next
revision retains complete unique traversal of all 10,000 files and bounded pages.
Archive GUI round trips, primary browser host-instance isolation, persistent
history, bilingual layouts and actual Windows scaling have passed.

Remaining mandatory proof includes the complete file/transfer/lifecycle and
secret/export sequence, ARM keyboard input ownership, editor Save As, browser
child/protocol/about:support actions, and matching P03–P08 final-source regression.
New native input, exact dialog-field and measurement-report fixes remain under
Windows validation. No failed historical result is relabeled successful.
P10 remains NOT_STARTED; final T01–T66 installed acceptance remains P12.

## Implementation underway

The product groups real owned environments into Applications, Processes, Files,
Permissions, Activity and a separate Retention/recovery area. Activity and current
launch eligibility remain independent. Onboarding distinguishes missing,
untrusted, unavailable, restart-required, untested and verified engine states.
EN/RU appearance preferences remain presentation-only and grant no engine rights.

A bounded private history stores typed manager actions/outcomes, timestamps and
diagnostic IDs, with optional local environment identities. Shared diagnostics
exclude those environment identities and all paths, arguments, external error
text, certificate data and file contents. The exact bundle is shown before a
single-use, 60-second native Save choice; existing output is never replaced.
History retains at most 512 events for 30 days. Engine access auditing is not
claimed. Unverified context exposes session history without opening a persistent
production profile.

Permission edits can be queued in backend memory with their native selection
leases. They remain unapplied until an explicit fresh apply, complete stopped
scope and original policy checks. Selections expire after 60 seconds and are not
restored after restart. No automatic policy apply or launch replay is introduced.

## Implemented outputs

- [Product UX and accessibility](../PRODUCT_UX.md).
- [Application compatibility matrix](../APPLICATION_COMPATIBILITY.md).
- [Performance and minimized diagnostics](../PRODUCT_PERFORMANCE_AND_DIAGNOSTICS.md).
- Normal release Windows lab: `.github/workflows/p09.yml`, `Invoke-P09.ps1`,
  official hashed application fixtures and actual UIA/browser/job-accounting probes.
- Strict evidence retainer and repository gate reject missing cases, wrong native
  architectures, stale sources, exceeded budgets and missing matching regressions.

## Checks so far

Local frontend build, three foundation UI tests and four product helper tests pass.
The repository validator and 18 tooling tests pass. Portable Rust tests, Windows
adapter metadata Clippy and PowerShell/C# compile checks are recorded separately
from native execution. Earlier product builds passed on both Windows targets at
`ef2c4bd85830b6e1a486c0646e4e2e045f74a811` (Actions `38773439542`).
Full native product lab `38782723570` was submitted at
`53c8e58c1e4866fa02a417b44697e65443cbc2b9`; both release builds passed, then fixture setup failed because a script variable
conflicted with PowerShell HOME. No native product case executed. Original stage
JSON is retained under `investigation-53c8e58`; the fixture variable is renamed.

The subsequent run `38785005254` at `8a396083d79403ccca35a623beb5cef99ad7305f`
verified official application packages/signatures and prepared normal release
binaries on both targets. Each standard-user actor was refused by the backend
during fixture environment seeding. No product UX case completed. The immutable
structured results remain in `investigation-8a39608`; fixture diagnostics now
retain only the bounded backend refusal code and numeric seed position.

A subsequent run `38787517417` at `53410943b28f54b8dfb2859446f0a5bf1950ee6d`
identified Server refusal `SIBLING_RECONCILIATION_REQUIRED` at environment 06 and
ARM refusal `NETWORK_ENFORCEMENT_FAILED` at environment 03. Both raw structured
investigations are retained. The fixture now retains existing minimized native
probe result/status/evidence reports for the network investigation.

A deterministic portable regression reproduced different mandatory sibling denial
ordering during rollout and after the SQLite UUID-ordered listing. Canonical
ordering fixes it without changing rule membership or granting access. A second
regression creates ten environments and revalidates every existing policy after
each creation. The adapter's 40 portable tests pass; native validation is pending.
The reference workload also requires more than 64 architecture-specific retained
diagnostics. The bound is now 256. Successfully verified private diagnostic
definitions retire after fresh identity/configuration/automation/idle checks;
root data and audit records remain, and the saved synthetic report is checked
unchanged. Failed diagnostics stay fenced. P09 verifies these actual boundaries.

Intermediate P03 run `38786046681` at `8b71cae6d9188e9d16986486893b1f5ce4c2ff74`
passed on both targets: 19 foundation tests, 3 normal native tests, 3 foundation UI
tests and 32 actual command-boundary cases. It is historical, not matching final
source proof. Current product/native jobs are running at
`c5cd614f7b98485a287cc6d489b649e095dd4157` (`38789783607` and `38789783651`).

Both native product builds at `c5cd614f7b98485a287cc6d489b649e095dd4157`
passed 52 adapter tests per target. The full run `38789783651` reached environment
08 on Server, then hit the 120-second policy deadline. ARM environment 03 failed
an unboxed endpoint positive control before that canary was dispatched. Original
minimized numeric/boolean probe reports remain in `investigation-c5cd614`.
No product UX case completed. The next run uses a bounded 600-second full-rollout
deadline, a three-second unboxed control handshake with no request retry, and
safe endpoint-kind/stage/numeric failure evidence. Partial actor results are now
retained even on an actor timeout. Current runs at
`ce6098f1cad4cc36aa1dacaf96aaeb0628c94bae` are `38792628918` (build) and
`38792629133` (full native lab).

## Validation pending

Required native P09 proof: T30, T32, T41, T63 and T66; actual app versions and hashes;
keyboard/screen-reader semantics, themes, scaling and measured manager resource
budgets across Rust/UI/WebView processes. Matching P03/P04 regressions passed on both targets at `ce6098f`;
P05–P08 remain pending. Compile-only checks do not close the production phase gate.

P10 is eligible only after P09 closes. Packaging remains P11 and installed-candidate
acceptance remains P12. Original specification and acceptance entries are unchanged.

## Native display-scaling investigation

The actual Windows Settings provider exists on both hosted runners. Initial
discovery run `38794729595` passed. Run `38794886663` selected 100 percent and
observed 96 DPI, but the initial visible dropdown exposed only 100/125 percent.
It therefore failed to establish required Windows 150/200 percent coverage.
The next read/select-only public-provider investigation (`38795120675`) checks
advertised display resolutions before selecting scale. These disposable display
changes do not modify Windows security settings. WebView content zoom remains
separate and does not satisfy this missing native DPI evidence.

All 212 retained P09 investigation files were checked against their committed
Git blob bytes and manifest SHA-256 hashes after publication.

## Product sampler and display investigation update

Server run `38792629133` at `ce6098f` successfully seeded ten real verified, idle
environments and 10,000 files, with 110 successful diagnostic definitions retired
while retaining all synthetic reports and root data. The sampler then encountered
an InvalidOperationException; the next version distinguishes a verified exited
process from an unmeasurable live process, which still fails. The UIA startup
upper bound was 6349.9831 ms, above the 3000 ms target; no timing success is claimed.
The next watcher prewarms the actual desktop provider before starting the clock
and records native-window appearance separately. Required checks remain intact.

A local real-WebSocket transport reproduction proved that PowerShell emitted
VoidTaskResult alongside the CDP reply. Suppressing the void return restores a
single typed reply. This is transport verification, not Windows product evidence.

Display run `38795996049` observed 96/144/192 DPI on both runners after selecting
the advertised 1600x1200 mode. Returning to 100 percent passed on Server but failed
on ARM due to a virtualized dropdown item. Public ItemContainer/VirtualizedItem/
ScrollItem patterns now handle that case. Product-window DPI proof is still
required. The full gate now requires all twelve real DPI layouts separately
from content zoom. Four-box focused diagnostics cannot be retained as DONE.

P07 regression `38793653374` passed both targets. P06 `38793649785` passed Server
but ARM sessions prerequisites failed with ENDPOINT_POSITIVE_CONTROL_FAILED.
Full matching dependency evidence therefore remains blocked.

ARM product run `38792629133` also completed all ten verified idle environments,
165 retired diagnostics and 10,000 files. Its UIA startup upper bound was
4689.8484 ms. It encountered the same sampler/CDP failures, so P09 remains blocked.

Display discovery run `38796851020` passed the complete 100/150/200/100 sequence
with native DPI 96/144/192/96 on both runners. This demonstrates the provider and
display capacity; only actual product-window checks can establish UX coverage.

P05 ARM regression `38793646388` failed online availability: the parent UDP IPv4
loopback reply was missing while its child and independent server observations
passed. The subsequent WFP test inherited reconciliation-required state. The
next implementation bounds online UDP availability retries consistently with
existing online TCP retries. Unboxed controls use a frozen pre-dispatch counter
baseline so retries cannot masquerade as offline target traffic. Offline attempts
and all independent containment checks remain mandatory. A native regression
covers each endpoint after one to four completed controls. Endpoint failures are
now retained by P05/P06 as minimized numeric/typed records.

Focused ARM run `38796850868` at `bf116dc` refused environment 04 with
DIAGNOSTIC_PROCESS_SCOPE_CHANGED. The next cleanup waits up to one second only
for the same retained kernel object to signal completion when driver membership
disappears. An unknown live process still refuses termination. Failure evidence
contains only numeric query/wait status and comparison booleans, never identity
values. Unknown changed INI key names are withheld before local diagnostics.

The product cards now explicitly distinguish configured presets from last-checked
network policy and expose exact current launch-block reasons. A separate native
build fixture exercises the real measurement API for 60 seconds with the normal
GUI, no engine targets and no performance-budget claim. Job accounting uses the
exact marshaled Windows structure size. Only the full seeded workload can meet
the P09 performance gate.

Focused Server run `38796850868` proved real keyboard Tab/F6 and native UIA
names/invoke behavior. CDP stage calls failed after bootstrap, so document-ready
and actual React navigation readiness are now required before injection; safe
fixed classifications replace raw JavaScript exceptions in investigation output.
Fresh standard-user Settings activation failed. Display changes now use only
three fixed actions in the lab controller via owner-restricted named events. No
paths, code or arbitrary payload cross that boundary; the normal product receives
no event names. The standard user still independently checks actual manager DPI.
A parent-controller result alone cannot satisfy the product DPI gate.

Native build/measurement run `38799721509` at `8398582` passed both targets,
including the real 60-second complete job-group sampler. This is a debug GUI
without reference environments and does not claim the P09 performance budget.
Focused run `38798053888` at `7ed2836` reached four verified environments on
both targets but stopped in OVERVIEW before environment cards became available.
The next lab revision retains only onboarding state, fixed backend reason codes
and environment counts on failure. It never retains raw UI/JavaScript exceptions.
Dependent UI scenarios stop after their first failed prerequisite; a measured
performance-budget failure still allows independent product checks to run.

Full run `38799721407` at `8398582` stopped before seeding on both targets:
the PowerShell 7 actor used the .NET Framework event-opening overload. The ACL
channel was created, but its standard-user self-check raised InvalidCastException.
The actor now uses EventWaitHandleAcl.OpenExisting; the Windows PowerShell 5.1
UIA helper retains its correct framework overload. No permission was broadened.

Both P05 (`38798057764`) and P06 (`38798061737`) passed at `7ed2836`. These
are historical after the cleanup/UI changes. P03 passed at `8398582` in run
`38800451929`, with unchanged current production sources. P04 `38800456163` passed
Server but ARM timed out in both actual boxed-manager checks. No boxed control
or metadata success is claimed; a fresh full P04 run is `38802021230`.

Focused Server run `38801426429` at `d2b138a` verified standard-user access to all
five restricted display events and completed twenty private diagnostics. Native
UIA preparation exceeded its 20-second fixture-ready bound before the manager
started. The next watcher initializes only the desktop provider, without querying
all desktop windows, and has a 60-second preparation bound. The product timer
still starts afterwards and the 3000 ms budget is unchanged. A failed startup
measurement does not prevent independent UI scenarios in diagnostic mode.

Fresh P04 run `38802021230` passed both targets at `d2b138a`, including both
boxed-manager checks. Earlier timeouts remain historical. The single-environment
layout diagnostic is separate from the four-environment application diagnostic
and the mandatory full ten-environment gate; neither diagnostic can close P09.

Focused ARM run `38801426429` at `d2b138a` identified the initial-view blocker:
the fresh observation and direct policy worker both returned OBSERVED with four
owned environments, but onboarding remained unavailable. P09 had treated the
P04 service-process identity restriction as a prohibition on independently
authenticated production SDK operations. The UI now reads owned metadata after
fresh trusted Unboxed observation and recognizes the basic route only after
an actual native worker returns OBSERVED. That proof expires in 15 seconds,
is tied to the observation generation and is cleared on focus/refusal. Service
process identity stays Unknown; native context_safe and every operation gate
remain unchanged. Unit cases require this separate proof and reject stale,
boxed, stopped-driver and inconsistent service-identity states.


Run `38804430207` at `d16affc` passed Server overview, identity-preserving rename,
keyboard/UIA and all twelve WebView language/theme/zoom combinations. It failed
the startup, idle CPU and memory budgets (see the measured report). Actual 100%
Windows DPI passed; reopening Settings prevented 150% and final restoration.
The controller now keeps the same Settings window until final restoration. ARM
stopped at an unreviewed live WerFault process during private diagnostic cleanup;
no termination exception was added. Cleanup may wait one second for the same
held process object to exit naturally and otherwise retains its refusal.

The bounded read-only observer and supported WebView memory target require fresh
native compilation and measurements. UI route/control observations are tied to
the same health generation; completed managed mutations request a fresh metadata
read. A lab button waits for normal enabled state before one click. ARM's missing
optional npm native binding is handled by at most one repeat of the exact locked,
script-free install. No dependency pin or Windows security check is bypassed.


At `eaab83c`, native product build `38811627887` passed both targets, including
55 native adapter tests, three app tests, four product UI tests, native Clippy
and the actual 60-second measurement fixture. The fixture has zero reference
environments and makes no performance-gate claim. P03 (`38811673054`) and P04
(`38811676793`) passed on both targets. A retained MiB/MB unit mistake is
corrected to the specification's strict 250,000,000-byte memory threshold.


Single-environment run `38811626796` passed Server overview, rename, keyboard/UIA
and all twelve content-zoom layouts, but failed the display-controller request
after native 100% DPI. Startup's external UIA upper bound was 5659.6163 ms
(native window 2534.9429 ms). No startup success is claimed. The next fixture
records navigation lookup, invoke and language lookup separately, restores an
existing Settings window before reuse, and retains each controller's fixed
stage/result. A failed DPI case remains failed and blocks acceptance, but no
longer prevents independent application/file workflows from collecting evidence;
presentation reset is attempted even if display restoration fails.


Full ARM `38811627938` refused an unreviewed live WerFault in environment 03.
The same retained process object may now complete naturally within ten seconds;
a timeout still refuses cleanup and never authorizes termination. Both completion
and refusal record only the bound and typed outcome. This native adjustment
makes previous P03/P04 proof historical until a matching regression passes.
ARM's layout diagnostic passed overview/rename, then failed keyboard setup.
The next UIA fixture records separate foreground/Tab/F6 stages, verifies actual
foreground ownership and waits for actual focus instead of fixed 100 ms sleeps.


Layout diagnostic `38813731246` at `237696a` passed forty Server UI cases and
keyboard, but repeated Settings discovery still failed. Native window appearance
was 4746.4687 ms; UIA navigation lookup 2915.5984 ms, invoke 114.2283 ms and
language lookup 166.1787 ms; total external bound 8261.5406 ms. The next revision
keeps one bounded lab controller and retained Settings provider across fixed
scale requests, matching the successful standalone discovery sequence. It accepts
no actor paths/code/payload and retains eight-request and fifty-minute bounds.
The parent consumes readiness before actor startup and terminates only its own
held controller during teardown. Standard-user manager DPI checks remain required.

Normal startup now emits only fixed numeric stage durations for initial engine
observation, before WebView construction and after window construction. The lab
retains these allowlisted numbers and the low-memory marker without raw captures.
No budget, required startup check or measurement denominator changed.


Full Server `38811627938` measured 238777613-byte average working set (passes
250 MB), 1.594772336% CPU and 4567.2086 ms startup (both fail). The four-box
Server diagnostic `38813487866` passed real external activity latency, then
could not open the policy editor. Its external fixture had left Enabled=y; the
fixture now restores only the managed Enabled=n dispatch fence and independently
verifies the held process remains alive. No production conflict rule changed.
ARM UIA now uses a real click at the navigation provider's clickable point after
verifying the hit window belongs to the actual manager. No global foreground
permission or Windows security setting is changed. CPU diagnostics separate the
held manager's CPU and child remainder; live WebView attribution is explicitly
incomplete. The original complete kernel-job CPU and elapsed interval remain
the sole authoritative budget measurement.


The first persistent-controller run could not initially discover Settings after
waiting for the actor. The next controller prepares its retained provider at
100% before readiness/actor startup and records this separate display preparation.
It stays outside product timing and receives no actor payload. Its scale actions
and the independently measured manager DPI remain mandatory. Native startup
tracing at `9daaf46` attributed 83 ms to observation and 4167 ms through WebView
construction. The next normal product tries fixed software composition using
only `--disable-gpu`; no sandbox or security-disable browser argument is added.
This change requires measured native validation and makes no performance claim.


The `c20c7e9` focused Server job stopped before actor startup because the retained
display server did not signal readiness. Its official-package/stage evidence
does not establish any product scenario. A short standalone two-target fixture
now exercises exactly the five restricted events, server readiness and four
fixed scale requests, without building/installing the product or engine. The
controller retains only typed initialization stage, exception class and source
line on failure, never raw exceptions or private paths. It cannot replace real
standard-user product-window DPI proof.


Isolated retained-controller run `38817227177` passed preparation and all four
fixed requests on both Windows targets. Product layout run `38815909628` at
`c20c7e9` passed all 76 Server UI cases, including actual Windows DPI 96/144/192;
it is one-environment DIAGNOSTIC_ONLY, not a full P09 gate. ARM stopped before
keyboard because its clickable point hit a foreign window; no click was sent.
The fixture now raises only its own manager window without activation and
checks the actual Windows root-owner chain before a real click. Complete kernel
job CPU remains authoritative. Additional fixed counters attribute only completed
held observation workers' CPU/frames and are explicitly incomplete diagnostics.


A failed display-server bootstrap now retains its readiness/held-process exit
status and continues the independent standard-user product actor. The parent
answers fixed display requests with failure when that owned controller has
failed; it never substitutes a successful DPI result. The mandatory DPI case
still fails and blocks acceptance. Application, file, history and performance
evidence no longer depends on this unrelated fixture bootstrap succeeding.


The fixture now records keyboard failure without blocking independent DOM/DPI
checks. A failed dependent policy/file GUI sequence remains failed and records
its typed dependency result, closes its own inspected GUI/held synthetic member
and proceeds to separate application environments. Editor/archive failures remain
failed; explicit checked stops of that exact owned test environment separate
the next application workflow. Missing dependent cases and any failure still
reject P09. This collects independent compatibility proof without claiming skipped
work or replacing any native operation guard.


The software-composition diagnostic passed 76 Server presentation cases but
measured a 40921.4589 ms startup upper bound (39678 ms through WebView creation).
The zero-environment CPU fixture showed no improvement. The rendering override
is removed; no benefit is inferred from that experiment. Standard-user fixtures
now set their profile variables from loaded Windows known folders and use a
private writable fixture TEMP, verified before cases. Parent profile/temp values
are not carried into that actor. New native measurements remain required.


The four-environment diagnostic now also samples the normal inspector-free
manager's complete kernel job for sixty seconds, after independently observing
all four environments idle. `performance-diagnostic.json` explicitly declares
four reference environments and no performance-gate claim; the full ten-box
acceptance requirement is unchanged. This obtains completed-observer CPU/frames
earlier for profiling. The single-environment layout diagnostic remains short.
Case diagnostics clear the previous UI stage before each new case.


Policy editor failure is explained by the native journal: LIST durably marks a
Verified environment Conflict if it observes the external fixture's Enabled=y
transition. Restoring the flag cannot automatically restore verification. Before
the independent queued-edit scenario the fixture now explicitly stops its own
external member, performs native Inspect/Repair against the exact current
fingerprint when needed, and launches a fresh held member through the actual
managed registration/launch path. Queue checks bind its PID and creation time
through a fresh original-driver-backed native list. UI Stop and explicit stopped
Apply remain required. No journal state or conflict check is bypassed. Failure
diagnostics now retain only selected policy stage/reason and editor-presence
booleans to distinguish native refusal from a missing UI.


The next runtime keeps one bounded conditional health read and publishes full
observations every 1.7 seconds. This removes the client's extra polling delay
without caching configuration or dropping any per-frame trust/context/root/
process check. The same command/output remains; there is no new IPC permission.
Two portable tests cover notification-before-wait and single-reservation release
on timeout/drop. Native adapter Clippy, frontend compilation and four product
tests pass locally; actual Windows CPU/update results remain pending.


ARM's latest layout diagnostic passed all 76 presentation cases and real display
DPI, while the keyboard helper refused its click target. Helpers now use a
per-thread Per-Monitor-V2 coordinate context. A click requires both actual native
window ownership and the exact navigation provider's UIA identity/ancestry at
the point, not a matching caption. Foreground ownership and actual focus are
checked before keys. Ctrl+comma and Ctrl+1 additionally require the actual
Settings language control and environment search page, respectively. No Windows
security setting or broad foreground permission is changed.


Four-environment Server `38819558103` measured 0.985937681% complete-job CPU and
224065273-byte average working set. One completed sixty-frame observer used
0.390625 CPU seconds; this is four-box diagnostic evidence, not the ten-box gate.
Actual Firefox main HTTP attribution with an existing clean host instance passed.
Editor focus, archive exit and the browser child-link action failed. The next
fixture focuses the exact owned Scintilla provider before typing; child-link
lookup waits across only the verified browser PID's visible windows and uses its
supported native Invoke or MSAA default action. Archive creation/extraction uses
the official package's GUI worker 7zG.exe and retains its hash; nonzero exits
remain failures and retain only their numeric code. No engine exception or
browser security preference changed.


A fresh ARM diagnostic again refused a still-live unreviewed System reporter.
Its held object now has at most sixty seconds to complete naturally; a live
object still refuses cleanup, with no added termination whitelist or OS/WER
setting change. The existing native policy worker remains bounded to 600 seconds.
Only the stopped-Apply UI/transport wait is aligned to a 660-second outer bound;
other UI/transport limits stay unchanged, and success still requires actual
Verified policy/readback. The editor provider must also be visible.


The archive fixture's reported ExitCode was null, not a known nonzero code.
Waiting now uses a retained Windows process handle, actual creation-time match,
WaitForSingleObject and GetExitCodeProcess. A process already completed before
opening its handle has an explicitly unknown exit; actual boxed output/CRC and
unchanged-host checks still determine workflow completion, with no redispatch.
The accessibility helper chooses the largest visible owned non-dialog window,
records exact editor provider/point/focus stages and has a UTF-8 BOM for Windows
PowerShell 5.1, preserving Unicode confirmation captions.

The application fixture now selects GUI processes only after a fresh complete
native membership list and a held-object birth, expected official executable path
and liveness comparison. A helper or error window in the same box cannot stand
in for the selected editor, archive manager or Firefox. The native picker fixture
also recognizes the actual fixed production file-transfer title. These are lab
corrections; fresh native application results are still required.
The Firefox fixture preserves the external-protocol warning preference. It may
explicitly invoke the owned Open Link provider only when the prompt contains the
fixed synthetic protocol, and it never toggles a persistent allow permission.
Actual boxed handler execution and the unchanged host marker remain mandatory.

Focused run `38824150548` passed actual keyboard checks and measured 0.90245%
complete-job idle CPU / 225494339-byte average working set with four environments;
it remains diagnostic-only, and its 9591 ms startup is not a passing budget.
Its layout sequence exposed a lab transport defect: direct screenshot/AX calls
referenced an undeclared timeout, whereas evaluation calls inherited the caller's
variable. The transport now declares its bounded default explicitly. Source-line
numbers on accessibility failures are retained without stack paths or raw text.

Full ARM run `38824148996` at `496272b` refused the tenth CREATE with
`NETWORK_ENFORCEMENT_FAILED`. Its 139 retained raw reports show one online incoming
IPv4 TCP failure; the other three incoming and all outbound channels succeeded.
The boxed incoming listeners previously waited sequentially while the host
observer used concurrent 900 ms reads. They now observe all four channels
concurrently with independent finite windows. A synthetic online TCP availability
connect may retry only before any connection exists, for at most four seconds;
offline still makes one attempt and every required positive/negative channel
must match. No engine rule, user dispatch, firewall or security setting changes.
Fresh matching P03–P09 native regressions remain required.

Review found that history persistence still used the older P04 service-PID gate,
so the standard-user lab always used the honestly labeled session fallback even
when its native history worker could authenticate independently. Fresh verified
unboxed status now permits that worker attempt for the exact known SCM-only
limitation; no service identity or storage authority is synthesized. Presentation
changes no longer query history. The native product lab now requires a real
history database before claiming its local-history secret scan passed.
The retained Settings controller now minimizes its own window between fixed DPI
requests and restores it only for the next actual Settings operation. This keeps
the elevated lab Settings window from covering the standard-user manager during
physical keyboard checks; actual Windows/manager DPI verification and the final
100% restoration/close still run unchanged.

Control views now expose separate `launch_reason` and process-observation `reason`.
The native eligibility calculation preserves its exact refusal code while process
activity stays independently observed. Both product views use the launch cause;
P06's real WFP-unavailable/running/Stop case now requires a distinct launch refusal
while process observation remains OBSERVED. No dispatch or Stop guard changes.

Focused `38826425388` on Server passed actual keyboard navigation, all bilingual
zoom/DPI layouts, archive GUI create/extract with boxed byte verification, and
existing-host-browser isolation. Picker diagnostics identify the missing filename
provider immediately after dialog creation; the fixture now waits for its enabled
fixed-name/ID control. Notepad++ exposed no Scintilla UIA provider, so its document
input uses the exact visible owned Scintilla HWND, verifies its native hit and
focused thread control, then performs actual keyboard edit/Save As. This does not
replace the manager's separate mandatory UIA/keyboard checks. The browser canary
is explicitly activated in its verified window before invoking its link. Each
browser subcase may now fail independently so the protocol/content-sandbox
results are still collected; all remain mandatory at the final gate.
Lab console processes now stay hidden (actor) or use CREATE_NO_WINDOW (helper),
while the production GUI remains ordinary. The keyboard fixture waits for fresh
UIA and native hit-testing agreement after window restoration, retaining the
same ownership/provider/focus requirements. This removes helper-window and async
layout interference without broad foreground permissions or an input bypass.

Diagnostic `c2f9b5a` measured 1.18415% CPU / 226910825-byte average working set on
Server and 1.29373% / 229258465 bytes on ARM, with four environments. CPU still
fails the reference target. The next UI consumes each bounded native health
notification immediately and uses a single freshness-expiry timer instead of
periodic full UI clock rendering. Readonly control refresh is 14 seconds within
its unchanged 15-second validity. Native activity, worker framing, mutation guards
and full reference budgets are unchanged; no passing performance claim is made.

Focused `ba8b1cf` preserved both native manager keyboard/role checks on Server,
all 78 applicable UI assertions, real persistent-history presence/secret scanning,
archive round trip, main browser isolation and the actual launch-overhead bound.
Picker filename and editor/browser automation still failed; their cases remain
mandatory. Pinned upstream `guiclass.c` confirms `Sandbox:<box>:` window-class
names. The editor now recognizes only that exact independently selected box's
Scintilla class, in addition to the original unprefixed class. The native picker
may use only its fixed filename IDs/ancestry and owned enabled IDOK button, with
exact text readback; the production picker lease/capability checks stay intact.

Browser canary documents are explicitly loaded and their native titles observed.
When a provider is unavailable, physical Tab/Enter activates their single link;
child traffic must increase after the action and still pass live socket/driver
attribution. The protocol case uses a real boxed HTTP page/hyperlink, retains
Firefox's warning, and may send one explicit Enter confirmation only in that
owned synthetic browser. The actual handler must execute boxed with no host
marker. about:support is read through its clipboard JSON button or actual rendered
text; only the positive effective content-sandbox level and source kind survive.
Raw support content is never retained and the clipboard is cleared. These lab
paths neither dispatch the helper directly nor disable a browser security option.
The fixture uses WindowFromPhysicalPoint for UIA's documented physical screen
coordinates on both architectures. Native owner/provider agreement remains
mandatory; the change does not accept a foreign window or translate an unknown
hit into success. Only a boolean native-bounds comparison is added to failures.

ARM focused launch added 1078 ms at `ba8b1cf`, exceeding the 1000 ms target.
Register/Launch/Stop responses now observe only their requested environment and
carry an explicit parent-validated `environment_scope`. Their pre-dispatch/full
namespace, component, root, executable, receipt and Stop guards are unchanged;
LIST/StopManaged/Reconcile still observe all owned environments. This removes
unrelated response-only availability calculations from ordinary dispatch timing.
Fresh actual latency and P06–P09 regression proof remain required.

Full `e6ccf0e` measured 1.18046% CPU / 232257623-byte average working set on
Server; startup 8356.7 ms still failed. ARM refused CREATE 5 after the same held
WerFault process remained live for 60 seconds. The refusal/retained data are
preserved and no reporter termination is authorized. The parent lab now reads
only bounded Application Error/WER records for an exact known component list,
retaining whitelisted module kinds and numeric exception codes. It changes no
error-reporting, firewall, Defender, engine or OS security setting. This is
optional fault diagnosis, never a passing containment result.

NativeEngine construction authenticated and released component objects during a
full observation, then immediately authenticated them again for that same
operation. It now authenticates once and retains those exact no-write/no-delete
objects while repeating the existing full SCM/DACL/driver/context/box observation
and operation guards. No trust cache crosses operations. Complete box snapshots
also keep their exact prior JSON byte limit with incremental item lengths;
repeated serialization of every previous box is removed. An independent full
serializer oracle tests Unicode/escapes, exact-limit success and unchanged rows
on refusal. Native observation content and all response limits remain intact.
Native picker input accepts only its enabled known editable ComboBox/Edit
provider or fixed-ID native field with exact readback. If that field is not
already present, it may activate the standard File name mnemonic only in the
exact owned foreground dialog. The proven native field path needs no physical
foreground workaround. Focus helpers require
the exact native root window, in addition to PID ownership. No arbitrary edit
field, foreign window, native picker result or selection lease is substituted.

Public Actions artifact reads remain available while authenticated publication is
blocked. ARM focused `5012abe` passed the actual picker, queued diff, explicit
whole-box Stop and independently verified stopped Apply (83 UI assertions). Its
case failed only because a redundant cleanup Stop raced the subsequent UI refresh.
Successful verified stopped Apply no longer dispatches that second Stop. Only
readonly LIST may wait up to four seconds for an explicit pre-work namespace-lock
refusal; mutations and uncertain outcomes are never retried. Exact refusal action
and whitelisted native hit-owner categories improve diagnosis without retaining
PIDs, paths or arbitrary process names. Physical input still requires the same
native ownership/provider checks.
The GUI fixture now drains its exact held kernel job after normal manager exit,
using the same owned-job termination already used for the synthetic host browser.
It waits for the existing accounting API to report zero active members before
starting another GUI. No unrelated PID, sandbox or system reporter is selected.
This prevents an earlier fixture's WebView children from remaining on the test
desktop; it changes neither product termination behavior nor resource samples.

At `a200862`, native Scintilla discovery and exact editor focus passed on Server,
but Save As was not found. The native dialog enumerator now recognizes only the
original class or the pinned engine class prefix for the exact expected box,
just like the already-scoped editor/filename enumerators. Browser navigation
pastes only its fixed synthetic address, verifies selected-address readback,
and clears the clipboard. Actual native title, socket attribution, boxed
outputs and unchanged host data remain mandatory. Windows proof is pending.

An additional incoming positive-control timing mismatch remained: the online
host waited five seconds for a response, but an accepted boxed TCP peer had
only 900 ms to send its first byte. The online target now uses the same bounded
five-second handshake window; offline negative-control timing is unchanged.
The native receiver test deliberately delays a connected peer for 1100 ms and
still requires exact IPv6 and both UDP responses while IPv4 stays unanswered.
No failed observation is converted to success and no policy rule is changed.

The delayed-byte regression passed Linux but failed on both actual Windows
targets (`38837492326`), exposing the platform-specific cause: Winsock accepted
sockets inherit the nonblocking listener mode. Setting a read timeout does not
clear that mode, so a first read before the byte arrived returned immediately.
The accepted socket now explicitly switches to blocking mode before applying
the same bounded handshake timeouts. Offline probes still make one attempt and
all positive/negative endpoint observations remain mandatory. Windows revalidation
is required; the Linux result was never treated as containment evidence.

Focused Server `9b3acd8` identified a second-client fixture race before the policy
case: independent CLI preparation attempted Stop while the still-open activity
GUI ran its periodic readonly worker. Preparation now closes/drains that GUI,
performs the existing exact cleanup/repair/register/launch, then reopens the same
normal product and profile for the complete real picker/diff/queue/Stop/Apply
sequence. No mutation is retried and namespace locking is unchanged. The added
GUI capture joins all prior captures in the secret scan, preserving error-log
coverage across the explicit fixture restart. Actual Windows proof is pending.

ARM focused `9b3acd8` passed the real queued-policy workflow and reached the
populated-file case, which timed out. Fixed stage codes, row counts and the
existing rendered error code now locate that failure without retaining names
or paths. Native input still encountered a foreign desktop overlay. The helper
may temporarily raise only its exact verified owned window into the topmost
band, checks native point/root ownership before any input, and restores the
prior band afterwards. Originally topmost windows are left as found. No foreign
window is activated, terminated or accepted, and foreground restrictions remain.

A separate readonly desktop workflow observes whether the hosted runner input
desktop is Default (1), another desktop (0), or unavailable (-1), plus only a
fixed foreground-process category. It changes no logon, lock, desktop, RDP or
Windows security setting. The same field accompanies actual actor observations
so an inaccessible input desktop can be distinguished from a covered window.

The pinned [Notepad++ shortcut source](https://github.com/notepad-plus-plus/notepad-plus-plus/blob/v8.9.8.1/PowerEditor/src/Parameters.cpp)
assigns Save As to Ctrl+Alt+S; the former fixture incorrectly sent Ctrl+Shift+S
(Save All). The real Save As path now uses the correct original shortcut.
Clipboard navigation gives the external application time to process focus/paste
before clearing and reading back its selected address; exact readback remains
mandatory. Fixed workspace traversal matches unique enumerated Windows directory
names without assuming the casing of the system-volume directory.

Readonly desktop run `38839051225` found the Default input desktop on both hosted
targets. No locked-desktop exemption is claimed. Repeated ARM full runs also
retained a live unreviewed WerFault in a generated scope. Optional parent-fixture
CIM diagnosis now classifies only fixed known component names associated with a
live reporter; no command lines, paths or process IDs are retained. This weak
association is never authority for termination, trust or a passing result.

The original acceptance gate 7 explicitly requires measured engineering budgets
and user-impact explanations for deviations. The earlier retainer added an
unrequested all-targets-must-be-met gate. It now preserves the exact targets and
complete ten-environment/10,000-file/60-second measurement, records all five
MET/DEVIATION results with user impact, and validates them independently against
the actual sample fields. Missing full samples or explanations still fail.
Functional/security cases, native ownership, all application/file workflows,
mandatory rules, containment and matching regressions remain required. Historical
failed runs keep their original results; no old proof is relabeled successful.

Focused Server `f2ebba3` passed the queued-policy UI and reached the actual file
page. It contained 126 rows, within the required 128-row bound; the fixture had
incorrectly required a full 128 rows. The check now records the actual DOM size
and still requires complete unique traversal of all 10,000 files and bounded
native pages. The editor reached its genuine Save As dialog but its filename
provider was unavailable. Known editable native classes remain restricted to
fixed filename IDs/ancestry within the exact owned dialog, including hosted
child controls; exact set/readback is still required.

Firefox clipboard-based address readback remained unavailable. Navigation now
uses documented Windows SendInput scan-code chords and Unicode text, with
checked native delivery and exact foreground PID/root ownership. Every current
canary page must still be observed after a blank navigation and all resulting
requests independently attributed to a held original-driver member. Child links
and protocol confirmations use actual native keys; no handler is dispatched by
the helper. Clipboard diagnostics remain required to obtain a positive actual
about:support sandbox level, and are never replaced with a static preference.

Native point lookup now uses WindowFromPoint under the already-required per-
monitor-v2 helper context, matching UIA and cursor screen coordinates. Exact
native PID/root and focused-element checks still precede/verify input. A boolean
comparison with the legacy physical-point API diagnoses disagreement. On failure,
unknown process names remain hashed. Only a valid Microsoft-signed component
under the protected Windows system directories may expose its component basename;
no path, PID, certificate data or arbitrary application inventory is retained.

At `ec2a16b`, both Windows targets still had a foreign PickerHost window over
all physical input targets. Its name hash matched `pickerhost.exe` in the public
Windows filename catalog; it is not admitted as a manager/browser input owner.
Before product GUIs start, a lab-only preparation step may cancel one visible
initial PickerHost dialog only after same-user, protected Windows location and
Microsoft signature/system-package validation. It uses WindowPattern.Close,
waits for that exact window to disappear, dispatches no process termination,
selects no application and changes no defaults or Windows security setting.
The normal native ownership checks remain mandatory afterwards.

The editor's actual dialog exposes Edit/1001 rather than the legacy filename
IDs. An explicitly delivered File name mnemonic can identify the native focused
editable child of that exact dialog; set/readback and actual boxed saved bytes
remain required. Browser input uses the Windows PowerShell 5.1 UInt16 type name,
with sanitized error-record kinds and actual INPUT/pointer sizes on failures.
The deceptive filename is located through actual bounded UI pagination instead
of assuming its enumeration position. Complete native traversal still requires
10,000 unique files, and before/after registration/receipt observations must both
be successful. Only an explicit pre-work readonly LIST lock refusal can wait;
no mutation or uncertain outcome is retried.

P03–P08 all passed both targets at `ec2a16b` (runs `38842214153`,
`38842216379`, `38842218236`, `38842220204`, `38842222263`, `38842224221`).
Their reviewed original JSON remains retained. The next P09 fixture changes
require matching final-source confirmation; no native runtime code changed.

The desktop preparation helper returns OBSERVED for its setup observation; its
caller now expects that exact setup status instead of a product-case PASSED. All
other accessibility helpers still require PASSED. Preparation also runs before
seeding to expose setup errors promptly, then repeats before the first GUI to
catch delayed initial Windows prompts. Both invocations precede product targets.

### Owner-scoped initial desktop preparation

The `cf6edad` focused ARM run identified the visible input obstruction as
Windows `PickerHost`, owned by a different account from the standard-user
actor. The actor correctly refused to close it. The lab controller now accepts
one additional fixed `prepare` event through the existing owner-restricted
kernel event channel. It independently repeats the same-user, protected Windows
component and signature/package checks before cancelling the initial chooser.
The actor re-observes the desktop once after acknowledgement. Preparation is
bounded to four controller requests, accepts no paths or commands, runs before
product windows and never changes application defaults or terminates processes.
The product receives no event names. PowerShell parsing, fixture compilation,
JavaScript syntax, the repository validator and all 18 tooling tests passed;
actual Windows execution remains required.

### Save completion and native browser interaction diagnostics

The cancelled `cf6edad` Server diagnostic completed the Notepad++ native Save As
field/button interaction, but the output was not observed after the fixed
500 ms delay. The fixture now waits up to 30 seconds for the exact boxed output
before stopping the editor; byte equality and unchanged host input/output remain
mandatory. Browser navigation uses owned-window Windows SendKeys with a verified
synthetic URI clipboard paste and clears the clipboard afterwards. The helper
records only expected-title booleans, not browser text. The about:support text
parser accepts Mozilla's actual “Effective Content Process Sandbox Level” label;
a positive observed level is still required. File UI failures now distinguish a
missing canary, missing escaped direction marker and missing full suffix without
recording filenames. These changes require actual Windows confirmation.

All six `cf6edad` P03–P08 regressions passed on both targets. Their reviewed raw
JSON is retained as historical exact-commit evidence; newer P09 fixture changes
require final matching-source validation. The unsuccessful `ec2a16b` full run and
cancelled `cf6edad` partial runs are also retained without a completion claim.

### Inert directional filename omission corrected

Source review found the cause of the T63 omission: `canonical_validated` used
`windows::text` for final/long path buffers, and that engine-text decoder rejects
direction controls. Listing then skipped the otherwise ordinary held file. Only
the `file_names` inert-I/O branch now decodes these bounded UTF-16 path buffers
without the engine/INI text restriction. The validated source grammar and exact
native path equality remain; reparse, hardlink, fixed NTFS, private root and held
identity checks are unchanged. Output names and engine paths still reject the
controls. A real Windows filesystem regression checks the held identity, escaped
full suffix, strict engine-path refusal and output-name refusal. Windows Clippy
cross-check passed; native execution and matching P03–P08 proof are pending.

### Recurring initial Windows picker remains constrained to its enrolled process

The `ffae987` ARM artifact proves that the controller cancelled a same-user,
authenticated Windows PickerHost with UIA Window.Close. The actor re-observed zero
visible picker windows, but the same component obstructed later physical input.
The controller now enrolls a picker process only before any manager/editor/browser
process exists. Later cancellation is permitted only for that exact PID and
creation time, with fresh same-user, protected image and signature/package checks.
The channel accepts no PID, window, path or command from the actor. There are at
most eight preparation requests. A helper may request this fixed action once
when a native hit test identifies PickerHost, then must positively re-establish
ownership of the intended input window/point. An unknown or replacement process
is refused while products run. The desktop is also re-observed after the measured
manager closes and before the inspected GUI starts. No process is terminated,
application/default selected, product dialog dismissed or target action retried.
PowerShell/C# compilation, native input layout, the repository validator and all
18 tooling tests passed; the recurring-window path needs actual Windows proof.

### Standalone display fixture channel alignment

The separate `Test-P09-Display.ps1` diagnostic still created the old five-event
channel after the controller gained a sixth fixed preparation event. Both
`38850034600` jobs correctly refused to start the incomplete channel. This missed
companion fixture is now aligned with the production lab's six events and tests
preparation acknowledgement before the four actual DPI requests. No product
logic or Windows security setting changes. Matching source regression will be
rerun for the final fixture tree; superseded evidence stays historical.

### Standard-user process query precedes owner delegation

The `4956792` ARM diagnostic stopped during initial desktop preparation: the
standard actor could enumerate the foreign picker window but could not query its
process creation time. The new birth check ran before the existing same-user
refusal and therefore prevented delegation. Same-user authentication now runs
first, allowing only the existing fixed controller delegation on refusal. The
controller still requires a nonempty creation identity and repeats fresh owner,
protected image and Microsoft signature/package checks before enrollment or
cancellation. No access right, trust check or PID reuse protection is removed.

### Actual b04a766 results and owned native picker correction

Both focused targets proved all 10,000 entries on 79 pages, maximum 128 entries
and 127 DOM rows; all 88 UI assertions passed. Server recorded 2786.2 ms first UI
list / 178982 ms complete native walk; ARM 2502.6 ms / 85113.5 ms. The real inert
Unicode path correction is confirmed. The secret EXE picker did not appear on
either target. Editor Save As interaction on Server did not produce output even
within 30 seconds. Browser URI paste did not produce the expected page title;
keyboard typing now avoids a cross-boundary clipboard assumption. The helper
requires the picker to close and types the editor filename through the verified
native field before Enter. Byte equality/unchanged host requirements remain.

Production policy and diagnostic file dialogs now have the requesting native
window as parent and run on a dedicated joined thread. This keeps rfd's required
STA initialization independent of a reused worker's COM apartment. A Windows
regression initializes its caller as MTA and verifies that the picker thread can
initialize STA. Existing path, identity, scope, expiry, preview and create-new
checks are unchanged. The UI preserves only known typed native selection refusal
codes; it does not render raw exceptions. Tauri's protected IPC is unchanged.

The lab records bounded native hit/root/foreground visibility, known class kinds,
interactive desktop/session booleans and counts of PickerHost child windows.
The controller's zero visible top-level count did not establish a clear input
point. No new window-cancellation authority is granted. Picker cleanup is now
idempotent so a failed helper is not consumed twice. Only safe rendered error
codes are retained for a missing picker, and startup traces retain numeric marks.

The b04a766 full ARM run stopped at CREATE 10 with
DIAGNOSTIC_SYSTEM_IMAGE_UNREVIEWED and one unassociated WerFault reporter. It has
no full reference measurement. No reporter kill/whitelist or error-reporting
change is added. P04 run 38852273760 recorded an unexpected boxed startup exit 1
on Server; the unchanged-source repeat 38852853178 passed all cases on both
platforms. Both outcomes remain historical, and the startup cause is undetermined.

### Visible initial picker enumeration and targeted application diagnosis

The f9b719d ARM layout diagnostic proved an active console session, interactive
WinSta0 and Default thread/input desktops for both users. Startup and all 76 UI
assertions passed. Physical input still hit a visible top-level PickerHost, while
the controller's EnumWindows-derived list had zero visible candidates and its own
foreground was PickerHost. The lab now supplements enumeration with a bounded,
cycle-checked top-level z-order walk and the independently queried foreground.
Only known PickerHost PIDs are candidates. At most eight visible windows are
handled, each with fresh same-user/root-owner, protected Microsoft image and
process-birth checks. Enrollment still occurs before products; later requests
require an enrolled process birth. No broader process/window authority or kill
path is introduced. The intended input window/point must still be reverified.

An explicit apps-only diagnostic executes the existing real CLI/boxed pinned
editor, archive and browser scenarios without manager GUI or performance claims.
It is always DIAGNOSTIC_ONLY, records that the normal manager WebView was not
exercised, and cannot satisfy the full P09 retainer. The default full workload
and every mandatory full case remain unchanged. This reduces iteration time for
remaining native app input work while the complete gate runs independently.

### Browser document focus and Windows accessibility provider

The f9b719d Server diagnostic passed the complete native Notepad++ save workflow:
exact boxed output was present within 5 ms, expected bytes matched and host data
remained unchanged. Browser request history still contained only the initial
boxed main request, so a successful SendKeys call was not navigation proof.
The helper now verifies a neutral native click inside the known canary document
and actual focus before addressing the browser. It uses the real owned Windows
UI Automation address field when available, with exact value readback and native
Enter, and retains the native keyboard fallback. All expected-page, actual HTTP,
held process/original-driver attribution and handler/output checks remain.

Disposable Firefox host/boxed profiles explicitly enable the accessibility
provider with `accessibility.force_disabled=-1`. Mozilla documents -1 as force
enable, 0 as on-request and 1 as disabled in
[nsAccessibilityService.cpp](https://github.com/mozilla-firefox/firefox/blob/main/accessible/base/nsAccessibilityService.cpp).
This is an accessibility preference, not a content sandbox exception. The real
about:support effective sandbox level must still be positive. Its owned Windows
TextPattern can supply the rendered level directly; only that number and source
kind are retained, and raw support content is never saved.

Native target/modal window discovery now uses the bounded z-order enumeration
and the existing native root-owner predicate, and recognizes the exact expected
picker title as well as the classic dialog class. This supports owned modal
windows without assuming every native picker is enumerated as a classic desktop
window. Tauri IPC remains protected and unchanged. The missing picker diagnostic
records only rendered typed errors and a form-presence flag; no raw native
arguments, selections, URLs or exceptions are exported.

### Initial UWP picker advertises an unimplemented Window.Close

The 83d0e6c ARM layout artifact found two visible PickerHost windows through the
new z-order enumeration. The controller authenticated both as its same-user
protected Microsoft component with the enrolled process birth. The first closed;
the second advertised WindowPattern but threw NotImplementedException from Close.
The controller now falls back to the same exact-window WM_CLOSE only for
NotImplementedException/NotSupportedException, repeating owner and birth checks
immediately before posting. Other failures remain refusals and the window must
actually become invisible. No new process identity, permission, termination,
application selection or OS-default change is accepted.

### Collapse owned Settings lists after selecting display values

The display controller expanded the resolution and scaling comboboxes and used
SelectionItem.Select without explicitly collapsing either list. Selection alone
does not guarantee that a popup closes. The controller now reacquires each
combobox by its existing fixed automation ID, collapses it and verifies Collapsed
before minimizing Settings. This is an ordinary action on the already owned
Settings control and adds no window/process permission. Windows must confirm
whether the outstanding PickerHost surfaces and physical input are corrected.


### Reviewed Save passes; ordinary export destination required

At `aa5b8f5`, Server focused 38879930769 and full 38879931585 both saved the
exact reviewed minimized bytes and passed 95 UI assertions. The full run passed
21 native cases, including actual editor/archive and all four browser workflows.
The only failed case was the dependent transfer/lifecycle sequence. Its picker
selected the lab-private ProgramData folder, and the native guard correctly
refused DESTINATION_SENSITIVE_SCOPE. The UI exposed that exact typed reason.
The test now selects a unique ordinary owner-profile folder and observes actual
UI Complete / OBSERVED without an error before checking the real file and its
SHA-256. Production destination guards are unchanged. No downstream lifecycle
success is claimed from the failed run. Original JSON and hashes are retained;
ARM and final matching-source results remain pending.


### The second initial PickerHost surface is Shell_SystemDialog

Both ARM `aa5b8f5` runs positively saved exact reviewed bytes and passed 95 UI
assertions. The full run completed the ten-environment/10000-file/60-second
workload. In addition to the sensitive export refusal, browser welcome failed a
real physical point guard: the hit belonged to WINDOWS_PICKER_HOST with exact
class Shell_SystemDialog. The initial-owner controller acknowledged preparation
but discovered no eligible visible component window through its existing bounded
lookups. The lab now queries that exact class and uses the same initial-shell
Hide branch as Shell_SystemDim, only after existing same-user, protected Microsoft
image/signature and enrolled PID/creation-time guards. Actual invisibility and
target point ownership still must pass. New process identities are never enrolled
during product execution; no process is terminated. Full startup UIA passed;
focused startup UIA failed with no accessible navigation and remains a real
historical failure. The fresh matching-source result is mandatory.


## Superseded detailed report snapshot after aa5b8f5

Historical snapshot; the current phase report is authoritative. All failures below
remain historical failures and do not satisfy a final matching-source gate.

### Historical P09 report

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


## Correct the completion assertion against the actual transfer journal

Source inspection after `2aef3c7` found an error in the newly added UI fixture:
its successful row expected Complete / OBSERVED, but the persisted transfer
reason is TRANSFER_COMPLETED_UNTRUSTED. The response-level reason OBSERVED is
not the row's transfer reason. The assertion now requires the actual displayed
Complete / TRANSFER_COMPLETED_UNTRUSTED label, no UI error, real output bytes and
SHA-256 equality. No production code or guard changed. Runs 38884281687 and
38884280563 were cancelled as superseded by this known assertion correction;
they cannot close a gate. Fresh runs use the corrected exact source.


## First full 217f550 ARM attempt refuses environment four

Run 38885567690 stopped ARM at SEEDING_ENVIRONMENT_04 with
DIAGNOSTIC_SYSTEM_IMAGE_UNREVIEWED. Read-only CIM observed WerFault without a
verified target association; fixed component logs had no corresponding event.
No component cause is inferred and no full reference sample exists. Original
reviewed JSON and hashes are retained. No reporter is killed/trusted/exempted.
Fresh full matrix 38887488001 repeats exactly unchanged `217f550` on the immutable
candidate pin `verify/p09-217f550`. This is a fresh VM retry, not a waived failure
or successful gate; focused and final matching regressions remain required.
