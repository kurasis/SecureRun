param([string]$Manager,[string]$EngineHome,[string]$Fixture,[string]$Box,[string]$Probe)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$result=@{status='IN_PROGRESS'}
try {
    $principal=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    if($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'STANDARD_USER_REQUIRED'}
    Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'engine_bridge.cs')))
    $bridge=[P02Bridge]::new($EngineHome,$Fixture,[string[]]@($Probe))
    $bridge.Register($Box);$bridge.Set($Box,'Enabled','n');$bridge.Set($Box,'FileRootPath',(Join-Path $Fixture "boxes/$Box"))
    $bridge.Set($Box,'DropAdminRights','y');$bridge.Set($Box,'AutoRecover','n');$bridge.Set($Box,'AutoDelete','n');$bridge.Set($Box,'UseFileImage','n')
    $null=$bridge.ProvisionFreshRoot($Box);$bridge.Set($Box,'Enabled','y')
    [P02Bridge]::MinimizeProcessEnvironment($EngineHome)
    $receipt=$bridge.Launch($Box,$Probe,[string[]]@('hold-session',$Fixture,$Box,'p04-standard',$EngineHome))
    try {
        @{ready=$true;standard_user=$true} | ConvertTo-Json | Set-Content (Join-Path $Fixture 'results/p04-standard-ready.json') -Encoding utf8
        $clock=[Diagnostics.Stopwatch]::StartNew()
        do {
            $o=(& $Manager --observation-once) | ConvertFrom-Json
            $b=@($o.boxes|Where-Object name -eq $Box)
            if($b.Count -eq 1 -and $b[0].complete -and @($b[0].processes.session|Select-Object -Unique).Count -ge 2){break}
            Start-Sleep -Milliseconds 200
        }while($clock.ElapsedMilliseconds -lt 45000)
        if($o.reason -ne 'OBSERVED' -or $b.Count -ne 1 -or -not $b[0].complete -or $b[0].activity -ne 'RUNNING' -or @($b[0].processes.session|Select-Object -Unique).Count -lt 2){throw 'PRODUCTION_SAME_SID_SESSION_OBSERVATION_FAILED'}
        $sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        if(@($b[0].processes|Where-Object owner_sid -ne $sid).Count -ne 0 -or $b[0].owned -or -not $b[0].read_only){throw 'PRODUCTION_OWNER_OR_UNOWNED_SCOPE_FAILED'}
        $result=@{status='PASSED';standard_user=$true;production_manager_context=$o.manager_context;production_bridge_context=$o.bridge_context;simultaneous_session_count=@($b[0].processes.session|Select-Object -Unique).Count;process_count=$b[0].processes.Count;all_session_complete=$b[0].complete;activity=$b[0].activity;same_owner_verified=$true;all_births_present=(@($b[0].processes|Where-Object creation_time -eq 0).Count -eq 0);unowned_read_only=$true;private_identity_or_paths_recorded=$false;production_mutations=0}
    } finally {[P02Bridge]::CloseReceipt($receipt)}
} catch {$result.status='FAILED';$result.code=if($_.Exception.Message -cmatch '\b([A-Z][A-Z0-9_]{3,80})\b'){$Matches[1]}else{'STANDARD_OBSERVATION_FAILED'}}
$result | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $Fixture 'results/p04-standard-result.json') -Encoding utf8
if($result.status -eq 'PASSED'){exit 0}
exit 1
