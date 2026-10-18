$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'Read-P11LiveFaultMetadata.ps1')
function Require([bool]$Value){if(-not $Value){throw 'P11_LIVE_METADATA_TEST_FAILED'}}
$xml='<WERReportMetadata><ProblemSignatures><EventType>APPCRASH</EventType><Parameter0>C:\PRIVATE_CANARY\SandboxieRpcSs.exe</Parameter0><Parameter1>5.73.8.0</Parameter1><Parameter3>C:\PRIVATE_CANARY\rpcss.dll</Parameter3><Parameter6>c0000005</Parameter6><Parameter7>000012ab</Parameter7><Parameter9>S-1-5-21-PRIVATE_CANARY</Parameter9></ProblemSignatures></WERReportMetadata>'
$parsed=[P11LiveWer]::ParseXml([Text.Encoding]::UTF8.GetBytes($xml));Require ($parsed['fault_module_kind'] -ceq 'rpcss.dll' -and $parsed['exception_code_hex'] -ceq 'c0000005' -and $parsed['exception_offset_hex'] -ceq '000012ab')
Require (($parsed|ConvertTo-Json -Compress) -notmatch 'PRIVATE_CANARY|S-1-|C:\\')
$other=[P11LiveWer]::ParseXml([Text.Encoding]::UTF8.GetBytes($xml.Replace('SandboxieRpcSs.exe','Other.exe')));Require ($null -eq $other)
$unknown=[P11LiveWer]::ParseXml([Text.Encoding]::UTF8.GetBytes($xml.Replace('rpcss.dll','PRIVATE_CANARY.dll')));Require ($unknown['fault_module_kind'] -ceq 'WITHHELD')
$hang=[P11LiveWer]::ParseXml([Text.Encoding]::UTF8.GetBytes($xml.Replace('APPCRASH','AppHangB1')));Require ($hang['exception_code_hex'] -ceq 'WITHHELD')
foreach($encoding in @([Text.Encoding]::UTF8,[Text.Encoding]::Unicode)){
 $bad='<?xml version="1.0"?><!DOCTYPE x [<!ENTITY private SYSTEM "file:///PRIVATE_CANARY">]><x>&private;</x>'
 $bytes=$encoding.GetPreamble()+$encoding.GetBytes($bad);$rejected=$false;try{$null=[P11LiveWer]::ParseXml($bytes)}catch{$rejected=$true};Require $rejected
}
$wer="AppName=SandboxieRpcSs.exe`nEventType=APPCRASH`nSig[3].Name=Fault Module Name`nSig[3].Value=ntdll.dll`nSig[6].Name=Exception Code`nSig[6].Value=c0000409"
$report=[P11LiveWer]::ParseWer([Text.Encoding]::UTF8.GetBytes($wer));Require ($report['fault_module_kind'] -ceq 'ntdll.dll' -and $report['exception_code_hex'] -ceq 'c0000409')
Write-Output 'PASS: live WER parsing, private-field suppression, unknown names, event layout and UTF8/UTF16 DTD rejection'
