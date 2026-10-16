# P09 — Product UX and application compatibility

Status: IN_PROGRESS. Requested scope: full P09 only.
Dependency: P08 passed on both owner-selected Windows targets; its exact-source
proof remains historical while P09 changes are validated.

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
The repository validator and 14 tooling tests pass. Portable Rust tests, Windows
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
