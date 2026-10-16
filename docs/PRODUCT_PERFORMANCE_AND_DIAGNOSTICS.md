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

Each full sample uses ten actual idle environments, 10,000 files and at least
60 seconds of complete kernel-job accounting. A later ARM run at `496272b`
refused CREATE 10 during an online incoming TCP diagnostic and has no resource
sample. It cannot replace the completed reference workload.

Focused run `38826425388` at `c2f9b5a` measured 1.18415% CPU / 226910825 bytes on
Server and 1.29373% / 229258465 bytes on ARM. These four-environment measurements
are diagnostic-only and their CPU also exceeds the target. Compilation and the
separate zero-environment measurement fixture cannot satisfy the performance gate.

The next revision uses a bounded read-only observation worker: authenticated
component file objects remain held against writes/deletion for at most 60 seconds.
Each 1.7-second snapshot still checks SCM configuration/status, protected object
ownership/DACL/link identity, current driver ABI, manager/worker context, boxes,
processes, roots and configuration. A stale, changed or failed observation clears
availability. Every mutation independently repeats its full native checks; the
observer supplies no mutation authority. WebView2's public low-memory target
reduces caches without changing its sandbox or excluding any child from the
measurement. Fresh Windows measurements are required before claiming further improvement.
Numeric startup tracing at `9daaf46` found 83 ms initial engine observation,
90 ms to WebView construction and 4167 ms through window construction. A software-composition experiment did not improve the isolated CPU measurement
and produced a 40.9-second cold-start outlier. The next build restores the normal
WebView rendering defaults rather than accepting an unproven rendering change.
The standard-user actor derives its profile environment from its loaded Windows
profile and uses an owner-private writable fixture TEMP. This is measured setup,
not a change to any engine, sandbox or Windows security setting.

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


The next observer revision combines a complete snapshot every 1.7 seconds with
one bounded conditional status request, returning immediately on publication.
It reduces full-snapshot work while removing the extra client polling delay;
configuration checks are not cached or omitted. Native scope/context checks for
every operation remain independent. One reserved waiter and a three-second
deadline bound this read-only wait; resource and update budgets still require
actual matching Windows measurements.

The next UI consumes its existing bounded conditional health read immediately
after each completed snapshot, instead of adding a one-second polling phase. An
unchanged/error reply has a one-second backoff, and unmount releases its wait. A
single deadline timer expires claims without a periodic full UI clock render.
Readonly control eligibility refreshes every 14 seconds, within its unchanged
15-second validity; process activity still uses complete 1.7-second native
observations. Slow/failed refreshes become Unknown. Every action repeats full
current native guards. These changes require fresh full-workload measurements.

Native operation setup retains its once-authenticated immutable component objects
through full context observation and execution, avoiding two immediate hash/
signature passes over the same protected bytes in one operation. Every new
operation still authenticates independently. Box snapshot byte accounting is
incremental with the exact same compact-JSON bound; no native checks or fields
are skipped. Fresh reference measurements are required.

Current observed deviations mean that the first interactive window can arrive
later than three seconds and that idle processor use can exceed the one-percent
target, potentially increasing power use. Average working set has met the
250,000,000-byte target in the completed reference samples cited above. These
observations are specific to the documented hosted runners and do not establish
Windows 11 x64 release performance. Both targets now have a complete reference resource sample; application, file,
accessibility and final-source phase proof remain incomplete.
