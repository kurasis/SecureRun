# Product UX and accessibility

P09 implementation; native validation is pending. This document describes the
implemented behavior and the checks required to claim the phase exit gate.

The original interface uses neutral surfaces, a single accent, text status labels,
visible focus, system/light/dark themes and English/Russian resources. Environments
are searchable owned metadata. Engine boxes that are not owned remain read-only
in Settings. Applications, Processes, Files, Permissions and Activity share a
selected environment; retention and destructive recovery are secondary actions.
Display-name changes preserve the UUID, generation, applied policy and data.
Concurrent stale renames fail, and permanent operation tombstones prevent replay.

Activity uses fresh original-driver observations, independently from current
launch prerequisites. Cards and the selected summary show the configured preset
separately from the last verified network policy. Stale/unverified policy data
shows Unknown. A blocked launch exposes its exact backend reason, including stale
control observations and inactive environments. An unavailable or incomplete observation is Unknown, never
an empty process list authorizing cleanup. Engine onboarding distinguishes
missing, untrusted, unavailable, restart-required, untested and verified states.
Standard read-access limitations appear at policy selection. Mandatory protection
rules are read-only; unsupported device/clipboard controls and paid presets state
their unavailable status and reason. Official help has two fixed HTTPS targets.

Policy edits show the current and desired rules and require review of the diff.
A queued edit keeps native picker identities in bounded backend memory for at
most 60 seconds. It does not alter enforcement. Explicit application requires
fresh policy/generation checks and complete stopped scope. Restart never resumes
an edit, launch, export or cleanup automatically. Stop-all confirmation captures
and names exact environment identities before issuing individual rechecked stops.

Application arguments are an advanced structured array with an inert preview and
a warning against command-line secrets. The file browser shows full escaped
names and bounded pages. Collision choices are Rename and Skip. Files and logs
never offer a host association or automatic opening of exported data.

Keyboard navigation includes Tab, visible focus, Ctrl+1, Ctrl+comma and F6.
Environment tabs use roving focus with arrows, Home and End. Native modal dialogs,
semantic labels, a skip link, status regions, reduced-motion and forced-colors
support are implemented. Content scale uses actual native WebView zoom at
100/150/200 percent. The lab separately selects advertised display modes and Windows scaling through
the public Windows Settings UI Automation provider. The full gate requires
actual manager-window DPI values 96/144/192, with content zoom held at 100 percent;
WebView zoom evidence alone does not establish Windows display DPI coverage.

The P09 lab drives the normal release binary as a standard user. Windows UI
Automation performs real keyboard navigation, native picker actions and an
accessible-name/invoke check. The real Chromium accessibility tree checks the
three settings combobox names. Twelve EN/RU × light/dark × content-scale layouts and twelve additional
EN/RU × light/dark × actual Windows DPI layouts
check labels, clipping and computed text contrast; synthetic screenshots are
retained. These checks demonstrate provider semantics and keyboard operation,
not a subjective review by a person using every screen reader.

Current result: pending [P09 manifest](evidence/p09/manifest.json). Compile-only
checks and DOM assertions do not substitute for successful native execution.

A four-environment focused diagnostic mode skips the performance gate. Its
artifacts and summary are explicitly DIAGNOSTIC_ONLY. The evidence retainer
rejects it even if another field is changed to PASSED. Only the full ten-box
reference workload can close P09. Native product DPI execution remains pending.

On disposable CI VMs the lab controller changes only the three fixed Windows
scaling values. Owner-restricted named events carry these requests without paths,
commands or payload text. The normal application receives no controller names
and uses no elevated product helper. The standard-user checker independently
measures the actual manager-window DPI and the real WebView layouts.

A separate single-environment layout diagnostic checks the initial real product
views, rename, keyboard, themes, content zoom and Windows DPI. It omits official
application downloads and stops before application/file/retention workflows. Its
summary and artifacts are diagnostic only; the full gate still requires every
application, scenario, architecture and ten-environment performance workload.
