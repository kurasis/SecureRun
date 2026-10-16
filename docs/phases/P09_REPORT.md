# P09 — Product UX and application compatibility

Status: DONE. The [formal manifest](../evidence/p09/manifest.json) retains successful
full proof on Windows Server 2025 x64 and Windows 11 ARM64. Each target passed all
22 native scenarios and 101 UI assertions with zero failures.

Verified runtime/lab source: `f9a9755a4e32bac27ef65ad9e4b5fdca32f7a67f`.
[Full P09 run 38894071449](https://github.com/kurasis/SecureRun/actions/runs/38894071449)
and all six P03–P08 regressions use this exact commit. Later documentation/evidence
commits preserve those protected source bytes. Requested scope is P09 only;
P10–P12 remain NOT_STARTED. Installed T01–T66 acceptance remains unrun until P12.

## Delivered behavior and principal files

The [original native interface](../../ui/main.tsx) presents Applications, Processes,
Files, Permissions, Activity and Retention/recovery using real backend state.
Activity and launch eligibility are independent. Onboarding distinguishes missing,
untrusted, unavailable, restart-required, untested and verified engines and explains
Standard-user service-identity limitations. Mandatory rules are read-only; uncertain
outcomes direct the user to inspect recorded state before another action.

[English/Russian resources](../../ui/strings.ts), [presentation](../../ui/product.ts),
visible keyboard focus, themes and actual 100/150/200 percent content/Windows scaling
are complete. [Application controls](../../ui/controls.tsx) require loaded metadata
and use the current environment revision for launch. Backend CAS refusal remains;
mutations are never retried automatically after an uncertain result.

[File views](../../ui/files.tsx) show complete inert escaped filenames and bounded
pages. Selection does not launch or register a file. Exact native input, transfer
hashes, rename-or-skip collision handling and host integrity are verified.
Metadata rename preserves identity/policy/generation and stores a replay tombstone.
Running policy changes require reviewed differences, explicit queue, whole-box
Stop and independently verified stopped Apply. Archive/Unarchive/Reset use separate
native confirmation naming the exact environment and retained/deleted state.

[Native product commands](../../src-tauri/src/product.rs) and
[adapter state](../../crates/sandboxie-adapter/src/windows/provisioning/product.rs)
provide bounded observation/history and minimized diagnostics. Private history
retains typed events for at most 30 days/512 entries. Shared export removes local
environment identities, limits events/bytes, requires exact preview and an expiring
one-use native Save token, creates new files only and never opens/uploads output.
[Native pickers](../../src-tauri/src/native.rs) use a fresh thread and the actual
parent window. Exact reviewed output and local UTF-8/UTF-16 captures passed secret-
canary checks. Inert UTF-16 filename decoding preserves complete metadata while
strict engine/configuration/output-name and containment guards remain enforced.

Read-only observation holds authenticated immutable objects for at most 60 seconds,
checking fresh driver/process/configuration/root state each frame. Mutations repeat
their own guards. WebView2 uses its public low-memory target with normal rendering.
Completed private enforcement definitions retire only after verified idle, retaining
data/evidence; failed scopes remain fenced. No recursive diagnostic-data cleanup,
browser sandbox disabling, host fallback or broad exception is introduced.

## Exact-source validation

| Gate | Actions run | Result per target |
|---|---|---|
| P03 | [38893325430](https://github.com/kurasis/SecureRun/actions/runs/38893325430) | 19 foundation, 4 app, 3 frontend and 32 native command cases; portable job passed |
| P04 | [38893328564](https://github.com/kurasis/SecureRun/actions/runs/38893328564) | 61 adapter tests and 19 native observation/trust cases |
| P05 | [38893332061](https://github.com/kurasis/SecureRun/actions/runs/38893332061) | 61 adapter tests and 45 applicable native cases; T52 N/A because no elevation/helper route exists |
| P06 | [38893334893](https://github.com/kurasis/SecureRun/actions/runs/38893334893) | 21 Server / 22 ARM launch/control cases |
| P07 | [38893338017](https://github.com/kurasis/SecureRun/actions/runs/38893338017) | 28 Server / 29 ARM safe-file/boxed-EXE cases; zero actor failures |
| P08 | [38893340716](https://github.com/kurasis/SecureRun/actions/runs/38893340716) | 38 native lifecycle/recovery cases each; zero actor failures |
| P09 | [38894071449](https://github.com/kurasis/SecureRun/actions/runs/38894071449) | 22 native cases and 101 UI assertions each; zero failures |

Formal retainers accepted evidence in dependency order with every protected source,
including lab tools, unchanged. P09 completion retains 690 original JSON files and
22 reviewed synthetic PNGs with byte hashes. Historical failed/cancelled/diagnostic-
only trials remain immutable history; none substitutes for the successful full run.

Each full target used the normal release manager as a Standard user, ten actual
idle environments, 10000 files, complete 79-page traversal and at least 60 seconds
of kernel-job CPU including exited workers/WebViews. Engine/targets and the separate
inspected interaction instance are excluded from idle accounting.

Real keyboard/Windows UIA, native picker/confirmation, Chromium accessibility,
English/Russian light/dark content scales and actual window DPI 96/144/192 passed.
The official editor saved boxed bytes, the archive GUI created/extracted matching
content, and Firefox proved separate host/boxed profiles, actual main/child socket
ownership, boxed reachable protocol execution and effective content sandbox level 9.
These are provider/automation results, not a subjective audit of every screen reader.

Production feature checks cover T30/T32/T41/T63/T66 without completing the separate
installed-candidate acceptance registry. Local validation includes the repository/
specification/evidence validator and 18 Python tooling tests. Windows/portable jobs
include release builds, type checks, Rust tests/formatting/Clippy and frontend tests;
fixture JavaScript/PowerShell/C# syntax/compilation checks also passed.

Commands include `python tools/lab/validate_repository.py`,
`python -m unittest discover -s tests -q`, `node --check tools/probe/p09_ui.js`,
`gh workflow run p03.yml` through `p09.yml` on the exact pin, and the corresponding
`retain_pXX_evidence.py --download-directory ... --tested-commit ... --run-id ...`
commands. Linux checks alone are never native Windows proof.

## Measured budgets and user impact

Original targets are unchanged. Specification
[acceptance gate 7](../specification/08_TESTING_AND_ACCEPTANCE.md#acceptance-gates)
requires measured deviations with impact explanations; no mandatory functional or
reference-workload check is waived. Both assessments are MEASURED_DEVIATION.

| Metric | Original target | Server x64 | Windows 11 ARM64 |
|---|---:|---:|---:|
| Interactive startup ms | ≤3000 | 3810.259 — deviation | 2365.5266 — met |
| Complete-job idle CPU % | <1 | 1.1422099692 — deviation | 1.2406132546 — deviation |
| Average working set bytes | <250000000 | 229795180 — met | 254373796 — deviation |
| Process update ms | ≤2000 | 1186.4 — met | 1349 — met |
| Added launch ms | <1000 | 541 — met | 552 — met |

Server startup can delay interactive controls beyond three seconds. Higher idle CPU
may increase power use. ARM average memory exceeds the target by 4373796 bytes,
leaving less RAM for other applications. Samples lasted 60190/60139 ms with 233/223
observations. See [performance/diagnostics](../PRODUCT_PERFORMANCE_AND_DIAGNOSTICS.md),
[application compatibility](../APPLICATION_COMPATIBILITY.md) and
[UX/accessibility](../PRODUCT_UX.md) for exact scope and original evidence.

## Limits and handoff

Owner-selected labs are Server 2025 x64 build 26100 and Windows 11 ARM64 build 26200,
with actual x86 and emulated x64 regressions. Engine: original Sandboxie Plus 1.18.6 /
core 5.73.6 / ABI 0x57230. This does not certify an installed Windows 11 x64 release,
other app/engine versions, plugins, paid entitlement or future updates.

Earlier CI failures included unreviewed system-image refusals with unassociated
WerFault and obstructed desktop surfaces. Their original failures remain in
[the investigation log](P09_INVESTIGATION_LOG.md) and manifest history. No reporter
was killed/trusted/exempted, no unknown window hidden and no OS security setting,
TLS, signature, checksum or browser sandbox check weakened. The lab prepares only
fixed authenticated initial Microsoft surfaces with exact process birth and scoped
requests; actual target point ownership still must pass. No engine is bundled.

The original 26 specification documents are unchanged. P10 is the next eligible
phase, not part of this request. Packaging and installed acceptance remain P11/P12;
all 66 final acceptance entries remain NOT_STARTED.
