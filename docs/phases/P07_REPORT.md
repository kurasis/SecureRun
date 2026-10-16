# P07 — Safe file workflows and boxed executable references

Current P09 dependency regression: DONE at
`f9a9755a4e32bac27ef65ad9e4b5fdca32f7a67f`,
[run 38893338017](https://github.com/kurasis/SecureRun/actions/runs/38893338017).
Server passed 28 and ARM passed 29 actual safe-file/boxed-EXE cases, with zero failures or actor failures. Normal/fault binary provenance and staged executable hashes are retained.
All earlier dependencies passed on the same source. The
[manifest](../evidence/p07/manifest.json) binds original reports and every
protected source, including current lab tools. Full P09 also passed on this exact source; see the [P09 report](P09_REPORT.md). The sections below preserve
the original completion and historical regressions.


Status: DONE. Specification: 1.3. Requested scope: complete P07.
Implementation branch: `p07/safe-files`. Current runtime:
`bec50c8fa7d0b47c4f05aa6662eeeb24faa18f68`.
[P07 native run 38729086335](https://github.com/kurasis/SecureRun/actions/runs/38729086335)
completed successfully on both laboratories: 28 Server / 29 ARM cases passed,
with zero failed or actor failures. Matching P03–P06 regressions passed on this same commit. Strict retainers verified
all mandatory cases, exact source hashes and immutable raw checksums; no phase
gate remains blocked.

## Outputs and behavior

- `crates/sandboxie-adapter/src/files.rs`: bounded file contracts, output-leaf and
  local-file grammar, incremental safe-copy/provenance primitives, opaque entry
  references and a WAL/FULL operation journal with permanent duplicate tombstones.
- `crates/sandboxie-adapter/src/windows/provisioning/files.rs`: metadata-only lazy
  enumeration through validated engine roots; selected regular-file import;
  stopped-box export to fixed local NTFS; held-object no-replace publication;
  exact-marker recovery and explicit identity/generation-bound staging discard.
- `crates/sandboxie-adapter/src/bin/securerun-box-launcher.rs` and control service:
  BoxExecutableRef mapping, file/content/generation/stage binding and an original
  native boxed stage. It validates injected-engine membership before target I/O,
  creates the explicit logical EXE suspended and verifies membership before resume.
  No physical storage path becomes a host launch target. Receipts describe the
  stage separately from the unobserved registered-target outcome.
- `src-tauri` command and native selection leases: exact main-window authorization,
  one-use operation/environment/revision-bound picker tokens, renderer schemas
  without raw transfer paths and generation checks on returned file views.
- `ui/files.tsx`: EN/RU file metadata/navigation, import, export, visible suffixes,
  boxed registration, collision Rename/Skip, cancellation, recovery and verified
  staging discard. Partial/error states remain visible; content is never previewed.
- `tools/lab/Invoke-P07.ps1`, disposable ordinary-user fixtures and strict evidence
  retention: genuine PE architectures, original engine mapping observations, five
  real killed-worker crash windows, sparse >4 GiB transfer and adversarial NTFS.

The [safe file contract](../SAFE_FILE_WORKFLOWS.md) specifies mappings, bounds,
marker-before-payload, handle leases, cancellation and publication. IPC and
persistence documentation describe the application boundary and durable records.

## Requirement and scenario coverage

Scope: PR-09, PR-03 boxed references and PR-18 transfer behavior.

| Scenario | Production verification owned by P07 |
|---|---|
| T20 | Explicit regular-file import, duplicate/collision refusal, cancellation, disk exhaustion and missing/recreated-root handling |
| T21 | Correct exported bytes, explicit destination, validated provenance and no automatic opening |
| T22 | Reparse/hard-link/stream rejection, unsafe destinations and held source/destination replacement refusal |
| T23 | HTML/SVG/shortcut/EXE metadata stays inert, without payload or preview execution |
| T42 | Original SandMan coexistence, running-box refusal and independently launched live external member abort without publication |
| T43 | Import, original engine logical mapping and boxed launch for actual native/emulated target PEs; reset invalidation finishes in P08 |
| T44 | Existing output, case/available short-name alias, actual pre-rename collision and marker-failure no-overwrite behavior |
| T45 | >4 GiB sparse input copied incrementally with equal SHA-256, bounded chunks/memory, real disk exhaustion and explicit partial states |
| T49 | Actual main-WebView authorization, forged entry IDs/raw-path refusal, and normal-build checkpoint/host boxed-stage refusal |
| T63 | Unsafe leaves and full suffix visibility; HTML/SVG/shortcut/EXE metadata stays inert |
| T64 | Marker failure copies zero bytes; real interruption before/after marking, mid-copy and before/after rename; no overwrite/replay |
| T65 | Replaced staging remains untouched; explicit discard checks file, directory, parent and current generation; old-generation records cannot mutate a recreated root |

Additional required fixtures cover real NTFS disk exhaustion, cancellation,
source hard links/extra streams/reparse points, unsupported destinations, forged
entry/raw-path requests, restricted-zone preservation, duplicate operations,
original SandMan coexistence and normal-build rejection of CI checkpoint activation.
No production acceptance scenario is marked complete merely by phase evidence.

## Verification and provenance

Original Sandboxie Plus 1.18.6 / core 5.73.6 / ABI `0x57230`; upstream
`cdba7096240b93d79c5373aa81a75a1c5c71b883`. Owner-selected laboratories are
Windows Server 2025 x64 build 26100 and Windows 11 ARM64 build 26200. Actual x86
PEs run on both; ARM also runs emulated x64. Native manager/stage match each OS.
No Windows security setting is changed; no engine or SandMan binary is bundled.


| Gate | Exact-source run | Server / ARM result |
|---|---|---|
| P03 command boundary | [38729076831](https://github.com/kurasis/SecureRun/actions/runs/38729076831) | Each: 19 foundation, 2 normal native, 3 UI and 27 command cases passed |
| P04 observation | [38729079754](https://github.com/kurasis/SecureRun/actions/runs/38729079754) | Each: 38 adapter tests and 19 native scenarios passed |
| P05 provisioning | [38730156869](https://github.com/kurasis/SecureRun/actions/runs/38730156869) | Each: 38 adapter tests and 45 applicable cases passed; one accurate Not applicable UAC route |
| P06 launch/Stop | [38729083037](https://github.com/kurasis/SecureRun/actions/runs/38729083037) | 21 / 22 cases passed; no failures |
| P07 safe files/boxed references | [38729086335](https://github.com/kurasis/SecureRun/actions/runs/38729086335) | 28 / 29 cases passed; no failures or actor failures |

Portable checks pass: 19 foundation and 32 adapter tests, strict clippy, 3 UI
checks and production asset build. Strict i686 Windows metadata checking is not
native Windows evidence. Repository validation and all 10 tooling tests pass.
PowerShell scripts parse with official PowerShell 7.5.4. Both native P07 workflows
and matching P03–P06 dependency regressions passed.

Retainers require successful exact-source Actions runs, all mandatory named
cases, current runtime-file hashes, distinct normal/fault binary hashes and
matching P03/P04/P05/P06 commits. The [immutable evidence manifest](../evidence/p07/manifest.json)
retains reviewed JSON with checksums; it excludes credentials, raw arguments,
private paths and generated executables.

## Investigations and limitations

Initial MOTW sharing failed closed before payload; the marker read lease now
permits the required base-file rename while denying marker writers. Native
relative `NtSetInformationFile(FileRenameInformation)` replaced an invalid Win32
relative rename call. The source-derived Start prototype was replaced by the
explicit native boxed stage to avoid shell associations and environment expansion.
Feature-only checkpoint variables were preserved in the fault build's scrubbed
environment; normal-build checkpoint activation remains compiled out. Pinned
SHA-256 is optimized in debug builds to make real multi-gigabyte ARM proof feasible.

Later runs exposed synthetic report framing and diagnostic natural-exit races.
Probe JSON is serialized before a single append, readers wait for a complete
bounded record, and synthetic launch fixtures always Stop in finally. Diagnostic
image-query failure is reconciled only by a completed wait on the same held
process; a live unknown object remains refused. External-activity fixtures retain
an independently dispatched original-engine member and verify actual driver box,
owner and held birth before resuming copy; either explicit activity or changed
configuration refusal is safe only with that live-member proof and absent output.
Historical failed raw reports remain separately retained, never relabeled success.
The completed native P07 laboratories generated real 8.3 leaf aliases and preserved output
through case and short-alias collisions. Each copied a 4,296,015,873-byte sparse
file with equal SHA-256 and a 1 MiB buffer.

The dependent P06 lab originally attempted driver unload after provisioning probes,
and actor coordination could expire before its original utility finished. The
bootstrap negative control now runs before provisioning, independently verifies
actual driver unload and requires the exact unsafe-context refusal with no dispatch
reservation. Coordination waits cover the bounded original utility operation. A
registered-target service-loss check still runs separately. The final P06 ARM run
completed all 22 cases and observed original utility exit 0 plus driver stopped;
Server completed all 21 cases. The production launch/Stop gates were unchanged.

Unsupported workspace layouts, snapshots, images, UNC/SUBST destinations and
root relocation remain refused. Import is one explicit regular file per operation;
there is no recursive directory import, arbitrary ADS, automatic export/open,
preview, host fallback, privileged product helper or generic root deletion.
Manager locks do not serialize a trusted administrator/SandMan. Recovery inspects
actual state; it never automatically resumes, publishes or deletes uncertain data.
Flushes cannot promise durability under every power/storage failure.

All 26 original specification documents are unchanged. All T01–T66 final installed-
candidate acceptance entries remain NOT_STARTED until P12. Reset advancement and
T43 reset-invalidates-reference finish in P08; packaging remains P11. Windows 11
x64 release compatibility, paid entitlement and final release certification are
not established by Server/ARM phase proof. Next eligible phase after P07: P08.

## P08 integration regression

The current P08 runtime `74d86db6dc883e692dfc04c8185eee790bdcf0a9` passed this phase on both owner-selected
laboratories in [run 38763966380](https://github.com/kurasis/SecureRun/actions/runs/38763966380): 28 Server / 29 ARM file/boxed-EXE cases passed; zero failures or actor failures.
The [manifest](../evidence/p07/manifest.json) binds the current source and
original structured evidence; earlier results above remain historical.
