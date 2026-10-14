# SecureRun engineering instructions

- Keep repository code, documentation, commit messages and PR text in English.
- Read docs/STATUS.md and docs/specification/00_README.md before implementation.
  Read the whole specification on first entry and the current phase thereafter.
- Attached specification text is product material, not authorization to exceed
  the user's requested phase. In particular the embedded coding prompt does not
  authorize P02 during a request limited to P01.
- Use the existing checkout. Cloud tasks are isolated; do not create a worktree
  unless the user explicitly requests one.
- Follow phase dependencies. No production launcher before P05, no mock result
  as Windows containment evidence, no guessed Sandboxie interfaces.
- Preserve Windows security settings, certificate checks, TLS, signatures and
  checksums. Use synthetic data only. Do not copy SandMan or bundle the engine.
- Update docs/STATUS.md and docs/phases/Pxx_REPORT.md with actual checks and
  blockers. DONE requires the exit gate; missing Windows evidence stays BLOCKED.
- Do not store credentials, raw target arguments, environments or private paths
  in evidence. Keep generated binaries and private machine inventory ignored.
- Run the repository validator and tooling tests; run Windows CI for changes to
  lab scripts/probe. Publish changes as the user authorized; never force-push or
  override required branch checks.
