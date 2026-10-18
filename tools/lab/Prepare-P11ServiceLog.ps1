$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
if($env:GITHUB_ACTIONS -ne 'true' -or $env:PROCESSOR_ARCHITECTURE -ne 'ARM64'){throw 'DISPOSABLE_ARM_ACTIONS_VM_REQUIRED'}
if($env:GITHUB_RUN_ID -cnotmatch '^\d{1,20}$' -or $env:GITHUB_RUN_ATTEMPT -cnotmatch '^\d{1,6}$'){throw 'DIAGNOSTIC_RUN_ID_INVALID'}
$privateDirectory=Join-Path $env:ProgramFiles ('SecureRun-P11-ServiceLog-'+$env:GITHUB_RUN_ID+'-'+$env:GITHUB_RUN_ATTEMPT)
if(Test-Path -LiteralPath $privateDirectory){throw 'DIAGNOSTIC_LOG_PREEXISTING_HOME_REFUSED'}
$null=New-Item -ItemType Directory -Path $privateDirectory
$acl=[Security.AccessControl.DirectorySecurity]::new();$admins=[Security.Principal.SecurityIdentifier]::new('S-1-5-32-544');$acl.SetOwner($admins);$acl.SetAccessRuleProtection($true,$false)
foreach($sid in @($admins,[Security.Principal.SecurityIdentifier]::new('S-1-5-18'))){$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid,'FullControl','ContainerInherit,ObjectInherit','None','Allow'))}
Set-Acl -LiteralPath $privateDirectory -AclObject $acl
"home=$privateDirectory"|Out-File -LiteralPath $env:GITHUB_OUTPUT -Append -Encoding utf8
