# P06 — Isolated launch and scoped process control

Status: IN_PROGRESS. Requested scope: complete P06.

P05 originally passed on runtime a6cdbd1 (run 38648135812), with matching
P03/P04 regressions. P06 changes require fresh matching regression evidence;
historical raw evidence is preserved unchanged.

Implemented: one-use native registration, private application records, bounded
original SDK launch, durable dispatch reservations, CRT quoting, suspended
pre-execution membership checks, immutable launch receipts, all-session process
observation, independent held-object Stop/Stop managed, basic English/Russian UI.
Custom target CWD is carried separately by the SDK; host workers use System32.
No shell, imported/boxed EXE mapping, target elevation or host launch fallback.

Local checks: 19 foundation, 27 adapter, 8 tooling and 3 UI tests pass; UI build
passes; i686 Windows metadata-only strict clippy passes (not Windows execution).
Native production-path proof is in progress on both owner-selected laboratories.
Phase completion, P07 eligibility and release acceptance are not claimed yet.
