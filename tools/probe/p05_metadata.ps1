[CmdletBinding()]
param([Parameter(Mandatory)][string]$Manager,[Parameter(Mandatory)][string]$Fixture,[Parameter(Mandatory)][string]$EngineHome,[Parameter(Mandatory)][string]$Tool)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$result=@{status='IN_PROGRESS';standard_user=$false;privileged_helper=$false;foreign_resource_writes=0}
function Require([bool]$ok,[string]$code){if(-not $ok){throw $code}}
function Policy($request){
    $s=[Diagnostics.ProcessStartInfo]::new($Manager);$s.UseShellExecute=$false;$s.WorkingDirectory=$EngineHome;$s.RedirectStandardInput=$true;$s.RedirectStandardOutput=$true;$s.RedirectStandardError=$true;$s.ArgumentList.Add('--policy-once');$p=[Diagnostics.Process]::Start($s)
    try{$read=$p.StandardOutput.ReadToEndAsync();$err=$p.StandardError.ReadToEndAsync();$p.StandardInput.Write((ConvertTo-Json -InputObject $request -Depth 10 -Compress));$p.StandardInput.Close();Require ($p.WaitForExit(150000)) 'METADATA_POLICY_TIMEOUT';Require ($p.ExitCode -eq 0) 'METADATA_POLICY_EXIT_FAILED';return $read.Result|ConvertFrom-Json}finally{if(-not $p.HasExited){$p.Kill($true)};$p.Dispose()}
}
function Run-Fixture([string]$action){
    $s=[Diagnostics.ProcessStartInfo]::new($Tool);$s.UseShellExecute=$false;$s.WorkingDirectory=$EngineHome;$s.RedirectStandardOutput=$true;$s.RedirectStandardError=$true;$s.ArgumentList.Add($action);$p=[Diagnostics.Process]::Start($s)
    try{$output=$p.StandardOutput.ReadToEndAsync();$errorOutput=$p.StandardError.ReadToEndAsync();Require ($p.WaitForExit(30000)) 'METADATA_FIXTURE_TIMEOUT';Require ($p.ExitCode -eq 0) 'METADATA_FIXTURE_EXIT_FAILED'}finally{if(-not $p.HasExited){$p.Kill($true)};$p.Dispose()}
}
try{
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent();$principal=[Security.Principal.WindowsPrincipal]::new($identity);Require (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) 'STANDARD_TOKEN_REQUIRED';$result.standard_user=$true
    $r=Policy @{action='CREATE';display_name='Synthetic metadata authority fixture';operation_id=[Guid]::NewGuid().ToString();policy=@{schema=1;preset='STANDARD_OFFLINE';grants=@()}};Require ($r.reason -eq 'OBSERVED' -and $r.environments[0].stage -eq 'VERIFIED') 'METADATA_BASELINE_NOT_VERIFIED';$e=$r.environments[0]
    Run-Fixture 'corrupt'
    try{
        $r=Policy @{action='LIST'};$bad=$r.environments[0];Require ($bad.stage -eq 'CONFLICT' -and $bad.reason -eq 'OWNERSHIP_BINDING_CHANGED' -and $null -eq $bad.fingerprint -and -not $bad.production_launch_available) 'FORGED_METADATA_ACCEPTED'
        $r=Policy @{action='APPLY';environment_id=$e.id;expected_revision=$e.revision;operation_id=[Guid]::NewGuid().ToString();acknowledge_view_change=$false;policy=@{schema=1;preset='STANDARD_OFFLINE';grants=@()}};Require ($r.reason -eq 'RECONCILIATION_REQUIRED') 'FORGED_METADATA_DISPATCHED'
        $result.forged_compiler_root_and_mandatory_layer_refused=$true;$result.launch_blocked=$true;$result.status='PASSED'
    }finally{Run-Fixture 'restore'}
}catch{$result.status='FAILED';$result.code=if($_.Exception.Message -cmatch '\b([A-Z][A-Z0-9_]{3,80})\b'){$Matches[1]}else{'METADATA_AUTHORITY_FAILED'}}
$result|ConvertTo-Json|Set-Content (Join-Path $Fixture 'results/metadata-authority.json') -Encoding utf8
if($result.status -ne 'PASSED'){exit 1}
