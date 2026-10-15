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
function Register-Probe([string]$mode,[string]$leaf){$id=[Guid]::NewGuid().ToString();$q=@{action='REGISTER';environment_id=$e.id;expected_revision=$e.revision;operation_id=$id;display_name='P08 workload';executable=(Join-Path (Split-Path $script:active) 'securerun-launch-probe.exe');arguments=@($mode,(Join-Path $Fixture $leaf));working_directory=$null};$r=Call $q 'control';Require (($r.receipts|Where-Object operation_id -eq $id).state -eq 'REGISTERED') 'WORKLOAD_REGISTER_FAILED';return ($r.applications|Where-Object environment_id -eq $e.id)[-1]}
function Start-Normal-Desktop {$s=[Diagnostics.ProcessStartInfo]::new($script:active);$s.UseShellExecute=$false;$s.WorkingDirectory=Join-Path $env:SystemRoot 'System32';$s.RedirectStandardOutput=$true;$s.RedirectStandardError=$true;$p=[Diagnostics.Process]::Start($s);$null=$p.StandardOutput.ReadToEndAsync();$null=$p.StandardError.ReadToEndAsync();return $p}
function Native-Confirm([string]$intent,[bool]$accept){
 $s=[Diagnostics.ProcessStartInfo]::new($script:active);$s.UseShellExecute=$false;$s.WorkingDirectory=Join-Path $env:SystemRoot 'System32';$s.RedirectStandardInput=$true;$s.RedirectStandardOutput=$true;$s.RedirectStandardError=$true;$s.StandardInputEncoding=[Text.UTF8Encoding]::new($false);$s.StandardOutputEncoding=[Text.UTF8Encoding]::new($false);$s.ArgumentList.Add('--lifecycle-confirm-once');$p=[Diagnostics.Process]::Start($s)
 try{$read=$p.StandardOutput.ReadToEndAsync();$errors=$p.StandardError.ReadToEndAsync();$q=@{action='ACT';environment_id=$e.id;expected_revision=$e.revision;expected_generation=$e.generation;operation_id=[Guid]::NewGuid().ToString();intent=$intent;language='en'};$p.StandardInput.Write((ConvertTo-Json -InputObject $q -Compress));$p.StandardInput.Close();[P08Desktop]::Confirm($p,$script:active,$e.id,$accept);Require ($p.WaitForExit(180000)) 'NATIVE_CONFIRMATION_RESULT_TIMEOUT';Require ($p.ExitCode -eq 0) 'NATIVE_CONFIRMATION_PROCESS_FAILED';return ($read.Result|ConvertFrom-Json)}finally{if(-not $p.HasExited){$p.Kill();$null=$p.WaitForExit(10000)};$p.Dispose()}
}
try{
 $who=[Security.Principal.WindowsIdentity]::GetCurrent();Require (-not ([Security.Principal.WindowsPrincipal]::new($who)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) 'STANDARD_USER_REQUIRED'
 $script:active=if($Mode -eq 'fault'){$FaultManager}else{$Manager}
 $userTemp=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Temp';$null=New-Item -ItemType Directory -Path $userTemp -Force;$env:TEMP=$userTemp;$env:TMP=$userTemp
 $script:source=Join-Path $Fixture 'synthetic.txt';[IO.File]::WriteAllText($source,'SYNTHETIC_P08_RETAINED_CONTENT');$hash=(Get-FileHash -LiteralPath $source).Hash
 New-Environment
 if($Mode -eq 'normal'){
  Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'p08_desktop.cs')))
  Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'p05_lab.cs')))
  Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'engine_bridge.cs')))
  $lab=[P05Lab]::new($EngineHome,$Fixture,$PSScriptRoot)
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
  Case 'T24' 'native_confirmation_names_environment_and_cancel_consumes_plan' {
   $null=Import 'native-confirmation.txt';$before=$e.generation
   $r=Native-Confirm 'RESET' $false;Require ($r.reason -eq 'LIFECYCLE_CONFIRMATION_CANCELLED') $r.reason;Refresh-Environment;Require ($e.generation -eq $before) 'CANCEL_CHANGED_GENERATION';Require (@(Get-ChildItem -LiteralPath $root -Recurse -File -Filter 'native-confirmation.txt').Count -eq 1) 'NATIVE_CANCEL_DELETED_DATA'
   $r=Native-Confirm 'RESET' $true;Require ($r.reason -eq 'OBSERVED') $r.reason;Refresh-Environment;Empty-Root;Require ($e.generation -eq ($before+1)) 'NATIVE_CONFIRMATION_NOT_COMMITTED'
   @{real_native_dialog=$true;normal_production_binary=$true;affected_environment_uuid_visible=$true;cancel_preserves_data=$true;cancelled_plan_consumed=$true;explicit_accept_completed_reset=$true;renderer_confirmation_boolean=$false}
  }
  Case 'T06' 'persistent_workload_survives_actual_normal_window_close' {
   $held=Register-Probe 'hold' ('persistent-'+[Guid]::NewGuid().ToString('N')+'.jsonl');$receipt=Launch $held;Require ($receipt.state -eq 'RUNNING_BOXED') $receipt.reason
   $gui=Start-Normal-Desktop
   try{[P08Desktop]::CloseNormalWindow($gui,$script:active)}finally{if(-not $gui.HasExited){$gui.Kill();$null=$gui.WaitForExit(10000)};$gui.Dispose()}
   $r=Call @{action='LIST'} 'control';$view=$r.environments|Where-Object environment_id -eq $e.id;Require ($view.complete -and $view.activity -eq 'RUNNING' -and $view.processes.pid -contains $receipt.process.pid) 'UI_EXIT_TERMINATED_PERSISTENT_WORKLOAD';Stop-Owned
   @{normal_desktop_window_opened_and_closed=$true;protected_normal_binary=$true;actual_boxed_process_survived=$true;complete_all_session_observation=$true;auto_cleanup=$false}
  }
  Case 'T06' 'disposable_waits_for_background_descendants_and_survives_manager_crash' {
   $null=Act 'DISPOSABLE';$background=Register-Probe 'background' ('disposable-'+[Guid]::NewGuid().ToString('N')+'.jsonl');$receipt=Launch $background
   $clock=[Diagnostics.Stopwatch]::StartNew();do{$r=Call @{action='LIST'} 'control';$view=$r.environments|Where-Object environment_id -eq $e.id;if($view.complete -and $view.processes.Count -ge 2){break};Start-Sleep -Milliseconds 100}while($clock.ElapsedMilliseconds -lt 15000)
   Require ($view.complete -and $view.processes.Count -ge 2 -and $view.activity -eq 'RUNNING') 'DISPOSABLE_DESCENDANTS_NOT_OBSERVED'
   $r=Call @{action='PREPARE';environment_id=$e.id;expected_revision=$e.revision;expected_generation=$e.generation;operation_id=[Guid]::NewGuid().ToString();intent='RESET'} 'lifecycle' $true;Require ($r.reason -eq 'STOP_REQUIRED_ALL_SESSIONS') $r.reason
   $gui=Start-Normal-Desktop;try{[P08Desktop]::WaitNormalWindow($gui,$script:active);$gui.Kill();Require ($gui.WaitForExit(10000)) 'ACTUAL_GUI_CRASH_FAILED'}finally{if(-not $gui.HasExited){$gui.Kill();$null=$gui.WaitForExit(10000)};$gui.Dispose()}
   $r=Call @{action='LIST'} 'control';$view=$r.environments|Where-Object environment_id -eq $e.id;Require ($view.complete -and $view.activity -eq 'RUNNING' -and $view.processes.Count -ge 2) 'GUI_CRASH_CLEANED_DISPOSABLE';Stop-Owned
   $r=Call @{action='LIST'};$view=$r.environments|Where-Object environment_id -eq $e.id;Require ($view.mode -eq 'DISPOSABLE' -and $view.disposable_pending -and $view.activity -eq 'IDLE') 'DISPOSABLE_LEFTOVER_NOT_VISIBLE'
   $r=Launch $script:registeredHost;Require ($r.state -eq 'REFUSED' -and $r.reason -eq 'DISPOSABLE_LEFTOVER_RESUME_EXPORT_OR_DELETE') $r.reason
   $null=Act 'RESUME';$r=Launch $script:registeredHost;Require ($r.state -in @('RUNNING_BOXED','PRIMARY_EXITED_BOXED')) $r.reason;Stop-Owned;$null=Act 'PERSISTENT'
   @{actual_background_descendants=2;cleanup_refused_until_entire_box_empty=$true;actual_manager_process_killed=$true;workloads_survived=$true;leftover_reopened_from_durable_metadata=$true;resume_explicit=$true;automatic_export_or_cleanup=$false}
  }
  Case 'T43' 'reset_invalidates_imported_executable_and_old_transfer_references' {
   $exe=Join-Path (Split-Path $script:active) 'securerun-launch-probe.exe';$q=@{action='IMPORT';environment_id=$e.id;expected_revision=$e.revision;operation_id=[Guid]::NewGuid().ToString();source=$exe;name='P08 imported Программа.exe'};$null=Call $q 'files';$w=Workspace;$entry=$w.entries|Where-Object name -eq 'P08 imported Программа.exe';Require ($null -ne $entry) 'BOXED_EXE_IMPORT_MISSING'
   $id=[Guid]::NewGuid().ToString();$output=Join-Path $Fixture 'boxed-before-reset.jsonl';$q=@{action='REGISTER';environment_id=$e.id;expected_revision=$e.revision;operation_id=$id;file_id=$entry.id;arguments=@('short',$output)};$r=Call $q 'files';Require ($r.application_id -eq $id) 'BOXED_REGISTER_FAILED'
   $c=Call @{action='LIST'} 'control';$boxed=$c.applications|Where-Object {$_.environment_id -eq $e.id -and $_.boxed};$receipt=Launch $boxed;Require ($receipt.state -in @('BOXED_STAGE_RUNNING','BOXED_STAGE_EXITED')) $receipt.reason
   $clock=[Diagnostics.Stopwatch]::StartNew();do{$reports=@(Get-ChildItem -LiteralPath $root -Recurse -File -Filter 'boxed-before-reset.jsonl');if($reports.Count -eq 1){break};Start-Sleep -Milliseconds 100}while($clock.ElapsedMilliseconds -lt 10000);Require ($reports.Count -eq 1 -and -not(Test-Path -LiteralPath $output)) 'BOXED_LOGICAL_LAUNCH_MISSING';Stop-Owned
   $generation=$e.generation;$null=Act 'RESET';$r=Call @{action='LIST'} 'control';$stale=$r.applications|Where-Object id -eq $boxed.id;Require (-not $stale.available -and $e.generation -eq ($generation+1)) 'RESET_BOXED_REFERENCE_STILL_AVAILABLE'
   $receipt=Launch $boxed;Require ($receipt.state -eq 'REFUSED' -and $receipt.reason -eq 'BOX_EXECUTABLE_GENERATION_CHANGED') $receipt.reason
   $destination=Join-Path ([Environment]::GetFolderPath('UserProfile')) 'SecureRun-P08-Output';$null=New-Item -ItemType Directory -Path $destination -Force
   $r=Call @{action='EXPORT';environment_id=$e.id;expected_revision=$e.revision;operation_id=[Guid]::NewGuid().ToString();file_id=$entry.id;destination=$destination;name='must-not-publish.exe'} 'files' $true
   Require ($r.reason -in @('FILE_REFERENCE_GENERATION_CHANGED','FILE_REFERENCE_NOT_FOUND')) $r.reason;Require (-not(Test-Path -LiteralPath (Join-Path $destination 'must-not-publish.exe'))) 'STALE_TRANSFER_PUBLISHED'
   @{actual_imported_executable_ran_logically_before_reset=$true;host_report_absent=$true;generation_advanced=$true;application_record_retained_unavailable=$true;old_boxed_launch_refused=$true;old_file_reference_refused=$true;physical_host_fallback=$false}
  }
  Case 'T18' 'current_automation_and_auto_delete_drift_block_cleanup_without_silent_repair' {
   $null=Import 'hooks-canary.txt';$box='SR_'+$e.id.Replace('-','');$lab.Register($box)
   foreach($pair in @(@('OnBoxDelete','C:\P08_UNAPPROVED_HOOK.exe'),@('AutoDelete','y'),@('AutoRecover','y'))){
    $lab.Set($box,$pair[0],$pair[1]);try{$r=Call @{action='PREPARE';environment_id=$e.id;expected_revision=$e.revision;expected_generation=$e.generation;operation_id=[Guid]::NewGuid().ToString();intent='RESET'} 'lifecycle' $true;Require ($r.reason -ne 'OBSERVED' -and $null -eq $r.plan) 'UNAPPROVED_LIFECYCLE_ACCEPTED';Require ($lab.Read($box,$pair[0],0x70000000) -eq $pair[1]) 'EXTERNAL_SETTING_SILENTLY_REPAIRED'}finally{$lab.Set($box,$pair[0],$(if($pair[0] -eq 'OnBoxDelete'){$null}else{'n'}))}
   }
   Require (@(Get-ChildItem -LiteralPath $root -Recurse -File -Filter 'hooks-canary.txt').Count -eq 1) 'HOOK_REFUSAL_DELETED_DATA'
   @{current_hook_rejected=$true;automatic_recovery_and_delete_drift_rejected=$true;unapproved_values_not_silently_removed=$true;data_retained=$true;host_hook_executed=$false}
  }
  Case 'T55' 'root_substitution_and_unsupported_image_configuration_never_authorize_cleanup' {
   $box='SR_'+$e.id.Replace('-','');$lab.Register($box);$backup=$root+'.p08-original';$replacement=$root+'.p08-replacement';Move-Item -LiteralPath $root -Destination $backup
   try{$null=New-Item -ItemType Directory -Path $root;[IO.File]::WriteAllText((Join-Path $root 'replacement-canary.txt'),'REPLACEMENT');$r=Call @{action='PREPARE';environment_id=$e.id;expected_revision=$e.revision;expected_generation=$e.generation;operation_id=[Guid]::NewGuid().ToString();intent='REMOVE'} 'lifecycle' $true;Require ($r.reason -in @('STOP_ROOT_CHANGED','ROOT_IDENTITY_CHANGED','CLEANUP_ROOT_CHANGED')) $r.reason;Require ([IO.File]::ReadAllText((Join-Path $root 'replacement-canary.txt')) -eq 'REPLACEMENT') 'REPLACEMENT_ROOT_MUTATED'}finally{if(Test-Path -LiteralPath $root){Move-Item -LiteralPath $root -Destination $replacement};Move-Item -LiteralPath $backup -Destination $root}
   $lab.LifecycleSetting($box,'UseFileImage','y');try{$r=Call @{action='PREPARE';environment_id=$e.id;expected_revision=$e.revision;expected_generation=$e.generation;operation_id=[Guid]::NewGuid().ToString();intent='RESET'} 'lifecycle' $true;Require ($r.reason -ne 'OBSERVED') 'IMAGE_CONFIGURATION_ACCEPTED'}finally{$lab.LifecycleSetting($box,'UseFileImage','n')}
   @{unexpected_root_identity_refused=$true;replacement_canary_preserved=$true;original_identity_restored_by_fixture_only=$true;unsupported_images_refused=$true;no_root_rebinding_or_deletion_by_path=$true}
  }
  Case 'T24' 'hardlinks_and_reparse_traversal_rejected_before_native_dispatch' {
   $outside=Join-Path $Fixture 'outside-cleanup';$null=New-Item -ItemType Directory -Path $outside;[IO.File]::WriteAllText((Join-Path $outside 'keep.txt'),'OUTSIDE_CANARY');$before=(Get-FileHash (Join-Path $outside 'keep.txt')).Hash
   $alias=Join-Path $root 'hardlink.txt';$null=New-Item -ItemType HardLink -Path $alias -Target (Join-Path $outside 'keep.txt')
   $p=Prepare 'RESET';try{$r=Commit $p $true;Require ($r.reason -eq 'CLEANUP_HARDLINK_REJECTED') $r.reason}finally{Remove-Item -LiteralPath $alias};$null=Call @{action='RECOVER';operation_id=$p.operation_id}
   $junction=Join-Path $root 'junction';$null=New-Item -ItemType Directory -Path $junction;[P02StorageSeal]::MakeJunction($junction,$outside,0x100)
   $p=Prepare 'RESET';try{$r=Commit $p $true;Require ($r.reason -in @('CLEANUP_REPARSE_REJECTED','REPARSE_OR_HARDLINK_REJECTED')) $r.reason}finally{[IO.Directory]::Delete($junction)};$null=Call @{action='RECOVER';operation_id=$p.operation_id}
   Require ((Get-FileHash (Join-Path $outside 'keep.txt')).Hash -eq $before) 'OUTSIDE_CLEANUP_CANARY_CHANGED'
   @{hardlink_rejected_before_dispatch=$true;reparse_rejected_before_dispatch=$true;outside_canary_preserved=$true;generic_recursive_cleanup=$false}
  }
  Case 'T28' 'missing_ownership_database_cannot_adopt_or_remove_existing_box' {
   $path=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'SecureRun/metadata/policy.sqlite';$saved=Join-Path $Fixture 'original-policy.sqlite';$empty=Join-Path $Fixture 'new-empty-policy.sqlite';Move-Item -LiteralPath $path -Destination $saved
   try{$r=Call @{action='LIST'};Require ($r.environments.Count -eq 0) 'MISSING_METADATA_ADOPTED_ENGINE_BOX';$r=Call @{action='PREPARE';environment_id=$e.id;expected_revision=$e.revision;expected_generation=$e.generation;operation_id=[Guid]::NewGuid().ToString();intent='REMOVE'} 'lifecycle' $true;Require ($r.reason -eq 'OWNERSHIP_NOT_FOUND') $r.reason}finally{if(Test-Path -LiteralPath $path){Move-Item -LiteralPath $path -Destination $empty};Move-Item -LiteralPath $saved -Destination $path}
   Refresh-Environment;Require ($e.stage -eq 'VERIFIED') 'EXACT_METADATA_RESTORE_FAILED'
   @{fresh_process_reopened_sqlite=$true;existing_engine_box_not_adopted=$true;remove_without_ownership_refused=$true;original_database_not_overwritten=$true;data_preserved=$true}
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
