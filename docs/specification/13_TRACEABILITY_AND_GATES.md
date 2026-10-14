# Traceability and Gate Decisions

Use this table to prevent incomplete features from being disguised as optional UI controls. Test IDs refer to 08_TESTING_AND_ACCEPTANCE.md. Phase IDs refer to 09_DEVELOPMENT_STAGES.md and its linked phase files. Multiple IDs in a cell represent complementary checks, not alternatives.

| Requirement | Main phases | Minimum evidence |
|---|---|---|
| PR-01 Engine detection | P01, P02, P04 | T01/T02/T39/T46/T50; T58 |
| PR-02 Environment management | P05, P08 | T17/T28/T34/T48; T57/T60/T65 |
| PR-03 Executable registration | P06, P07 | T03/T04/T43/T49/T50 |
| PR-04 Isolated launch | P02, P05, P06 | T01–T07/T14/T15/T39/T41/T50/T51/T55; T58/T59/T61 |
| PR-05 Process observations | P04, P06 | T05–T07/T36/T46/T56; T62 |
| PR-06 Scoped stopping | P06, P08 | T19/T26/T33/T36/T54; T58/T62 |
| PR-07 Persistent/disposable modes | P08 | T06/T25/T42/T48 |
| PR-08 Permissions/network | P02, P05 | T08–T18/T31/T37–T40/T51/T53; T59/T60 |
| PR-09 Import/list/export | P07 | T20–T23/T42–T45; T63/T64/T65 |
| PR-10 Reset/remove/archive | P08 | T24/T28/T33/T34/T48; T65 |
| PR-11 History/diagnostics | P03, P09 | Structured error/redaction checks plus T45; T66 |
| PR-12 Crash/restart recovery | P03, P08 | T18/T25/T28/T46/T48/T55/T56; T61/T64/T65 |
| PR-13 Drift/capability handling | P04, P05 | T14–T18/T34/T39; T59 |
| PR-14 Install/upgrade/uninstall | P11 | T29/T48 and reproducible packaging evidence; T57/T58 |
| PR-15 Accessibility/localization | P09 | EN/RU, keyboard/screen reader, themes and scaling report; T63 |
| PR-16 Storage isolation | P02, P05, P07 | T22/T34/T35/T47/T52/T55; T57/T59/T60 |
| PR-17 Session completeness | P02, P04, P06 | T19/T36/T46 |
| PR-18 Bounded resource handling | P03, P07, P09 | T45 and measured performance report; T66 |

## Gate classification

**Mandatory baseline:** original-engine discovery/trust, owned environments, launch/stop, Standard offline/online policy semantics, file rules, safe import/list/export, lifecycle/recovery, ACL/root/session protection, accurate UI, packaging and documented evidence. A missing mandatory capability blocks first-release completion. A safe partial build can still be handed off with the exact blocker stated.

**Optional and capability-gated:** certificate-dependent privacy/hardening presets; individually verified clipboard/device controls; the elevated helper if no supported operation requires it. A helper that exists makes its security tests mandatory. A supported preset makes all tests of its claims mandatory.

**Deferred:** everything listed as deferred in product requirements, including snapshots, encrypted storage, broad installer compatibility, domain/proxy controls, raw config import, engine distribution and multi-user administration. Multi-user administration being deferred does not waive protection from another user or safe handling of another Windows session.

## Resolving a blocked P02

1. Record the failing operation, exact upstream version/source, observed result and missing evidence.
2. Try a documented alternative adapter mechanism within the same architecture, such as a narrow native bridge, without weakening policy.
3. Continue independent pure-code/UI work if useful, marking the integration gate blocked.
4. If a mandatory requirement cannot be implemented safely, present a concrete scope/architecture change for user decision. Never silently turn it into an optional feature.

Do not request permission for ordinary reversible implementation choices already authorized by the development request. Explicit review remains necessary for newly proposed system-wide security configuration changes, purchases, destructive user-data actions, or material scope changes.

## Evidence templates for the implementation repository

`docs/STATUS.md`: current phase Pxx; requirements completed; tests run/passed/failed/blocked; evidence links; exact blockers; next action.

`docs/ENGINE_MATRIX.md`: Windows build; architecture; engine/component versions and release commit; adapter version; component trust method; supported presets; known conflicts; test-run reference.

`docs/OPERATION_MAP.md`: logical operation; upstream CLI/API; source permalink; privilege; argument/output format; timeout/cancellation; preconditions; postconditions; failure-injection tests.

`docs/TEST_REPORT.md`: ID; requirement; platform tuple; expected/actual result; Passed/Failed/Blocked/Not applicable with reason; evidence; residual limitation. Do not include private keys, certificate payloads or real user data.

## Cross-cutting phase ownership

P10 owns integrated adversarial review for all applicable requirements; P12 owns final acceptance for all requirements. T49–T66 are implemented in their feature phases and rerun in P10/P12 as applicable. P02 smoke evidence is feasibility evidence, not a production pass. The phase index is the single source of dependency ordering.

New revision 1.3 scenarios remain mandatory for the applicable boundary. T57 can be Not applicable only when there is no elevated helper path; engine-scoped actions still require their own authorization tests. T58 always covers the manager even if no helper exists. T60 may pass by safely deferring creation until affected boxes stop, with the limitation shown in the UI. T61 must distinguish safe at-most-once dispatch from an unsupported exactly-once execution claim.
