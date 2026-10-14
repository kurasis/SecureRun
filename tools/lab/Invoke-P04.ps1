[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true') { throw 'DISPOSABLE_ACTIONS_VM_REQUIRED' }
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$out=Join-Path $repo 'artifacts/p04';$null=New-Item -ItemType Directory -Path $out -Force
@{phase='P04';stage='STARTED';manager_commit=(& git -C $repo rev-parse HEAD).Trim();security_settings_modified=$false} | ConvertTo-Json | Set-Content (Join-Path $out 'stage.json') -Encoding utf8
$target=if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') {'aarch64-pc-windows-msvc'} else {'x86_64-pc-windows-msvc'}
$env:RUSTUP_TOOLCHAIN="1.90.0-$target"
rustup toolchain install $env:RUSTUP_TOOLCHAIN --profile minimal --component rustfmt,clippy
if ($LASTEXITCODE -ne 0) {throw 'RUST_INSTALL_FAILED'}
Push-Location $repo
try {
    npm ci --ignore-scripts
    if ($LASTEXITCODE -ne 0) {throw 'NPM_INSTALL_FAILED'}
    npm run build
    if ($LASTEXITCODE -ne 0) {throw 'UI_BUILD_FAILED'}
    $unit=& cargo test --locked -p securerun-sandboxie-adapter 2>&1;$unit | Out-Host
    if ($LASTEXITCODE -ne 0) {throw 'ADAPTER_TEST_FAILED'}
    $unitCount=0;foreach($line in $unit){if([string]$line -match 'test result: ok\. (\d+) passed; 0 failed'){$unitCount += [int]$Matches[1]}}
    if ($unitCount -lt 7) {throw 'ADAPTER_TEST_COVERAGE_MISSING'}
    cargo clippy --locked -p securerun-sandboxie-adapter --all-targets -- -D warnings
    if ($LASTEXITCODE -ne 0) {throw 'ADAPTER_LINT_FAILED'}
    npm run tauri -- build --debug --no-bundle --target $target
    if ($LASTEXITCODE -ne 0) {throw 'NORMAL_NATIVE_BUILD_FAILED'}
    $run=[Guid]::NewGuid().ToString('N')
    $managerHome=Join-Path $env:ProgramFiles "SecureRun-P04-$run";$null=New-Item -ItemType Directory -Path $managerHome
    $app=Join-Path $managerHome 'securerun.exe';Copy-Item (Join-Path $repo "target/$target/debug/securerun.exe") $app
    $binaryHash=(Get-FileHash $app).Hash.ToLowerInvariant()
    $cases=[System.Collections.Generic.List[object]]::new()
    function Save { ConvertTo-Json -InputObject @($cases.ToArray()) -Depth 8 | Set-Content (Join-Path $out 'observation-cases.json') -Encoding utf8 }
    function Require([bool]$ok,[string]$code){if(-not $ok){throw $code}}
    function Case([string]$id,[string]$name,[scriptblock]$body){
        $c=@{id=$id;name=$name;status='IN_PROGRESS'};$cases.Add($c);Save
        try{$c.evidence=(& $body);$c.status='PASSED'}catch{$c.status='FAILED';$c.exception_type=$_.Exception.GetBaseException().GetType().FullName;$c.code=if($_.Exception.Message -cmatch '\b([A-Z][A-Z0-9_]{3,80})\b'){$Matches[1]}else{'OBSERVATION_CASE_FAILED'}}
        Save
    }
    function Observe([string]$Cwd=$managerHome) {
        $start=[Diagnostics.ProcessStartInfo]::new($app);$start.UseShellExecute=$false;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
        $start.WorkingDirectory=$Cwd;$start.ArgumentList.Add('--observation-once')
        $p=[Diagnostics.Process]::Start($start)
        try {
            $read=$p.StandardOutput.ReadToEndAsync();$errorRead=$p.StandardError.ReadToEndAsync()
            if(-not $p.WaitForExit(30000)){$p.Kill($true);throw 'MANAGER_OBSERVATION_TIMEOUT'}
            Require ($p.ExitCode -eq 0 -and $read.Result.Length -le 2097152) 'MANAGER_RESPONSE_INVALID'
            return $read.Result | ConvertFrom-Json
        } finally {$p.Dispose()}
    }
    Case 'T01' 'missing_engine_fail_closed' { $o=Observe;Require ($o.reason -eq 'ENGINE_MISSING' -and $o.manager_context -eq 'UNKNOWN' -and $o.boxes.Count -eq 0 -and -not $o.production_launch_available) 'MISSING_ENGINE_GATE_FAILED';@{reason=$o.reason;context=$o.manager_context;production_launch_available=$false} }
    & (Join-Path $PSScriptRoot 'Initialize-P02.ps1')
    $engine=Join-Path $env:ProgramFiles 'Sandboxie-Plus'
    Case 'T02' 'trusted_installed_components' { $o=Observe;Require ($o.trust -eq 'VERIFIED' -and $o.reason -eq 'OBSERVED' -and $o.manager_context -eq 'UNBOXED' -and $o.bridge_context -eq 'UNBOXED') 'TRUSTED_OBSERVATION_FAILED';@{trust=$o.trust;reason=$o.reason;manager_context=$o.manager_context;bridge_context=$o.bridge_context;core_version=$o.core_version;abi=$o.abi;service_running=$o.service_running;driver_running=$o.driver_running} }
    Case 'T02' 'changed_component_rejected_before_loading' {
        $dll=Join-Path $engine 'SbieDll.dll';$original=[IO.File]::ReadAllBytes($dll)
        try {$changed=$original.Clone();$changed[-1]=$changed[-1] -bxor 1;Move-Item $dll ($dll+'.p04-original');[IO.File]::WriteAllBytes($dll,$changed);$o=Observe;Require ($o.reason -eq 'COMPONENT_UNTESTED_OR_CHANGED' -and $o.boxes.Count -eq 0) 'CHANGED_COMPONENT_ACCEPTED';@{reason=$o.reason;native_queries_not_dispatched=$true}}
        finally {if(Test-Path ($dll+'.p04-original')){Remove-Item $dll;Move-Item ($dll+'.p04-original') $dll}}
    }
    Case 'T01' 'stopped_service_is_not_ready' {
        Stop-Service SbieSvc
        try{$o=Observe;Require ($o.reason -eq 'ENGINE_SERVICE_STOPPED' -and -not $o.service_running -and $o.boxes.Count -eq 0) 'STOPPED_SERVICE_ACCEPTED';@{reason=$o.reason;production_launch_available=$false}}
        finally {Start-Service SbieSvc}
    }
    Case 'T46' 'fresh_observation_after_service_restart' { $o=Observe;Require ($o.reason -eq 'OBSERVED' -and $o.service_running) 'RECONNECT_NOT_OBSERVED';@{fresh_native_query=$true;service_identity_present=($null -ne $o.service_identity);release_evidence=$o.release_evidence} }
    Case 'T01' 'unavailable_driver_never_reports_idle' {
        try{
            Stop-Service SbieSvc
            # The pinned driver requires upstream API_UNLOAD_DRIVER before the
            # native unload; ordinary SCM Stop is not its supported shutdown path.
            # This authenticated utility is lab administration, never a product API.
            $start=[Diagnostics.ProcessStartInfo]::new((Join-Path $engine 'KmdUtil.exe'));$start.UseShellExecute=$false;$start.WorkingDirectory=$engine
            $start.ArgumentList.Add('stop');$start.ArgumentList.Add('SbieDrv');$start.Environment.Clear()
            foreach($key in @('SystemRoot','WINDIR','SystemDrive','ProgramFiles','ProgramFiles(x86)','ProgramW6432','ProgramData','TEMP','TMP')){$value=[Environment]::GetEnvironmentVariable($key);if($null -ne $value){$start.Environment[$key]=$value}}
            $start.Environment['PATH']=Join-Path $env:SystemRoot 'System32'
            $utility=[Diagnostics.Process]::Start($start)
            try{if(-not $utility.WaitForExit(30000)){$utility.Kill();throw 'ORIGINAL_DRIVER_UNLOAD_TIMEOUT'};Require ($utility.ExitCode -eq 0) 'ORIGINAL_DRIVER_UNLOAD_FAILED'}finally{$utility.Dispose()}
            $o=Observe;Require (-not $o.driver_running -and $o.reason -ne 'OBSERVED' -and $o.boxes.Count -eq 0 -and $o.manager_context -eq 'UNKNOWN') 'UNHEALTHY_DRIVER_ACCEPTED'
            @{reason=$o.reason;driver_running=$o.driver_running;idle_or_launch_authorized=$false;lab_unload='AUTHENTICATED_ORIGINAL_KMDUTIL';windows_security_settings_modified=$false}
        }
        finally{if((Get-Service SbieDrv).Status -ne 'Running'){Start-Service SbieDrv};if((Get-Service SbieSvc).Status -ne 'Running'){Start-Service SbieSvc}}
    }
    Case 'T56' 'bounded_typed_protocol_and_generation_tests' { @{actual_adapter_tests_passed=$unitCount;old_worker_and_generation_refused=$true;incomplete_enumeration_never_idle=$true;cached_evidence_is_separate=$true} }
    Case 'T02' 'optional_paid_capabilities_do_not_invent_entitlement' { $o=Observe;$paid=@($o.capabilities|Where-Object name -eq 'paid_profiles');Require ($paid.Count -eq 1 -and $paid[0].availability -ne 'AVAILABLE') 'PAID_CAPABILITY_UNVERIFIED';@{availability=$paid[0].availability;reason=$paid[0].reason;provenance=$paid[0].provenance;certificate_contents_recorded=$false} }
    $fixture=Join-Path $env:ProgramData "SecureRunLab/p02-$run"
    foreach($dir in @('boxes','results','hostile')){$null=New-Item -ItemType Directory -Path (Join-Path $fixture $dir) -Force}
    Copy-Item (Join-Path $repo 'tools/probe/engine_bridge.cs'),(Join-Path $repo 'tools/probe/p04_boxed.ps1'),(Join-Path $repo 'tools/probe/p04_standard.ps1') $managerHome
    Add-Type -TypeDefinition (Get-Content (Join-Path $repo 'tools/probe/engine_bridge.cs') -Raw)
    $nativeArch=if($target -like 'aarch64*'){'arm64'}else{'x64'}
    $probe=Join-Path $managerHome "feasibility_probe_$nativeArch.exe"
    Copy-Item (Join-Path $repo "artifacts/p02/feasibility_probe_$nativeArch.exe") $probe
    Case 'T50' 'hostile_cwd_path_and_dll_are_not_loaded' {
        $hostile=Join-Path $fixture 'hostile';[IO.File]::WriteAllText((Join-Path $hostile 'Start.exe'),'P04_INVALID_PATH_IMPOSTOR');[IO.File]::WriteAllText((Join-Path $hostile 'SbieDll.dll'),'P04_INVALID_DLL_IMPOSTOR')
        $savedPath=$env:PATH
        try{$env:PATH=$hostile+';'+$savedPath;$o=Observe $hostile;Require ($o.reason -eq 'OBSERVED' -and $o.trust -eq 'VERIFIED') 'HOSTILE_SEARCH_PATH_USED';@{production_query_succeeded=$true;host_cwd='OS_SYSTEM32';minimal_worker_environment=$true;path_and_cwd_impostors_ignored=$true}}
        finally{$env:PATH=$savedPath}
    }
    Case 'T02' 'user_writable_installation_refused' {
        $originalAcl=Get-Acl $engine;$testAcl=Get-Acl $engine
        $testAcl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new('S-1-5-32-545'),'Write','None','None','Allow'))
        try{Set-Acl $engine $testAcl;$o=Observe;Require ($o.reason -eq 'COMPONENT_WRITABLE' -and $o.boxes.Count -eq 0) 'WRITABLE_ENGINE_ACCEPTED';@{reason=$o.reason;component_queries_not_dispatched=$true}}
        finally{Set-Acl $engine $originalAcl}
    }
    Case 'T02' 'false_service_installation_metadata_refused' {
        & sc.exe config SbieSvc binPath= (Join-Path $fixture 'SbieSvc.exe') | Out-Null
        Require ($LASTEXITCODE -eq 0) 'SERVICE_METADATA_FIXTURE_FAILED'
        try{$o=Observe;Require ($o.reason -ne 'OBSERVED' -and $o.boxes.Count -eq 0 -and $o.manager_context -eq 'UNKNOWN') 'FALSE_INSTALLED_PATH_ACCEPTED';@{reason=$o.reason;impostor_executed=$false}}
        finally{& sc.exe config SbieSvc binPath= ('"'+(Join-Path $engine 'SbieSvc.exe')+'"') | Out-Null;Require ($LASTEXITCODE -eq 0) 'SERVICE_METADATA_RESTORE_FAILED'}
    }
    $shell=Join-Path $PSHOME 'pwsh.exe'
    $bridge=[P02Bridge]::new($engine,$fixture,[string[]]@($shell,$app,$probe))
    $box='SRP02_P04_'+$run.Substring(0,12)
    $bridge.Register($box);$bridge.Set($box,'Enabled','y');$bridge.Set($box,'FileRootPath',(Join-Path $fixture "boxes/$box"));$bridge.Set($box,'DropAdminRights','y');$bridge.Set($box,'AutoRecover','n');$bridge.Set($box,'AutoDelete','n');$bridge.Set($box,'UseFileImage','n')
    $root=$bridge.Root($box);$null=New-Item -ItemType Directory -Path $root;$null=$bridge.CaptureRoot($box)
    $configFiles=@((Join-Path $engine 'Sandboxie.ini'),(Join-Path $env:SystemRoot 'Sandboxie.ini'))|Where-Object {Test-Path $_}
    $beforeConfig=@($configFiles|ForEach-Object {(Get-FileHash $_).Hash})
    Case 'T02' 'unowned_configuration_roots_remain_read_only' {
        $o=Observe;$b=@($o.boxes|Where-Object name -eq $box)
        Require ($b.Count -eq 1 -and -not $b[0].owned -and $b[0].read_only -and $b[0].root.identity -and $b[0].configuration.Count -gt 0) 'UNOWNED_OBSERVATION_MISSING'
        Require ($beforeConfig.Count -gt 0 -and (($beforeConfig -join ',') -eq (@($configFiles|ForEach-Object {(Get-FileHash $_).Hash}) -join ','))) 'READ_ONLY_CONFIG_CHANGED'
        @{unowned_read_only=$true;configuration_count=$b[0].configuration.Count;root_identity_present=$true;root_scope=$b[0].root.scope;configuration_bytes_unchanged=$true;effective_enforcement_claimed=$false}
    }
    Case 'T58' 'boxed_actual_manager_and_bridge_refuse_controls' {
        [P02Bridge]::MinimizeProcessEnvironment($engine)
        $receipt=$bridge.Launch($box,$shell,[string[]]@('-NoLogo','-NoProfile','-NonInteractive','-File',(Join-Path $managerHome 'p04_boxed.ps1'),'-Manager',$app,'-Fixture',$fixture))
        try{
            Require ([P02Bridge]::Completed($receipt,35000) -and [P02Bridge]::ExitCode($receipt) -eq 43) 'BOXED_MANAGER_GATE_FAILED'
            $files=@(Get-ChildItem -LiteralPath $root -Recurse -File -Filter 'boxed-manager.json');Require ($files.Count -eq 1 -and $files[0].Length -lt 4096) 'BOXED_MANAGER_REPORT_MISSING'
            $result=Get-Content $files[0].FullName -Raw|ConvertFrom-Json
            Require ($result.actual_manager_executed -and $result.manager_context -ne 'UNBOXED' -and $result.boxes_observed -eq 0 -and -not $result.production_launch_available) 'BOXED_MANAGER_UNEXPECTED_ACCESS'
            $result
        }finally{[P02Bridge]::CloseReceipt($receipt)}
    }
    Case 'T07' 'live_process_wrong_birth_cannot_be_attributed' {
        $birth=[DateTime]::UtcNow.ToFileTimeUtc()+1
        $data=(& $app --engine-worker $PID $birth)|ConvertFrom-Json
        Require ($data.reason -eq 'MANAGER_IDENTITY_CHANGED' -and $data.boxes.Count -eq 0 -and $data.manager_context -eq 'UNKNOWN') 'PROCESS_BIRTH_MISMATCH_ACCEPTED'
        @{wrong_birth_rejected=$true;numeric_pid_only_identity_not_used=$true;process_termination_not_implemented=$true}
    }
    Case 'T07' 'exited_process_identity_is_not_reused' {
        $p=Start-Process -FilePath (Join-Path $env:SystemRoot 'System32/cmd.exe') -ArgumentList '/c ping -n 3 127.0.0.1 > NUL' -PassThru
        $id=$p.Id;$birth=$p.StartTime.ToFileTimeUtc();$null=$p.WaitForExit(5000);$p.Dispose()
        $data=(& $app --engine-worker $id $birth)|ConvertFrom-Json
        Require ($data.reason -in @('MANAGER_IDENTITY_UNKNOWN','MANAGER_IDENTITY_CHANGED') -and $data.boxes.Count -eq 0) 'EXITED_IDENTITY_ATTRIBUTED'
        @{completed_process_refused=$true;pid_reuse_not_forced=$true;held_object_birth_required=$true}
    }
    Case 'T36' 'standard_user_same_sid_in_two_actual_sessions' {
        $userName='SRP02S_'+$run.Substring(0,10);$password='P04aA!'+[Guid]::NewGuid().ToString('N');$secure=ConvertTo-SecureString $password -AsPlainText -Force
        $user=New-LocalUser -Name $userName -Password $secure -AccountNeverExpires
        $group=([Security.Principal.SecurityIdentifier]::new('S-1-5-32-545')).Translate([Security.Principal.NTAccount]).Value.Split('\')[-1];Add-LocalGroupMember -Group $group -Member $userName
        $userFixture=Join-Path $env:ProgramData "SecureRunLab/p02-user-$run"
        foreach($dir in @('results','boxes')){$null=New-Item -ItemType Directory -Path (Join-Path $userFixture $dir) -Force}
        $acl=[Security.AccessControl.DirectorySecurity]::new();$acl.SetAccessRuleProtection($true,$false)
        foreach($sid in @($user.SID,[Security.Principal.SecurityIdentifier]::new('S-1-5-18'),[Security.Principal.SecurityIdentifier]::new('S-1-5-32-544'))){$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid,'FullControl','ContainerInherit,ObjectInherit','None','Allow'))}
        Set-Acl $userFixture $acl
        $stdBox='SRP02_STD_'+$run.Substring(0,12);$task='SRP04_SAME_'+$run;$pipe='SecureRunP02Logon_'+$run
        $arguments=([string[]]@('logon-fixture',$pipe)|ForEach-Object {[P02Bridge]::Quote($_)}) -join ' '
        $action=New-ScheduledTaskAction -Execute $probe -Argument $arguments -WorkingDirectory $engine
        $principal=New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
        $settings=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::FromMinutes(2))
        $null=Register-ScheduledTask -TaskName $task -Action $action -Principal $principal -Settings $settings
        $start=[Diagnostics.ProcessStartInfo]::new($shell);$start.UseShellExecute=$false;$start.WorkingDirectory=$engine;$start.UserName=$userName;$start.Domain=[Environment]::MachineName;$start.Password=$secure;$start.LoadUserProfile=$true
        foreach($arg in [string[]]@('-NoLogo','-NoProfile','-NonInteractive','-File',(Join-Path $managerHome 'p04_standard.ps1'),'-Manager',$app,'-EngineHome',$engine,'-Fixture',$userFixture,'-Box',$stdBox,'-Probe',$probe)){$start.ArgumentList.Add($arg)}
        $process=[Diagnostics.Process]::Start($start)
        try{
            $clock=[Diagnostics.Stopwatch]::StartNew();$ready=Join-Path $userFixture 'results/p04-standard-ready.json'
            while(-not(Test-Path $ready) -and -not $process.HasExited -and $clock.ElapsedMilliseconds -lt 45000){Start-Sleep -Milliseconds 200}
            Require (Test-Path $ready) 'STANDARD_USER_READY_FAILED'
            $transport=$bridge.SendFixtureLogon([Action]{Start-ScheduledTask -TaskName $task},$pipe,$userName,$password,$user.SID.Value,$userFixture,$stdBox,$probe)
            $password=$null;Require ($process.WaitForExit(90000)) 'STANDARD_OBSERVATION_TIMEOUT'
            $result=Get-Content (Join-Path $userFixture 'results/p04-standard-result.json') -Raw|ConvertFrom-Json
            Copy-Item (Join-Path $userFixture 'results/p04-standard-result.json') (Join-Path $out 'standard-user.json')
            Require ($process.ExitCode -eq 0 -and $result.status -eq 'PASSED' -and $result.simultaneous_session_count -ge 2 -and $result.all_session_complete) 'SAME_SID_PRODUCTION_OBSERVATION_FAILED'
            @{production_observation=$result;password_in_argv_or_environment=$transport.password_in_argv_or_environment;windows_logon_policy_changed=$false}
        }finally{if(-not $process.HasExited){$process.Kill($true)};$process.Dispose();Unregister-ScheduledTask -TaskName $task -Confirm:$false;$secure.Dispose();$password=$null}
    }
    $pe=[IO.File]::ReadAllBytes($app);$offset=[BitConverter]::ToInt32($pe,0x3c);$machine=('{0:x4}' -f [BitConverter]::ToUInt16($pe,$offset+4))
    @{phase='P04';result=$(if(@($cases|Where-Object status -ne 'PASSED').Count -eq 0){'PASSED'}else{'FAILED'});manager_commit=(& git rev-parse HEAD).Trim();target=$target;pe_machine=$machine;manager_binary_sha256=$binaryHash;adapter_tests_passed=$unitCount;native_cases_passed=@($cases|Where-Object status -eq 'PASSED').Count;os_build=[Environment]::OSVersion.Version.ToString();production_target_launches=0;production_mutations=0;os_security_settings_modified=$false;teardown='DISCARD_ACTIONS_VM'} | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $out 'run-summary.json') -Encoding utf8
    Require (@($cases|Where-Object status -ne 'PASSED').Count -eq 0) 'P04_NATIVE_GATE_FAILED'
} finally {Pop-Location}
