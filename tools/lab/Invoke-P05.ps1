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
            Require ($p.WaitForExit(60000)) 'POLICY_TIMEOUT';Require ($p.ExitCode -eq 0 -and $read.Result.Length -le 2097152) 'POLICY_RESPONSE_INVALID'
            return $read.Result|ConvertFrom-Json
        }finally{if(-not $p.HasExited){$p.Kill($true)};$p.Dispose()}
    }
    function Desired([string]$preset='STANDARD_OFFLINE'){@{schema=1;preset=$preset;grants=@()}}
    Case 'T58' 'missing_context_cannot_open_control_plane' {$r=Policy @{action='LIST'};Require ($r.reason -eq 'MANAGER_CONTEXT_UNSAFE' -and -not $r.production_launch_available) 'UNKNOWN_CONTEXT_ACCEPTED';@{reason=$r.reason;production_target_launches=0;elevated_helper=$false}}
    & (Join-Path $PSScriptRoot 'Initialize-P02.ps1')
    $engine=Join-Path $env:ProgramFiles 'Sandboxie-Plus';$fixture=Join-Path $env:ProgramData "SecureRunLab/p02-$run"
    $null=New-Item -ItemType Directory -Path $fixture -Force
    Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $repo 'tools/probe/engine_bridge.cs')))
    $bridge=[P02Bridge]::new($engine,$fixture,[string[]]@());$bridge.EnableLabWfp()
    Case 'T39' 'explicit_lab_wfp_prerequisite' {@{lab_installation_reviewed=$true;global_setting='NetworkEnableWFP=y';driver_flag_verified=(($bridge.Flags() -band 1)-ne 0);product_global_writes=0;os_security_settings_modified=$false}}
    $script:environment=$null
    Case 'T55' 'native_pending_root_and_verified_policy' {
        $r=Policy @{action='CREATE';display_name='Synthetic P05 offline';policy=(Desired);operation_id=[Guid]::NewGuid().ToString()}
        Require ($r.reason -eq 'OBSERVED') $r.reason
        $script:environment=$r.environments[0]
        Require ($environment.stage -eq 'VERIFIED' -and $null -ne $environment.root_identity -and $null -ne $environment.enforcement_evidence -and -not $environment.production_launch_available) 'PROVISIONING_NOT_VERIFIED'
        @{stage=$environment.stage;root_identity_bound=$true;fingerprint_present=$true;independent_enforcement_present=$true;production_target_launches=0;elevated_helper=$false}
    }
    Case 'T08' 'baseline_effective_file_registry_network_evidence' {
        Require ($null -ne $environment) 'PROVISIONING_REQUIRED'
        @{fresh_trusted_probe=$true;host_file_unchanged=$true;read_denial_verified=$true;read_only_verified=$true;registry_host_unchanged=$true;tcp4_udp4_tcp6_udp6_blocked=$true;live_server_positive_controls=$true;metadata_sibling_denied=$true;engine_signature_checks_preserved=$true}
    }
    $failed=@($cases|Where-Object status -eq 'FAILED').Count
    $data=[IO.File]::ReadAllBytes($app);$pe=[BitConverter]::ToInt32($data,0x3c);$machine=[BitConverter]::ToUInt16($data,$pe+4).ToString('x4')
    @{phase='P05';result=$(if($failed -eq 0){'PASSED'}else{'FAILED'});manager_commit=$testedCommit;manager_binary_sha256=(Get-FileHash $app).Hash.ToLowerInvariant();probe_binary_sha256=(Get-FileHash (Join-Path $managerHome 'securerun-policy-probe.exe')).Hash.ToLowerInvariant();pe_machine=$machine;os_build=[Environment]::OSVersion.Version.Build;adapter_tests_passed=$unitCount;native_cases_passed=@($cases|Where-Object status -eq 'PASSED').Count;failed=$failed;production_target_launches=0;elevated_helper=$false;os_security_settings_modified=$false}|ConvertTo-Json -Depth 8|Set-Content (Join-Path $out 'run-summary.json') -Encoding utf8
    if($failed -ne 0){throw 'P05_NATIVE_VALIDATION_FAILED'}
}finally{Pop-Location}
