param([string]$Manager,[string]$Fixture)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$o=(& $Manager --observation-once) | ConvertFrom-Json
@{actual_manager_executed=$true;manager_context=$o.manager_context;bridge_context=$o.bridge_context;trust=$o.trust;reason=$o.reason;boxes_observed=$o.boxes.Count;production_launch_available=$o.production_launch_available;control_or_elevation_dispatched=$false;self_relaunch_or_escape_attempted=$false} | ConvertTo-Json | Set-Content (Join-Path $Fixture 'results/boxed-manager.json') -Encoding utf8
if($o.manager_context -eq 'UNBOXED' -or $o.production_launch_available -or $o.boxes.Count -ne 0){exit 44}
exit 43
