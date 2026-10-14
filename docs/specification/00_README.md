# Windows Application Isolation Manager — Developer Handoff

Version: 1.3 (security and failure-mode review; P01-P12) | Prepared/reviewed: 2026-10-14 (Asia/Dubai) | Language: English

## Objective

Build a Windows desktop application that manages application isolation using a separately installed, original Sandboxie engine. Provide an original, understandable interface for creating environments, assigning applications, configuring permissions, running programs, inspecting processes and files, and safely resetting environments.

The product is a manager of an existing security boundary. It does not implement a new sandbox, hypervisor, antivirus, or kernel driver. The initial intended use is personal. Do not assume permission to redistribute Sandboxie or entitlement to paid features.

## Confirmed decisions

- Use the Sandboxie-based approach selected by the user.
- Use an original interface over the installed engine; do not fork SandMan for v1.
- Run application windows on the ordinary Windows desktop.
- Do not require a VM for everyday use. Disposable VMs remain appropriate for development testing.
- Deliver a native Windows application, not a website or remote service.

## Engineering defaults

These are proposed implementation decisions, not additional user requirements. Use them unless repository constraints justify a documented alternative.

- Windows 11 x64, on currently serviced builds validated in the test matrix.
- Tauri 2 + React + TypeScript frontend; Rust backend; Microsoft WebView2 runtime.
- SQLite for manager metadata; Sandboxie remains authoritative for engine configuration and process membership.
- Single interactive Windows user per manager instance. English and Russian UI strings; English engineering documentation.
- No account system, cloud sync, telemetry, or automatic file upload.
- Original Sandboxie Plus x64 installation as the first supported backend. Test 32-bit target processes separately; defer ARM64 and Windows 10 support.
- Separate engine installation and updates in v1; provide official links and detection.

## Read order

1. [Product requirements](01_PRODUCT_REQUIREMENTS.md)
2. [Threat model and invariants](02_SECURITY_MODEL.md)
3. [Architecture and data](03_ARCHITECTURE_AND_DATA.md)
4. [Sandboxie integration contract](04_SANDBOXIE_INTEGRATION.md)
5. [Policies and permissions](05_POLICIES_AND_PERMISSIONS.md)
6. [Files and lifecycle](06_FILES_AND_LIFECYCLE.md)
7. [UX specification](07_UX_SPECIFICATION.md)
8. [Verification and acceptance](08_TESTING_AND_ACCEPTANCE.md)
9. [Development stages](09_DEVELOPMENT_STAGES.md)
10. [Sources, licensing, and open risks](10_SOURCES_AND_LICENSING.md)
11. [Starting prompt for the coding agent](11_CODING_AGENT_PROMPT.md)
12. [Review findings and changes](12_REVIEW_FINDINGS.md)
13. [Requirement traceability and gate decisions](13_TRACEABILITY_AND_GATES.md)

## Requirement interpretation

MUST is a release requirement. SHOULD allows a documented, justified alternative. MAY indicates an optional enhancement. Security invariants take precedence over convenience features. P02 must resolve version-specific implementation details from upstream source and a real Windows test environment; do not invent APIs, CLI flags, INI directives, or certificate checks.

The archive is a specification, not a working application or a security certification. No Windows execution or compatibility testing was performed while preparing it. Sources were initially checked on 2026-10-13 UTC, with targeted security references checked on 2026-10-14 UTC; pin a tested release and source commit during implementation.

## Definition of first release

All mandatory phases P01 through P12 pass. A UI backed only by mocks is not a completed release. Unsupported capabilities remain disabled with a reason. Unavailable Windows execution must be reported as a release blocker, never converted into a passing result.

Disabling an optional feature is allowed. Disabling a mandatory feature is an incomplete release unless the user approves a scope change. Import/export, baseline network blocking, safe cleanup and ownership checks cannot be quietly dropped after P02. This review improved the specification; it did not establish runtime security or compatibility.

The phases/ directory contains 12 individually actionable development phases. Begin with P01, then P02; policy/provisioning in P05 must precede production target launch in P06. The current package contains 26 Markdown documents and 66 named acceptance scenarios.

## Revision 1.3 review scope

This revision closes 10 specification findings (R26-R35): privileged metadata authority, boxed manager execution, editable mandatory protections, future sibling coverage, duplicate launch dispatch, termination races, unsafe output names, export staging/provenance, stale recovery artifacts and secret-bearing logs. Ten new scenarios T57-T66 have feature-phase owners and final acceptance gates. See the review findings document for severity, changes and evidence.

The architecture and P01-P12 ordering are retained. The original v1.2 package is not replaced by this newly named archive. Runtime-dependent checks remain NOT_STARTED; document consistency checks do not constitute implementation or Windows security testing.
