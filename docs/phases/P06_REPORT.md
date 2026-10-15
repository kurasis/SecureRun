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

Local checks: 19 foundation, 28 adapter, 9 tooling and 3 UI tests pass; UI build
passes; i686 Windows metadata-only strict clippy passes (not Windows execution).
Native production-path proof is in progress on both owner-selected laboratories.
Phase completion, P07 eligibility and release acceptance are not claimed yet.


Initial investigation run 38696611210 (3822c22) failed in the new harness before
launch: its mandatory synthetic SMB positive control was missing and a later
account name exceeded Windows' 20-character limit. Both setup defects were fixed;
reviewed minimized reports remain under `docs/evidence/p06/investigation-3822c22`.
No test exclusion or product security relaxation was used to bypass these failures.

The next investigation (572592d, run 38697466505) proved actual custom-CWD boxed
launch on both targets. Most other cases were refused because the PowerShell
client serialized its absent optional CWD as an empty string; the unmanaged
fixture also enabled its root before creating it. Those client/setup defects
were corrected, preserving minimized raw failures as historical evidence.
