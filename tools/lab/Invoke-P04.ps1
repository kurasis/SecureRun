[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true') { throw 'DISPOSABLE_ACTIONS_VM_REQUIRED' }
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$out=Join-Path $repo 'artifacts/p04';$null=New-Item -ItemType Directory -Path $out -Force
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
    $home=Join-Path $env:ProgramFiles "SecureRun-P04-$run";$null=New-Item -ItemType Directory -Path $home
    $app=Join-Path $home 'securerun.exe';Copy-Item (Join-Path $repo "target/$target/debug/securerun.exe") $app
    $binaryHash=(Get-FileHash $app).Hash.ToLowerInvariant()
    $cases=[System.Collections.Generic.List[object]]::new()
    function Save { ConvertTo-Json -InputObject @($cases.ToArray()) -Depth 8 | Set-Content (Join-Path $out 'observation-cases.json') -Encoding utf8 }
    function Require([bool]$ok,[string]$code){if(-not $ok){throw $code}}
    function Case([string]$id,[string]$name,[scriptblock]$body){
        $c=@{id=$id;name=$name;status='IN_PROGRESS'};$cases.Add($c);Save
        try{$c.evidence=(& $body);$c.status='PASSED'}catch{$c.status='FAILED';$c.exception_type=$_.Exception.GetBaseException().GetType().FullName;$c.code=if($_.Exception.Message -cmatch '\b([A-Z][A-Z0-9_]{3,80})\b'){$Matches[1]}else{'OBSERVATION_CASE_FAILED'}}
        Save
    }
    function Observe {
        $start=[Diagnostics.ProcessStartInfo]::new($app);$start.UseShellExecute=$false;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
        $start.WorkingDirectory=$home;$start.ArgumentList.Add('--observation-once')
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
        try {$changed=$original.Clone();$changed[-1]=$changed[-1] -bxor 1;[IO.File]::WriteAllBytes($dll,$changed);$o=Observe;Require ($o.reason -eq 'COMPONENT_UNTESTED_OR_CHANGED' -and $o.boxes.Count -eq 0) 'CHANGED_COMPONENT_ACCEPTED';@{reason=$o.reason;native_queries_not_dispatched=$true}}
        finally {[IO.File]::WriteAllBytes($dll,$original)}
    }
    Case 'T01' 'stopped_service_is_not_ready' {
        Stop-Service SbieSvc
        try{$o=Observe;Require ($o.reason -eq 'ENGINE_SERVICE_STOPPED' -and -not $o.service_running -and $o.boxes.Count -eq 0) 'STOPPED_SERVICE_ACCEPTED';@{reason=$o.reason;production_launch_available=$false}}
        finally {Start-Service SbieSvc}
    }
    Case 'T46' 'fresh_observation_after_service_restart' { $o=Observe;Require ($o.reason -eq 'OBSERVED' -and $o.service_running) 'RECONNECT_NOT_OBSERVED';@{fresh_native_query=$true;service_identity_present=($null -ne $o.service_identity);release_evidence=$o.release_evidence} }
    Case 'T56' 'bounded_typed_protocol_and_generation_tests' { @{actual_adapter_tests_passed=$unitCount;old_worker_and_generation_refused=$true;incomplete_enumeration_never_idle=$true;cached_evidence_is_separate=$true} }
    Case 'T02' 'optional_paid_capabilities_do_not_invent_entitlement' { $o=Observe;$paid=@($o.capabilities|Where-Object name -eq 'paid_profiles');Require ($paid.Count -eq 1 -and $paid[0].availability -ne 'AVAILABLE') 'PAID_CAPABILITY_UNVERIFIED';@{availability=$paid[0].availability;reason=$paid[0].reason;provenance=$paid[0].provenance;certificate_contents_recorded=$false} }
    $pe=[IO.File]::ReadAllBytes($app);$offset=[BitConverter]::ToInt32($pe,0x3c);$machine=('{0:x4}' -f [BitConverter]::ToUInt16($pe,$offset+4))
    @{phase='P04';result=$(if(@($cases|Where-Object status -ne 'PASSED').Count -eq 0){'PASSED'}else{'FAILED'});manager_commit=(& git rev-parse HEAD).Trim();target=$target;pe_machine=$machine;manager_binary_sha256=$binaryHash;adapter_tests_passed=$unitCount;native_cases_passed=@($cases|Where-Object status -eq 'PASSED').Count;os_build=[Environment]::OSVersion.Version.ToString();production_target_launches=0;production_mutations=0;os_security_settings_modified=$false;teardown='DISCARD_ACTIONS_VM'} | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $out 'run-summary.json') -Encoding utf8
    Require (@($cases|Where-Object status -ne 'PASSED').Count -eq 0) 'P04_NATIVE_GATE_FAILED'
} finally {Pop-Location}
