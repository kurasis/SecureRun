# P09 performance and minimized diagnostics

The engineering targets and complete reference workload remain unchanged.
[Acceptance gate 7](specification/08_TESTING_AND_ACCEPTANCE.md#acceptance-gates)
requires measured budgets and user-impact explanations for deviations. A measured
deviation is recorded separately from a passed functional/security scenario; it
never becomes a claim that the numerical target was met. Missing measurements,
focused/inspected workloads, incomplete process groups or missing mandatory
application/file/accessibility proof still prevent phase completion.

The lab produces `performance-budget-assessment.json` with all five original
targets, observed values, exact comparisons, MET/DEVIATION results and user impact.
The retainer recomputes it from the actual samples and rejects absent or changed
explanations, contradictory target flags and non-finite data. Current full samples
miss some engineering targets. Normal release runs measured:

| Full reference run | Runner | Startup ms | Complete-job CPU % | Average working set bytes | Result |
|---|---|---:|---:|---:|---|
| `38839426236`, `f2ebba3` | Server | 5503.9137 | 0.753328196 | 229493149 | CPU and memory targets met; startup deviation |
| `38839426236`, `f2ebba3` | ARM | 2362.7337 | 1.220673525 | 245477794 | Startup and memory targets met; CPU deviation |
| `38851310774`, `b04a766` | Server | 3723.5445 | 1.201683426 | 230145977 | Startup and CPU deviations; mandatory application cases failed |
| `38864957115`, `f4c4603` | Server | 6933.7482 | 1.137207001 | 230689013 | Startup and CPU deviations; mandatory launch/browser cases failed |
| `38870280695`, `7ccda2b` | ARM | 2616.9734 | 1.143244435 | 243431929 | Startup and memory targets met; CPU deviation; six mandatory cases failed |
| `38872735865`, `be0b4c7` | Server | 5210.3185 | 1.090117483 | 228568370 | Startup and CPU deviations; four mandatory cases failed |

The `f4c4603` ARM run stopped at environment seven with an unreviewed system image
and an unassociated WerFault; that run has no full ARM sample. The later
`7ccda2b` ARM run completed ten idle environments, 10000 files, 223 samples and
60135 ms of complete kernel-job accounting, including exited workers. It also
completed all 79 file pages and 93 UI assertions, but retained six mandatory
workflow failures and cannot close P09.

The `b04a766` ARM run stopped at CREATE 10 with an unreviewed system image and
an unassociated WerFault; it has no full resource sample. No reporting setting
is changed and no reporter is killed or accepted through a new whitelist.

Each full sample uses ten actual idle environments, 10,000 files and at least
60 seconds of complete kernel-job accounting. A later ARM run at `496272b`
refused CREATE 10 during an online incoming TCP diagnostic and has no resource
sample. It cannot replace the completed reference workload.

Focused run `38826425388` at `c2f9b5a` measured 1.18415% CPU / 226910825 bytes on
Server and 1.29373% / 229258465 bytes on ARM. These four-environment measurements
are diagnostic-only and their CPU also exceeds the target. Compilation and the
separate zero-environment measurement fixture cannot satisfy the performance gate.

The current bounded read-only observer holds authenticated component objects for
at most 60 seconds. Each 1.7-second frame independently checks current service,
protected object identity, driver ABI, manager context, boxes, processes, roots
and configuration. Every mutation repeats its independent native guards. One
conditional status waiter has a three-second deadline. The frontend consumes
completed frames immediately, backs off unchanged/error replies and uses a
single claim-expiry timer. Control eligibility refreshes within its original
15-second validity. Unknown or failed observations clear availability.

WebView2 uses its public low-memory target and normal rendering defaults. A
software-composition experiment was reverted after failing to improve CPU and
producing a 40.9-second startup outlier. The actor uses its loaded Windows profile
and owner-private writable fixture TEMP; no security setting is changed.
Historical samples cannot establish performance at the final source revision.

| Workload | Required reference budget | Measurement |
|---|---|---|
| Startup | Interactive within 3 seconds | Normal release without inspector; prewarmed Windows UIA watcher invokes Settings and observes its enabled language control |
| Idle | CPU below 1% over at least 60 seconds | Complete kernel job CPU delta including exited children; denominator explicitly records logical processor count |
| Idle memory | Aggregate average working set below 250 MB (250,000,000 bytes) | Sample the complete manager/Rust/WebView job every 250 ms; retain peak and sample count too |
| Process update | At most 2 seconds | Introduce an actual independently launched boxed member and wait for the real environment card |
| Added launch latency | Below 1 second | Same fixed benign probe through original dispatch and checked manager dispatch; remove no production checks |
| File list | Ten idle environments; one box with 10,000 files | Measure first actual UI listing and walk every native page; retain at most 128 rows per page/DOM |

The fixture creates the manager suspended, assigns its process to a held kernel
job, then resumes it. WebView and short-lived manager workers stay in that
accounting group. Engine/service and target workloads are excluded. A separate
inspected GUI is used for interaction checks after idle measurement; inspector
resources never count as a production idle result. Hosted-runner hardware and
native Windows DPI are recorded as limitations of the reference workload.

Manager history accepts only typed actions, outcomes, a diagnostic UUID, a
timestamp and an optional local environment UUID. It has no arbitrary message,
filename, argument, environment or certificate field. Private SQLite history
retains at most 512 events for 30 days. If persistence cannot be confirmed, the
interface labels session history explicitly. Manager events describe requests
and observed outcomes, not general engine access auditing or target completion.

Shared JSON removes the local environment UUID too. Its exact schema contains
schema/product, at most 64 action/outcome/diagnostic-ID/timestamp events and an
explicit false engine-access-events-available flag. Preview is exact and expires
after 60 seconds. Save consumes its backend token before a native file picker,
uses only the reviewed bytes and a new ordinary JSON filename, never replaces an
existing file, and never opens or uploads the output. There is no renderer path
or arbitrary diagnostic-body argument.

Private enforcement diagnostics retain at most 256 generated scopes. A completed
verified definition is retired only after exact current scope and complete idle
checks; its data and audit evidence remain. Failed scopes remain fenced. No
recursive diagnostic data deletion or automatic retry of user work is added.

The native lab actually passes a synthetic secret argument to a boxed probe and
injects a different synthetic manager environment secret. The probe reports that
it received the intended argument and did not inherit the environment secret.
It emits adversarial synthetic error text. The lab scans manager captures,
private history/WAL and exact exported diagnostics in UTF-8 and UTF-16. Target
arguments and raw errors are never copied into retained evidence. A real reviewed
redacted example is retained only after its native save succeeds.

Current result: pending [P09 manifest](evidence/p09/manifest.json).


Current observed deviations mean that the first interactive window can arrive
later than three seconds and that idle processor use can exceed the one-percent
target, potentially increasing power use. Average working set has met the
250,000,000-byte target in the completed reference samples cited above. These
observations are specific to the documented hosted runners and do not establish
Windows 11 x64 release performance. Both targets have historical complete reference samples; final-source measurement,
application, accessibility and phase proof remain incomplete.
