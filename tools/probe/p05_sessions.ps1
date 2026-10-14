param([string]$Manager,[string]$EngineHome,[string]$Fixture)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$result=@{status='IN_PROGRESS';standard_user=$false;production_target_launches=0}
function Require([bool]$ok,[string]$code){if(-not $ok){throw $code}}
function Policy($request){
    $start=[Diagnostics.ProcessStartInfo]::new($Manager);$start.UseShellExecute=$false;$start.WorkingDirectory=$EngineHome;$start.RedirectStandardInput=$true;$start.RedirectStandardOutput=$true;$start.ArgumentList.Add('--policy-once')
    $p=[Diagnostics.Process]::Start($start)
    try{$read=$p.StandardOutput.ReadToEndAsync();$p.StandardInput.Write((ConvertTo-Json -InputObject $request -Depth 10 -Compress));$p.StandardInput.Close();Require ($p.WaitForExit(150000)) 'SESSION_POLICY_TIMEOUT';Require ($p.ExitCode -eq 0) 'SESSION_POLICY_EXIT_FAILED';return $read.Result|ConvertFrom-Json}finally{if(-not $p.HasExited){$p.Kill($true)};$p.Dispose()}
}
function Observe {
    $s=[Diagnostics.ProcessStartInfo]::new($Manager);$s.UseShellExecute=$false;$s.WorkingDirectory=$EngineHome;$s.RedirectStandardOutput=$true;$s.RedirectStandardError=$true;$s.ArgumentList.Add('--observation-once');$p=[Diagnostics.Process]::Start($s)
    try{$read=$p.StandardOutput.ReadToEndAsync();$errors=$p.StandardError.ReadToEndAsync();Require ($p.WaitForExit(30000)) 'SESSION_OBSERVATION_TIMEOUT';Require ($p.ExitCode -eq 0) 'SESSION_OBSERVATION_EXIT_FAILED';return $read.Result|ConvertFrom-Json}finally{if(-not $p.HasExited){$p.Kill($true)};$p.Dispose()}
}
try{
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent();$principal=[Security.Principal.WindowsPrincipal]::new($identity);Require (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) 'STANDARD_USER_REQUIRED';$result.standard_user=$true
    $actorSession=[Diagnostics.Process]::GetCurrentProcess().SessionId;Require ($actorSession -ne 0) 'INDEPENDENT_ACTOR_SESSION_REQUIRED'
    $policy=@{schema=1;preset='STANDARD_OFFLINE';grants=@()};$r=Policy @{action='CREATE';display_name='Cross-session stopped gate';operation_id=[Guid]::NewGuid().ToString();policy=$policy};Require ($r.reason -eq 'OBSERVED') $r.reason;$e=$r.environments[0]
    Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'p05_lab.cs')))
    $lab=[P05Lab]::new($EngineHome,$Fixture,$PSScriptRoot);$box='SR_'+$e.id.Replace('-','');$lab.Register($box);$lab.Set($box,'Enabled','y')
    @{box=$box;owner_sid=$identity.User.Value}|ConvertTo-Json|Set-Content (Join-Path $Fixture 'results/session-ready.json') -Encoding utf8
    $clock=[Diagnostics.Stopwatch]::StartNew()
    $result.stage='OBSERVING_OTHER_SESSION'
    do{$o=Observe;$b=@($o.boxes|Where-Object name -eq $box);if($b.Count -eq 1 -and $b[0].complete -and @($b[0].processes|Where-Object session -eq 0).Count -ge 1){break};Start-Sleep -Milliseconds 100}while($clock.ElapsedMilliseconds -lt 30000)
    Require ($o.reason -eq 'OBSERVED' -and $b.Count -eq 1 -and $b[0].complete -and @($b[0].processes|Where-Object session -eq 0).Count -ge 1 -and @($b[0].processes|Where-Object owner_sid -ne $identity.User.Value).Count -eq 0) 'ACTUAL_OTHER_SESSION_NOT_OBSERVED'
    $roots=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'SecureRun/boxes';$before=@(Get-ChildItem $roots).Count
    $a=Policy @{action='APPLY';environment_id=$e.id;expected_revision=$e.revision;operation_id=[Guid]::NewGuid().ToString();acknowledge_view_change=$false;policy=$policy};Require ($a.reason -eq 'STOP_REQUIRED_ALL_SESSIONS') 'OTHER_SESSION_POLICY_MUTATION_ALLOWED'
    $c=Policy @{action='CREATE';display_name='Other-session rollout must defer';operation_id=[Guid]::NewGuid().ToString();policy=$policy};Require ($c.reason -eq 'STOP_REQUIRED_ALL_SESSIONS' -and @(Get-ChildItem $roots).Count -eq $before) 'OTHER_SESSION_STORAGE_CREATED'
    $after=Observe;$live=@($after.boxes|Where-Object name -eq $box);Require ($live.Count -eq 1 -and $live[0].complete -and @($live[0].processes|Where-Object session -eq 0).Count -ge 1) 'OTHER_SESSION_PROCESS_WAS_TERMINATED'
    $result=@{status='PASSED';standard_user=$true;actor_session=$actorSession;target_session=0;same_owner_verified=$true;real_windows_sessions=$true;all_session_complete=$true;apply_reason=$a.reason;create_reason=$c.reason;new_storage_absent=$true;held_process_not_terminated=$true;production_target_launches=0;credential_values_retained=$false}
}catch{$result.status='FAILED';$result.exception_type=$_.Exception.GetBaseException().GetType().FullName;$result.script_line=$_.InvocationInfo.ScriptLineNumber;$result.code=if($_.Exception.Message -cmatch '\b([A-Z][A-Z0-9_]{3,80})\b'){$Matches[1]}else{'CROSS_SESSION_GATE_FAILED'}}
$result|ConvertTo-Json -Depth 6|Set-Content (Join-Path $Fixture 'results/cross-session.json') -Encoding utf8
if($result.status -ne 'PASSED'){exit 1}
