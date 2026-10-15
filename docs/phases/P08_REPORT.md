# P08 — Lifecycle, cleanup and recovery

Status: IN_PROGRESS. Requested scope: P08 only. Dependency: P07 completed at
runtime `bec50c8fa7d0b47c4f05aa6662eeeb24faa18f68`; current regressions are pending.

The implementation introduces explicit Persistent/Disposable retention, native
confirmation, Archive/Unarchive, Reset and removal after verified cleanup.
Reset preserves the definition and host application records, advances environment
generation and invalidates boxed executable references and selection tokens.
Disposable leftovers are offered for Resume, Export or Delete; nothing is
cleaned or exported automatically at startup or manager exit.

Cleanup uses only the pinned original QSbieAPI native export proven in P02.
A bounded namespace/ACL seal precedes dispatch; all-session idle, current roots,
ownership, configuration and automation are checked. A separate unboxed ordinary-
user controller retains root restoration authority across executor/UI loss.
The executor has a 128 MiB job limit, one process and a bounded native callback.
A failed operation remains journaled; recovery inspects actual identities and
postconditions without replaying destructive actions or adopting replacement roots.

Portable tests, strict i686 metadata checking and UI checks are being executed.
Real Server 2025 x64 and Windows 11 ARM64 proof is pending. No native success,
phase DONE, installed-candidate acceptance or release certification is claimed.
All 26 original specification documents and 66 final acceptance statuses remain
unchanged. Packaging-related T48 portions finish in P11. Next eligible phase only
after the complete P08 gate: P09.

Initial ARM run 38736673131 passed 40 adapter tests and failed three new seal tests
before any engine mutation: joining an empty root-relative component introduced
a trailing separator rejected by strict local-file grammar. Root resolution now
keeps the original canonical root spelling. No path validation was weakened.

Runs 38741141781 and 38742057167 disproved restoration by root inheritance alone.
The isolated native deletion probe also confirmed that retaining child metadata
handles delays namespace unlink until their final close. The revised protocol
retains restoration handles for survivors and releases only kernel-confirmed
delete-pending objects; a controller-bound pre-seal snapshot prevents the worker
from sealing a different set of objects. COMPLETE is withheld until the controller
restores the recorded ACLs after the held executor exits. Native verification of
the revised protocol is pending.

Full native run 38743266538 compiled the production and fault Tauri binaries on
both platforms, but the first original cleanup returned an unresolved status;
no P08 native scenario was accepted as passed. Its reviewed raw reports are
retained under `evidence/p08/investigation-918f10f`. Two independent harness
issues were identified: PowerShell concatenation collapsed the direct worker's
three argv entries into one, and the multi-session fixture did not temporarily
enable its original-client dispatch. The next run records bounded native status
codes and controller stage traces instead of hiding the initial failure behind
subsequent reconciliation refusals. Six isolated native seal cases subsequently
passed on both targets at source 3e844cf.
