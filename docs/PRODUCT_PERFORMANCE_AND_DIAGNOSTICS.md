# P09 performance and minimized diagnostics

The engineering targets and complete reference workload remain unchanged.
[Acceptance gate 7](specification/08_TESTING_AND_ACCEPTANCE.md#acceptance-gates)
requires measured budgets and user-impact explanations for deviations. A measured
deviation is recorded separately from a passed functional/security scenario; it
never becomes a claim that the numerical target was met. Missing measurements,
focused/inspected workloads, incomplete process groups or missing mandatory
application/file/accessibility proof still prevent phase completion.

## Current P10 full reference measurement

Status: DONE at `75b6c0bab24e7ea0edd86a3be2adea6648456a6b`,
[full integration run 39068949002](https://github.com/kurasis/SecureRun/actions/runs/39068949002). Both targets passed 22 native cases and
101 UI assertions using the normal release build and complete ten-environment/
10000-file workload, with no inspector and complete kernel-job CPU including
exited workers/WebViews. Engine and target processes are excluded.

| Metric | Unchanged target | Server x64 | Windows 11 ARM64 |
|---|---:|---:|---:|
| Interactive startup ms | ≤3000 | 6120.0595 — DEVIATION | 2350.5837 — MET |
| Complete-job idle CPU % | <1 | 1.20385222183 — DEVIATION | 1.09853284926 — DEVIATION |
| Average working set bytes | <250000000 | 232934286 — MET | 244505374 — MET |
| Process update ms | ≤2000 | 684.6 — MET | 1281.3 — MET |
| Added launch ms | <1000 | 441 — MET | 504 — MET |

Server: 60028 ms/234 samples, peak working set 381493248 bytes.
ARM: 60094 ms/223 samples, peak working set 416952320 bytes.
The memory target applies to the average, not the peak.

Server takes longer before interactive controls are available. Idle CPU on both
targets exceeds the original target and may increase power use. Average memory,
process update and added-launch targets were met on both. Original target flags
and user impact are preserved in the current assessments; both are
MEASURED_DEVIATION with mandatory_checks_waived=false. No functional/security
check or reference-workload condition was waived.

- [Server exact assessment](evidence/p09/completion-75b6c0b/windows-2025/performance-budget-assessment.json)
- [ARM exact assessment](evidence/p09/completion-75b6c0b/windows-11-arm/performance-budget-assessment.json)

## Historical P09 completion measurement

Status: DONE at `f9a9755a4e32bac27ef65ad9e4b5fdca32f7a67f`,
[run 38894071449](https://github.com/kurasis/SecureRun/actions/runs/38894071449).
All 22 native cases and 101 UI assertions passed on each target. Both normal
release samples used ten actual idle environments and 10000 files without an
inspector, with complete kernel-job CPU including exited workers/WebViews.
Server: 60190 ms/233 observations; ARM: 60139 ms/223 observations. Engine and
application-target processes are excluded from the measured manager group.

| Metric | Unchanged target | Server x64 | Windows 11 ARM64 |
|---|---:|---:|---:|
| Interactive startup ms | ≤3000 | 3810.259 — DEVIATION | 2365.5266 — MET |
| Complete-job idle CPU % | <1 | 1.1422099692 — DEVIATION | 1.2406132546 — DEVIATION |
| Average working set bytes | <250000000 | 229795180 — MET | 254373796 — DEVIATION |
| Process update ms | ≤2000 | 1186.4 — MET | 1349 — MET |
| Added launch ms | <1000 | 541 — MET | 552 — MET |

Server can take longer before controls become interactive. Higher idle CPU may
increase power use. ARM average memory is 4373796 bytes above target, leaving
less available to other applications. Peak observed working sets were
395481088/416501760 bytes; the original memory budget applies to the average.
All five targets and exact flags remain in the original
[Server assessment](evidence/p09/completion-f9a9755/windows-2025/performance-budget-assessment.json)
and [ARM assessment](evidence/p09/completion-f9a9755/windows-11-arm/performance-budget-assessment.json).
Both are MEASURED_DEVIATION with mandatory_checks_waived=false. No missing
functional/security case or reference workload was waived.

## Earlier measurements and measurement method

The lab produces `performance-budget-assessment.json` with all five original
targets, observed values, exact comparisons, MET/DEVIATION results and user impact.
The retainer recomputes it from the actual samples and rejects absent or changed
explanations, contradictory target flags and non-finite data. Earlier full samples also
missed some engineering targets. Historical normal release runs measured:

| Full reference run | Runner | Startup ms | Complete-job CPU % | Average working set bytes | Result |
|---|---|---:|---:|---:|---|
| `38839426236`, `f2ebba3` | Server | 5503.9137 | 0.753328196 | 229493149 | CPU and memory targets met; startup deviation |
| `38839426236`, `f2ebba3` | ARM | 2362.7337 | 1.220673525 | 245477794 | Startup and memory targets met; CPU deviation |
| `38851310774`, `b04a766` | Server | 3723.5445 | 1.201683426 | 230145977 | Startup and CPU deviations; mandatory application cases failed |
| `38864957115`, `f4c4603` | Server | 6933.7482 | 1.137207001 | 230689013 | Startup and CPU deviations; mandatory launch/browser cases failed |
| `38870280695`, `7ccda2b` | ARM | 2616.9734 | 1.143244435 | 243431929 | Startup and memory targets met; CPU deviation; six mandatory cases failed |
| `38872735865`, `be0b4c7` | Server | 5210.3185 | 1.090117483 | 228568370 | Startup and CPU deviations; four mandatory cases failed |
| `38876095712`, `96159c8` | Server | 7028.298 | 0.739384482 | 233778657 | Startup deviation; CPU/memory targets met; native Save failed |
| `38879931585`, `aa5b8f5` | Server | 4008.2433 | 1.247539768 | 230728418 | Startup and CPU deviations; 21 native cases passed, sensitive test export destination refused |
| `38879931585`, `aa5b8f5` | ARM | 2872.8287 | 1.286900400 | 239241041 | Startup/memory targets met; CPU deviation; sensitive test export and browser welcome failed |
| `38887959409`, `0071e2c` | Server | 5848.2869 | 0.739890212 | 230532884 | Startup deviation; CPU/memory met; 99 UI assertions, next confirmation unobserved |
| `38887959409`, `0071e2c` | ARM | 2411.0373 | 1.227338717 | 244125310 | Startup/memory met; CPU deviation; 101 UI/complete lifecycle passed, archive/browser failed |
| `38891751077`, `f9a9755` | Server | 5472.0596 | 1.080477340 | 228076482 | All 22 native/101 UI cases passed; startup/CPU deviations; update/added-launch targets met |

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
Historical samples cannot replace the final-source measurement above.

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

Current result: DONE in the [P09 manifest](evidence/p09/manifest.json), with all
matching P03–P08 source-bound regressions. Exact reviewed native Save examples are
retained for [Server](evidence/p09/completion-f9a9755/windows-2025/reviewed-diagnostic-example.json)
and [ARM](evidence/p09/completion-f9a9755/windows-11-arm/reviewed-diagnostic-example.json).
The native saved bytes exactly equal their reviewed minimized previews; local
history and captured errors passed synthetic secret scans.

These measurements apply to the documented hosted tuples. They do not establish
installed Windows 11 x64 release performance. Earlier setup/workflow failures and
budget deviations remain immutable history. No Windows reporting/security setting,
engine signature/TLS/checksum or browser sandbox protection was weakened to pass.
