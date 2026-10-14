# P05 helper decision

No privileged product helper is implemented or required for baseline user-owned
provisioning. This is an implementation decision undergoing production-path
verification, distinct from the completed P02 feasibility route.

The current Windows user owns the manager's private profile and derived roots.
The original protected engine service performs its own configuration IPC. The
manager never uses an elevated identity to create user storage, set arbitrary
ACLs, enroll roots, delete files or launch a target. User-writable database records
cannot authorize privileged effects because no such product effects exist.

P04 ordinary-user service-process identity remains Unknown where Windows refuses
the query; P05 does not fabricate that identity or weaken the P04 observation
contract. Its narrow ordinary-user route independently checks protected installed
components, running SCM services, original driver responses, unboxed self/parent
context and OS owner/birth identity before using original service IPC. A failure
refuses provisioning before metadata access.

Administrator actions in `tools/probe/p05_lab.cs` and the Actions provisioning
scripts are disposable lab fixtures. They require a fresh lab scope and are not
compiled into the application, exported over Tauri IPC or installed as services.
They may create standard test accounts and configure the fresh engine WFP
prerequisite; they do not change Defender, firewall or certificate policy.

Helper-only UAC denial, helper enrollment/replay and different-administrator UAC
scenarios are Not applicable when recording P05 scope. Boxed manager/worker,
forged requests, root/metadata ACL isolation and forged database checks remain
applicable and require actual verification; absence of a helper is not a passing
substitute for those checks. Any future helper requires a new independently
authorized resource protocol and its own tests before a product route depends on
it. Production target launch remains disabled.
