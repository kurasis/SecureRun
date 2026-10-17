# P05 helper decision

No privileged product helper is implemented or required for baseline user-owned
provisioning. This decision is verified through the completed P05 production paths,
distinct from the earlier P02 feasibility route.

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

Original RpcSs support may use SYSTEM or the interactive session's token according
to source-reviewed RunSandboxedGetToken behavior. This is a separately installed
engine dependency, not a product elevation broker. Diagnostic shutdown checks its
driver box SID, held process birth, critical state and signed protected installed
image, and derives an allowed session identity from Windows. The diagnostic also
preserves the driver's restricted Anonymous Logon primary token and never disables
that restriction. Both original RpcSs and DcomLaunch companions
must match the exact protected signed installed paths. A packet observer uses
only rights already available to the caller; it cannot request elevation.
The manager's root and metadata owner always comes from its own original user token. The ordinary
user test must confirm storage remains in that user's profile even when original
RPC support uses another session identity.

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
it. The P05 phase itself does not dispatch registered user targets. P06 implements
production launch through the same ordinary-user trust boundary; no helper was added.
