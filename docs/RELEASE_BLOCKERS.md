# Release blockers and remaining prerequisites

P10 status: IN_PROGRESS; exact-source Windows validation is pending.

| Item | Classification | State and closure requirement |
|---|---|---|
| P10-F01 diagnostic Save context | Mandatory security verification | Code corrected; require native Unknown-context refusal and successful unboxed Save on both targets. |
| P10-F02 complete IPC probing | Mandatory security verification | Harness corrected; require all 17 actual ACL denials from each forbidden window on both targets. |
| P10-F03 boxed worker families | Mandatory security verification | Harness extended; require actual boxed worker refusal despite a valid claimed host parent. |
| Exact-source P03–P09 integration | Mandatory P10 exit gate | Current manifests temporarily BLOCKED; old successful source is historical. Repeat all affected native gates and retain original proof. |
| P11 installed artifacts | Remaining release prerequisite | Installer, reproducibility, upgrade/uninstall/retention, licensing and signing status; no installed packaging pass claimed in P10. |
| P12 installed candidate | Remaining release prerequisite | Complete final T01–T66 acceptance on the declared release tuple. Current catalog remains NOT_STARTED. |

Optional exclusions: no elevated product helper, paid privacy presets or advertised
clipboard/device restriction. A helper-only N/A does not exempt applicable boxed
client, metadata, ownership, context or root checks. Native laboratory limitations
and measured performance deviations are recorded explicitly in
[the security review](SECURITY_REVIEW.md); no mandatory failure is waived.

This list must show zero unresolved mandatory containment findings before P10 is
marked DONE. Release prerequisites P11/P12 remain visible after that closure.
