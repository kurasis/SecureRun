$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'Read-P11ExceptionDump.ps1')
. (Join-Path $PSScriptRoot 'Invoke-P11ExceptionCapture.ps1')
# Synthetic format/privacy checks, never an operating-system exception claim.
$data=[byte[]]::new(4096)
function Set32([int]$Offset,[uint32]$Value){[Array]::Copy([BitConverter]::GetBytes($Value),0,$data,$Offset,4)}
function Set64([int]$Offset,[uint64]$Value){[Array]::Copy([BitConverter]::GetBytes($Value),0,$data,$Offset,8)}
function Require([bool]$Value){if(-not $Value){throw 'P11_PRIVATE_DUMP_PARSER_TEST_FAILED'}}
Set32 0 0x504d444d;Set32 4 0xa793;Set32 8 4;Set32 12 32
Set32 32 6;Set32 36 168;Set32 40 128
Set32 44 4;Set32 48 112;Set32 52 320
Set32 56 15;Set32 60 24;Set32 64 480
Set32 68 7;Set32 72 56;Set32 76 512
Set32 136 ([Convert]::ToUInt32('c0000005',16));Set64 152 ([uint64]0x100001234)
Set32 320 1;Set64 324 ([uint64]0x100000000);Set32 332 65536;Set32 344 640
Set32 480 24;Set32 484 1;Set32 488 4242
[Array]::Copy([BitConverter]::GetBytes([uint16]12),0,$data,512,2)
$name=[Text.Encoding]::Unicode.GetBytes('C:\PRIVATE_CANARY\SbieDll.dll');Set32 640 $name.Length;[Array]::Copy($name,0,$data,644,$name.Length)
$parsed=[P11ExceptionDump]::Parse($data,4242)
Require ($parsed['exception_code_hex'] -ceq 'c0000005' -and $parsed['fault_module_kind'] -ceq 'SbieDll.dll' -and $parsed['module_relative_offset_hex'] -ceq '0000000000001234' -and $parsed['process_architecture'] -ceq 'ARM64')
Require (($parsed|ConvertTo-Json -Compress) -notmatch 'PRIVATE_CANARY|C:\\|ThreadId|ExceptionAddress')
$rejected=$false;try{$null=[P11ExceptionDump]::Parse($data,4243)}catch{$rejected=$true};Require $rejected
$rejected=$false;try{$null=[P11ExceptionDump]::Parse([byte[]]$data[0..199],4242)}catch{$rejected=$true};Require $rejected
$unknown=[Text.Encoding]::Unicode.GetBytes('C:\PRIVATE_CANARY\UnknownPrivate.dll');Set32 640 $unknown.Length;[Array]::Copy($unknown,0,$data,644,$unknown.Length)
$parsed=[P11ExceptionDump]::Parse($data,4242);Require ($parsed['fault_module_kind'] -ceq 'WITHHELD' -and $parsed['module_relative_offset_hex'] -ceq 'WITHHELD')
$codes=@{};try{$null=[P11ExceptionDump]::Parse($data,4243)}catch{Add-P11CaptureCode $codes $_.Exception.GetBaseException().Message 'DIAGNOSTIC_DUMP_COLLECTION_FAILED'}
Require ($codes.ContainsKey('PRIVATE_DUMP_PROCESS_BINDING_FAILED'))
Add-P11CaptureCode $codes 'C:\PRIVATE_CANARY\bad.dmp' 'DIAGNOSTIC_DUMP_COLLECTION_FAILED'
Require ($codes.ContainsKey('DIAGNOSTIC_DUMP_COLLECTION_FAILED') -and ($codes|ConvertTo-Json) -notmatch 'PRIVATE_CANARY')
Write-Output 'PASS: synthetic exception/module/RVA, target binding, bounds and private-field suppression'

# A publisher-written dump has no independently held target receipt. Never
# relabel its own PID stream as independent authentication.
$privateDump=Join-Path ([IO.Path]::GetTempPath()) ('p11-publisher-dump-'+[Guid]::NewGuid().ToString('N'))
try{
 [IO.File]::WriteAllBytes($privateDump,$data)
 $publisher=[P11ExceptionDump]::ReadPublisherDump($privateDump)
 Require (-not $publisher['dump_target_id_matched'] -and -not $publisher['independent_live_target_authentication'] -and $publisher['dump_pid_internal_consistency_only'] -and $publisher['exception_code_hex'] -ceq 'c0000005')
 Require (($publisher|ConvertTo-Json) -notmatch 'PRIVATE_CANARY|4242')
 Set32 488 0;[IO.File]::WriteAllBytes($privateDump,$data)
 $rejected=$false;try{$null=[P11ExceptionDump]::ReadPublisherDump($privateDump)}catch{$rejected=$true};Require $rejected
 Set32 488 4242
}finally{Remove-Item -LiteralPath $privateDump -Force}
Write-Host 'PASS: publisher dump consistency never becomes independent live-target authentication'

# Tool pipes are drained with constant storage; raw output is never returned.
$privateReader=[IO.StringReader]::new(('x'*100000));try{$drain=[P11PrivateToolOutput]::Read($privateReader,4242);if($drain.GetAwaiter().GetResult().character_count -ne 65537){throw 'PRIVATE_OUTPUT_DRAIN_BOUND_FAILED'}}finally{$privateReader.Dispose()}
Write-Host 'PASS: constant-storage private tool output drain'

$privateReader=[IO.StringReader]::new("Monitoring PID: 98765`n[12:34:56] Exception: C0000005.PRIVATE_CANARY`nUnhandled: E0424242.PRIVATE_CANARY`nError debugging process:`nAccess is denied.`nC:\PRIVATE_CANARY\secret`n")
try{$parsed=[P11PrivateToolOutput]::Read($privateReader,98765).GetAwaiter().GetResult();Require ($parsed.monitoring_target_matched -and $parsed.statuses['ACCESS_DENIED'] -eq 1 -and $parsed.exception_codes['OBSERVED_c0000005'] -eq 1 -and $parsed.exception_codes['UNHANDLED_e0424242'] -eq 1);Require (($parsed|ConvertTo-Json -Depth 5) -notmatch 'PRIVATE_CANARY|98765|12:34:56')}finally{$privateReader.Dispose()}
Write-Host 'PASS: fixed tool states and exception codes only; private output suppressed'

# A zero exit code with a recognized debugger error is still a tool failure.
$privateDirectory=Join-Path ([IO.Path]::GetTempPath()) ('p11-tool-state-'+[Guid]::NewGuid().ToString('N'));$null=New-Item -ItemType Directory -Path $privateDirectory
try{
 $fakeProcess=[pscustomobject]@{HasExited=$true;ExitCode=0};$fakeProcess|Add-Member -MemberType ScriptMethod -Name Dispose -Value {}
 $fakeHold=[pscustomobject]@{HasExited=$true};$fakeHold|Add-Member -MemberType ScriptMethod -Name Dispose -Value {}
 $empty=[P11PrivateToolOutput]::Read([IO.StringReader]::new(''),98765).GetAwaiter().GetResult()
 $active=[Collections.Generic.List[object]]::new();$active.Add(@{process=$fakeProcess;hold=$fakeHold;debugger_seen=$false;id=98765;directory=$privateDirectory;stdout=[Threading.Tasks.Task]::FromResult($parsed);stderr=[Threading.Tasks.Task]::FromResult($empty)})
 $context=@{next_refresh_ms=[long]::MaxValue;active=$active;public=@{tool_status_counts=@{};tool_observed_exception_codes=@{};completed_with_live_undebugged_target=0;tool_failures=0;tool_exit_codes=@{};completed_without_exception_dump=0;dump_parser_failure_codes=@{}}}
 Update-P11ExceptionCapture $context 0
 Require ($context.active.Count -eq 0 -and $context.public.tool_failures -eq 1 -and $context.public.tool_status_counts['DEBUG_ERROR'] -eq 1 -and $context.public.dump_parser_failure_codes.Count -eq 0)
}finally{Remove-Item -LiteralPath $privateDirectory -Force -Recurse}
Write-Host 'PASS: zero tool exit cannot erase a recognized debugger failure'
# Exercise the actual start-info builder, including reserved-variable binding.
$priorSystemRoot=$env:SystemRoot;$privateEnvironmentName='SECURERUN_P11_PRIVATE_CANARY'
try{
 if(-not $env:SystemRoot){$env:SystemRoot=[IO.Path]::GetTempPath()}
 [Environment]::SetEnvironmentVariable($privateEnvironmentName,'DO_NOT_PROPAGATE')
 $syntheticHome=Join-Path ([IO.Path]::GetTempPath()) 'p11-synthetic-monitor-home'
 $syntheticOutput=Join-Path $syntheticHome 'private-output'
 $start=New-P11PrivateMonitorStartInfo (Join-Path $syntheticHome 'fixed-tool.exe') $syntheticHome $syntheticOutput 98765
 Require ($start.ArgumentList.Count -eq 7 -and $start.ArgumentList[5] -ceq '98765' -and $start.ArgumentList[6] -ceq ($syntheticOutput+[IO.Path]::DirectorySeparatorChar))
 Require ($start.WorkingDirectory -ceq $syntheticHome -and -not $start.Environment.ContainsKey($privateEnvironmentName))
}finally{$env:SystemRoot=$priorSystemRoot;[Environment]::SetEnvironmentVariable($privateEnvironmentName,$null)}
Write-Host 'PASS: actual monitor start-info binding, separate arguments and environment scrubbing'

# Sysinternals redirected output can be UTF16 without BOM, read as embedded NULs.
$utf16Ascii='Monitoring PID: 98765'+"`n"+'Unhandled: E0424242.PRIVATE_CANARY'+"`n"+'Error debugging process:'+"`n"+'Access is denied.'+"`n"
$nulOutput=($utf16Ascii.ToCharArray()|ForEach-Object {[string]$_+[char]0}) -join ''
$privateReader=[IO.StringReader]::new($nulOutput)
try{$parsed=[P11PrivateToolOutput]::Read($privateReader,98765).GetAwaiter().GetResult();Require ($parsed.monitoring_target_matched -and $parsed.exception_codes['UNHANDLED_e0424242'] -eq 1 -and $parsed.statuses['DEBUG_ERROR'] -eq 1 -and $parsed.statuses['ACCESS_DENIED'] -eq 1);Require (($parsed|ConvertTo-Json -Depth 5) -notmatch 'PRIVATE_CANARY|98765')}finally{$privateReader.Dispose()}
Write-Host 'PASS: NUL-interleaved redirected Sysinternals fixed-state output; no private strings'

# The pinned native tool also prints Process: <private name> (<private PID>).
$privateReader=[IO.StringReader]::new('Process:               PRIVATE_CANARY Process.exe (98765)'+"`n")
try{$parsed=[P11PrivateToolOutput]::Read($privateReader,98765).GetAwaiter().GetResult();Require ($parsed.monitoring_target_matched -and $parsed.statuses['MONITOR_HEADER_MATCH'] -eq 1);Require (($parsed|ConvertTo-Json -Depth 5) -notmatch 'PRIVATE_CANARY|98765')}finally{$privateReader.Dispose()}
Write-Host 'PASS: source-verified alternate process header binding without private fields'
