$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
# Import only the actual lab guard/cleanup functions. Synthetic dependency
# results verify dispatch decisions, never Windows containment or process state.
$source=Join-Path $PSScriptRoot '../probe/p09_standard.ps1';$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$errors)
if($errors.Count -ne 0){throw 'REPORTER_GUARD_SOURCE_PARSE_FAILED'}
foreach($name in @('Get-P09ReporterState','Test-P09ReporterSafety','Stop-Box')){
 $definition=$ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ceq $name},$true)
 if($null -eq $definition){throw 'REPORTER_GUARD_SOURCE_FUNCTION_MISSING'}
 . ([ScriptBlock]::Create($definition.Extent.Text))
}
function Require([bool]$Value){if(-not $Value){throw 'REPORTER_GUARD_UNIT_FAILED'}}
$temporary=Join-Path ([IO.Path]::GetTempPath()) ('p11-reporter-guard-'+[Guid]::NewGuid().ToString('N'))
try{
 $null=New-Item -ItemType Directory -Path $temporary;$results=$temporary;$script:stage='SYNTHETIC_GUARD_UNIT';$script:reporterSafetyRefusals=0;$script:nativeCalls=0;$script:fenceCalls=0
 $script:state=@{count=1;query_failed=$false}
 function Get-P09ReporterState {return $script:state}
 function Native {param($Request,$Kind) $script:nativeCalls++}
 $lab=[pscustomobject]@{};$lab|Add-Member -MemberType ScriptMethod -Name FenceFixture -Value {param($Box) $script:fenceCalls++}
 $environment=[pscustomobject]@{id='00000000-0000-4000-8000-000000000001'}
 Stop-Box $environment
 Require ($script:nativeCalls -eq 0 -and $script:fenceCalls -eq 0 -and $script:reporterSafetyRefusals -eq 1)
 $refusal=Get-Content (Join-Path $results 'reporter-cleanup-refused.json') -Raw|ConvertFrom-Json
 Require ($refusal.case_or_cleanup_refused -and -not $refusal.reporter_termination_requested)
 $script:state=@{count=0;query_failed=$true};Stop-Box $environment
 Require ($script:nativeCalls -eq 0 -and $script:fenceCalls -eq 0 -and $script:reporterSafetyRefusals -eq 2)
 $script:state=@{count=0;query_failed=$false};Stop-Box $environment
 Require ($script:nativeCalls -eq 1 -and $script:fenceCalls -eq 1 -and $script:reporterSafetyRefusals -eq 2)
 Write-Output 'PASS: synthetic reporter/query-error cleanup refusal and healthy dispatch; not Windows proof'
}finally{if(Test-Path -LiteralPath $temporary){Remove-Item -LiteralPath $temporary -Recurse -Force}}
