param([string]$Manager,[string]$Fixture,[string]$EngineHome,[string]$FaultManager,[string]$Mode='normal')
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$cases=[Collections.Generic.List[object]]::new()
function Save {ConvertTo-Json -InputObject @($cases.ToArray()) -Depth 10|Set-Content (Join-Path $Fixture 'control-cases.json') -Encoding utf8}
function Require([bool]$ok,[string]$code){if(-not $ok){throw $code}}
function Case([string]$id,[string]$name,[scriptblock]$body){$c=@{id=$id;name=$name;status='IN_PROGRESS'};$cases.Add($c);Save;try{$c.evidence=(& $body);$c.status='PASSED'}catch{$c.status='FAILED';$c.code=if($_.Exception.Message -cmatch '\b([A-Z][A-Z0-9_]{3,80})\b'){$Matches[1]}else{'CONTROL_CASE_FAILED'};$c.line=$_.InvocationInfo.ScriptLineNumber;$c.exception_type=$_.Exception.GetBaseException().GetType().FullName};Save;Write-Host ($name+' '+$c.status+$(if($c.ContainsKey('code')){' '+$c.code}else{''}))}
function Call($request,[string]$kind='control',[string]$image=$Manager){
    $s=[Diagnostics.ProcessStartInfo]::new($image);$s.UseShellExecute=$false;$s.WorkingDirectory=$EngineHome;$s.RedirectStandardInput=$true;$s.RedirectStandardOutput=$true;$s.RedirectStandardError=$true;$s.ArgumentList.Add("--$kind-once")
    $p=[Diagnostics.Process]::Start($s)
    try{$read=$p.StandardOutput.ReadToEndAsync();$err=$p.StandardError.ReadToEndAsync();$p.StandardInput.Write((ConvertTo-Json -InputObject $request -Depth 12 -Compress));$p.StandardInput.Close();Require ($p.WaitForExit(150000)) 'CONTROL_TIMEOUT';Require ($p.ExitCode -eq 0) 'CONTROL_WORKER_EXIT_FAILED';$r=$read.Result|ConvertFrom-Json;Require ($r.reason -eq 'OBSERVED') $r.reason;return $r}finally{if(-not $p.HasExited){$p.Kill($true)};$p.Dispose()}
}
function New-App([string]$exe,[string[]]$arguments,[string]$cwd=$null){
    $id=[Guid]::NewGuid().ToString();$r=Call @{action='REGISTER';environment_id=$script:e.id;expected_revision=$script:e.revision;operation_id=$id;display_name='Synthetic launch fixture';executable=$exe;arguments=$arguments;working_directory=$cwd}
    $receipt=$r.receipts|Where-Object operation_id -eq $id;Require ($receipt.state -eq 'REGISTERED') $receipt.reason
    return @($r.applications|Where-Object {$_.environment_id -eq $script:e.id})[-1]
}
function Launch($a,[string]$operation=[Guid]::NewGuid().ToString()){$r=Call @{action='LAUNCH';application_id=$a.id;environment_id=$a.environment_id;expected_revision=$a.revision;operation_id=$operation};return ($r.receipts|Where-Object operation_id -eq $operation)}
function Stop-Owned { $id=[Guid]::NewGuid().ToString();$r=Call @{action='STOP';environment_id=$script:e.id;operation_id=$id};$receipt=$r.receipts|Where-Object operation_id -eq $id;Require ($receipt.state -eq 'STOPPED') $receipt.reason;return $r }
function Reports([string]$leaf){$clock=[Diagnostics.Stopwatch]::StartNew();do{$files=@(Get-ChildItem -LiteralPath $script:root -Recurse -File -Filter $leaf);if($files.Count -gt 0){return @(Get-Content $files[0].FullName|ForEach-Object {$_|ConvertFrom-Json})};Start-Sleep -Milliseconds 100}while($clock.ElapsedMilliseconds -lt 15000);throw 'TARGET_REPORT_MISSING'}
try {
    $who=[Security.Principal.WindowsIdentity]::GetCurrent();$principal=[Security.Principal.WindowsPrincipal]::new($who);Require (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) 'STANDARD_TOKEN_REQUIRED'
    $active=if($Mode -eq 'normal'){$Manager}else{$FaultManager}
    $r=Call @{action='CREATE';display_name='P06 production-path fixture';operation_id=[Guid]::NewGuid().ToString();policy=@{schema=1;preset='STANDARD_OFFLINE';grants=@()}} 'policy' $active
    $script:e=$r.environments[0];$script:root=$e.compiled.section.FileRootPath[0];Require ($e.stage -eq 'VERIFIED') 'P05_GATE_REQUIRED'
    if($Mode -eq 'scope'){
        $Manager=$FaultManager;$probe=Join-Path (Split-Path $Manager) 'securerun-launch-probe.exe'
        $a=New-App $probe @('hold',(Join-Path $Fixture 'scope-held.jsonl'));$receipt=Launch $a;Require ($receipt.state -eq 'RUNNING_BOXED') $receipt.reason
        Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'p05_lab.cs')));$lab=[P05Lab]::new($EngineHome,$Fixture,$PSScriptRoot);$box='SR_'+$e.id.Replace('-','');$lab.Register($box)
        Case 'T62' 'actual_scope_change_after_process_handles_retained' {
            $env:SECURERUN_P06_PAUSE_STAGE='StopHeld';$id=[Guid]::NewGuid().ToString()
            $s=[Diagnostics.ProcessStartInfo]::new($Manager);$s.UseShellExecute=$false;$s.WorkingDirectory=$EngineHome;$s.RedirectStandardInput=$true;$s.RedirectStandardOutput=$true;$s.RedirectStandardError=$true
            foreach($arg in @('--control-worker',[string]$PID,[string]([Diagnostics.Process]::GetCurrentProcess().StartTime.ToFileTimeUtc()))){$s.ArgumentList.Add($arg)}
            $p=[Diagnostics.Process]::Start($s);$other=Join-Path $Fixture 'unrelated-root';$null=New-Item -ItemType Directory -Path $other
            try {
                $line=$p.StandardOutput.ReadLineAsync();$p.StandardInput.Write((ConvertTo-Json -InputObject @{action='STOP';environment_id=$e.id;operation_id=$id} -Compress));$p.StandardInput.Close();Require ($line.Wait(45000)) 'STOP_HELD_CHECKPOINT_TIMEOUT';Require ($line.Result -eq 'CHECKPOINT_StopHeld') 'STOP_HELD_CHECKPOINT_NOT_REACHED'
                $lab.Set($box,'FileRootPath',$other);$read=$p.StandardOutput.ReadToEndAsync();Require ($p.WaitForExit(30000)) 'STOP_SCOPE_CHANGE_TIMEOUT';$r=$read.Result|ConvertFrom-Json;$stopped=$r.receipts|Where-Object operation_id -eq $id
                Require ($stopped.state -eq 'UNKNOWN' -and $stopped.reason -eq 'STOP_SCOPE_CHANGED') 'CHANGED_SCOPE_TERMINATED'
                $targetProcess=[Diagnostics.Process]::GetProcessById([int]$receipt.process.pid);try{Require (-not $targetProcess.HasExited -and [string]$targetProcess.StartTime.ToFileTimeUtc() -eq $receipt.process.creation_time) 'HELD_PROCESS_WAS_TERMINATED'}finally{$targetProcess.Dispose()}
                @{real_held_handles=$true;scope_changed_before_dispatch=$true;target_survives=$true;numeric_pid_fallback=$false;unknown_completion_preserved=$true}
            }finally{Remove-Item Env:/SECURERUN_P06_PAUSE_STAGE -ErrorAction SilentlyContinue;$lab.Set($box,'FileRootPath',$root);if(-not $p.HasExited){$p.Kill($true)};$p.Dispose();$null=Stop-Owned}
        }
    }elseif($Mode -ne 'normal'){
        $Manager=$FaultManager;$probe=Join-Path (Split-Path $Manager) 'securerun-launch-probe.exe';$leaf='lost-'+[Guid]::NewGuid().ToString('N')+'.jsonl';$output=Join-Path $Fixture $leaf;$a=New-App $probe @('short',$output)
        $stage=if($Mode -eq 'reserved'){'Reserved'}else{'Accepted'};$id=[Guid]::NewGuid().ToString();$request=@{action='LAUNCH';application_id=$a.id;environment_id=$a.environment_id;expected_revision=$a.revision;operation_id=$id}
        $env:SECURERUN_P06_PAUSE_STAGE=$stage
        Case 'T61' ('actual_dispatch_interruption_'+$Mode) {
            $s=[Diagnostics.ProcessStartInfo]::new($Manager);$s.UseShellExecute=$false;$s.WorkingDirectory=$EngineHome;$s.RedirectStandardInput=$true;$s.RedirectStandardOutput=$true;$s.RedirectStandardError=$true
            foreach($arg in @('--control-worker',[string]$PID,[string]([Diagnostics.Process]::GetCurrentProcess().StartTime.ToFileTimeUtc()))){$s.ArgumentList.Add($arg)}
            $p=[Diagnostics.Process]::Start($s)
            try{$line=$p.StandardOutput.ReadLineAsync();$p.StandardInput.Write((ConvertTo-Json -InputObject $request -Compress));$p.StandardInput.Close();Require ($line.Wait(45000)) 'CHECKPOINT_TIMEOUT';Require ($line.Result -eq "CHECKPOINT_$stage") 'CHECKPOINT_NOT_REACHED';if($Mode -eq 'accepted'){Start-Sleep -Milliseconds 500};$p.Kill($true);Require ($p.WaitForExit(10000)) 'KILLED_WORKER_NOT_EXITED'}finally{if(-not $p.HasExited){$p.Kill($true)};$p.Dispose()}
            Remove-Item Env:/SECURERUN_P06_PAUSE_STAGE
            $before=if($Mode -eq 'accepted'){@(Reports $leaf).Count}else{0}
            foreach($n in 1..3){$retry=Call $request;$receipt=$retry.receipts|Where-Object operation_id -eq $id;Require ($receipt.state -eq 'UNKNOWN') 'UNCERTAIN_LAUNCH_REPLAYED'}
            $after=if($Mode -eq 'accepted'){@(Reports $leaf).Count}else{@(Get-ChildItem -LiteralPath $root -Recurse -File -Filter $leaf).Count}
            Require ($before -eq $after -and $before -eq $(if($Mode -eq 'accepted'){1}else{0})) 'TARGET_EXECUTED_MORE_THAN_ONCE'
            $null=Stop-Owned
            @{real_worker_killed=$true;checkpoint=$stage;duplicate_deliveries=3;target_executions=$after;automatic_replay=$false;receipt_state='UNKNOWN';standard_user=$true}
        }
    }else{
        $probes=@(Get-ChildItem (Split-Path $Manager) -Filter 'securerun-launch-probe*.exe')
        foreach($probe in $probes){
            Case 'T04' ('exact_arguments_'+$probe.BaseName) {
                $leaf='args-'+[Guid]::NewGuid().ToString('N')+'.jsonl';$output=Join-Path $Fixture $leaf
                $a=New-App $probe.FullName @('arguments',$output,'','Unicode Привет 🧪','spaces in argument','a"quote','trailing\','/terminate_all','& echo SHOULD_NOT_EXECUTE','\"tail\')
                $receipt=Launch $a;Require ($receipt.state -in @('RUNNING_BOXED','PRIMARY_EXITED_BOXED')) $receipt.reason
                $reports=Reports $leaf;Require ($reports.Count -eq 1 -and $reports[0].boxed -and $reports[0].arguments_exact -and -not(Test-Path $output)) 'ARGUMENT_OR_HOST_BOUNDARY_FAILED';$null=Stop-Owned
                @{boxed=$true;exact_target_argv=$true;host_output_absent=$true;actual_pe=$probe.BaseName;receipt=$receipt.state}
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
            foreach($pair in @(@('Enabled','y'),@('DropAdminRights','y'),@('AutoRecover','n'),@('AutoDelete','n'),@('UseFileImage','n'))){$b.Set($unowned,$pair[0],$pair[1])};$b.Set($unowned,'FileRootPath',(Join-Path $Fixture "boxes/$unowned"));$null=$b.ProvisionFreshRoot($unowned)
            $unownedReceipt=$b.Launch($unowned,$probe.FullName,[string[]]@('hold',(Join-Path $Fixture 'unmanaged.jsonl')))
            $outside=[Diagnostics.ProcessStartInfo]::new((Get-Command pwsh).Source);$outside.UseShellExecute=$false;foreach($arg in @('-NoProfile','-NonInteractive','-Command','Start-Sleep -Seconds 90')){$outside.ArgumentList.Add($arg)};$hostProcess=[Diagnostics.Process]::Start($outside)
            try{$owned=Launch $treeApp;$id=[Guid]::NewGuid().ToString();$r=Call @{action='STOP_MANAGED';operation_id=$id};$receipt=$r.receipts|Where-Object operation_id -eq $id
                Require ($receipt.state -eq 'STOPPED' -and $b.Count($unowned) -gt 0 -and -not $hostProcess.HasExited) 'UNMANAGED_WORKLOAD_TERMINATED';@{managed_empty=$true;unmanaged_box_survives=$true;unboxed_process_survives=$true;prefix_authority=$false}
            }finally{[P02Bridge]::StopReceipt($unownedReceipt);$null=$b.StopHeld($unowned);if(-not $hostProcess.HasExited){$hostProcess.Kill();$hostProcess.WaitForExit()};$hostProcess.Dispose()}
        }
        Case 'T26' 'rapid_launch_stop_serializes_and_duplicate_scope_conflicts' {
            foreach($n in 1..3){$receipt=Launch $treeApp;Require ($receipt.state -eq 'RUNNING_BOXED') $receipt.reason;$null=Stop-Owned}
            $id=[Guid]::NewGuid().ToString();$null=Call @{action='STOP';environment_id=$e.id;operation_id=$id}
            $s=[Diagnostics.ProcessStartInfo]::new($Manager);$s.UseShellExecute=$false;$s.RedirectStandardInput=$true;$s.RedirectStandardOutput=$true;$s.ArgumentList.Add('--control-once');$p=[Diagnostics.Process]::Start($s)
            try{$read=$p.StandardOutput.ReadToEndAsync();$p.StandardInput.Write((ConvertTo-Json -InputObject @{action='STOP_MANAGED';operation_id=$id} -Compress));$p.StandardInput.Close();Require ($p.WaitForExit(45000)) 'CONFLICT_TIMEOUT';$r=$read.Result|ConvertFrom-Json;Require ($r.reason -eq 'OPERATION_CONFLICT') 'OPERATION_SCOPE_REUSED'}finally{$p.Dispose()}
            @{rapid_cycles=3;conflicting_operation_refused=$true;all_waits_completed=$true}
        }
        Case 'T03' 'invalid_exe_and_control_characters_are_refused' {
            $id=[Guid]::NewGuid().ToString();$r=Call @{action='REGISTER';environment_id=$e.id;expected_revision=$e.revision;operation_id=$id;display_name='Invalid';executable=(Join-Path $Fixture 'missing.exe');arguments=@();working_directory=$null};$receipt=$r.receipts|Where-Object operation_id -eq $id;Require ($receipt.state -eq 'REFUSED') 'INVALID_EXE_ACCEPTED'
            $id=[Guid]::NewGuid().ToString();$r=Call @{action='REGISTER';environment_id=$e.id;expected_revision=$e.revision;operation_id=$id;display_name='Invalid';executable=$probe.FullName;arguments=@("bad`nargument");working_directory=$null};$receipt=$r.receipts|Where-Object operation_id -eq $id;Require ($receipt.state -eq 'REFUSED' -and $receipt.reason -eq 'TARGET_ARGUMENTS_INVALID') 'ARGUMENT_CONTROL_ACCEPTED'
            @{invalid_exe_refused=$true;controls_refused=$true;shell_used=$false}
        }
        Case 'T50' 'target_cwd_is_separate_from_host_worker_cwd' {
            $cwd=Join-Path $Fixture 'hostile cwd';$null=New-Item -ItemType Directory -Path $cwd;[IO.File]::WriteAllText((Join-Path $cwd 'SbieDll.dll'),'SYNTHETIC_INVALID_DLL');[IO.File]::WriteAllText((Join-Path $cwd 'Start.exe'),'SYNTHETIC_INVALID_EXE')
            $leaf='cwd-'+[Guid]::NewGuid().ToString('N')+'.jsonl';$a=New-App $probe.FullName @('short',(Join-Path $Fixture $leaf)) $cwd;$receipt=Launch $a;Require ($receipt.state -in @('RUNNING_BOXED','PRIMARY_EXITED_BOXED')) $receipt.reason;Require ((Reports $leaf)[0].boxed) 'HOSTILE_CWD_ESCAPED';$null=Stop-Owned
            @{hostile_target_directory_accepted_separately=$true;trusted_host_worker_cwd=$true;impostor_dependencies_unused=$true}
        }
    }
}catch{Case 'T01' 'required_prerequisites' {throw $_}}
finally{
    Save
    @{status=$(if(@($cases|Where-Object status -eq 'FAILED').Count -eq 0){'PASSED'}else{'FAILED'});standard_user=$true;mode=$Mode;cases=@($cases.ToArray())}|ConvertTo-Json -Depth 12|Set-Content (Join-Path $Fixture ('standard-'+$Mode+'.json')) -Encoding utf8
}
if(@($cases|Where-Object status -eq 'FAILED').Count -gt 0){exit 1}
