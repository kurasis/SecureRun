# P10 integrated production-path test report

Status: IN_PROGRESS. Windows run
[39068949002](https://github.com/kurasis/SecureRun/actions/runs/39068949002), candidate
`75b6c0bab24e7ea0edd86a3be2adea6648456a6b`.

The complete P03–P09 suite is scheduled independently on Windows Server 2025 x64
and Windows 11 ARM64, with real x86/native/emulated targets. All seven phase gates
must pass on this exact source; source hashes include their protected tools.
No diagnostic-only P09 workload can close the full gate. Failed/cancelled runs
remain failed/cancelled investigations and cannot supply passing dispositions.

Local validation passed: 19 foundation and 44 portable adapter tests, 22 Python
tooling/gate tests, TypeScript production build. Windows behavior remains pending.

The final report will enumerate T01–T66 from retained actual cases and explicitly
separate packaging-only, absent-helper, unadvertised optional controls and final
installed acceptance. The canonical [acceptance catalog](test-catalog.json)
remains entirely NOT_STARTED until P12.

See [internal findings](SECURITY_REVIEW.md),
[requirement traceability](REQUIREMENT_TRACEABILITY.md) and
[release blockers](RELEASE_BLOCKERS.md).
