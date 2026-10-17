[CmdletBinding()]
param([Parameter(Mandatory)][string]$Manager,[Parameter(Mandatory)][string]$Fixture,[Parameter(Mandatory)][string]$HostPid,[Parameter(Mandatory)][string]$HostBirth)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$result=@{status='IN_PROGRESS';actual_boxed_manager_executed=$false;actual_boxed_worker_executed=$false;claimed_unboxed_parent_accepted=$false;control_dispatched=$false;privileged_helper=$false;production_target_launches=0}
function Require([bool]$ok,[string]$code){if(-not $ok){throw $code}}
function Invoke-Control([string[]]$arguments,[string]$payload='{"action":"CREATE","display_name":"Boxed client must not enroll","operation_id":"3473aca3-8501-4845-9d60-b7dceafced20","policy":{"schema":1,"preset":"STANDARD_OFFLINE","grants":[]}}'){
    $s=[Diagnostics.ProcessStartInfo]::new($Manager);$s.UseShellExecute=$false;$s.WorkingDirectory=(Split-Path $Manager);$s.RedirectStandardInput=$true;$s.RedirectStandardOutput=$true;$s.RedirectStandardError=$true;foreach($a in $arguments){$s.ArgumentList.Add($a)};$p=[Diagnostics.Process]::Start($s)
    try{$read=$p.StandardOutput.ReadToEndAsync();$err=$p.StandardError.ReadToEndAsync();$p.StandardInput.Write($payload);$p.StandardInput.Close();Require ($p.WaitForExit(30000)) 'BOXED_CONTROL_TIMEOUT';Require ($p.ExitCode -eq 0 -and $read.Result.Length -le 2097152) 'BOXED_CONTROL_RESPONSE_INVALID';return $read.Result|ConvertFrom-Json}finally{if(-not $p.HasExited){$p.Kill($true)};$p.Dispose()}
}
try{
    $r=Invoke-Control @('--policy-once');$result.actual_boxed_manager_executed=$true;$result.manager_reason=$r.reason
    Require ($r.reason -in @('MANAGER_CONTEXT_UNSAFE','BRIDGE_JOB_FAILED') -and $r.environments.Count -eq 0 -and -not $r.production_launch_available -and -not $r.elevated_helper) 'BOXED_MANAGER_CONTROL_ACCEPTED'
    $r=Invoke-Control @('--policy-worker',$HostPid,$HostBirth);$result.actual_boxed_worker_executed=$true;$result.worker_reason=$r.reason
    Require ($r.reason -eq 'MANAGER_CONTEXT_UNSAFE' -and $r.environments.Count -eq 0 -and -not $r.production_launch_available) 'BOXED_WORKER_FORGED_PARENT_ACCEPTED'
    $result.worker_boundaries=@()
    foreach($entry in @(
        @{mode='control';payload='{"action":"STOP_MANAGED","operation_id":"3473aca3-8501-4845-9d60-b7dceafced20"}'},
        @{mode='files';payload='{"action":"CANCEL","operation_id":"3473aca3-8501-4845-9d60-b7dceafced20"}'},
        @{mode='lifecycle';payload='{"action":"COMMIT","operation_id":"3473aca3-8501-4845-9d60-b7dceafced20","plan_id":"3473aca3-8501-4845-9d60-b7dceafced20"}'},
        @{mode='product';payload='{"action":"RECORD","event":{"environment_id":null,"action":"LAUNCH","outcome":"OBSERVED","diagnostic_id":"3473aca3-8501-4845-9d60-b7dceafced20","unix_ms":0}}'})){
        $workerFlag='--'+$entry.mode+'-worker'
        $r=Invoke-Control @($workerFlag,$HostPid,$HostBirth) $entry.payload
        Require ($r.reason -eq 'MANAGER_CONTEXT_UNSAFE') 'BOXED_INTEGRATED_WORKER_ACCEPTED'
        $result.worker_boundaries+=@{mode=$entry.mode;reason=$r.reason;actual_boxed_execution=$true;claimed_unboxed_parent_accepted=$false}
    }
    $result.status='PASSED'
}catch{$result.status='FAILED';$result.code=if($_.Exception.Message -cmatch '\b([A-Z][A-Z0-9_]{3,80})\b'){$Matches[1]}else{'BOXED_POLICY_CONTROL_FAILED'}}
$result|ConvertTo-Json|Set-Content (Join-Path $Fixture 'results/boxed-policy.json') -Encoding utf8
if($result.status -eq 'PASSED'){exit 43};exit 44
