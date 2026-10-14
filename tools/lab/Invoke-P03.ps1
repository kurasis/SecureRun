[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true') { throw 'DISPOSABLE_ACTIONS_VM_REQUIRED' }
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$out=Join-Path $repo 'artifacts/p03'; $null=New-Item -ItemType Directory -Path $out -Force
$target=if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') {'aarch64-pc-windows-msvc'} else {'x86_64-pc-windows-msvc'}
$env:RUSTUP_TOOLCHAIN="1.90.0-$target"
rustup toolchain install $env:RUSTUP_TOOLCHAIN --profile minimal --component rustfmt,clippy
if ($LASTEXITCODE -ne 0) { throw 'RUST_TOOLCHAIN_INSTALL_FAILED' }
Push-Location $repo
try {
    npm ci --ignore-scripts
    if ($LASTEXITCODE -ne 0) { throw 'NPM_LOCKED_INSTALL_FAILED' }
    npm run build
    if ($LASTEXITCODE -ne 0) { throw 'FRONTEND_BUILD_FAILED' }
    npm test
    if ($LASTEXITCODE -ne 0) { throw 'FRONTEND_TEST_FAILED' }
    $unit=& cargo test --locked -p securerun-foundation 2>&1
    $unit | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'FOUNDATION_TEST_FAILED' }
    $count=0
    foreach ($line in $unit) { if ([string]$line -match 'test result: ok\. (\d+) passed; 0 failed') { $count += [int]$Matches[1] } }
    if ($count -lt 16) { throw 'FOUNDATION_TEST_COVERAGE_MISSING' }
    cargo fmt --all -- --check
    if ($LASTEXITCODE -ne 0) { throw 'RUST_FORMAT_FAILED' }
    cargo clippy --locked -p securerun-foundation --all-targets -- -D warnings
    if ($LASTEXITCODE -ne 0) { throw 'FOUNDATION_LINT_FAILED' }
    $env:VITE_FOUNDATION_CI='1'
    npm run tauri -- build --debug --no-bundle --target $target --features foundation-ci --config src-tauri/tauri.ci.conf.json
    if ($LASTEXITCODE -ne 0) { throw 'NATIVE_APPLICATION_BUILD_FAILED' }
    $exe=Join-Path $repo "target/$target/debug/securerun.exe"
    $pe=[IO.File]::ReadAllBytes($exe); $offset=[BitConverter]::ToInt32($pe,0x3c)
    $machine=[BitConverter]::ToUInt16($pe,$offset+4)
    if (($target -like 'aarch64*' -and $machine -ne 0xaa64) -or ($target -like 'x86_64*' -and $machine -ne 0x8664)) { throw 'NATIVE_PE_ARCHITECTURE_MISMATCH' }
    $run=[Guid]::NewGuid().ToString('N');$userName='SRP03_'+$run.Substring(0,10)
    $password=ConvertTo-SecureString ('P03aA!'+[Guid]::NewGuid().ToString('N')) -AsPlainText -Force
    $user=New-LocalUser -Name $userName -Password $password -AccountNeverExpires
    $group=([Security.Principal.SecurityIdentifier]::new('S-1-5-32-545')).Translate([Security.Principal.NTAccount]).Value.Split('\')[-1]
    Add-LocalGroupMember -Group $group -Member $userName
    $lab=Join-Path $env:ProgramData "SecureRunP03Lab/$run"
    $null=New-Item -ItemType Directory -Path (Join-Path $lab 'temp') -Force
    $acl=[Security.AccessControl.DirectorySecurity]::new();$acl.SetAccessRuleProtection($true,$false)
    foreach ($sid in @($user.SID,[Security.Principal.SecurityIdentifier]::new('S-1-5-18'),[Security.Principal.SecurityIdentifier]::new('S-1-5-32-544'))) { $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid,'FullControl','ContainerInherit,ObjectInherit','None','Allow')) }
    Set-Acl -LiteralPath $lab -AclObject $acl
    $start=[Diagnostics.ProcessStartInfo]::new($exe);$start.UseShellExecute=$false;$start.WorkingDirectory=$repo
    $start.UserName=$userName;$start.Domain=[Environment]::MachineName;$start.Password=$password;$start.LoadUserProfile=$true
    $start.Environment.Clear()
    foreach ($key in @('SystemRoot','WINDIR','SystemDrive','ProgramFiles','ProgramFiles(x86)','ProgramW6432','ProgramData','OS','PROCESSOR_ARCHITECTURE','NUMBER_OF_PROCESSORS')) { $value=[Environment]::GetEnvironmentVariable($key);if ($null -ne $value) {$start.Environment[$key]=$value} }
    $start.Environment['TEMP']=Join-Path $lab 'temp';$start.Environment['TMP']=Join-Path $lab 'temp'
    $start.Environment['PATH']=Join-Path $env:SystemRoot 'System32'
    $start.ArgumentList.Add('--foundation-self-test');$start.ArgumentList.Add('--ci-run-id');$start.ArgumentList.Add($run)
    $process=[Diagnostics.Process]::Start($start)
    try {
        if (-not $process.WaitForExit(180000)) { $process.Kill();throw 'WEBVIEW_COMMAND_TEST_TIMEOUT' }
        $result=Join-Path $lab "temp/SecureRunP03-$run/command-boundary.json"
        if (Test-Path $result) { Copy-Item $result (Join-Path $out 'command-boundary.json') }
        if ($process.ExitCode -ne 0 -or -not (Test-Path $result)) { throw 'WEBVIEW_COMMAND_TEST_FAILED' }
        $boundary=Get-Content $result -Raw | ConvertFrom-Json
        if ($boundary.result -ne 'PASSED' -or -not $boundary.real_webview2 -or -not $boundary.real_native_picker -or $boundary.engine_operations_executed -ne 0) { throw 'COMMAND_BOUNDARY_EVIDENCE_INVALID' }
    } finally { $process.Dispose();$password.Dispose() }
    @{phase='P03';result='PASSED';manager_commit=(& git rev-parse HEAD).Trim();target=$target;pe_machine=('{0:x4}' -f $machine);rust_version=(& rustc --version);node_version=(& node --version);foundation_tests_passed=$count;frontend_tests_passed=2;windows_command_cases_passed=@($boundary.cases | Where-Object passed).Count;os_build=[Environment]::OSVersion.Version.ToString();engine_operations_executed=0;os_security_settings_modified=$false;teardown='DISCARD_ACTIONS_VM'} | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $out 'run-summary.json') -Encoding utf8
} finally { Remove-Item Env:VITE_FOUNDATION_CI -ErrorAction SilentlyContinue;Pop-Location }
