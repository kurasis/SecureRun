[CmdletBinding()]
param([string]$EngineHome,[string]$Fixture,[string]$Box,[string]$Probe)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$result = @{ status = 'IN_PROGRESS'; elevated_helper = $false }
try {
    $principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'STANDARD_USER_REQUIRED' }
    Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'engine_bridge.cs')))
    $bridge = [P02Bridge]::new($EngineHome,$Fixture,[string[]]@($Probe))
    $result.current_session = $bridge.CurrentSession
    $bridge.Register($Box)
    $bridge.Set($Box,'Enabled','n')
    $bridge.Set($Box,'FileRootPath',(Join-Path $Fixture "boxes/$Box"))
    $bridge.Set($Box,'DropAdminRights','y')
    $bridge.Set($Box,'AllowNetworkAccess','n'); $bridge.Set($Box,'BlockLocalLoop','y')
    $bridge.Set($Box,'AutoRecover','n'); $bridge.Set($Box,'AutoDelete','n')
    $root = $bridge.Root($Box)
    if (Test-Path -LiteralPath $root) { throw 'PREEXISTING_ROOT_NOT_ADOPTED' }
    $result.parent_replacement = $bridge.ExerciseProvisionParentReplacement($Box)
    $result.provisioning = $bridge.ProvisionFreshRoot($Box)
    $result.root_replacement = $bridge.ExerciseRootReplacement($Box)
    $result.standard_user = $true
    $result.configuration_created_by_standard_user = $true
    $result.root_acl_applied_by_standard_user = $true
    $bridge.Set($Box,'Enabled','y')
    [P02Bridge]::MinimizeProcessEnvironment($EngineHome)
    $receipt = $bridge.Launch($Box,$Probe,[string[]]@('hold-session',$Fixture,$Box,'same-owner-current',$EngineHome))
    try {
        @{ initialized = $true; standard_user = $true; current_session = $bridge.CurrentSession } | ConvertTo-Json | Set-Content (Join-Path $Fixture 'results/standard-user-ready.json') -Encoding utf8
        $clock = [Diagnostics.Stopwatch]::StartNew()
        do {
            $result.sessions = $bridge.ObserveSameOwnerSessions($Box)
            if ($result.sessions.simultaneous_session_count -ge 2) { break }
            Start-Sleep -Milliseconds 100
        } while ($clock.ElapsedMilliseconds -lt 45000)
        $result.sessions_status = if ($result.sessions.simultaneous_session_count -ge 2 -and $result.sessions.current_session_observed -and $result.sessions.current_session_process_count -ge 1) { 'PASSED' } else { 'BLOCKED' }
        $result.completed_objects = $bridge.StopHeld($Box)
        if (-not [P02Bridge]::Completed($receipt,5000) -or $bridge.Count($Box) -ne 0) { throw 'STANDARD_USER_STOP_INCOMPLETE' }
    } finally { [P02Bridge]::CloseReceipt($receipt) }
    $result.unboxed_manager_diagnostics = $bridge.ManagerDiagnostics()
    $null = New-Item -ItemType Directory -Path (Join-Path $root 'sealed-test')
    'P02_NORMAL_USER_CLEANUP' | Set-Content (Join-Path $root 'sealed-test/fixture.txt')
    $result.unsafe_storage = $bridge.ExerciseUnsafeStorage($Box)
    $result.cleanup = $bridge.ClearOwnedWithNative($Box)
    if (-not $result.cleanup.contents_empty -or -not $result.cleanup.root_identity_retained) { throw 'STANDARD_USER_CLEANUP_UNCONFIRMED' }
    $result.definition_removal = $bridge.RemoveClearedDefinition($Box)
    $result.status = if ($result.sessions_status -eq 'PASSED') { 'PASSED' } else { 'BLOCKED' }
    if ($result.status -eq 'BLOCKED') { $result.diagnostic_code = 'SAME_SID_SECOND_SESSION_UNAVAILABLE' }
} catch {
    $result.status = 'FAILED'
    $message = $_.Exception.Message
    $result.diagnostic_code = if ($message -cmatch '\b([A-Z][A-Z0-9_]{3,80})\b') { $Matches[1] } else { 'STANDARD_USER_PROBE_FAILED' }
    $result.exception_type = $_.Exception.GetBaseException().GetType().FullName
}
$result | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $Fixture 'results/standard-user-result.json') -Encoding utf8
if ($result.status -eq 'PASSED') { exit 0 }
exit 1
