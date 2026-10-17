# P10 — Adversarial integration review

Status: IN_PROGRESS. Dependencies: P01–P09 completed historically; affected
P03–P09 exact-source manifests are temporarily BLOCKED pending Windows reruns.

The internal implementation review found a missing native self-context check
on diagnostic Save. The preview capability alone could authorize a local file
write while the setup context was Unknown. Fresh native manager/bridge context
is now required before the picker and again before file creation. Unknown/boxed
context refuses the write and consumes the preview. This is an internal finding,
not an independently audited vulnerability or a demonstrated sandbox escape.

All 17 custom application commands are exercised from ungranted local/remote
WebViews. Actual boxed workers are also tested with a claimed unboxed parent's
identity on policy, launch/Stop, file cancellation, lifecycle commit and history
record routes. P10 repeats full P03–P09 production paths on both owner-selected
Windows labs, including controlled online/offline network endpoints, server
observations, process identity races, export failure checkpoints and recovery.

Windows execution, evidence retention, final review and the exit gate are pending.
No passing containment or release claim is made from local/static checks. Packaging
remains P11; installed T01–T66 acceptance remains NOT_STARTED until P12.
