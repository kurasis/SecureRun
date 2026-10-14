[CmdletBinding()]
param([Parameter(Mandatory)][string]$Manager,[Parameter(Mandatory)][string]$Fixture,[Parameter(Mandatory)][string]$EngineHome)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$result=@{status='IN_PROGRESS';standard_user=$false;accepted_config_without_enforcement=$false;protected_status=$false;production_target_launches=0}
function Require([bool]$ok,[string]$code){if(-not $ok){throw $code}}
function Policy($request){
    $s=[Diagnostics.ProcessStartInfo]::new($Manager);$s.UseShellExecute=$false;$s.WorkingDirectory=$EngineHome;$s.RedirectStandardInput=$true;$s.RedirectStandardOutput=$true;$s.RedirectStandardError=$true;$s.ArgumentList.Add('--policy-once');$p=[Diagnostics.Process]::Start($s)
    try{$read=$p.StandardOutput.ReadToEndAsync();$err=$p.StandardError.ReadToEndAsync();$p.StandardInput.Write((ConvertTo-Json -InputObject $request -Depth 8 -Compress));$p.StandardInput.Close();Require ($p.WaitForExit(150000)) 'UNPROVEN_POLICY_TIMEOUT';Require ($p.ExitCode -eq 0) 'UNPROVEN_POLICY_EXIT_FAILED';return $read.Result|ConvertFrom-Json}finally{if(-not $p.HasExited){$p.Kill($true)};$p.Dispose()}
}
try{
    $principal=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent());Require (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) 'STANDARD_TOKEN_REQUIRED';$result.standard_user=$true
    $r=Policy @{action='CREATE';display_name='Accepted writes need independent proof';operation_id=[Guid]::NewGuid().ToString();policy=@{schema=1;preset='STANDARD_OFFLINE';grants=@()}}
    Require ($r.reason -eq 'DIAGNOSTIC_EXECUTION_FAILED' -and -not $r.production_launch_available) 'WRONG_DIAGNOSTIC_DID_NOT_FAIL'
    $r=Policy @{action='LIST'};Require ($r.reason -eq 'OBSERVED' -and $r.environments.Count -eq 1) 'UNPROVEN_OPERATION_NOT_JOURNALED';$e=$r.environments[0]
    Require ($e.stage -eq 'CONFLICT' -and $null -ne $e.root_identity -and $null -eq $e.fingerprint -and $null -eq $e.enforcement_evidence -and -not $e.production_launch_available) 'CONFIG_WRITE_TREATED_AS_ENFORCEMENT'
    $result.accepted_config_without_enforcement=$true;$result.root_binding_present=$true;$result.conflict_after_failed_probe=$true;$result.reason=$e.reason;$result.status='PASSED'
}catch{$result.status='FAILED';$result.code=if($_.Exception.Message -cmatch '\b([A-Z][A-Z0-9_]{3,80})\b'){$Matches[1]}else{'UNPROVEN_POLICY_GATE_FAILED'}}
$result|ConvertTo-Json|Set-Content (Join-Path $Fixture 'results/no-enforcement.json') -Encoding utf8
if($result.status -ne 'PASSED'){exit 1}
