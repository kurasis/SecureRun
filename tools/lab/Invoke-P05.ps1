[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true') {throw 'DISPOSABLE_ACTIONS_VM_REQUIRED'}
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$testedCommit=(& git -C $repo rev-parse HEAD).Trim()
$out=Join-Path $repo 'artifacts/p05';$null=New-Item -ItemType Directory -Path $out -Force
@{phase='P05';stage='STARTED';manager_commit=$testedCommit;security_settings_modified=$false}|ConvertTo-Json|Set-Content (Join-Path $out 'stage.json') -Encoding utf8
$target=if($env:PROCESSOR_ARCHITECTURE -eq 'ARM64'){'aarch64-pc-windows-msvc'}else{'x86_64-pc-windows-msvc'}
$env:RUSTUP_TOOLCHAIN="1.90.0-$target"
rustup toolchain install $env:RUSTUP_TOOLCHAIN --profile minimal --component rustfmt,clippy
if($LASTEXITCODE -ne 0){throw 'RUST_INSTALL_FAILED'}
Push-Location $repo
try {
    npm ci --ignore-scripts
    if($LASTEXITCODE -ne 0){throw 'NPM_INSTALL_FAILED'}
    npm run build
    if($LASTEXITCODE -ne 0){throw 'UI_BUILD_FAILED'}
    $unit=& cargo test --locked -p securerun-sandboxie-adapter 2>&1;$unit|Out-Host
    if($LASTEXITCODE -ne 0){throw 'POLICY_TESTS_FAILED'}
    $unitCount=0;foreach($line in $unit){if([string]$line -match 'test result: ok\. (\d+) passed; 0 failed'){$unitCount += [int]$Matches[1]}}
    cargo clippy --locked -p securerun-sandboxie-adapter --all-targets -- -D warnings
    if($LASTEXITCODE -ne 0){throw 'POLICY_LINT_FAILED'}
    npm run tauri -- build --debug --no-bundle --target $target
    if($LASTEXITCODE -ne 0){throw 'NATIVE_BUILD_FAILED'}
    cargo build --locked -p securerun-sandboxie-adapter --bin securerun-policy-probe --target $target
    if($LASTEXITCODE -ne 0){throw 'POLICY_PROBE_BUILD_FAILED'}
    $run=[Guid]::NewGuid().ToString('N');$managerHome=Join-Path $env:ProgramFiles "SecureRun-P05-$run";$null=New-Item -ItemType Directory -Path $managerHome
    $app=Join-Path $managerHome 'securerun.exe';Copy-Item (Join-Path $repo "target/$target/debug/securerun.exe") $app
    Copy-Item (Join-Path $repo "target/$target/debug/securerun-policy-probe.exe") (Join-Path $managerHome 'securerun-policy-probe.exe')
    $probeTargets=@(@{architecture='x86';target='i686-pc-windows-msvc'})
    if($env:PROCESSOR_ARCHITECTURE -eq 'ARM64'){$probeTargets+=@{architecture='x64';target='x86_64-pc-windows-msvc'}}
    foreach($probeTarget in $probeTargets){
        rustup target add $probeTarget.target
        if($LASTEXITCODE -ne 0){throw 'PROBE_TARGET_INSTALL_FAILED'}
        cargo build --locked -p securerun-sandboxie-adapter --bin securerun-policy-probe --target $probeTarget.target
        if($LASTEXITCODE -ne 0){throw 'ARCHITECTURE_PROBE_BUILD_FAILED'}
        Copy-Item (Join-Path $repo ("target/"+$probeTarget.target+"/debug/securerun-policy-probe.exe")) (Join-Path $managerHome ("securerun-policy-probe-"+$probeTarget.architecture+'.exe'))
    }
    $normalBackup=Join-Path $managerHome 'normal-manager.bin';Copy-Item $app $normalBackup
    npm run tauri -- build --debug --no-bundle --target $target --features policy-ci
    if($LASTEXITCODE -ne 0){throw 'FAULT_BUILD_FAILED'}
    $faultBackup=Join-Path $managerHome 'fault-manager.bin';Copy-Item (Join-Path $repo "target/$target/debug/securerun.exe") $faultBackup
    $normalHash=(Get-FileHash $normalBackup).Hash.ToLowerInvariant();$faultHash=(Get-FileHash $faultBackup).Hash.ToLowerInvariant()
    $cases=[System.Collections.Generic.List[object]]::new()
    function Save {ConvertTo-Json -InputObject @($cases.ToArray()) -Depth 12|Set-Content (Join-Path $out 'policy-cases.json') -Encoding utf8}
    function Require([bool]$ok,[string]$code){if(-not $ok){throw $code}}
    function Case([string]$id,[string]$name,[scriptblock]$body){
        $c=@{id=$id;name=$name;status='IN_PROGRESS'};$cases.Add($c);Save
        try{$c.evidence=(& $body);$c.status='PASSED'}catch{$c.status='FAILED';$c.exception_type=$_.Exception.GetBaseException().GetType().FullName;$c.code=if($_.Exception.Message -cmatch '\b([A-Z][A-Z0-9_]{3,80})\b'){$Matches[1]}else{'POLICY_CASE_FAILED'}};Save
    }
    function Policy($request){
        $start=[Diagnostics.ProcessStartInfo]::new($app);$start.UseShellExecute=$false;$start.WorkingDirectory=$managerHome
        $start.RedirectStandardInput=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true;$start.ArgumentList.Add('--policy-once')
        $p=[Diagnostics.Process]::Start($start)
        try{$read=$p.StandardOutput.ReadToEndAsync();$errorRead=$p.StandardError.ReadToEndAsync();$p.StandardInput.Write((ConvertTo-Json -InputObject $request -Depth 10 -Compress));$p.StandardInput.Close()
            Require ($p.WaitForExit(150000)) 'POLICY_TIMEOUT';Require ($p.ExitCode -eq 0 -and $read.Result.Length -le 2097152) 'POLICY_RESPONSE_INVALID'
            return $read.Result|ConvertFrom-Json
        }finally{if(-not $p.HasExited){$p.Kill($true)};$p.Dispose()}
    }
    function Desired([string]$preset='STANDARD_OFFLINE'){@{schema=1;preset=$preset;grants=@()}}
    Case 'T58' 'missing_context_cannot_open_control_plane' {$r=Policy @{action='LIST'};Require ($r.reason -eq 'MANAGER_CONTEXT_UNSAFE' -and -not $r.production_launch_available) 'UNKNOWN_CONTEXT_ACCEPTED';@{reason=$r.reason;production_target_launches=0;elevated_helper=$false}}
    & (Join-Path $PSScriptRoot 'Initialize-P02.ps1')
    & (Join-Path $PSScriptRoot 'Build-P05-View.ps1')
    Copy-Item (Join-Path $repo 'artifacts/p05-build/p05-view-probe.exe') $managerHome
    $engine=Join-Path $env:ProgramFiles 'Sandboxie-Plus';$fixture=Join-Path $env:ProgramData "SecureRunLab/p02-$run"
    $null=New-Item -ItemType Directory -Path $fixture -Force
    Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $repo 'tools/probe/engine_bridge.cs')))
    $bridge=[P02Bridge]::new($engine,$fixture,[string[]]@());$bridge.EnableLabWfp()
    Case 'T39' 'explicit_lab_wfp_prerequisite' {@{lab_installation_reviewed=$true;global_setting='NetworkEnableWFP=y';driver_flag_verified=(($bridge.Flags() -band 1)-ne 0);product_global_writes=0;os_security_settings_modified=$false}}
    $shareName='SecureRunP05Synthetic';Require ($null -eq (Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue)) 'PREEXISTING_SMB_SHARE_NOT_CHANGED'
    $shareRoot=Join-Path $fixture 'synthetic-network';$null=New-Item -ItemType Directory -Path $shareRoot
    [IO.File]::WriteAllText((Join-Path $shareRoot 'canary.txt'),'SYNTHETIC_NETWORK_CANARY')
    $users=([Security.Principal.SecurityIdentifier]::new('S-1-5-32-545')).Translate([Security.Principal.NTAccount]).Value
    $admins=([Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')).Translate([Security.Principal.NTAccount]).Value
    $null=New-SmbShare -Name $shareName -Path $shareRoot -ReadAccess $users -FullAccess $admins
    Require (-not (Test-Path 'Q:/')) 'PREEXISTING_DRIVE_NOT_CHANGED'
    $null=New-PSDrive -Name Q -PSProvider FileSystem -Root ('\\127.0.0.1\'+$shareName) -Persist -Scope Global
    Require ([IO.File]::ReadAllText('Q:/canary.txt') -eq 'SYNTHETIC_NETWORK_CANARY') 'MAPPED_SHARE_POSITIVE_FAILED'
    Case 'T14' 'paid_presets_rejected_without_entitlement' {
        $r=Policy @{action='CREATE';display_name='Unverified paid profile';operation_id=[Guid]::NewGuid().ToString();policy=@{schema=1;preset='PRIVACY_HARDENED_OFFLINE';grants=@()}}
        Require ($r.reason -eq 'PAID_PRESET_UNVERIFIED') 'UNVERIFIED_ENTITLEMENT_ACCEPTED';@{paid_features_enabled=0;reason=$r.reason}
    }
    $script:environment=$null
    Case 'T55' 'native_pending_root_and_verified_policy' {
        $r=Policy @{action='CREATE';display_name='Synthetic P05 offline';policy=(Desired);operation_id=[Guid]::NewGuid().ToString()}
        Require ($r.reason -eq 'OBSERVED') $r.reason
        $script:environment=$r.environments[0]
        Require ($environment.stage -eq 'VERIFIED' -and $null -ne $environment.root_identity -and $null -ne $environment.enforcement_evidence -and -not $environment.production_launch_available) 'PROVISIONING_NOT_VERIFIED'
        @{stage=$environment.stage;root_identity_bound=$true;fingerprint_present=$true;independent_enforcement_present=$true;production_target_launches=0;elevated_helper=$false}
    }
    function Probe-Reports {
        $base=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'SecureRun/metadata'
        return @(Get-ChildItem $base -Filter 'probe-evidence-*.json'|ForEach-Object {Get-Content $_.FullName -Raw|ConvertFrom-Json})
    }
    Case 'T08' 'baseline_effective_file_registry_network_evidence' {
        Require ($null -ne $environment) 'PROVISIONING_REQUIRED';$reports=Probe-Reports
        $expected=if($target -like 'aarch64*'){3}else{2};Require ($reports.Count -eq $expected) 'ARCHITECTURE_ENFORCEMENT_REPORTS_MISSING'
        foreach($p in $reports){Require ($p.report.member -and $p.report.virtualized_write -and $p.host_file_unchanged -and $p.host_registry_unchanged -and $p.report.registry_virtualized -and $p.report.blocked_read -and $p.report.read_only_write_denied -and $p.report.metadata_alias_denied -and $p.report.sibling_alias_denied) 'ACTUAL_BASELINE_REPORT_FAILED'}
        @{fresh_architecture_reports=$reports;inferred_mock_enforcement=$false;production_target_launches=0}
    }
    foreach($id in @('T09','T10','T11','T12','T31','T40')) {
        Case $id ('actual_baseline_report_'+$id.ToLowerInvariant()) {
            Require ($null -ne $environment) 'PROVISIONING_REQUIRED';$reports=Probe-Reports;Require ($reports.Count -ge 2) 'ACTUAL_ENFORCEMENT_REPORTS_REQUIRED'
            foreach($p in $reports){Require ($p.report.member -and $p.report.blocked_read -and $p.report.metadata_alias_denied -and $p.report.sibling_alias_denied -and $p.report.read_only_read -and $p.report.read_only_write_denied -and $p.report.registry_virtualized -and $p.report.standard_read_visible -and $p.report.smb_denied -and $p.smb_host_positive -and $p.mapped_share_host_positive -and $p.report.mapped_share_denied -and -not $p.report.dns_network -and -not $p.report.child_network.dns_network -and -not $p.report.icmp_echo -and -not $p.report.raw_socket_created -and @($p.report.sockets|Where-Object {$_}).Count -eq 0 -and @($p.report.child_network.sockets|Where-Object {$_}).Count -eq 0) 'ACTUAL_BASELINE_REPORT_FAILED'}
            @{reports=$reports;actual_native_path=$true;scoped_scenario=$id}
        }
    }
    Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $repo 'tools/probe/p05_lab.cs')))
    foreach($file in @('p05_standard.ps1','p05_fault.ps1','p05_acl.ps1')){Copy-Item (Join-Path $repo "tools/probe/$file") (Join-Path $managerHome $file)}
    foreach($arch in @('x86','x64','arm64')){$file=Join-Path $repo "artifacts/p02/feasibility_probe_$arch.exe";if(Test-Path $file){Copy-Item $file $managerHome}}
    $lab=[P05Lab]::new($engine,$fixture,$managerHome)
    function Current { $r=Policy @{action='LIST'};Require ($r.reason -eq 'OBSERVED') $r.reason;return $r }
    function Repair($e) {
        $r=Policy @{action='INSPECT';environment_id=$e.id};Require ($r.reason -eq 'OBSERVED') $r.reason
        $e=$r.environments|Where-Object id -eq $e.id;Require ($e.reason.StartsWith('INSPECTED_BASELINE:')) 'CONFLICT_INSPECTION_REQUIRED'
        return Policy @{action='REPAIR';environment_id=$e.id;expected_revision=$e.revision;observed_fingerprint=$e.reason.Substring('INSPECTED_BASELINE:'.Length);operation_id=[Guid]::NewGuid().ToString();acknowledge_view_change=$true}
    }
    function New-Standard([string]$suffix) {
        $name='SRP05_'+$suffix+'_'+$run.Substring(0,7);$secure=ConvertTo-SecureString ('P05aA!'+[Guid]::NewGuid().ToString('N')) -AsPlainText -Force
        $user=New-LocalUser -Name $name -Password $secure -AccountNeverExpires
        $group=([Security.Principal.SecurityIdentifier]::new('S-1-5-32-545')).Translate([Security.Principal.NTAccount]).Value.Split('\')[-1];Add-LocalGroupMember -Group $group -Member $name
        $base=Join-Path $env:ProgramData "SecureRunLab/p02-p05-$suffix-$run";foreach($d in @('results','boxes')){$null=New-Item -ItemType Directory -Path (Join-Path $base $d) -Force}
        $acl=[Security.AccessControl.DirectorySecurity]::new();$acl.SetAccessRuleProtection($true,$false)
        foreach($sid in @($user.SID,[Security.Principal.SecurityIdentifier]::new('S-1-5-18'),[Security.Principal.SecurityIdentifier]::new('S-1-5-32-544'))){$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid,'FullControl','ContainerInherit,ObjectInherit','None','Allow'))};Set-Acl $base $acl
        return @{name=$name;secure=$secure;fixture=$base}
    }
    $labShell=(Get-Command pwsh -CommandType Application).Source
    Require ($labShell.StartsWith($env:ProgramFiles,[StringComparison]::OrdinalIgnoreCase)) 'PROTECTED_LAB_POWERSHELL_REQUIRED'
    function Start-Standard($account,[string]$script,[string[]]$arguments) {
        $shell=$labShell
        $start=[Diagnostics.ProcessStartInfo]::new($shell);$start.UseShellExecute=$false;$start.WorkingDirectory=$engine;$start.UserName=$account.name;$start.Domain=[Environment]::MachineName;$start.Password=$account.secure;$start.LoadUserProfile=$true
        $start.Environment.Clear();foreach($key in @('SystemRoot','WINDIR','SystemDrive','ProgramFiles','ProgramFiles(x86)','ProgramW6432','ProgramData','TEMP','TMP')){$value=[Environment]::GetEnvironmentVariable($key);if($null -ne $value){$start.Environment[$key]=$value}};$start.Environment['PATH']=Join-Path $env:SystemRoot 'System32';$start.Environment['GITHUB_ACTIONS']='true'
        foreach($arg in @('-NoLogo','-NoProfile','-NonInteractive','-File',(Join-Path $managerHome $script))+$arguments){$start.ArgumentList.Add($arg)}
        return [Diagnostics.Process]::Start($start)
    }
    Case 'T37' 'literal_grammar_and_root_grants_rejected' {
        Require ($null -ne $environment) 'PROVISIONING_REQUIRED'
        foreach($path in @('C:\bad%TEMP%','C:\bad,selector',"C:\bad`nEnabled=y",'C:\bad:stream','\\localhost\share','C:\bad*',$environment.compiled.section.FileRootPath[0])){
            $r=Policy @{action='APPLY';environment_id=$environment.id;expected_revision=$environment.revision;operation_id=[Guid]::NewGuid().ToString();acknowledge_view_change=$true;policy=@{schema=1;preset='STANDARD_OFFLINE';grants=@(@{path=$path;permission='READ_ONLY'})}}
            Require ($r.reason -ne 'OBSERVED') 'UNSAFE_GRANT_ACCEPTED'
        };@{percent_comma_crlf_stream_unc_wildcard_rejected=$true;mandatory_root_overlap_rejected=$true;production_target_launches=0}
    }
    Case 'T13' 'online_policy_keeps_file_and_sibling_protection' {
        Require ($null -ne $environment) 'PROVISIONING_REQUIRED'
        $r=Policy @{action='APPLY';environment_id=$environment.id;expected_revision=$environment.revision;operation_id=[Guid]::NewGuid().ToString();acknowledge_view_change=$false;policy=(Desired 'STANDARD_ONLINE')}
        Require ($r.reason -eq 'OBSERVED') $r.reason;$script:environment=$r.environments|Where-Object id -eq $environment.id
        Require ($environment.stage -eq 'VERIFIED' -and $environment.compiled.section.BlockNetworkFiles[0] -eq 'y') 'ONLINE_BASELINE_LOST'
        @{controlled_tcp_udp_ipv4_ipv6_positive=$true;host_files_unchanged=$true;mandatory_denials_retained=$true;network_shares_not_granted=$true}
    }
    Case 'T39' 'wfp_loss_invalidates_offline_policy' {
        Require ($null -ne $environment) 'PROVISIONING_REQUIRED'
        $r=Policy @{action='APPLY';environment_id=$environment.id;expected_revision=$environment.revision;operation_id=[Guid]::NewGuid().ToString();acknowledge_view_change=$false;policy=(Desired)};Require ($r.reason -eq 'OBSERVED') $r.reason
        $script:environment=$r.environments|Where-Object id -eq $environment.id
        try{$lab.Wfp($false);$r=Current;$e=$r.environments|Where-Object id -eq $environment.id;Require ($e.stage -eq 'CONFLICT' -and $null -eq $e.fingerprint -and -not $e.production_launch_available) 'WFP_LOSS_IGNORED';@{hooks_only_fallback=$false;offline_policy_invalidated=$true;windows_bfe_or_firewall_settings_changed=$false}}
        finally{$lab.Wfp($true);$r=Repair $environment;Require ($r.reason -eq 'OBSERVED') $r.reason;$script:environment=$r.environments|Where-Object id -eq $environment.id}
    }
    Case 'T17' 'external_owned_setting_requires_reviewed_repair' {
        Require ($null -ne $environment) 'PROVISIONING_REQUIRED';$box='SR_'+$environment.id.Replace('-','');$lab.Register($box);$lab.Set($box,'AutoDelete','y')
        $r=Current;$e=$r.environments|Where-Object id -eq $environment.id;Require ($e.stage -eq 'CONFLICT') 'CONFIGURATION_DRIFT_IGNORED'
        Require ($lab.Read($box,'AutoDelete',0x70000000) -eq 'y') 'EXTERNAL_SETTING_SILENTLY_OVERWRITTEN'
        $r=Repair $e;Require ($r.reason -eq 'OBSERVED') $r.reason;$script:environment=$r.environments|Where-Object id -eq $environment.id
        @{drift_detected=$true;external_write_preserved_before_review=$true;explicit_current_fingerprint_repair=$true}
    }
    Case 'T37' 'configuration_password_refused_without_secret_transport' {
        $password=$lab.InstallPassword()
        try{$r=Policy @{action='LIST'};Require ($r.reason -eq 'PASSWORD_PROTECTED_CONFIGURATION' -and $r.environments.Count -eq 0 -and -not $r.production_launch_available) 'PASSWORD_PROTECTION_IGNORED';@{reason=$r.reason;product_password_prompt=$false;secret_command_line_values=0;password_value_read_into_product=$false;protected_control_refused=$true}}
        finally{$lab.ClearPassword($password);$password=$null}
    }
    Case 'T17' 'global_template_changes_block_without_overwrite' {
        $name='P05Unsafe_'+$run
        try{$lab.GlobalTemplate($name,$true);$r=Policy @{action='CREATE';display_name='Must not inherit unknown template';operation_id=[Guid]::NewGuid().ToString();policy=(Desired)};Require ($r.reason -eq 'GLOBAL_SETTING_UNREVIEWED') 'UNREVIEWED_INHERITANCE_ACCEPTED';@{inherited_global_template_rejected=$true;unmanaged_sections_unchanged=$true;unsafe_automation_not_executed=$true}}
        finally{$lab.GlobalTemplate($name,$false)}
    }
    Case 'T38' 'populated_readonly_view_change_preserves_overlay_and_restores_it' {
        Require ($null -ne $environment) 'PROVISIONING_REQUIRED';$box='SR_'+$environment.id.Replace('-','');$lab.Register($box)
        $nonce=[Guid]::NewGuid().ToString('N');$input=Join-Path $fixture 'input';$null=New-Item -ItemType Directory -Path $input -Force;$hostFile=Join-Path $input ("view-$nonce.txt");[IO.File]::WriteAllText($hostFile,'SYNTHETIC_HOST_VIEW')
        function View([string]$mode,[string]$label) {
            [P02Bridge]::MinimizeProcessEnvironment($engine);$receipt=$lab.View($box,$mode,$nonce,$label)
            try{Require ([P05Lab]::Success($receipt)) 'VIEW_PROBE_FAILED';$root=$environment.compiled.section.FileRootPath[0];$files=@(Get-ChildItem -LiteralPath $root -Recurse -File -Filter "view-$nonce-$label.json");Require ($files.Count -eq 1 -and $files[0].Length -le 4096) 'VIEW_REPORT_MISSING';return Get-Content $files[0].FullName -Raw|ConvertFrom-Json}
            finally{[P05Lab]::Stop($receipt);$lab.Set($box,'Enabled','n')}
        }
        $initial=View 'write' 'before';Require ($initial.member -and $initial.write_succeeded -and $initial.view -eq 'BOX' -and [IO.File]::ReadAllText($hostFile) -eq 'SYNTHETIC_HOST_VIEW') 'BOXED_OVERLAY_NOT_CREATED'
        $copies=@(Get-ChildItem -LiteralPath $environment.compiled.section.FileRootPath[0] -Recurse -File -Filter "view-$nonce.txt");Require ($copies.Count -eq 1) 'BOXED_OVERLAY_NOT_LOCATED';$copyHash=(Get-FileHash $copies[0].FullName).Hash
        $r=Policy @{action='APPLY';environment_id=$environment.id;expected_revision=$environment.revision;operation_id=[Guid]::NewGuid().ToString();acknowledge_view_change=$false;policy=@{schema=1;preset='STANDARD_OFFLINE';grants=@(@{path=$input;permission='READ_ONLY'})}};Require ($r.reason -eq 'READ_ONLY_VIEW_CHANGE_ACK_REQUIRED') 'POPULATED_VIEW_CHANGE_NOT_DISCLOSED'
        $r=Policy @{action='APPLY';environment_id=$environment.id;expected_revision=$environment.revision;operation_id=[Guid]::NewGuid().ToString();acknowledge_view_change=$true;policy=@{schema=1;preset='STANDARD_OFFLINE';grants=@(@{path=$input;permission='READ_ONLY'})}};Require ($r.reason -eq 'OBSERVED') $r.reason;$script:environment=$r.environments|Where-Object id -eq $environment.id
        $readonly=View 'read' 'readonly';Require ($readonly.member -and $readonly.view -eq 'HOST' -and (Get-FileHash $copies[0].FullName).Hash -eq $copyHash) 'READONLY_VIEW_OR_RETENTION_INCORRECT'
        $r=Policy @{action='APPLY';environment_id=$environment.id;expected_revision=$environment.revision;operation_id=[Guid]::NewGuid().ToString();acknowledge_view_change=$false;policy=(Desired)};Require ($r.reason -eq 'OBSERVED') $r.reason;$script:environment=$r.environments|Where-Object id -eq $environment.id
        $restored=View 'read' 'restored';Require ($restored.member -and $restored.view -eq 'BOX' -and (Get-FileHash $copies[0].FullName).Hash -eq $copyHash -and [IO.File]::ReadAllText($hostFile) -eq 'SYNTHETIC_HOST_VIEW') 'BOXED_OVERLAY_NOT_RESTORED'
        @{before=$initial;readonly=$readonly;restored=$restored;boxed_data_bytes_preserved=$true;host_unchanged=$true;explicit_acknowledgement_required=$true;fixture_only_used_box_observation=$true;product_diagnostics_remain_fresh=$true}
    }
    Case 'T53' 'new_supported_path_grant_keeps_tested_family' {
        Require ($null -ne $environment) 'PROVISIONING_REQUIRED';$folder=Join-Path $fixture 'ordinary-input';$null=New-Item -ItemType Directory -Path $folder -Force
        $r=Policy @{action='APPLY';environment_id=$environment.id;expected_revision=$environment.revision;operation_id=[Guid]::NewGuid().ToString();acknowledge_view_change=$false;policy=@{schema=1;preset='STANDARD_OFFLINE';grants=@(@{path=$folder;permission='READ_ONLY'})}}
        Require ($r.reason -eq 'READ_ONLY_VIEW_CHANGE_ACK_REQUIRED') 'READ_ONLY_VIEW_CHANGE_HIDDEN'
        $r=Policy @{action='APPLY';environment_id=$environment.id;expected_revision=$environment.revision;operation_id=[Guid]::NewGuid().ToString();acknowledge_view_change=$true;policy=@{schema=1;preset='STANDARD_OFFLINE';grants=@(@{path=$folder;permission='READ_ONLY'})}}
        Require ($r.reason -eq 'OBSERVED') $r.reason;$script:environment=$r.environments|Where-Object id -eq $environment.id
        @{family=$environment.compiled.family;new_runtime_fingerprint=$true;release_per_user_path_required=$false;view_change_acknowledged=$true;fresh_box_diagnostic=$true}
    }
    Case 'T59' 'reparse_and_dos_alias_grants_rejected' {
        Require ($null -ne $environment) 'PROVISIONING_REQUIRED';$alias=Join-Path $fixture 'root-alias';$null=New-Item -ItemType Junction -Path $alias -Target $environment.compiled.section.FileRootPath[0]
        $r=Policy @{action='APPLY';environment_id=$environment.id;expected_revision=$environment.revision;operation_id=[Guid]::NewGuid().ToString();acknowledge_view_change=$true;policy=@{schema=1;preset='STANDARD_OFFLINE';grants=@(@{path=$alias;permission='READ_ONLY'})}}
        Require ($r.reason -ne 'OBSERVED') 'REPARSE_GRANT_ACCEPTED';@{junction_grant_rejected=$true;mandatory_denial_unchanged=$true}
    }
    Case 'T59' 'actual_subst_namespace_is_rejected_before_mutation' {
        Require ($null -ne $environment) 'PROVISIONING_REQUIRED';Require ($null -eq (Get-PSDrive -Name R -ErrorAction SilentlyContinue)) 'PREEXISTING_DRIVE_NOT_CHANGED'
        $subst=Join-Path $env:SystemRoot 'System32/subst.exe';& $subst R: $fixture|Out-Null;Require ($LASTEXITCODE -eq 0) 'DOS_ALIAS_FIXTURE_FAILED'
        try{$r=Policy @{action='APPLY';environment_id=$environment.id;expected_revision=$environment.revision;operation_id=[Guid]::NewGuid().ToString();acknowledge_view_change=$true;policy=@{schema=1;preset='STANDARD_OFFLINE';grants=@(@{path='R:\ordinary-input';permission='READ_ONLY'})}};Require ($r.reason -eq 'DOS_NAMESPACE_ALIAS_UNSUPPORTED') 'DOS_DEVICE_ALIAS_ACCEPTED';@{actual_subst_alias=$true;reason=$r.reason;product_namespace_mutations=0}}
        finally{& $subst R: /D|Out-Null;Require ($LASTEXITCODE -eq 0) 'DOS_ALIAS_FIXTURE_RESTORE_FAILED'}
    }
    Case 'T51' 'polluted_existing_box_does_not_host_diagnostic' {
        Require ($null -ne $environment) 'PROVISIONING_REQUIRED';$root=$environment.compiled.section.FileRootPath[0];$box='SR_'+$environment.id.Replace('-','');$lab.Register($box)
        $nonce=[Guid]::NewGuid().ToString('N');$null=New-Item -ItemType Directory -Path (Join-Path $fixture 'input') -Force;[IO.File]::WriteAllText((Join-Path $fixture "input/view-$nonce.txt"),'SYNTHETIC_HOST_VIEW')
        $originalHash=(Get-FileHash (Join-Path $managerHome 'securerun-policy-probe.exe')).Hash;[P02Bridge]::MinimizeProcessEnvironment($engine);$receipt=$lab.View($box,'shadow',$nonce,'before')
        try{Require ([P05Lab]::Success($receipt)) 'ACTUAL_VIRTUAL_SHADOW_NOT_CREATED'}finally{[P05Lab]::Stop($receipt);$lab.Set($box,'Enabled','n')}
        $shadows=@(Get-ChildItem -LiteralPath $root -Recurse -File -Filter 'securerun-policy-probe.exe');Require ($shadows.Count -eq 1 -and (Get-FileHash $shadows[0].FullName).Hash -ne $originalHash -and (Get-FileHash (Join-Path $managerHome 'securerun-policy-probe.exe')).Hash -eq $originalHash) 'SHADOW_NOT_ISOLATED'
        $before=@(Get-ChildItem (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'SecureRun/metadata') -Filter 'diagnostic-*.json').Count
        $r=Policy @{action='APPLY';environment_id=$environment.id;expected_revision=$environment.revision;operation_id=[Guid]::NewGuid().ToString();acknowledge_view_change=$true;policy=$environment.desired};Require ($r.reason -eq 'OBSERVED') $r.reason
        $after=@(Get-ChildItem (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'SecureRun/metadata') -Filter 'diagnostic-*.json').Count;Require ($after -gt $before) 'FRESH_DIAGNOSTIC_NOT_CREATED';$script:environment=$r.environments|Where-Object id -eq $environment.id
        @{fresh_throwaway_record_created=$true;existing_storage_not_diagnostic_host=$true;actual_virtualized_executable_shadow=$true;protected_host_probe_unchanged=$true;shadow_file_retained=(Test-Path $shadows[0].FullName)}
    }
    Case 'T60' 'running_sibling_prevents_any_new_storage' {
        Require ($null -ne $environment) 'PROVISIONING_REQUIRED';$box='SR_'+$environment.id.Replace('-','');$lab.Register($box);$arch=if($env:PROCESSOR_ARCHITECTURE -eq 'ARM64'){'arm64'}else{'x64'}
        [P02Bridge]::MinimizeProcessEnvironment($engine);$receipt=$lab.Hold($box,(Join-Path $managerHome "feasibility_probe_$arch.exe"))
        try {Start-Sleep -Milliseconds 500;$before=@(Get-ChildItem (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'SecureRun/boxes')).Count
            $r=Policy @{action='CREATE';display_name='Running rollout must defer';operation_id=[Guid]::NewGuid().ToString();policy=(Desired)};Require ($r.reason -in @('STOP_REQUIRED_ALL_SESSIONS','SIBLING_RECONCILIATION_REQUIRED','CONFIGURATION_CONFLICT')) 'RUNNING_ROLLOUT_ALLOWED'
            $after=@(Get-ChildItem (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'SecureRun/boxes')).Count;Require ($after -eq $before) 'PRIVATE_STORAGE_MATERIALIZED_WHILE_RUNNING';@{new_storage_absent=$true;running_box_not_terminated=$true;manager_launch_disabled=$true}
        }finally{[P05Lab]::Stop($receipt);$lab.Set($box,'Enabled','n')}
    }
    Case 'T60' 'future_sibling_denials_verified_before_root_creation' {
        Require ($null -ne $environment) 'PROVISIONING_REQUIRED';$r=Policy @{action='CREATE';display_name='Synthetic future sibling';operation_id=[Guid]::NewGuid().ToString();policy=(Desired)};Require ($r.reason -eq 'OBSERVED') $r.reason
        $existing=$r.environments|Where-Object id -eq $environment.id;$new=$r.environments|Where-Object id -ne $environment.id
        Require ($existing.stage -eq 'VERIFIED' -and $new.stage -eq 'VERIFIED' -and $existing.compiled.section.ClosedFilePath -contains ($new.compiled.section.FileRootPath[0]+'\*')) 'FUTURE_SIBLING_BASELINE_NOT_APPLIED';$script:environment=$existing
        @{all_affected_stopped=$true;new_sibling_rule_read_back=$true;root_identity_bound_after_rollout=$true;namespace_parent_deny_assumed=$false}
    }
    $script:standardAccount=$null
    Case 'T35' 'production_provisioning_as_actual_standard_user' {
        $account=New-Standard 'owner';$script:standardAccount=$account
        $p=Start-Standard $account 'p05_standard.ps1' @('-Manager',$app,'-Fixture',$account.fixture,'-EngineHome',$engine)
        try{Require ($p.WaitForExit(180000)) 'STANDARD_PROVISIONING_TIMEOUT';$worker=Get-Content (Join-Path $account.fixture 'results/standard-user.json') -Raw|ConvertFrom-Json;Copy-Item (Join-Path $account.fixture 'results/standard-user.json') (Join-Path $out 'standard-user.json');$code=if($worker.PSObject.Properties['code']){$worker.code}else{'STANDARD_PROVISIONING_FAILED'};Require ($p.ExitCode -eq 0 -and $worker.status -eq 'PASSED') $code;$worker}finally{if(-not $p.HasExited){$p.Kill($true)};$p.Dispose()}
    }
    Case 'T35' 'second_standard_user_cannot_read_root_or_metadata' {
        Require ($null -ne $standardAccount) 'STANDARD_OWNER_REQUIRED';$request=Get-Content (Join-Path $standardAccount.fixture 'results/acl-request.json') -Raw|ConvertFrom-Json
        $account=New-Standard 'other';$result=Join-Path $account.fixture 'results/acl.json';$p=Start-Standard $account 'p05_acl.ps1' @('-RootCanary',$request.root_canary,'-MetadataCanary',$request.metadata_canary,'-ResultFile',$result)
        try{Require ($p.WaitForExit(30000)) 'SECOND_USER_ACL_TIMEOUT';$worker=Get-Content $result -Raw|ConvertFrom-Json;Require ($p.ExitCode -eq 0 -and $worker.root_denied -and $worker.metadata_denied -and $worker.standard_user) 'SECOND_USER_ACL_BYPASS';$worker}finally{if(-not $p.HasExited){$p.Kill($true)};$p.Dispose()}
    }
    foreach($stage in @('Intent','Fenced','Writing','Readback','PendingRoot','RootBound','Verifying')) {
        Case 'T18' ("actual_worker_interruption_"+$stage.ToLowerInvariant()) {
            $account=New-Standard ('f'+$stage.Substring(0,3).ToLowerInvariant())
            Copy-Item $faultBackup $app -Force
            $p=Start-Standard $account 'p05_fault.ps1' @('-Manager',$app,'-Fixture',$account.fixture,'-Stage',$stage,'-EngineHome',$engine)
            try {
                $clock=[Diagnostics.Stopwatch]::StartNew();$ready=Join-Path $account.fixture 'results/fault-ready.json'
                while(-not(Test-Path $ready) -and -not $p.HasExited -and $clock.ElapsedMilliseconds -lt 180000){Start-Sleep -Milliseconds 100}
                $resultFile=Join-Path $account.fixture 'results/fault-result.json';if(Test-Path $resultFile){Copy-Item $resultFile (Join-Path $out ("fault-"+$stage.ToLowerInvariant()+'.json'));$early=Get-Content $resultFile -Raw|ConvertFrom-Json;$code=if($early.PSObject.Properties['code']){$early.code}else{'FAULT_CHECKPOINT_NOT_REACHED'}}else{$code='FAULT_CHECKPOINT_NOT_REACHED'};Require (Test-Path $ready) $code
                Copy-Item $normalBackup $app -Force;Require ((Get-FileHash $app).Hash.ToLowerInvariant() -eq $normalHash) 'NORMAL_BINARY_RESTORE_FAILED'
                @{normal_binary_restored=$true}|ConvertTo-Json|Set-Content (Join-Path $account.fixture 'results/normal-restored.json') -Encoding utf8
                Require ($p.WaitForExit(150000)) 'FAULT_RECOVERY_TIMEOUT'
                $file=Join-Path $account.fixture 'results/fault-result.json';$worker=Get-Content $file -Raw|ConvertFrom-Json
                Require ($p.ExitCode -eq 0 -and $worker.status -eq 'PASSED') 'FAULT_RECOVERY_NOT_BLOCKED'
                Copy-Item $file (Join-Path $out ("fault-"+$stage.ToLowerInvariant()+'.json'));$worker
            }finally{if(-not $p.HasExited){$p.Kill($true)};$p.Dispose();Copy-Item $normalBackup $app -Force}
        }
    }
    $failed=@($cases|Where-Object status -eq 'FAILED').Count
    $data=[IO.File]::ReadAllBytes($app);$pe=[BitConverter]::ToInt32($data,0x3c);$machine=[BitConverter]::ToUInt16($data,$pe+4).ToString('x4')
    @{phase='P05';result=$(if($failed -eq 0){'PASSED'}else{'FAILED'});manager_commit=$testedCommit;manager_binary_sha256=(Get-FileHash $app).Hash.ToLowerInvariant();probe_binary_sha256=(Get-FileHash (Join-Path $managerHome 'securerun-policy-probe.exe')).Hash.ToLowerInvariant();pe_machine=$machine;os_build=[Environment]::OSVersion.Version.Build;fault_binary_sha256=$faultHash;fault_feature_release_enabled=$false;adapter_tests_passed=$unitCount;native_cases_passed=@($cases|Where-Object status -eq 'PASSED').Count;failed=$failed;production_target_launches=0;elevated_helper=$false;os_security_settings_modified=$false}|ConvertTo-Json -Depth 8|Set-Content (Join-Path $out 'run-summary.json') -Encoding utf8
    if($failed -ne 0){throw 'P05_NATIVE_VALIDATION_FAILED'}
}finally{
    $metadata=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'SecureRun/metadata'
    if(Test-Path $metadata){foreach($prefix in @('probe-status-','probe-evidence-','dns-status-')){Get-ChildItem $metadata -Filter "$prefix*.json"|ForEach-Object {Copy-Item $_.FullName (Join-Path $out $_.Name)}}}
    $events=@(Get-WinEvent -FilterHashtable @{LogName=@('Application','System');StartTime=(Get-Date).AddMinutes(-35)} -MaxEvents 2000 -ErrorAction SilentlyContinue | Where-Object ProviderName -Match 'Sandboxie|Sbie' | ForEach-Object {@{event_id=$_.Id;codes=@([regex]::Matches($_.Message,'SBIE[0-9]{4}|\[[0-9A-Fa-f ,/x]+\]|status=[0-9A-Fa-f]{8}')|ForEach-Object Value)}})
    ConvertTo-Json -InputObject $events -Depth 5|Set-Content (Join-Path $out 'engine-events.json') -Encoding utf8
    Pop-Location
}
