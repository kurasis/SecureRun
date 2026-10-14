# Verification and Acceptance

## Test environments and evidence

Use a disposable Windows 11 x64 VM or a dedicated test PC with snapshots/backups for engine integration tests. This is a development requirement, not a product runtime dependency. Test official signed Sandboxie components under normal Windows security settings. Do not disable driver-signature enforcement to validate the intended release architecture.

Use a benign purpose-built probe that attempts controlled file, registry, child-process and network operations against synthetic canaries. Never test with actual malware or the user's real documents, browser sessions, passwords or production credentials. Fixtures must be under unique test-owned paths and have deterministic teardown.

Unit tests on Linux can validate pure policy compilation, parsing and metadata behavior, but cannot prove Windows containment. Mocks are useful for failure injection and do not count as isolation evidence. An unavailable Windows runner means Windows-dependent gates remain blocked.

For each result record: test ID, expected/actual outcome, OS build, engine/component versions, source commit, manager commit, architecture, certificate capability class (no key contents), policy hash, timestamps and artifact paths. “Not run”, “Blocked” and “Passed” are distinct. Include negative controls so an inaccessible endpoint or missing test file does not yield a false pass.

## Mandatory test matrix

| ID | Scenario | Required result |
|---|---|---|
| T01 | Engine missing, service stopped, driver unhealthy | Target never launches on host |
| T02 | Fake Start.exe in PATH/current directory or changed engine binary | Rejected without executing impostor |
| T03 | Valid engine, invalid EXE and unusual arguments | Clear failure; no shell or injected command executes |
| T04 | Unicode, spaces, quotes, trailing backslashes, option-like arguments | Exact intended target arguments; no extra upstream flags |
| T05 | Normal target and child/grandchild processes | Confirmed engine membership in the intended box |
| T06 | Target spawns background child and exits | Environment remains Running; no early cleanup |
| T07 | PID exits and is reused | Unrelated process never terminated or attributed to box |
| T08 | Write/modify/delete synthetic host file under isolated-change policy | Host canary unchanged; intended boxed state observable |
| T09 | Read selected blocked host files and enumerate protected folder | Expected access denied; verify aliases and descendants |
| T10 | Read-only path write attempt | Reads work; forbidden writes fail with documented semantics |
| T11 | Registry canary reads/writes under each preset | Effective policy matches expected host visibility; host values unchanged |
| T12 | Network blocked | No target-caused egress on controlled socket/DNS/loopback/LAN paths; cached DNS answers handled separately |
| T13 | Network allowed | Positive controls succeed without silently widening file policy |
| T14 | Required certificate missing/expired or feature unknown | Dependent launch blocked; Standard remains honestly labeled |
| T15 | Config write accepted but enforcement absent | Verification fails; no protected/active status |
| T16 | Policy changed while processes run | New policy not falsely reported active; restart required |
| T17 | External INI/template edits, duplicate rules and stale revisions | Drift detected; no unrelated settings overwritten |
| T18 | Crash after each configuration mutation phase | Reconciliation yields correct or blocked state |
| T19 | Stop selected/all managed environments | Unmanaged box remains running |
| T20 | Import collision, cancellation, disk full and missing root | No partial file presented as complete; no host grant |
| T21 | Export normal file | Correct bytes, explicit destination, no auto-open |
| T22 | Export reparse traversal, hard-link escape, alternate stream, path swap | Rejected or safely contained; no secret host file copied |
| T23 | Export malicious HTML/SVG/shortcut/executable filename/content | Host UI executes no payload or preview handler |
| T24 | Cleanup with junctions, locked files and stale engine state | Host canaries survive; incomplete deletion visible |
| T25 | Manager crashes with persistent/disposable boxes active | Persistent workload survives; disposable leftovers recoverable |
| T26 | Repeated rapid launch/stop/export/reset and two manager instances | Serialization and single-instance control prevent conflicting actions |
| T27 | UAC denied, spoofed helper request or sandboxed IPC caller | No unauthorized privileged operation |
| T28 | Database migration failure, corrupted record, metadata missing | No accidental adoption/deletion of unrelated box |
| T29 | Manager upgrade/uninstall | Retention decisions honored; engine independently preserved |
| T30 | Supported browser/editor/archive utility | Documented usability with engine and application protections retained |
| T31 | Standard mode reads a non-blocked canary | UI limitation accurately reflects remaining visibility |
| T32 | Clipboard/device controls advertised by adapter | Each advertised restriction verified; unavailable controls disabled |
| T33 | Custom/inherited DeleteCommand and SandMan event triggers | Managed operations blocked; no host marker command executes |
| T34 | Root moved, replaced, overlapped or same-name box recreated | No automatic adoption, launch or deletion of new/old unrelated roots |
| T35 | Second standard Windows user and another managed box probe storage | No unauthorized root or metadata access; legitimate engine access retained |
| T36 | Same user in another Windows session; incomplete enumeration | No premature Idle state, cleanup or broad termination |
| T37 | Configuration contains literal percent/comma/CRLF or protected password | No directive injection or secret command-line exposure; unsupported case blocked |
| T38 | Existing boxed copy then ReadFilePath policy change | Correct host view, explicit disclosure, retained boxed data after reversal |
| T39 | WFP disabled/fails after a previously valid setup | Offline launch blocked; no hooks-only fallback |
| T40 | DNS broker, SMB/mapped drive and unprivileged raw/ICMP tests | Offline egress checked at controlled endpoints; no share access in managed presets |
| T41 | Browser already running on host; protocol/COM/helper request | No URL/document handoff to unboxed instance in supported workflow |
| T42 | SandMan open with lifecycle events; external launch during export | No upstream auto-recovery/deletion; transfer stays stable or aborts safely |
| T43 | Boxed EXE import, launch, reset | Correct logical boxed executable; reset invalidates it without host fallback |
| T44 | Export collision, no-replace race, provenance stream failure | Existing destination preserved; no complete unlabeled output |
| T45 | Files larger than 4 GiB, sparse growth, disk full, noisy diagnostics | Bounded memory/queues; cancellable transfer and explicit partial-operation recovery |
| T46 | Service restart, sleep/resume, outdated observations | Reconciliation; Running/Unknown activity remains distinct from Blocked eligibility |
| T47 | Same-SID boxed helper client and forged caller identity | Peer identity obtained from OS; no privileged command or metadata tampering |
| T48 | Archive/unarchive, uninstall with retained data and failed migration rollback | Definition/data recoverable; no orphaning or silent deletion |
| T49 | Unauthorized WebView/origin, forged IDs and frontend path/confirmation payload | Custom-command ACL and Rust authorization reject request; no arbitrary host operation |
| T50 | Host utility launched with hostile target CWD/PATH/DLL fixtures | Only trusted host dependencies execute; target CWD transmitted safely or rejected |
| T51 | Diagnostic requested for box containing malicious shadow files/registry entries | Diagnostic runs in fresh test box; no untrusted probe dependency or false per-box proof |
| T52 | UAC completed using a different administrator account | Original owner/session preserved; no target launch or accidental admin-profile storage |
| T53 | New user path grant inside supported policy family | Validated applied fingerprint without requiring a new release; unsafe interactions rejected |
| T54 | Optional certificate expires while workload is running | Safe scoped Stop remains available when its own prerequisites hold; no host fallback |
| T55 | Fresh box without root and root substituted during provisioning | PendingRoot cannot launch target; only journaled verified creation binds identity |
| T56 | Delayed events/operation results from old engine generation | New runtime and eligibility state cannot be overwritten by stale results |
| T57 | Forged user database/ownership marker, helper enrollment replay and privileged path swap | No privileged write, ACL change or deletion outside independently authorized resources; helper absence explicitly recorded |
| T58 | Manager, bridge or helper starts boxed; self-context query fails | Control operations and elevation refused; no self-relaunch or host escape; minimal diagnostics only |
| T59 | User grant or inherited rule overlaps mandatory manager/sibling exclusions; alias changes | Required isolation cannot be removed through editable policy; unsupported paths rejected |
| T60 | Create a new sibling while an existing managed box runs | Existing box cannot read/write the new storage; unsafe rollout waits before materializing private data |
| T61 | Launch accepted but receipt lost; duplicate request; restart after dispatch reservation | Same operation is never automatically dispatched twice; uncertainty retained even when no target PID remains |
| T62 | Target exits or scope changes between observation and termination dispatch | Stop remains bound to authorized environment/process objects; no numeric-PID fallback or premature completion |
| T63 | Reserved/ambiguous output names, case/short aliases, deceptive suffix and bidi controls | Safe Rename/Skip; no namespace escape, overwrite or concealed extension; normal Unicode names still work |
| T64 | Export crash before provenance, mid-copy, before rename and after rename/before journal commit | No payload copied before marker; partial files remain incomplete; final output reconciled without replacement |
| T65 | Temporary artifact replaced; stale import/export/cleanup journal after reset/recreation | No path-only rollback deletion or old-generation mutation; identity mismatch stays unresolved |
| T66 | Secret canaries in argv/environment/errors and control characters in diagnostics | Canary secrets absent from local logs and shared bundles; untrusted text cannot forge structured events |


For T22 include destination reparse replacement and prefix-confusion paths, not just source traversal. For T17 include settings introduced by inherited global templates. Test short-lived processes separately from persistent GUI workloads. Confirm a failure test cannot leave a target running outside the box unnoticed.

For T12/T40 a DNS result satisfied from cache or the hosts file is not a failure; target-caused outbound traffic is. Use unique queries and isolated server/packet observations. Test incoming as well as outgoing sockets. Run these tests in the dedicated lab; do not add unsolicited network calls to the user's normal launch path. For T41 exercise the target's own child-launch APIs and reachable host brokers; a launcher exiting quickly is not proof of safe handoff.

T57 verifies the privilege boundary even with forged lower-trust metadata; it does not require treating unboxed same-user code as unable to read ordinary user files. T58 must cover the manager itself as well as its IPC peer. T59/T60 include alias and creation-order variants; testing only two boxes that already existed is insufficient.

For T61 inject failure both before and after engine acceptance, including a target that completes before the UI reconnects. For T62 inspect the actual dispatch path as well as exercising bounded process churn; a stress test that happens not to hit PID reuse is insufficient evidence. T64/T65 need failure injection at named protocol steps and synthetic replacement canaries, not deletion of real user files. T66 scans local debug/error capture as well as the exported bundle using synthetic secrets only.

Every test spanning an optional helper/feature may be marked Not applicable only with the missing component/capability recorded. Tests for mandatory baseline requirements cannot be waived merely because they failed or lack an environment. Basic performance/accessibility/install checks require evidence in addition to this security matrix.

## Acceptance gates

1. All applicable mandatory requirements have evidence, not screenshots alone.
2. Every advertised preset passes its enforcement tests on each supported OS/engine pair.
3. Baseline works without optional certificates; licensed presets are tested with a legitimately available certificate or explicitly excluded from the first supported release matrix.
4. No unresolved release-blocking flaw in launch fail-closed behavior, host file integrity, ownership checks, command injection, export containment, ambiguous-operation replay, mandatory policy protection or privileged IPC.
5. Dependencies are pinned; builds, install and uninstall are reproducible from documented steps.
6. English/Russian UI, keyboard access and scaling checks pass.
7. Performance budgets are measured; deviations have user-impact explanations.

Optional features with no valid test entitlement remain disabled. Do not purchase anything or request real secrets merely to turn a blocked optional test green.

Use bounded resource fixtures: simulate disk-full in an isolated limited-capacity test volume and process storms with strict lab limits. Never fill the real host system disk or create an unbounded fork/process loop as a test.
