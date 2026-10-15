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
