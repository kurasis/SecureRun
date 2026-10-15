# P09 performance and minimized diagnostics

Native measurements are pending. No measured result is inferred from compilation.

| Workload | Required reference budget | Measurement |
|---|---|---|
| Startup | Interactive within 3 seconds | Normal release without inspector; prewarmed Windows UIA watcher invokes Settings and observes its enabled language control |
| Idle | CPU below 1% over at least 60 seconds | Complete kernel job CPU delta including exited children; denominator explicitly records logical processor count |
| Idle memory | Aggregate average working set below 250 MiB | Sample the complete manager/Rust/WebView job every 250 ms; retain peak and sample count too |
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
