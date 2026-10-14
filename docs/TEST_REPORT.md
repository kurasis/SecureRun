# P01 test report

The full [66-scenario catalog](test-catalog.json) preserves expected outcomes from
[the specification](specification/08_TESTING_AND_ACCEPTANCE.md). All T01–T66 are
NOT_STARTED. No security acceptance scenario passes from lab setup.

| Check | Expected | Actual/status | Evidence |
|---|---|---|---|
| Repository integrity | Original 26 documents, valid links and complete outputs | Pending final validation | `python tools/lab/validate_repository.py` |
| Tooling regression | Hash mismatch/size/tampering fail; valid data passes | Pending final validation | `python -m unittest discover -s tests -v` |
| Official source tag | Exact full commit agrees between Git and API | PASSED | cdba7096240b93d79c5373aa81a75a1c5c71b883 |
| Official installer bytes | Expected size and SHA256 with TLS enabled | PASSED on Linux | [JSON](evidence/p01/linux-provenance.json) |
| Harmless Windows x64 EXE | Build and execute on Windows 11 ARM64; record emulation | Pending CI | GitHub Actions artifacts |
| Windows installer trust | Valid Authenticode, recorded signer | Pending CI | installer-trust.json |
| Disposable Windows 11 x64 engine lab | Exact OS/security/virtualization and fixture evidence | BLOCKED: ARM64 emulation cannot load x64 driver | [lab](LAB_SETUP.md) |
| Second account/session, endpoint controls, bounded volumes | Synthetic, isolated, observed | NOT_RUN | P02 runtime prerequisite |

Test timestamps and manager source commits belong to each run's JSON inventory.
The engine release/source tuple is pinned, but no installed engine component
versions, policy hash or containment artifacts exist. Do not invent those fields.
