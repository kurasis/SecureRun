# Trusted engine observation

P04's production adapter is [securerun-sandboxie-adapter](../crates/sandboxie-adapter/src/lib.rs).
It exports observation only. It contains no launch, termination, configuration write,
cleanup, helper or engine-download interface.

## Discovery and trust

Discovery reads the protected Windows service manager's SbieSvc/SbieDrv metadata.
It does not search PATH, the current directory, user configuration or a prefixed
box name. The running service's actual image and process birth must match that
metadata. Driver/service states and native driver version are separate observations.
The original service protects its process object from a standard user. When that
OS access is denied, the adapter reports SCM PID/status provenance separately from
Unknown image/birth identity, keeps control-plane safety false, and still permits
trusted read-only driver queries after confirming both own processes Unboxed.
It never fabricates a service birth or requests elevation to inspect it.

Before loading code, the bridge retains no-delete ancestor handles and no-write /
no-delete component handles, rejects reparse points and multiply linked files,
checks privileged ownership and DACLs, hashes the original components, verifies
PE architecture and invokes Windows Authenticode with its normal policy defaults.
No certificate-check, TLS or signature bypass is introduced. This is Windows
Authenticode plus exact authenticated-payload provenance, not a promise that every
refresh obtains a uniform online revocation answer. Failures remain explicit.

The compiled [compatibility manifest](../crates/sandboxie-adapter/compatibility-v1.json)
uses schema/protocol version 1, exact Plus/core/ABI/source pins, native architecture,
tested OS bases, installer-derived component hashes and P02 route provenance.
Other versions/components fail closed. Its evidence covers read-only ABI feasibility,
not a production policy family, hardened Windows 11 x64 tuple or final acceptance.
Release evidence is distinct from each newly collected runtime observation.

## Narrow worker and own context

The application starts its own held executable with a fixed engine-worker mode,
OS-observed manager PID/birth and no other request fields. No replaceable sibling
or generic subprocess command enters this route. The host CWD comes from the OS
System32 API; the worker receives only trusted Windows directory variables and
System32 PATH. SbieDll loads by verified absolute path with its protected directory
and System32 search only. There is no Qt/QSbieAPI runtime dependency in P04.

A Windows job limits the worker to one process and 128 MiB committed memory, and
kills it when the job closes. Stdout is capped at 2 MiB; stderr and stdin are not
protocols. The external deadline is 20 seconds. Malformed, extra-field, oversized,
wrong-parent and older-than-15-second responses are refused. Native pipe-size and
timeout tests exercise this same capture function with fixed OS test processes.

Before configuration/process/root enumeration, the worker checks the original
driver version/ABI and both its own context and the held manager object. Only
healthy pinned STATUS_INVALID_CID means Unboxed; success means Boxed and every
other failure is Unknown. Boxed/Unknown cannot grant control authority. A positively
boxed normal desktop startup exits with code 78 before opening metadata or creating
its WebView. An in-process Sandboxie-named module is also a conservative startup
refusal because the desktop never loads engine code; absence of that module never
establishes Unboxed. Unknown startup supplies read-only setup; no production profile is
opened/migrated, no elevation is requested and no self-escape/relaunch occurs.

This observation protocol remains read-only. The normal desktop uses separate
P05 through P08 workers for provisioning, dispatch, file transfer and lifecycle
operations. The independently compiled P03 metadata fixture remains synthetic,
visibly marked and incapable of executing engine operations.

## Identity, completeness and configuration

All-session enumeration uses native EnumProcessEx(allSessions=true, session=-1),
bounded to 1,024 entries, with before/returned/after counts. Success at capacity,
changed counts, duplicate PIDs or inaccessible/changed identities is incomplete.
Each returned identity binds PID, actual held-object creation time, native box,
owner SID and session. A PID is not durable identity and no PID-kill fallback exists.
FILETIME creation values serialize as decimal strings so the local JavaScript
client cannot round identities above its safe-integer range.
Incomplete enumeration is Unknown, never Idle. Snapshots do not atomically lock
external engine clients; later mutation phases must revalidate their own dispatch
preconditions rather than treating a past Idle view as a lock.

Existing sections are never adopted from their names. Box namespaces are validated;
reserved global/user/template sections are excluded and an Enabled directive is
required, following the pinned native configuration semantics. Every observed box
is explicitly unowned/read-only. QueryConf returns bounded ordered duplicate raw
and expanded/inherited values for 24 allowlisted security/lifecycle keys. Passwords
and certificate contents are never queried. The fingerprint covers those observed
keys only; it is not a complete configuration revision or an enforcement oracle.
Unknown/truncated configuration data stays incomplete.

QueryBoxPath uses the reviewed two-pass UTF-16 byte lengths and native DOS-path
translation. Materialized roots have real no-reparse ancestry/file identities;
missing roots are PendingRoot, permission failures remain Unknown. The root's
scope is the current caller, never a claimed root binding for another SID/session.
Root observations are read-only; provisioning/immutable owned-root enrollment and
overlap checks remain P05's responsibility.

## Generations, freshness and capability provenance

Only the latest observation ticket can commit. Service process/birth changes,
installation identity changes, context/health transitions, expiry and the Windows
GetTickCount64 versus QueryUnbiasedInterruptTime suspend delta invalidate health.
The desktop checks host transitions every second, expires observations after 15
seconds, clears selection leases and increments the persistence connection
generation. The UI keeps one conditional health read outstanding, rejects older generation/
sequence views and independently ages displayed activity. Separate production
control summaries refresh every ten seconds and after managed mutations; their
eligibility expires after fifteen seconds and cannot cross a health generation. Resume/focus invalidates the
display before taking another observation. Existing-running versus blocked/unknown
eligibility remains orthogonal.

The capability report inherits observed engine version and timestamp from its
containing observation. Unknown/unavailable reasons and their provenance are
explicit. QueryDrvInfo's certificate-state low 32 bits are status only; neither a
certificate file nor accepted settings enable paid profiles. Paid enforcement stays
unverified; no certificate data, substitute certificate or bypass is introduced.
This read-only observation protocol never authorizes production launch. P06 uses
the separate [launch/control service](LAUNCH_AND_PROCESS_CONTROL.md) with fresh
action-specific checks. Failed/absent observations represent optional
capabilities as Unknown rather than silently making them available.

The debug executable's --observation-once and bounded six-snapshot
--observation-watch modes run the same adapter/context model for local diagnostics.
Their output can contain private roots/configuration/OS identities and must not be
uploaded as shared logs. CI retains only allowlisted counts, statuses and test
outcomes, omitting private paths, SIDs, raw arguments/environments and certificates.

## Production operation route and P09 status

The P04 observation flag remains false when service process image/birth is
unavailable to a standard user. It is not a claim that P05 through P08 cannot
operate: those workers independently validate protected SCM/component provenance,
the authenticated original SDK/driver route and actual held manager/worker
contexts before opening metadata or performing an action. They never invent a
service birth or control a service process through an unverified PID.

P09 browses owned metadata only with a fresh trusted Unboxed observation. It
recognizes the basic production route only after an actual policy/control worker
returns OBSERVED, tied to the current observation generation and a 15-second
lifetime. Focus, stale observations or refused controls invalidate that UI proof.
The service-process diagnostic capability remains explicitly unavailable. Every
operation still performs its independent native authorization and verification.


## Bounded continuous read-only observation

P09's passive observer holds authenticated component and ancestor file objects
for at most sixty seconds. Initial discovery performs the same hash, architecture,
Authenticode and protected ownership/DACL checks as one-shot observation. While
those no-write/no-delete handles remain held, each 1.7-second frame checks current
SCM service/driver status and configuration, held component ownership/DACL/link
identity, native ABI/version, held manager identity/context, worker context and
the complete box/process/root/configuration snapshot. It does not reuse a prior
activity or root snapshot. Rotation authenticates new objects from scratch.

The fixed self-worker accepts only the OS-observed manager PID and birth. It has
no mutation or renderer-supplied payload, receives only trusted Windows directory
variables and remains in a one-process, 128 MiB, kill-on-close job. Each newline-
framed response is bounded to 2 MiB, timestamped and validated against the held
manager identity; a one-frame queue bounds buffering. First response has a
20-second bound, later responses four seconds, and the whole stream sixty seconds.
Early exit, malformed/stale frames, changed SCM or expiry clear availability.
Generation changes discard pending frames and invalidate selections/handles.

Production mutation workers retain their independent fresh discovery, context,
policy and target checks. The continuous observer cannot authorize an operation.


A conditional `get_engine_health` call may supply its last sequence. If that
sequence is still current, a single reserved waiter sleeps until a complete new
snapshot or a three-second deadline. Reservation precedes thread scheduling and
Drop releases it on completion/cancellation; no backend lock crosses the wait.
Publication stores the new sequence before notification, so early updates are
not lost. The invoking window is authorized again before returning. No new
command, event-bus permission or renderer callback queue is introduced. Every
1.7-second worker frame still collects the complete live configuration/context/
root/process snapshot. The actual two-second process-update gate must pass.
