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

Server investigation 91cd662 / run 38698529104 passed actual child/grandchild
membership, background activity, duplicate suppression, safe Stop with ineligible
launch, real changed-scope refusal after retaining handles, serialization,
service/component refusal, hostile CWD and stale revision checks. UTF-8 pipe
encoding, a PowerShell scenario/operation variable collision, the fixture's
absolute PowerShell path and enabling its deliberate other-session probe were
corrected. The complete gate remains pending on both platforms.

## Scope and interpretation

- PR-03 through PR-06 are implemented through the normal production adapter and
  scoped main-window command. The normal CLI framing exercises the same service.
- P06 owns T01–T07, T19, T26, T36, T50, T54, T56, T61 and T62. The retainer refuses
  completion unless every applicable named production case passes on both
  owner-selected targets, including actual native/x86 and ARM x64 emulation.
- T26 import/export/reset subcases belong to P07/P08 and are not claimed here.
  P06 covers rapid launch/Stop, duplicate/conflicting operations and competing
  manager processes through the real namespace lock.
- T54 covers baseline Stop while current launch eligibility fails. Actual paid
  certificate expiry is Not applicable: no paid preset or entitlement-dependent
  route is enabled. No replacement certificate, grace period or expiry bypass
  is fabricated. Stop has no optional-entitlement dependency.
- Target CWD is independently selected and identity-bound; host workers remain
  in System32. Native protocol input is UTF-8, distinct from Windows target argv.
- Retained scoped receipts are historical dispatch facts; current activity comes
  from complete engine membership. Empty enumeration never proves nonexecution.
- All T01–T66 final installed-candidate acceptance entries remain NOT_STARTED.
  P07 mapping/transfer and P08 cleanup/recovery are not implemented by P06.
