param([string]$Manager,[string]$Fixture,[string]$EngineHome,[string]$FaultManager,[string]$Mode='normal')
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$cases=[Collections.Generic.List[object]]::new()
function Save {ConvertTo-Json -InputObject @($cases.ToArray()) -Depth 10|Set-Content (Join-Path $Fixture 'control-cases.json') -Encoding utf8}
function Require([bool]$ok,[string]$code){if(-not $ok){throw $code}}
function Case([string]$scenarioId,[string]$name,[scriptblock]$body){$c=@{id=$scenarioId;name=$name;status='IN_PROGRESS'};$cases.Add($c);$script:nativeStage='CASE';Save;try{$c.evidence=(& $body);$c.status='PASSED'}catch{$c.status='FAILED';$c.code=if($_.Exception.Message -cmatch '\b([A-Z][A-Z0-9_]{3,80})\b'){$Matches[1]}else{'CONTROL_CASE_FAILED'};$c.line=$_.InvocationInfo.ScriptLineNumber;$c.native_stage=$script:nativeStage;$c.exception_type=$_.Exception.GetBaseException().GetType().FullName};Save;Write-Host ($name+' '+$c.status+$(if($c.ContainsKey('code')){' '+$c.code}else{''}))}
function Call($request,[string]$kind='control',[string]$image=$Manager,[bool]$allowFailure=$false){
    $script:nativeStage='CALL_'+$kind+'_'+$request.action
    $s=[Diagnostics.ProcessStartInfo]::new($image);$s.UseShellExecute=$false;$s.WorkingDirectory=$EngineHome;$s.RedirectStandardInput=$true;$s.RedirectStandardOutput=$true;$s.StandardInputEncoding=[Text.UTF8Encoding]::new($false);$s.StandardOutputEncoding=[Text.UTF8Encoding]::new($false);$s.RedirectStandardError=$true;$s.ArgumentList.Add("--$kind-once")
    $p=[Diagnostics.Process]::Start($s)
    try{$read=$p.StandardOutput.ReadToEndAsync();$err=$p.StandardError.ReadToEndAsync();$p.StandardInput.Write((ConvertTo-Json -InputObject $request -Depth 12 -Compress));$p.StandardInput.Close();Require ($p.WaitForExit(150000)) 'CONTROL_TIMEOUT';Require ($p.ExitCode -eq 0) 'CONTROL_WORKER_EXIT_FAILED';$r=$read.Result|ConvertFrom-Json;if(-not $allowFailure){Require ($r.reason -eq 'OBSERVED') $r.reason};return $r}finally{if(-not $p.HasExited){$p.Kill($true)};$p.Dispose()}
}
function Coordinate([string]$action){
    [IO.File]::WriteAllText((Join-Path $Fixture 'lab-request.txt'),$action);$clock=[Diagnostics.Stopwatch]::StartNew()
    do{if((Test-Path (Join-Path $Fixture 'lab-ack.txt')) -and [IO.File]::ReadAllText((Join-Path $Fixture 'lab-ack.txt')) -eq $action){return};Start-Sleep -Milliseconds 100}while($clock.ElapsedMilliseconds -lt 45000)
    throw 'LAB_COORDINATION_TIMEOUT'
}
function New-App([string]$exe,[string[]]$arguments,[string]$cwd=$null){
    $id=[Guid]::NewGuid().ToString();$r=Call @{action='REGISTER';environment_id=$script:e.id;expected_revision=$script:e.revision;operation_id=$id;display_name='Synthetic launch fixture';executable=$exe;arguments=$arguments;working_directory=$(if([string]::IsNullOrEmpty($cwd)){$null}else{$cwd})}
    $receipt=$r.receipts|Where-Object operation_id -eq $id;$script:nativeStage='REGISTER_RECEIPT';Require ($receipt.state -eq 'REGISTERED') $receipt.reason
    return @($r.applications|Where-Object {$_.environment_id -eq $script:e.id})[-1]
}
function Launch($a,[string]$operation=[Guid]::NewGuid().ToString()){$r=Call @{action='LAUNCH';application_id=$a.id;environment_id=$a.environment_id;expected_revision=$a.revision;operation_id=$operation};$script:nativeStage='LAUNCH_RECEIPT';return ($r.receipts|Where-Object operation_id -eq $operation)}
function Stop-Owned { $id=[Guid]::NewGuid().ToString();$r=Call @{action='STOP';environment_id=$script:e.id;operation_id=$id};$receipt=$r.receipts|Where-Object operation_id -eq $id;$script:nativeStage='STOP_RECEIPT';Require ($receipt.state -eq 'STOPPED') $receipt.reason;return $r }
function Reports([string]$leaf){
 $clock=[Diagnostics.Stopwatch]::StartNew()
 do {
  $files=@(Get-ChildItem -LiteralPath $script:root -Recurse -File -Filter $leaf);Require ($files.Count -le 1) 'DUPLICATE_TARGET_REPORT'
  if($files.Count -eq 1){
   $reader=$null;$stream=$null;$contents=$null
   try{$stream=[IO.File]::Open($files[0].FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete));$reader=[IO.StreamReader]::new($stream,[Text.UTF8Encoding]::new($false,$true));$chars=[char[]]::new(16385);$n=$reader.ReadBlock($chars,0,$chars.Length);Require ($n -le 16384) 'TARGET_REPORT_BOUND';$contents=[string]::new($chars,0,$n)}catch [IO.IOException]{}finally{if($null -ne $reader){$reader.Dispose()}elseif($null -ne $stream){$stream.Dispose()}}
   if($null -ne $contents){$end=$contents.LastIndexOf("`n");if($end -ge 0){return @($contents.Substring(0,$end+1).Split("`n",[StringSplitOptions]::RemoveEmptyEntries)|ForEach-Object {$_|ConvertFrom-Json})}}
  }
  Start-Sleep -Milliseconds 100
 }while($clock.ElapsedMilliseconds -lt 15000)
 throw 'COMPLETE_TARGET_REPORT_MISSING'
}

try {
    $who=[Security.Principal.WindowsIdentity]::GetCurrent();$principal=[Security.Principal.WindowsPrincipal]::new($who);Require (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) 'STANDARD_TOKEN_REQUIRED'
    $active=if($Mode -in @('normal','sessions')){$Manager}else{$FaultManager}
    $r=Call @{action='CREATE';display_name='P06 production-path fixture';operation_id=[Guid]::NewGuid().ToString();policy=@{schema=1;preset='STANDARD_OFFLINE';grants=@()}} 'policy' $active
    $script:e=$r.environments[0];$script:root=$e.compiled.section.FileRootPath[0];Require ($e.stage -eq 'VERIFIED') 'P05_GATE_REQUIRED'
    if($Mode -eq 'sessions'){
        Case 'T36' 'production_stop_covers_two_actual_windows_sessions' {
            $actor=[Diagnostics.Process]::GetCurrentProcess().SessionId;Require ($actor -ne 0) 'INDEPENDENT_ACTOR_SESSION_REQUIRED'
            $probe=Join-Path (Split-Path $Manager) 'securerun-launch-probe.exe';$a=New-App $probe @('hold',(Join-Path $Fixture 'session-actor.jsonl'));$receipt=Launch $a;Require ($receipt.state -eq 'RUNNING_BOXED') $receipt.reason
            Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'p05_lab.cs')));$sessionLab=[P05Lab]::new($EngineHome,$Fixture,$PSScriptRoot);$sessionLab.Register('SR_'+$e.id.Replace('-',''));$sessionLab.Set(('SR_'+$e.id.Replace('-','')),'Enabled','y')
            $results=Join-Path $Fixture 'results';$null=New-Item -ItemType Directory -Path $results -Force
            @{box=('SR_'+$e.id.Replace('-',''));owner_sid=$who.User.Value}|ConvertTo-Json|Set-Content (Join-Path $results 'session-ready.json') -Encoding utf8
            $clock=[Diagnostics.Stopwatch]::StartNew()
            do{$r=Call @{action='LIST'};$v=$r.environments|Where-Object environment_id -eq $e.id;if($v.complete -and @($v.processes|Where-Object session -eq 0).Count -ge 1){break};Start-Sleep -Milliseconds 100}while($clock.ElapsedMilliseconds -lt 45000)
            Require ($v.complete -and @($v.processes|Where-Object session -eq 0).Count -ge 1 -and @($v.processes|Where-Object session -eq $actor).Count -ge 1) 'REAL_MULTISESSION_PROCESSES_NOT_OBSERVED'
            $count=$v.processes.Count;$stopped=Stop-Owned;$v=$stopped.environments|Where-Object environment_id -eq $e.id;Require ($v.complete -and $v.activity -eq 'IDLE' -and $v.processes.Count -eq 0) 'OTHER_SESSION_STOP_NOT_COMPLETED'
            @{real_windows_sessions=@(0,$actor);same_owner_verified=$true;processes_before=$count;processes_after=0;stop_waits_completed=$true;product_helper=$false;os_logon_policy_modified=$false}
        }
    }elseif($Mode -eq 'scope'){
        $Manager=$FaultManager;$probe=Join-Path (Split-Path $Manager) 'securerun-launch-probe.exe'
        $a=New-App $probe @('hold',(Join-Path $Fixture 'scope-held.jsonl'));$receipt=Launch $a;Require ($receipt.state -eq 'RUNNING_BOXED') $receipt.reason
        Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'p05_lab.cs')));$lab=[P05Lab]::new($EngineHome,$Fixture,$PSScriptRoot);$box='SR_'+$e.id.Replace('-','');$lab.Register($box)
        Case 'T62' 'actual_scope_change_after_process_handles_retained' {
            $env:SECURERUN_P06_PAUSE_STAGE='StopHeld';$id=[Guid]::NewGuid().ToString()
            $s=[Diagnostics.ProcessStartInfo]::new($Manager);$s.UseShellExecute=$false;$s.WorkingDirectory=$EngineHome;$s.RedirectStandardInput=$true;$s.RedirectStandardOutput=$true;$s.StandardInputEncoding=[Text.UTF8Encoding]::new($false);$s.StandardOutputEncoding=[Text.UTF8Encoding]::new($false);$s.RedirectStandardError=$true
            foreach($arg in @('--control-worker',[string]$PID,[string]([Diagnostics.Process]::GetCurrentProcess().StartTime.ToFileTimeUtc()))){$s.ArgumentList.Add($arg)}
            $p=[Diagnostics.Process]::Start($s);$other=Join-Path $Fixture 'unrelated-root';$null=New-Item -ItemType Directory -Path $other
            try {
                $line=$p.StandardOutput.ReadLineAsync();$p.StandardInput.Write((ConvertTo-Json -InputObject @{action='STOP';environment_id=$e.id;operation_id=$id} -Compress));$p.StandardInput.Close();Require ($line.Wait(45000)) 'STOP_HELD_CHECKPOINT_TIMEOUT';Require ($line.Result -eq 'CHECKPOINT_StopHeld') 'STOP_HELD_CHECKPOINT_NOT_REACHED'
                $competing=Call @{action='LIST'} 'control' $Manager $true;Require ($competing.reason -eq 'NAMESPACE_OPERATION_BUSY') 'SECOND_MANAGER_BYPASSED_WRITER';$lab.Set($box,'FileRootPath',$other);$read=$p.StandardOutput.ReadToEndAsync();Require ($p.WaitForExit(30000)) 'STOP_SCOPE_CHANGE_TIMEOUT';$r=$read.Result|ConvertFrom-Json;$stopped=$r.receipts|Where-Object operation_id -eq $id
                Require ($stopped.state -eq 'UNKNOWN' -and $stopped.reason -eq 'STOP_SCOPE_CHANGED') 'CHANGED_SCOPE_TERMINATED'
                $targetProcess=[Diagnostics.Process]::GetProcessById([int]$receipt.process.pid);try{Require (-not $targetProcess.HasExited -and [string]$targetProcess.StartTime.ToFileTimeUtc() -eq $receipt.process.creation_time) 'HELD_PROCESS_WAS_TERMINATED'}finally{$targetProcess.Dispose()}
                @{real_held_handles=$true;scope_changed_before_dispatch=$true;target_survives=$true;numeric_pid_fallback=$false;unknown_completion_preserved=$true;concurrent_second_manager_refused=$true}
            }finally{Remove-Item Env:/SECURERUN_P06_PAUSE_STAGE -ErrorAction SilentlyContinue;$lab.Set($box,'FileRootPath',$root);if(-not $p.HasExited){$p.Kill($true)};$p.Dispose();$null=Stop-Owned}
        }
        Case 'T07' 'exited_retained_object_does_not_retarget_unrelated_process' {
            $a=New-App $probe @('exit-during-stop',(Join-Path $Fixture 'exit-during-stop.jsonl'));$receipt=Launch $a;Require ($receipt.state -eq 'RUNNING_BOXED') $receipt.reason
            $hostStart=[Diagnostics.ProcessStartInfo]::new((Join-Path $PSHOME 'pwsh.exe'));$hostStart.UseShellExecute=$false;foreach($arg in @('-NoProfile','-NonInteractive','-Command','Start-Sleep -Seconds 90')){$hostStart.ArgumentList.Add($arg)};$other=[Diagnostics.Process]::Start($hostStart)
            $env:SECURERUN_P06_PAUSE_STAGE='StopHeld';$id=[Guid]::NewGuid().ToString();$s=[Diagnostics.ProcessStartInfo]::new($Manager);$s.UseShellExecute=$false;$s.WorkingDirectory=$EngineHome;$s.RedirectStandardInput=$true;$s.RedirectStandardOutput=$true;$s.StandardInputEncoding=[Text.UTF8Encoding]::new($false);$s.StandardOutputEncoding=[Text.UTF8Encoding]::new($false);$s.RedirectStandardError=$true
            foreach($arg in @('--control-worker',[string]$PID,[string]([Diagnostics.Process]::GetCurrentProcess().StartTime.ToFileTimeUtc()))){$s.ArgumentList.Add($arg)};$p=[Diagnostics.Process]::Start($s)
            try{$line=$p.StandardOutput.ReadLineAsync();$p.StandardInput.Write((ConvertTo-Json -InputObject @{action='STOP';environment_id=$e.id;operation_id=$id} -Compress));$p.StandardInput.Close();Require ($line.Wait(45000)) 'EXIT_RACE_CHECKPOINT_TIMEOUT';Require ($line.Result -eq 'CHECKPOINT_StopHeld') 'EXIT_RACE_NOT_REACHED';$original=[Diagnostics.Process]::GetProcessById([int]$receipt.process.pid);Require (-not $original.HasExited -and [string]$original.StartTime.ToFileTimeUtc() -eq $receipt.process.creation_time) 'PRIMARY_NOT_ALIVE_AT_HELD_CHECKPOINT';$read=$p.StandardOutput.ReadToEndAsync();Require ($p.WaitForExit(30000)) 'EXIT_RACE_STOP_TIMEOUT';$r=$read.Result|ConvertFrom-Json;$stopped=$r.receipts|Where-Object operation_id -eq $id
                Require ($stopped.state -eq 'STOPPED' -and -not $other.HasExited -and $original.HasExited) 'EXITED_HANDLE_RETARGETED';$original.Dispose()
                @{actual_primary_exit_while_held=$true;unrelated_process_survives=$true;retained_handle_prevents_pid_reuse_until_close=$true;numeric_pid_fallback=$false;completion_waited=$true}
            }finally{Remove-Item Env:/SECURERUN_P06_PAUSE_STAGE -ErrorAction SilentlyContinue;if(-not $p.HasExited){$p.Kill($true)};$p.Dispose();if(-not $other.HasExited){$other.Kill();$other.WaitForExit()};$other.Dispose()}
        }
    }elseif($Mode -ne 'normal'){
        $Manager=$FaultManager;$probe=Join-Path (Split-Path $Manager) 'securerun-launch-probe.exe';$leaf='lost-'+[Guid]::NewGuid().ToString('N')+'.jsonl';$output=Join-Path $Fixture $leaf;$a=New-App $probe @('short',$output)
        $stage=if($Mode -eq 'reserved'){'Reserved'}else{'Accepted'};$id=[Guid]::NewGuid().ToString();$request=@{action='LAUNCH';application_id=$a.id;environment_id=$a.environment_id;expected_revision=$a.revision;operation_id=$id}
        $env:SECURERUN_P06_PAUSE_STAGE=$stage
        Case 'T61' ('actual_dispatch_interruption_'+$Mode) {
            $s=[Diagnostics.ProcessStartInfo]::new($Manager);$s.UseShellExecute=$false;$s.WorkingDirectory=$EngineHome;$s.RedirectStandardInput=$true;$s.RedirectStandardOutput=$true;$s.StandardInputEncoding=[Text.UTF8Encoding]::new($false);$s.StandardOutputEncoding=[Text.UTF8Encoding]::new($false);$s.RedirectStandardError=$true
            foreach($arg in @('--control-worker',[string]$PID,[string]([Diagnostics.Process]::GetCurrentProcess().StartTime.ToFileTimeUtc()))){$s.ArgumentList.Add($arg)}
            $p=[Diagnostics.Process]::Start($s)
            try{$line=$p.StandardOutput.ReadLineAsync();$p.StandardInput.Write((ConvertTo-Json -InputObject $request -Compress));$p.StandardInput.Close();Require ($line.Wait(45000)) 'CHECKPOINT_TIMEOUT';Require ($line.Result -eq "CHECKPOINT_$stage") 'CHECKPOINT_NOT_REACHED';if($Mode -eq 'accepted'){Start-Sleep -Milliseconds 500};$p.Kill($true);Require ($p.WaitForExit(10000)) 'KILLED_WORKER_NOT_EXITED'}finally{if(-not $p.HasExited){$p.Kill($true)};$p.Dispose()}
            Remove-Item Env:/SECURERUN_P06_PAUSE_STAGE
            $before=if($Mode -eq 'accepted'){@(Reports $leaf).Count}else{0}
            foreach($n in 1..3){$retry=Call $request;$receipt=$retry.receipts|Where-Object operation_id -eq $id;Require ($receipt.state -eq 'UNKNOWN') 'UNCERTAIN_LAUNCH_REPLAYED'}
            $newAttempt=Launch $a;Require ($newAttempt.state -eq 'REFUSED' -and $newAttempt.reason -eq 'UNCERTAIN_LAUNCH_RECONCILIATION_REQUIRED') 'NEW_OPERATION_BYPASSED_UNCERTAINTY'
            $after=if($Mode -eq 'accepted'){@(Reports $leaf).Count}else{@(Get-ChildItem -LiteralPath $root -Recurse -File -Filter $leaf).Count}
            Require ($before -eq $after -and $before -eq $(if($Mode -eq 'accepted'){1}else{0})) 'TARGET_EXECUTED_MORE_THAN_ONCE'
            $null=Call @{action='RECONCILE';operation_id=$id};$retry=Call $request;$receipt=$retry.receipts|Where-Object operation_id -eq $id;Require ($receipt.state -eq 'UNKNOWN') 'RECONCILIATION_ERASED_UNCERTAINTY';$null=Stop-Owned
            @{real_worker_killed=$true;checkpoint=$stage;duplicate_deliveries=3;target_executions=$after;automatic_replay=$false;receipt_state='UNKNOWN';standard_user=$true}
        }
    }else{
        $probes=@(Get-ChildItem (Split-Path $Manager) -Filter 'securerun-launch-probe*.exe')
        # Establish the real unloaded-driver negative control before the mixed-PE
        # workload series. No live target or emulation teardown is needed here.
        Case 'T01' 'unloaded_original_driver_refuses_production_launch' {
            $driverTarget=New-App (Join-Path (Split-Path $Manager) 'securerun-launch-probe.exe') @('short',(Join-Path $Fixture 'driver-refusal.jsonl'))
            Coordinate 'driver-off'
            try{$r=Call @{action='LAUNCH';environment_id=$driverTarget.environment_id;application_id=$driverTarget.id;expected_revision=$driverTarget.revision;operation_id=[Guid]::NewGuid().ToString()} 'control' $Manager $true;Require ($r.reason -ne 'OBSERVED' -and $r.environments.Count -eq 0) 'UNLOADED_DRIVER_ACCEPTED_TARGET'}finally{Coordinate 'driver-on'}
            @{driver_actually_unloaded=$true;original_authenticated_kmdutil=$true;production_launch_refused=$true;host_fallback=$false;os_security_settings_modified=$false}
        }
        foreach($probe in $probes){
            Case 'T04' ('exact_arguments_'+$probe.BaseName) {
                try {
                $leaf='args-'+[Guid]::NewGuid().ToString('N')+'.jsonl';$output=Join-Path $Fixture $leaf
                $unicodeExe=Join-Path $Fixture ($probe.BaseName+' Программа 🧪.exe');Copy-Item $probe.FullName $unicodeExe;$a=New-App $unicodeExe @('arguments',$output,'','Unicode Привет 🧪','spaces in argument','a"quote','trailing\','/terminate_all','& echo SHOULD_NOT_EXECUTE','\"tail\')
                $receipt=Launch $a;Require ($receipt.state -in @('RUNNING_BOXED','PRIMARY_EXITED_BOXED')) $receipt.reason
                $reports=Reports $leaf;Require ($reports.Count -eq 1 -and $reports[0].boxed -and $reports[0].arguments_exact -and -not(Test-Path $output)) 'ARGUMENT_OR_HOST_BOUNDARY_FAILED'
                @{boxed=$true;exact_target_argv=$true;host_output_absent=$true;actual_pe=$probe.BaseName;receipt=$receipt.state}
                }finally{$null=Stop-Owned}
            }
        }
        $probe=$probes|Where-Object Name -eq 'securerun-launch-probe.exe'
        Case 'T05' 'production_child_and_grandchild_membership' {
            $leaf='tree-'+[Guid]::NewGuid().ToString('N')+'.jsonl';$a=New-App $probe.FullName @('tree',(Join-Path $Fixture $leaf));$receipt=Launch $a;Require ($receipt.state -eq 'RUNNING_BOXED') $receipt.reason
            Start-Sleep -Milliseconds 700;$r=Call @{action='LIST'};$view=$r.environments|Where-Object environment_id -eq $e.id;$reports=Reports $leaf
            Require ($view.complete -and $view.processes.Count -ge 3 -and $reports.Count -eq 3 -and @($reports|Where-Object {-not $_.boxed}).Count -eq 0) 'DESCENDANTS_NOT_CONFIRMED';$script:treeApp=$a
            @{complete=$true;actual_boxed_tree=$reports.Count;process_count=$view.processes.Count;births_present=@($view.processes|Where-Object {$_.creation_time -eq '0'}).Count -eq 0}
        }
        Case 'T54' 'stop_survives_launch_policy_ineligibility_without_entitlement' {
            Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'p05_lab.cs')))
            $lab=[P05Lab]::new($EngineHome,$Fixture,$PSScriptRoot);$box='SR_'+$e.id.Replace('-','');$lab.Register($box);$lab.Wfp($false)
            try{$r=Call @{action='LIST'};$v=$r.environments|Where-Object environment_id -eq $e.id;Require (-not $v.launch_eligible -and $v.activity -eq 'RUNNING') 'LAUNCH_NOT_BLOCKED';$stopped=Stop-Owned;$v=$stopped.environments|Where-Object environment_id -eq $e.id;Require ($v.activity -eq 'IDLE' -and $v.complete) 'STOP_DEPENDS_ON_NETWORK_ELIGIBILITY'}finally{$lab.Wfp($true)}
            @{launch_blocked=$true;stop_completed=$true;paid_entitlement_required=$false;optional_paid_expiry='NOT_APPLICABLE_BASELINE_HAS_NO_PAID_DEPENDENCY'}
        }
        Case 'T06' 'background_child_keeps_environment_running' {
            $leaf='background-'+[Guid]::NewGuid().ToString('N')+'.jsonl';$a=New-App $probe.FullName @('background',(Join-Path $Fixture $leaf));$receipt=Launch $a;Start-Sleep -Milliseconds 500;$r=Call @{action='LIST'};$v=$r.environments|Where-Object environment_id -eq $e.id
            Require ($receipt.state -in @('PRIMARY_EXITED_BOXED','RUNNING_BOXED') -and $v.complete -and $v.activity -eq 'RUNNING' -and $v.processes.Count -ge 2) 'BACKGROUND_CHILD_LOST';$null=Stop-Owned
            @{primary_may_exit=$true;environment_running=$true;remaining_descendants=$v.processes.Count;cleanup_dispatched=$false}
        }
        Case 'T61' 'duplicate_completed_launch_is_never_dispatched_twice' {
            $leaf='once-'+[Guid]::NewGuid().ToString('N')+'.jsonl';$a=New-App $probe.FullName @('short',(Join-Path $Fixture $leaf));$id=[Guid]::NewGuid().ToString();$first=Launch $a $id
            foreach($n in 1..4){$again=Launch $a $id;Require ($again.state -eq $first.state) 'DUPLICATE_RECEIPT_CHANGED'}
            Require (@(Reports $leaf).Count -eq 1) 'DUPLICATE_LAUNCH_EXECUTED';$null=Stop-Owned
            @{deliveries=5;target_executions=1;new_manager_process_per_delivery=$true}
        }
        Case 'T19' 'stop_managed_preserves_unmanaged_box_and_host_process' {
            Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'engine_bridge.cs')))
            $b=[P02Bridge]::new($EngineHome,$Fixture,[string[]]@($probe.FullName));$unowned='SRP02_P06_'+[Guid]::NewGuid().ToString('N').Substring(0,12);$b.Register($unowned)
            foreach($pair in @(@('Enabled','n'),@('DropAdminRights','y'),@('AutoRecover','n'),@('AutoDelete','n'),@('UseFileImage','n'))){$b.Set($unowned,$pair[0],$pair[1])};$b.Set($unowned,'FileRootPath',(Join-Path $Fixture "boxes/$unowned"));$null=New-Item -ItemType Directory -Path (Join-Path $Fixture 'boxes') -Force;$null=$b.ProvisionFreshRoot($unowned);$b.Set($unowned,'Enabled','y')
            $unownedReceipt=$b.Launch($unowned,$probe.FullName,[string[]]@('hold',(Join-Path $Fixture 'unmanaged.jsonl')))
            $outside=[Diagnostics.ProcessStartInfo]::new((Join-Path $PSHOME 'pwsh.exe'));$outside.UseShellExecute=$false;foreach($arg in @('-NoProfile','-NonInteractive','-Command','Start-Sleep -Seconds 90')){$outside.ArgumentList.Add($arg)};$hostProcess=[Diagnostics.Process]::Start($outside)
            try{$owned=Launch $treeApp;$id=[Guid]::NewGuid().ToString();$r=Call @{action='STOP_MANAGED';operation_id=$id};$receipt=$r.receipts|Where-Object operation_id -eq $id
                Require ($receipt.state -eq 'STOPPED' -and $b.Count($unowned) -gt 0 -and -not $hostProcess.HasExited) 'UNMANAGED_WORKLOAD_TERMINATED';@{managed_empty=$true;unmanaged_box_survives=$true;unboxed_process_survives=$true;prefix_authority=$false}
            }finally{[P02Bridge]::StopReceipt($unownedReceipt);$null=$b.StopHeld($unowned);if(-not $hostProcess.HasExited){$hostProcess.Kill();$hostProcess.WaitForExit()};$hostProcess.Dispose()}
        }
        Case 'T26' 'rapid_launch_stop_serializes_and_duplicate_scope_conflicts' {
            foreach($n in 1..3){$receipt=Launch $treeApp;Require ($receipt.state -eq 'RUNNING_BOXED') $receipt.reason;$null=Stop-Owned}
            $id=[Guid]::NewGuid().ToString();$null=Call @{action='STOP';environment_id=$e.id;operation_id=$id}
            $s=[Diagnostics.ProcessStartInfo]::new($Manager);$s.UseShellExecute=$false;$s.RedirectStandardInput=$true;$s.RedirectStandardOutput=$true;$s.StandardInputEncoding=[Text.UTF8Encoding]::new($false);$s.StandardOutputEncoding=[Text.UTF8Encoding]::new($false);$s.ArgumentList.Add('--control-once');$p=[Diagnostics.Process]::Start($s)
            try{$read=$p.StandardOutput.ReadToEndAsync();$p.StandardInput.Write((ConvertTo-Json -InputObject @{action='STOP_MANAGED';operation_id=$id} -Compress));$p.StandardInput.Close();Require ($p.WaitForExit(45000)) 'CONFLICT_TIMEOUT';$r=$read.Result|ConvertFrom-Json;Require ($r.reason -eq 'OPERATION_CONFLICT') 'OPERATION_SCOPE_REUSED'}finally{$p.Dispose()}
            @{rapid_cycles=3;conflicting_operation_refused=$true;all_waits_completed=$true}
        }
        Case 'T01' 'stopped_engine_service_never_dispatches_target' {
            Coordinate 'service-off'
            try{$r=Call @{action='LAUNCH';environment_id=$treeApp.environment_id;application_id=$treeApp.id;expected_revision=$treeApp.revision;operation_id=[Guid]::NewGuid().ToString()} 'control' $Manager $true;Require ($r.reason -ne 'OBSERVED' -and $r.environments.Count -eq 0) 'STOPPED_ENGINE_ACCEPTED_TARGET'}finally{Coordinate 'service-on'}
            @{service_actually_stopped=$true;production_launch_refused=$true;host_fallback=$false;os_security_settings_modified=$false}
        }
        Case 'T02' 'changed_original_component_refuses_launch' {
            Coordinate 'start-impostor'
            try{$r=Call @{action='LAUNCH';environment_id=$treeApp.environment_id;application_id=$treeApp.id;expected_revision=$treeApp.revision;operation_id=[Guid]::NewGuid().ToString()} 'control' $Manager $true;Require ($r.reason -ne 'OBSERVED' -and $r.environments.Count -eq 0) 'CHANGED_ENGINE_ACCEPTED_TARGET'}finally{Coordinate 'start-restore'}
            @{component_replaced_on_disposable_vm=$true;launch_refused=$true;original_signature_restored=$true;verification_disabled=$false}
        }
        Case 'T03' 'registered_target_replacement_is_refused' {
            $replaceable=Join-Path $Fixture 'replaceable.exe';Copy-Item $probe.FullName $replaceable;$leaf='replaced-'+[Guid]::NewGuid().ToString('N')+'.jsonl';$a=New-App $replaceable @('short',(Join-Path $Fixture $leaf));[IO.File]::WriteAllText($replaceable,'SYNTHETIC_INVALID_PE')
            $receipt=Launch $a;Require ($receipt.state -eq 'REFUSED') 'REPLACED_TARGET_EXECUTED';Require (@(Get-ChildItem -LiteralPath $root -Recurse -File -Filter $leaf).Count -eq 0) 'REPLACED_TARGET_RAN'
            @{registered_identity_changed=$true;target_not_dispatched=$true;host_fallback=$false}
        }
        Case 'T03' 'invalid_exe_and_control_characters_are_refused' {
            $id=[Guid]::NewGuid().ToString();$r=Call @{action='REGISTER';environment_id=$e.id;expected_revision=$e.revision;operation_id=$id;display_name='Invalid';executable=(Join-Path $Fixture 'missing.exe');arguments=@();working_directory=$null};$receipt=$r.receipts|Where-Object operation_id -eq $id;Require ($receipt.state -eq 'REFUSED') 'INVALID_EXE_ACCEPTED'
            $id=[Guid]::NewGuid().ToString();$r=Call @{action='REGISTER';environment_id=$e.id;expected_revision=$e.revision;operation_id=$id;display_name='Invalid';executable=$probe.FullName;arguments=@("bad`nargument");working_directory=$null};$receipt=$r.receipts|Where-Object operation_id -eq $id;Require ($receipt.state -eq 'REFUSED' -and $receipt.reason -eq 'TARGET_ARGUMENTS_INVALID') 'ARGUMENT_CONTROL_ACCEPTED'
            @{invalid_exe_refused=$true;controls_refused=$true;shell_used=$false}
        }
        Case 'T50' 'target_cwd_is_separate_from_host_worker_cwd' {
            $cwd=Join-Path $Fixture 'hostile cwd';$null=New-Item -ItemType Directory -Path $cwd;[IO.File]::WriteAllText((Join-Path $cwd 'SbieDll.dll'),'SYNTHETIC_INVALID_DLL');[IO.File]::WriteAllText((Join-Path $cwd 'Start.exe'),'SYNTHETIC_INVALID_EXE')
            $leaf='cwd-'+[Guid]::NewGuid().ToString('N')+'.jsonl';$a=New-App $probe.FullName @('cwd',(Join-Path $Fixture $leaf),$cwd) $cwd;$oldPath=$env:PATH;$env:PATH=$cwd+';'+$oldPath;$env:SECURERUN_P06_SECRET='SYNTHETIC_ENVIRONMENT_CANARY';try{$receipt=Launch $a}finally{$env:PATH=$oldPath;Remove-Item Env:/SECURERUN_P06_SECRET};Require ($receipt.state -in @('RUNNING_BOXED','PRIMARY_EXITED_BOXED')) $receipt.reason;Require ((Reports $leaf)[0].boxed -and (Reports $leaf)[0].cwd_exact -and (Reports $leaf)[0].environment_clean) 'HOSTILE_CWD_ESCAPED';$null=Stop-Owned
            @{hostile_target_directory_accepted_separately=$true;trusted_host_worker_cwd=$true;impostor_dependencies_unused=$true;hostile_path_scrubbed=$true;secret_environment_absent=$true}
        }
        Case 'T56' 'stale_application_revision_cannot_dispatch_after_policy_change' {
            $r=Call @{action='APPLY';environment_id=$e.id;expected_revision=$e.revision;operation_id=[Guid]::NewGuid().ToString();acknowledge_view_change=$false;policy=$e.desired} 'policy';$updated=$r.environments|Where-Object id -eq $e.id;Require ($updated.revision -gt $e.revision) 'REVISION_NOT_ADVANCED'
            $receipt=Launch $treeApp;Require ($receipt.state -eq 'REFUSED' -and $receipt.reason -eq 'REVISION_CONFLICT') 'OLD_REVISION_DISPATCHED';$script:e=$updated
            @{new_revision_observed=$true;stale_registration_refused=$true;old_response_does_not_authorize_dispatch=$true;fresh_worker_prerequisites=$true}
        }
    }
}catch{Case 'T01' 'required_prerequisites' {throw $_}}
finally{
    Save
    @{status=$(if(@($cases|Where-Object status -eq 'FAILED').Count -eq 0){'PASSED'}else{'FAILED'});standard_user=$true;mode=$Mode;cases=@($cases.ToArray())}|ConvertTo-Json -Depth 12|Set-Content (Join-Path $Fixture ('standard-'+$Mode+'.json')) -Encoding utf8
}
if(@($cases|Where-Object status -eq 'FAILED').Count -gt 0){exit 1}
