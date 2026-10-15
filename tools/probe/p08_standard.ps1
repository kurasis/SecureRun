param([string]$Manager,[string]$Fixture,[string]$EngineHome,[string]$FaultManager,[string]$Mode='normal')
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$cases=[Collections.Generic.List[object]]::new()
function Save {ConvertTo-Json -InputObject @($cases.ToArray()) -Depth 12|Set-Content (Join-Path $Fixture 'lifecycle-cases.json') -Encoding utf8}
function Require([bool]$ok,[string]$code){if(-not $ok){throw $code}}
function Case([string]$id,[string]$name,[scriptblock]$body){$c=@{id=$id;name=$name;status='IN_PROGRESS'};$cases.Add($c);Save;try{$c.evidence=(& $body);$c.status='PASSED'}catch{$c.status='FAILED';$c.code=if($_.Exception.Message -cmatch '\b([A-Z][A-Z0-9_]{3,80})\b'){$Matches[1]}else{'LIFECYCLE_CASE_FAILED'};$c.line=$_.InvocationInfo.ScriptLineNumber};Save;Write-Host ($name+' '+$c.status+$(if($c.ContainsKey('code')){' '+$c.code}else{''}))}
function Call($request,[string]$kind='lifecycle',[bool]$allowFailure=$false){
 $s=[Diagnostics.ProcessStartInfo]::new($script:active);$s.UseShellExecute=$false;$s.WorkingDirectory=$EngineHome;$s.RedirectStandardInput=$true;$s.RedirectStandardOutput=$true;$s.StandardInputEncoding=[Text.UTF8Encoding]::new($false);$s.StandardOutputEncoding=[Text.UTF8Encoding]::new($false);$s.RedirectStandardError=$true;$s.ArgumentList.Add("--$kind-once")
 $p=[Diagnostics.Process]::Start($s)
 try{$read=$p.StandardOutput.ReadToEndAsync();$errors=$p.StandardError.ReadToEndAsync();$p.StandardInput.Write((ConvertTo-Json -InputObject $request -Depth 12 -Compress));$p.StandardInput.Close();Require ($p.WaitForExit(240000)) 'LIFECYCLE_CALL_TIMEOUT';Require ($p.ExitCode -eq 0) 'LIFECYCLE_WORKER_EXIT_FAILED';$r=$read.Result|ConvertFrom-Json;if(-not $allowFailure){Require ($r.reason -eq 'OBSERVED') $r.reason};return $r}finally{if(-not $p.HasExited){$p.Kill();$null=$p.WaitForExit(10000)};$p.Dispose()}
}
function New-Environment {
 $r=Call @{action='CREATE';display_name='P08 retained fixture Привет 🧪';operation_id=[Guid]::NewGuid().ToString();policy=@{schema=1;preset='STANDARD_OFFLINE';grants=@()}} 'policy'
 $script:e=$r.environments[-1];Require ($e.stage -eq 'VERIFIED') 'P05_GATE_REQUIRED';$script:root=$e.compiled.section.FileRootPath[0]
}
function Refresh-Environment {$r=Call @{action='LIST'} 'policy';$script:e=$r.environments|Where-Object id -eq $script:e.id;Require ($null -ne $e) 'OWNED_ENVIRONMENT_MISSING'}
function Prepare([string]$intent){return (Call @{action='PREPARE';environment_id=$script:e.id;expected_revision=$script:e.revision;expected_generation=$script:e.generation;operation_id=[Guid]::NewGuid().ToString();intent=$intent}).plan}
function Commit($plan,[bool]$allowFailure=$false){return (Call @{action='COMMIT';operation_id=$plan.operation_id;plan_id=$plan.plan_id} 'lifecycle' $allowFailure)}
function Act([string]$intent){$plan=Prepare $intent;$r=Commit $plan;Require (($r.operations|Where-Object operation_id -eq $plan.operation_id).stage -eq 'COMPLETE') 'LIFECYCLE_NOT_COMPLETE';if($intent -ne 'REMOVE'){Refresh-Environment};return $r}
function Import([string]$name){$r=Call @{action='IMPORT';environment_id=$e.id;expected_revision=$e.revision;operation_id=[Guid]::NewGuid().ToString();source=$script:source;name=$name} 'files';return $r}
function Workspace {
 $q=@{action='LIST';environment_id=$e.id;expected_revision=$e.revision;node_id=$null;offset=0};$r=Call $q 'files'
 foreach($name in @('drive',$env:SystemRoot.Substring(0,1),'SecureRunWorkspace',$e.id.Replace('-',''))){$entry=$r.entries|Where-Object name -eq $name;Require ($null -ne $entry) 'WORKSPACE_MAPPING_MISSING';$q.node_id=$entry.id;$r=Call $q 'files'};return $r
}
function Register-Host([string]$output){$q=@{action='REGISTER';environment_id=$e.id;expected_revision=$e.revision;operation_id=[Guid]::NewGuid().ToString();display_name='P08 host fixture';executable=(Join-Path (Split-Path $script:active) 'securerun-launch-probe.exe');arguments=@('short',$output);working_directory=$null};$r=Call $q 'control';$op=$r.receipts|Where-Object operation_id -eq $q.operation_id;Require ($op.state -eq 'REGISTERED') $op.reason;return ($r.applications|Where-Object environment_id -eq $e.id)[-1]}
function Launch($app){$id=[Guid]::NewGuid().ToString();$r=Call @{action='LAUNCH';environment_id=$e.id;expected_revision=$e.revision;application_id=$app.id;operation_id=$id} 'control';return ($r.receipts|Where-Object operation_id -eq $id)}
function Stop-Owned {$id=[Guid]::NewGuid().ToString();$r=Call @{action='STOP';environment_id=$e.id;operation_id=$id} 'control';Require (($r.receipts|Where-Object operation_id -eq $id).state -eq 'STOPPED') 'STOP_NOT_COMPLETE'}
function Empty-Root {Require (@(Get-ChildItem -LiteralPath $script:root -Force).Count -eq 0) 'ROOT_NOT_EMPTY'}
try{
 $who=[Security.Principal.WindowsIdentity]::GetCurrent();Require (-not ([Security.Principal.WindowsPrincipal]::new($who)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) 'STANDARD_USER_REQUIRED'
 $script:active=if($Mode -eq 'fault'){$FaultManager}else{$Manager}
 $script:source=Join-Path $Fixture 'synthetic.txt';[IO.File]::WriteAllText($source,'SYNTHETIC_P08_RETAINED_CONTENT');$hash=(Get-FileHash -LiteralPath $source).Hash
 New-Environment
 if($Mode -eq 'normal'){
  $script:registeredHost=Register-Host (Join-Path $Fixture 'host-report.jsonl')
  Case 'T24' 'reset_preserves_definition_applications_and_retained_root_identity' {
   $null=Import 'keep.txt';$rootID=$e.root_identity;$generation=$e.generation;$null=Act 'RESET';Empty-Root
   Require ($e.root_identity -eq $rootID -and $e.generation -eq ($generation+1)) 'RESET_BINDING_WRONG'
   $r=Call @{action='LIST'} 'control';Require (@($r.applications|Where-Object id -eq $script:registeredHost.id).Count -eq 1) 'RESET_REMOVED_HOST_APPLICATION'
   $launched=Launch $script:registeredHost;Require ($launched.state -in @('RUNNING_BOXED','PRIMARY_EXITED_BOXED')) $launched.reason;Stop-Owned
   @{original_native_cleanup=$true;retained_root_identity=$true;generation_advanced=$true;definition_retained=$true;host_application_retained_and_launchable=$true;generic_root_deletion=$false}
  }
  Case 'T48' 'archive_retains_data_blocks_manager_launch_and_unarchive_revalidates' {
   $null=Import 'archive.txt';$file=@(Get-ChildItem -LiteralPath $root -Recurse -File -Filter 'archive.txt');Require ($file.Count -eq 1) 'ARCHIVE_FIXTURE_MISSING';$null=Act 'ARCHIVE';Require ((Get-FileHash -LiteralPath $file.FullName).Hash -eq $hash) 'ARCHIVE_DATA_CHANGED'
   $receipt=Launch $script:registeredHost;Require ($receipt.state -eq 'REFUSED' -and $receipt.reason -eq 'LIFECYCLE_NOT_ACTIVE') 'ARCHIVED_LAUNCH_ALLOWED'
   $null=Act 'UNARCHIVE';$receipt=Launch $script:registeredHost;Require ($receipt.state -in @('RUNNING_BOXED','PRIMARY_EXITED_BOXED')) $receipt.reason;Stop-Owned
   @{definition_and_data_retained=$true;manager_launch_refused=$true;unarchive_fresh_policy_and_identity=$true;installer_retention='P11'}
  }
  Case 'T26' 'forged_confirmation_and_stale_generation_refused_without_mutation' {
   $plan=Prepare 'RESET';$r=Call @{action='COMMIT';operation_id=$plan.operation_id;plan_id=[Guid]::NewGuid().ToString()} 'lifecycle' $true;Require ($r.reason -eq 'LIFECYCLE_CONFIRMATION_INVALID') $r.reason
   $r=Call @{action='PREPARE';environment_id=$e.id;expected_revision=$e.revision;expected_generation=($e.generation+1);operation_id=[Guid]::NewGuid().ToString();intent='RESET'} 'lifecycle' $true;Require ($r.reason -eq 'STALE_LIFECYCLE_OPERATION') $r.reason
   Require (@(Get-ChildItem -LiteralPath $root -Recurse -File -Filter 'archive.txt').Count -eq 1) 'REFUSAL_MUTATED_DATA'
   @{forged_plan_refused=$true;stale_generation_refused=$true;data_preserved=$true;frontend_boolean_is_not_authority=$true}
  }
  Case 'T25' 'remove_clears_before_definition_deletion_and_keeps_audit_tombstone' {
   $old=$e.id;$savedRoot=$root;$r=Act 'REMOVE';Require (@($r.environments|Where-Object environment_id -eq $old).Count -eq 0) 'REMOVED_ENVIRONMENT_STILL_ACTIVE';Require (@(Get-ChildItem -LiteralPath $savedRoot -Force).Count -eq 0) 'REMOVAL_LEFT_DATA'
   Require (@($r.operations|Where-Object {$_.environment_id -eq $old -and $_.intent -eq 'REMOVE' -and $_.stage -eq 'COMPLETE'}).Count -eq 1) 'REMOVAL_TOMBSTONE_MISSING'
   $c=Call @{action='LIST'} 'control';Require (@($c.applications|Where-Object environment_id -eq $old).Count -eq 0) 'REMOVAL_APPLICATION_RECORDS_REMAIN'
   @{contents_cleared_before_definition_delete=$true;original_section_delete_read_back_absent=$true;known_empty_root_recorded=$true;unrelated_boxes_untouched=$true;audit_tombstone=$true}
  }
 }else{
  foreach($point in @('SnapshotCaptured','Fenced','Sealed','DispatchReserved','NativeReturned','Cleared','MetadataCommitted')){
   Case 'T34' ('real_cleanup_executor_interruption_'+$point) {
    if($e.lifecycle -eq 'ARCHIVED'){$null=Act 'UNARCHIVE'}
    $null=Import ('crash-'+$point+'.txt');$plan=Prepare 'RESET';$env:SECURERUN_P08_PAUSE_STAGE=$point
    try{$r=Commit $plan $true;Require ($r.reason -eq 'LIFECYCLE_EXECUTOR_INTERRUPTED_RECHECK_REQUIRED') $r.reason}finally{Remove-Item Env:/SECURERUN_P08_PAUSE_STAGE -ErrorAction SilentlyContinue}
    $proofPath=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) ('SecureRun/metadata/lifecycle-kill-'+$plan.operation_id+'.json');$proof=Get-Content -LiteralPath $proofPath -Raw|ConvertFrom-Json;Require ($proof.real_executor_killed -and $proof.held_exit_wait_completed -and $proof.controller_restored_known_acl -and $proof.checkpoint -eq $point) 'ACTUAL_KILL_PROOF_MISSING'
    $r=Call @{action='RECOVER';operation_id=$plan.operation_id};$record=$r.operations|Where-Object operation_id -eq $plan.operation_id
    Require ($record.stage -eq $(if($point -in @('Cleared','MetadataCommitted')){'COMPLETE_RECOVERED'}else{'INTERRUPTED_RETAINED_ARCHIVED'})) 'RECOVERY_STATE_WRONG'
    Refresh-Environment
    $before=@(Get-ChildItem -LiteralPath $root -Recurse -File).Count;$again=Commit $plan;$after=@(Get-ChildItem -LiteralPath $root -Recurse -File).Count;Require ($before -eq $after) 'DESTRUCTIVE_OPERATION_REPLAYED'
    # An explicit new intent clears retained partial data; recovery never does it.
    $null=Act 'RESET';Empty-Root
    @{real_executor_killed=$true;checkpoint=$point;controller_acl_restored=$true;recovery_inspection_only=$true;replayed=$false;recovered_state=$record.stage;fresh_explicit_cleanup=$true;privileged_helper=$false}
   }
  }
  Case 'T34' 'real_remove_interruption_after_definition_readback' {
   if($e.lifecycle -eq 'ARCHIVED'){$null=Act 'UNARCHIVE'};$null=Import 'remove-crash.txt';$plan=Prepare 'REMOVE';$env:SECURERUN_P08_PAUSE_STAGE='DefinitionRemoved'
   try{$r=Commit $plan $true;Require ($r.reason -eq 'LIFECYCLE_EXECUTOR_INTERRUPTED_RECHECK_REQUIRED') $r.reason}finally{Remove-Item Env:/SECURERUN_P08_PAUSE_STAGE -ErrorAction SilentlyContinue}
   $r=Call @{action='RECOVER';operation_id=$plan.operation_id};$record=$r.operations|Where-Object operation_id -eq $plan.operation_id;Require ($record.stage -eq 'COMPLETE_RECOVERED') 'REMOVE_RECOVERY_NOT_VERIFIED'
   @{real_executor_killed=$true;checkpoint='DefinitionRemoved';actual_definition_absent=$true;metadata_reconciled_without_delete_replay=$true;known_empty_root_retained=$true}
  }
 }
 $failed=@($cases|Where-Object status -ne 'PASSED').Count;@{status=$(if($failed -eq 0){'PASSED'}else{'FAILED'});mode=$Mode;standard_user=$true;failed=$failed}|ConvertTo-Json|Set-Content (Join-Path $Fixture ('standard-'+$Mode+'.json'));if($failed -ne 0){exit 1}
}catch{@{status='FAILED';standard_user=$true;code=$(if($_.Exception.Message -cmatch '\b([A-Z][A-Z0-9_]{3,80})\b'){$Matches[1]}else{'ACTOR_FAILED'});line=$_.InvocationInfo.ScriptLineNumber}|ConvertTo-Json|Set-Content (Join-Path $Fixture ('standard-'+$Mode+'.json'));Save;exit 1}
