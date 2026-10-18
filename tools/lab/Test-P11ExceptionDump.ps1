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

# Tool pipes are drained with constant storage; raw output is never returned.
$privateReader=[IO.StringReader]::new(('x'*100000));try{$drain=[P11DebugScope]::DrainPrivateOutput($privateReader);if($drain.GetAwaiter().GetResult() -ne 65537){throw 'PRIVATE_OUTPUT_DRAIN_BOUND_FAILED'}}finally{$privateReader.Dispose()}
Write-Host 'PASS: constant-storage private tool output drain'
