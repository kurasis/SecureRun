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

The normal desktop currently remains observation-only even when context is safe:
provisioning belongs to P05 and production dispatch to P06. The independently
compiled P03 metadata fixture remains synthetic, visibly marked and incapable of
executing engine operations.

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
generation. The UI polls every five seconds, rejects older generation/sequence
views and independently ages displayed activity. Resume/focus invalidates the
display before taking another observation. Existing-running versus blocked/unknown
eligibility remains orthogonal.

The capability report inherits observed engine version and timestamp from its
containing observation. Unknown/unavailable reasons and their provenance are
explicit. QueryDrvInfo's certificate-state low 32 bits are status only; neither a
certificate file nor accepted settings enable paid profiles. Paid enforcement stays
unverified; no certificate data, substitute certificate or bypass is introduced.
Production launch remains unavailable. Failed/absent observations represent optional
capabilities as Unknown rather than silently making them available.

The debug executable's --observation-once and bounded six-snapshot
--observation-watch modes run the same adapter/context model for local diagnostics.
Their output can contain private roots/configuration/OS identities and must not be
uploaded as shared logs. CI retains only allowlisted counts, statuses and test
outcomes, omitting private paths, SIDs, raw arguments/environments and certificates.
