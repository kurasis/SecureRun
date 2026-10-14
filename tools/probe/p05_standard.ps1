[CmdletBinding()]
param([Parameter(Mandatory)][string]$Manager,[Parameter(Mandatory)][string]$Fixture,[Parameter(Mandatory)][string]$EngineHome)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$result=@{status='IN_PROGRESS';standard_user=$false;elevated_helper=$false}
function Require([bool]$ok,[string]$code){if(-not $ok){throw $code}}
function Policy($request){
    $start=[Diagnostics.ProcessStartInfo]::new($Manager);$start.UseShellExecute=$false;$start.WorkingDirectory=$EngineHome;$start.RedirectStandardInput=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true;$start.ArgumentList.Add('--policy-once')
    $p=[Diagnostics.Process]::Start($start)
    try{$read=$p.StandardOutput.ReadToEndAsync();$err=$p.StandardError.ReadToEndAsync();$p.StandardInput.Write((ConvertTo-Json -InputObject $request -Depth 10 -Compress));$p.StandardInput.Close();Require ($p.WaitForExit(60000)) 'STANDARD_POLICY_TIMEOUT';Require ($p.ExitCode -eq 0) 'STANDARD_POLICY_EXIT_FAILED';return $read.Result|ConvertFrom-Json}
    finally{if(-not $p.HasExited){$p.Kill($true)};$p.Dispose()}
}
try {
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent();$principal=[Security.Principal.WindowsPrincipal]::new($identity)
    Require (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) 'STANDARD_TOKEN_REQUIRED';$result.standard_user=$true
    $r=Policy @{action='CREATE';display_name='Standard user production path';operation_id=[Guid]::NewGuid().ToString();policy=@{schema=1;preset='STANDARD_OFFLINE';grants=@()}}
    Require ($r.reason -eq 'OBSERVED' -and $r.environments.Count -eq 1) $r.reason
    $e=$r.environments[0];Require ($e.stage -eq 'VERIFIED' -and $null -ne $e.root_identity -and $null -ne $e.enforcement_evidence -and $e.owner_sid -eq $identity.User.Value -and -not $e.production_launch_available) 'STANDARD_PROVISIONING_UNVERIFIED'
    $root=$e.compiled.section.FileRootPath[0];$local=[Environment]::GetFolderPath('LocalApplicationData');Require ($root.StartsWith((Join-Path $local 'SecureRun/boxes'),[StringComparison]::OrdinalIgnoreCase)) 'WRONG_USER_PROFILE_BOUND'
    $metadata=Join-Path $local 'SecureRun/metadata/standard-acl-canary.txt';$canary=Join-Path $root 'standard-acl-canary.txt';[IO.File]::WriteAllText($metadata,'SYNTHETIC_METADATA');[IO.File]::WriteAllText($canary,'SYNTHETIC_ROOT')
    @{root_canary=$canary;metadata_canary=$metadata}|ConvertTo-Json|Set-Content (Join-Path $Fixture 'results/acl-request.json') -Encoding utf8
    $result.owner_from_os=$true;$result.original_user_profile_preserved=$true;$result.root_identity_bound=$true;$result.verified_without_uac=$true;$result.context='UNBOXED';$result.production_target_launches=0;$result.status='PASSED'
}catch{$result.status='FAILED';$result.code=if($_.Exception.Message -cmatch '\b([A-Z][A-Z0-9_]{3,80})\b'){$Matches[1]}else{'STANDARD_PROVISIONING_FAILED'}}
$result|ConvertTo-Json -Depth 8|Set-Content (Join-Path $Fixture 'results/standard-user.json') -Encoding utf8
if($result.status -ne 'PASSED'){exit 1}
