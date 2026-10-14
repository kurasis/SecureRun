param([string]$Manager,[string]$Fixture)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$result=@{actual_manager_executed=$false;manager_context='UNKNOWN';bridge_context='UNKNOWN';trust='UNKNOWN';reason='NATIVE_DIAGNOSTIC_UNAVAILABLE';boxes_observed=0;production_launch_available=$false;control_or_elevation_dispatched=$false;self_relaunch_or_escape_attempted=$false}
$safe=$false
try {
    $start=[Diagnostics.ProcessStartInfo]::new($Manager);$start.UseShellExecute=$false;$start.WorkingDirectory=(Split-Path $Manager);$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true;$start.ArgumentList.Add('--observation-once')
    $p=[Diagnostics.Process]::Start($start);$result.actual_manager_executed=$true
    try {
        $read=$p.StandardOutput.ReadToEndAsync();$errorRead=$p.StandardError.ReadToEndAsync()
        if(-not $p.WaitForExit(30000)){$p.Kill();throw 'BOXED_NATIVE_DIAGNOSTIC_TIMEOUT'}
        $result.native_exit_code=$p.ExitCode;$result.stdout_chars=$read.Result.Length
        if($p.ExitCode -ne 0 -or $read.Result.Length -gt 2097152){throw 'BOXED_NATIVE_DIAGNOSTIC_FAILED'}
        $o=$read.Result|ConvertFrom-Json
        $result.manager_context=$o.manager_context;$result.bridge_context=$o.bridge_context;$result.trust=$o.trust;$result.reason=$o.reason;$result.boxes_observed=$o.boxes.Count;$result.production_launch_available=$o.production_launch_available
        $safe=$o.manager_context -ne 'UNBOXED' -and -not $o.production_launch_available -and $o.boxes.Count -eq 0
    }finally{$p.Dispose()}
}catch{$result.failure_type=$_.Exception.GetBaseException().GetType().FullName;$result.failure_code=if($_.Exception.Message -cmatch '\b([A-Z][A-Z0-9_]{3,80})\b'){$Matches[1]}else{'BOXED_DIAGNOSTIC_FAILED'}}
$result|ConvertTo-Json|Set-Content (Join-Path $Fixture 'results/boxed-manager.json') -Encoding utf8
if($safe){exit 43}
exit 44
