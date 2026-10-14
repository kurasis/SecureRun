# UX Specification

## Visual direction

Create an original, restrained Windows utility: neutral surfaces, clear typography, compact but readable spacing, consistent controls and a single accent color. Support light/dark themes and Windows scaling at 100%, 150% and 200%. Avoid decorative dashboards, fake security scores, gradients everywhere and claims such as “100% safe”. Icons supplement text; color never carries status alone.

## Navigation

- Environments: searchable list/cards with name, preset, network state, persistence and running-process count.
- Selected environment: Applications, Processes, Files, Permissions, Activity.
- Settings: engine status, diagnostics, language, appearance, retention and official help.

Primary actions: Run, Stop environment, Add application. Destructive actions remain in a clearly labeled secondary area. “Stop all managed environments” enumerates exactly which environments it affects.

## Onboarding

Detect engine and show one of: Not installed, Installation untrusted, Service unavailable, Restart required, Version not tested, Ready. Give official installation instructions and Recheck. Do not launch a target while setup is incomplete. A newly observed untested engine version is blocked for protected launching until the compatibility manifest is updated; metadata browsing remains available.

Explain Standard's read-access limits at preset selection. Show certificate-dependent presets as unavailable with a specific reason and an option to open official certificate management. Never imply a certificate is an antivirus guarantee or required for every basic operation.

## Environment creation

Inputs: display name, persistent/disposable, preset, network mode, optional selected blocked folders. Present a concise effective-permissions summary before creation. Generate technical box IDs internally. Box creation can show progress and errors; a partial result stays nonlaunchable with a repair action.

## Permissions editor

Show Desired and Applied when they differ. Human labels: “Blocked”, “Read only”, “Changes stay inside environment”. Do not use “Allow files” for multiple meanings. Show a diff before a security-reducing change. Editing a running environment queues a desired policy but does not claim activation; applying requires stopping the entire environment.

Show mandatory manager/cross-box protection as read-only system rules. Editable personal-folder exclusions cannot remove these rules, and conflicting grants explain why they are rejected. Creating a new box may require stopping affected boxes if the validated storage policy cannot protect future siblings in advance.

Security indicators: Verified for this configuration, Needs verification, Unavailable, Configuration changed. These describe configuration/enforcement checks, not the trustworthiness of a program. No generic green “Safe” badge.

Display runtime activity independently from eligibility: for example, “Running - new launches blocked: configuration changed”. If engine observation fails, show “Activity unknown”; never show zero processes or enable deletion from missing data. Read-only permission changes on populated locations disclose that existing boxed copies may become hidden. Archive retains data and definition; Remove deletes them after confirmation.

## Applications and files

Adding an application uses a file picker and an optional advanced arguments editor. The backend stores a structured argument array; show a preview without executing it. No paste-and-run host command field. A document opens only with a user-selected registered viewer inside the chosen environment, a verified import/grant, and the same launch checks. Host associations are not used.

Files show name, relative location, size and modified time. No host preview. Export uses an explicit destination picker and collision dialog; filenames are displayed as inert text. Confirmations distinguish Reset contents, Remove environment and Archive.

Show complete filename extensions and visibly escaped control/bidirectional characters. Unsafe export names require a validated Rename or Skip. Interrupted exports appear as incomplete; never offer automatic opening of staging or completed output.

For v1 export collisions provide Rename and Skip only. The retention action is labeled Archive, not “Remove and keep data”. Show imported executable references separately from host-installed EXEs. Storage and process-limit displays distinguish measured/advisory values from engine-enforced limits.

## Errors

Every error includes a plain-language cause, affected action, safe next step and expandable diagnostic ID. Suggested stable codes: ENGINE_MISSING, ENGINE_UNTRUSTED, ENGINE_UNTESTED, ENGINE_UNAVAILABLE, CAPABILITY_UNAVAILABLE, POLICY_CONFLICT, POLICY_UNVERIFIED, LAUNCH_FAILED, MEMBERSHIP_UNKNOWN, BOX_BUSY, PATH_UNSAFE, EXPORT_FAILED, CLEANUP_INCOMPLETE.

Add MANAGER_CONTEXT_UNSAFE, OPERATION_OUTCOME_UNKNOWN, STALE_OPERATION and PRIVILEGED_SCOPE_REJECTED. For an uncertain launch, offer Recheck and safe Stop when available; do not implement Retry as replay of the same request. Explain that a new explicit launch may repeat work if the earlier target already executed. A boxed manager offers instructions to start the installed manager outside the box, without invoking a bypass or host relaunch itself.

Do not suggest turning off antivirus, Secure Boot, Windows driver protections or the browser's sandbox. Do not offer “Run normally” as recovery from a failed isolated launch. A separate host launch feature is outside v1.

## Accessibility and diagnostics

Use semantic controls, visible keyboard focus, screen-reader labels and reduced-motion support. Long paths can be copied without forcing horizontal layout overflow. Redact user names, full paths, command arguments, certificate data and file contents in shared diagnostics by default. Show the exact diagnostic bundle before the user saves or shares it. No automatic reporting.

Apply secret minimization before local logging, not only when exporting diagnostics. The advanced arguments editor explains that command-line credentials can be exposed to the host and must not be used as a secret store. Log display uses structured fields and escaped controls so an engine error or target filename cannot forge manager events.
