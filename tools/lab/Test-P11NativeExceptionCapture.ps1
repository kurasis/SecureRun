# Explicit own-process synthetic test. Not Sandboxie evidence or a phase gate.
param([Parameter(Mandatory)][string]$ToolHome)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
if($env:GITHUB_ACTIONS -ne 'true' -or $env:PROCESSOR_ARCHITECTURE -ne 'ARM64'){throw 'DISPOSABLE_ARM_ACTIONS_VM_REQUIRED'}
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
. (Join-Path $PSScriptRoot 'Read-P11ExceptionDump.ps1')
. (Join-Path $PSScriptRoot 'Invoke-P11ExceptionCapture.ps1')
$context=New-P11ExceptionCapture $ToolHome $repo ([datetime]::UtcNow)
$report=@{classification='SYNTHETIC_HOST_DEBUG_PREFLIGHT_NOT_ENGINE_PROOF';result='IN_PROGRESS';debugger_present_confirmed=$false;exception_dump_confirmed=$false;raw_output_uploaded=$false;windows_security_or_wer_modified=$false;observer_existing_debug_privilege_enabled=$true;tool_stdout=$null;tool_stderr=$null}
$target=$null;$monitor=$null;$codeLease=$null;$stdout=$null;$stderr=$null
try{
 $vswhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
 $vs=& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
 if($LASTEXITCODE -ne 0 -or -not $vs){throw 'DIAGNOSTIC_PREFLIGHT_COMPILER_MISSING'}
 Import-Module (Join-Path $vs 'Common7/Tools/Microsoft.VisualStudio.DevShell.dll')
 Enter-VsDevShell -VsInstallPath $vs -SkipAutomaticLocation -DevCmdArguments '-arch=arm64 -host_arch=arm64'|Out-Null
 $source=Join-Path $PSScriptRoot 'p11-debug-preflight.c';$exe=Join-Path $ToolHome 'synthetic-debug-preflight.exe'
 if(Test-Path -LiteralPath $exe){throw 'DIAGNOSTIC_PREFLIGHT_PREEXISTING_CODE_REFUSED'}
 Push-Location $ToolHome
 try{& cl.exe /nologo /W4 /WX /O2 /DUNICODE /D_UNICODE $source "/Fe:$exe" /link /MACHINE:ARM64;if($LASTEXITCODE -ne 0){throw 'DIAGNOSTIC_PREFLIGHT_BUILD_FAILED'}}finally{Pop-Location}
 $codeLease=Open-P11PinnedFile $exe;$report.synthetic_source_sha256=(Get-FileHash $source).Hash.ToLowerInvariant();$report.synthetic_code_sha256=Get-P11StreamHash $codeLease
 $bytes=[IO.File]::ReadAllBytes($exe);$pe=[BitConverter]::ToInt32($bytes,0x3c);if([BitConverter]::ToUInt16($bytes,$pe+4) -ne 0xaa64){throw 'DIAGNOSTIC_PREFLIGHT_ARCHITECTURE_FAILED'}
 $directory=Join-Path $ToolHome 'private-preflight';$null=New-Item -ItemType Directory -Path $directory
 $ready=Join-Path $ToolHome ('preflight-release-'+[Guid]::NewGuid().ToString('N'))
 $start=[Diagnostics.ProcessStartInfo]::new($exe);$start.UseShellExecute=$false;$start.WorkingDirectory=$ToolHome;$start.ArgumentList.Add($ready)
 $target=[Diagnostics.Process]::Start($start);$birth=[P11DebugScope]::ReadBirth([uint32]$target.Id);if($birth -eq 0){throw 'DIAGNOSTIC_PREFLIGHT_BIRTH_UNAVAILABLE'}
 $present=$false;if(-not [P11DebugScope]::TryDebugger([uint32]$target.Id,$birth,[ref]$present) -or $present){throw 'DIAGNOSTIC_PREFLIGHT_INITIAL_DEBUGGER_REFUSED'}
 $monitor=[Diagnostics.Process]::Start((New-P11PrivateMonitorStartInfo $context.exe $ToolHome $directory ([uint32]$target.Id)))
 $stdout=[P11PrivateToolOutput]::Read($monitor.StandardOutput,[uint32]$target.Id);$stderr=[P11PrivateToolOutput]::Read($monitor.StandardError,[uint32]$target.Id)
 $clock=[Diagnostics.Stopwatch]::StartNew()
 while($clock.ElapsedMilliseconds -lt 20000 -and -not $target.HasExited){
  $present=$false
  if([P11DebugScope]::TryDebugger([uint32]$target.Id,$birth,[ref]$present) -and $present){$report.debugger_present_confirmed=$true;[IO.File]::WriteAllText($ready,'RELEASE_OWN_SYNTHETIC_EXCEPTION');break}
  if($monitor.HasExited){break};Start-Sleep -Milliseconds 50
 }
 # The fixture exits naturally after 30 seconds if no release was authorized.
 $targetCompleted=$target.WaitForExit(35000);$monitorCompleted=$monitor.WaitForExit(15000)
 $report.target_completed_naturally=$targetCompleted;$report.monitor_completed=$monitorCompleted
 if($monitorCompleted){$report.tool_exit_code=$monitor.ExitCode;$report.tool_stdout=$stdout.GetAwaiter().GetResult();$report.tool_stderr=$stderr.GetAwaiter().GetResult()}
 $dumps=@(Get-ChildItem -LiteralPath $directory -File -Filter '*.dmp')
 if($targetCompleted -and $monitorCompleted -and $report.debugger_present_confirmed -and $dumps.Count -eq 1){
  $parsed=[P11ExceptionDump]::Read($dumps[0].FullName,[uint32]$target.Id)
  if($parsed['exception_code_hex'] -ceq 'e0424242'){$report.exception_dump_confirmed=$true;$parsed['classification']='SYNTHETIC_HOST_DEBUG_PREFLIGHT_NOT_ENGINE_PROOF';$report.exception=$parsed}
 }
 if(-not $report.exception_dump_confirmed){throw 'DIAGNOSTIC_PREFLIGHT_EXCEPTION_CAPTURE_UNAVAILABLE'}
 $report.result='PASSED'
}catch{
 $report.result='FAILED';$code=$_.Exception.GetBaseException().Message
 $report.code=if($code -cmatch '^DIAGNOSTIC_[A-Z0-9_]{1,100}$'){$code}else{'DIAGNOSTIC_PREFLIGHT_FAILED'}
 $report.exception_type=$_.Exception.GetBaseException().GetType().FullName;$report.script_line=$_.InvocationInfo.ScriptLineNumber
}finally{
 # Never kill the monitor/debuggee or dispatch on a name; VM disposal is final.
 if($null -ne $target){$report.target_left_for_vm_cleanup=(-not $target.HasExited);$target.Dispose()}
 if($null -ne $monitor){$report.monitor_left_for_vm_cleanup=(-not $monitor.HasExited);$monitor.Dispose()}
 if($null -ne $codeLease){$codeLease.Dispose()};$context.tool_lease.Dispose();try{$context.debug_privilege_lease.Dispose();$report.existing_debug_privilege_restored=$true}catch{$report.existing_debug_privilege_restored=$false;$report.result='FAILED';$report.code='DIAGNOSTIC_DEBUG_PRIVILEGE_RESTORE_FAILED'}
 $report|ConvertTo-Json -Depth 8|Set-Content (Join-Path $repo 'artifacts/p11-diagnostics/debug-preflight.json') -Encoding utf8
}
if($report.result -ne 'PASSED'){throw 'P11_SYNTHETIC_DEBUG_PREFLIGHT_FAILED_NO_ENGINE_WORKLOAD'}
Write-Host 'PASS: actual synthetic native debugger attachment and exception dump; no engine proof'
