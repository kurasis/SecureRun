[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true') { throw 'Disposable Actions VM required.' }
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$out = Join-Path $repo 'artifacts/p02'
$engineHome = Join-Path $env:ProgramFiles 'Sandboxie-Plus'
$cases = [System.Collections.Generic.List[object]]::new()
function Save-Cases {
    ConvertTo-Json -InputObject @($cases.ToArray()) -Depth 10 | Set-Content (Join-Path $out 'feasibility-cases.json') -Encoding utf8
}
function Invoke-Case([string]$id, [string]$name, [scriptblock]$body) {
    $result = @{ id = $id; case = $name; status = 'IN_PROGRESS'; timestamp_utc = [DateTime]::UtcNow.ToString('o') }
    $cases.Add($result); Save-Cases
    try { $result.evidence = (& $body); $result.status = 'PASSED' }
    catch {
        $result.status = 'FAILED'
        $result.exception_type = $_.Exception.GetBaseException().GetType().FullName
        $message = $_.Exception.Message
        $result.diagnostic_code = if ($message -cmatch '\b([A-Z][A-Z0-9_]{3,80})\b') { $Matches[1] } else { 'SPIKE_OPERATION_FAILED' }
        if ($result.diagnostic_code -match 'POSITIVE_CONTROL_UNAVAILABLE|UNAVAILABLE|UNRESOLVED|OUTCOME_UNKNOWN|INCOMPLETE') { $result.status = 'BLOCKED' }
    }
    Save-Cases
}
function Require([bool]$condition, [string]$code) { if (-not $condition) { throw $code } }
function Net-All($report) { return ($report.tcp4 -and $report.tcp6 -and $report.udp4 -and $report.udp6) }
function Net-None($report) { return (-not $report.tcp4 -and -not $report.tcp6 -and -not $report.udp4 -and -not $report.udp6) }
function Read-Report([string]$root, [string]$label) {
    # Fresh diagnostic boxes only; bounded metadata enumeration, no preview/associations.
    $files = @(Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction Stop | Select-Object -First 513)
    Require ($files.Count -lt 513) 'REPORT_ENUMERATION_BOUND'
    $report = @($files | Where-Object Name -EQ "$label.json")
    Require ($report.Count -eq 1 -and $report[0].Length -le 8192 -and -not ($report[0].Attributes -band [IO.FileAttributes]::ReparsePoint)) 'REPORT_IDENTITY_UNRESOLVED'
    return Get-Content -LiteralPath $report[0].FullName -Raw | ConvertFrom-Json
}
$inspection = Get-Content (Join-Path $out 'engine-inspection.json') -Raw | ConvertFrom-Json
if ($inspection.result -ne 'PASS') {
    foreach ($id in @('T01','T05','T08','T09','T12','T33','T35','T36','T55','T57','T58','T60','T62')) { $cases.Add(@{ id = $id; status = 'BLOCKED'; diagnostic_code = 'ENGINE_UNAVAILABLE' }) }
    Save-Cases; return
}
Add-Type -TypeDefinition (Get-Content (Join-Path $repo 'tools/probe/engine_bridge.cs') -Raw)
$run = [Guid]::NewGuid().ToString('N')
$fixture = Join-Path $env:ProgramData "SecureRunLab/p02-$run"
$probeHome = Join-Path $env:ProgramFiles 'SecureRun-P02-Probes'
if (Test-Path $probeHome) { throw 'Existing probe directory must not be overwritten.' }
New-Item -ItemType Directory -Path $probeHome | Out-Null
foreach ($dir in @('canaries','blocked','metadata','results','boxes')) { New-Item -ItemType Directory -Path (Join-Path $fixture $dir) -Force | Out-Null }
'P02_HOST_CANARY' | Set-Content (Join-Path $fixture 'canaries/write.txt') -NoNewline
'P02_SYNTHETIC_SECRET' | Set-Content (Join-Path $fixture 'blocked/secret.txt')
'P02_PUBLIC_SYNTHETIC_CONTROL' | Set-Content (Join-Path $fixture 'canaries/read-positive.txt')
'P02_SYNTHETIC_MANAGER_DATA' | Set-Content (Join-Path $fixture 'metadata/manager.txt')
$hostHash = (Get-FileHash (Join-Path $fixture 'canaries/write.txt')).Hash
$probeFiles = @(Get-ChildItem (Join-Path $out 'feasibility_probe_*.exe'))
foreach ($file in $probeFiles) { Copy-Item $file.FullName -Destination $probeHome }
$approved = @($probeFiles | ForEach-Object { Join-Path $probeHome $_.Name })
Copy-Item (Join-Path $repo 'tools/probe/engine_bridge.cs'),(Join-Path $repo 'tools/probe/boxed_bridge_guard.ps1') -Destination $probeHome
$guardShell = Join-Path $PSHOME 'pwsh.exe'
$bridge = [P02Bridge]::new($engineHome, $fixture, [string[]]$approved)
$guardBridge = [P02Bridge]::new($engineHome, $fixture, [string[]]@($guardShell))
$boxA = 'SRP02_A_' + $run.Substring(0,12)
$boxB = 'SRP02_B_' + $run.Substring(0,12)
$boxOnline = 'SRP02_ON_' + $run.Substring(0,12)
$boxes = @($boxA,$boxB,$boxOnline)
foreach ($box in $boxes) {
    $bridge.Register($box)
    $bridge.Set($box,'Enabled','y')
    $bridge.Set($box,'FileRootPath',(Join-Path $fixture "boxes/$box"))
    $bridge.Set($box,'DropAdminRights','y')
    $bridge.Set($box,'BlockNetworkFiles','y')
    $bridge.Set($box,'AutoRecover','n'); $bridge.Set($box,'AutoDelete','n')
    $bridge.Set($box,'UseFileImage','n')
    $bridge.Set($box,'AllowNetworkAccess',$(if ($box -eq $boxOnline) { 'y' } else { 'n' }))
    $bridge.Set($box,'BlockLocalLoop',$(if ($box -eq $boxOnline) { 'n' } else { 'y' }))
    $bridge.AppendClosed($box,(Join-Path $fixture 'blocked/*').Replace('/','\'))
    $bridge.AppendClosed($box,(Join-Path $fixture 'metadata/*').Replace('/','\'))
    foreach ($sibling in $boxes | Where-Object { $_ -ne $box }) { $bridge.AppendClosed($box,(Join-Path $fixture "boxes/$sibling/*").Replace('/','\')) }
}
function New-Root([string]$box) {
    $root = $bridge.Root($box)
    Require ($bridge.Count($box) -eq 0) 'BOX_BUSY'
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    Require (-not ((Get-Item -LiteralPath $root).Attributes -band [IO.FileAttributes]::ReparsePoint)) 'ROOT_REPARSE_REJECTED'
    $acl = [Security.AccessControl.DirectorySecurity]::new()
    $acl.SetAccessRuleProtection($true,$false)
    foreach ($sid in @([Security.Principal.WindowsIdentity]::GetCurrent().User,[Security.Principal.SecurityIdentifier]::new('S-1-5-18'),[Security.Principal.SecurityIdentifier]::new('S-1-5-32-544'))) {
        $rule = [Security.AccessControl.FileSystemAccessRule]::new($sid,'FullControl','ContainerInherit,ObjectInherit','None','Allow')
        $acl.AddAccessRule($rule)
    }
    Set-Acl -LiteralPath $root -AclObject $acl
    $null = $bridge.CaptureRoot($box)
    return $root
}
$roots = @{}
Invoke-Case 'T55' 'Pending root and fixed trusted initializer' {
    $initiallyAbsent = -not (Test-Path ($bridge.Root($boxA)))
    Require $initiallyAbsent 'PREEXISTING_ROOT'
    foreach ($box in $boxes) { $roots[$box] = New-Root $box }
    @{ pending_before_initializer = $initiallyAbsent; roots_source = 'SbieApi_QueryBoxPath'; explicit_initializer = 'HOST_FIXED_SYNTHETIC_FIXTURE'; ntfs = (Get-Volume -FilePath ($roots[$boxA]+'\')).FileSystem }
}
if ($roots.Count -ne 3) { throw 'Root initialization failed; mutation stops.' }
'P02_PRIVATE_SIBLING_CANARY' | Set-Content (Join-Path $roots[$boxB] 'private.txt')
[IO.File]::WriteAllText((Join-Path $fixture 'sibling-probe.txt'),(Join-Path $roots[$boxB] 'private.txt'),[Text.UnicodeEncoding]::new($false,$false))
# Protect manager metadata independently from sandbox policy, using generated lab paths only.
$metadataAcl = Get-Acl -LiteralPath $roots[$boxB]
Set-Acl -LiteralPath (Join-Path $fixture 'metadata') -AclObject $metadataAcl
Push-Location $engineHome
$endpoints = [P02Endpoints]::new()
$reports = @{}
function Probe-Args([string]$mode,[string]$box,[string]$label) {
    return [string[]]@($mode,$fixture,$box,$label,$engineHome, "$($endpoints.Ports[0])", "$($endpoints.Ports[1])", "$($endpoints.Ports[2])", "$($endpoints.Ports[3])", 'two words', 'quote"value', 'trailing\', '/terminate_all', 'Юникод')
}
try {
    Invoke-Case 'T12' 'Enable WFP only in the newly installed disposable lab' {
        $before = $bridge.Flags(); $bridge.EnableLabWfp(); $after = $bridge.Flags()
        @{ driver_flags_before = $before; driver_flags_after = $after; global_lab_setting = 'NetworkEnableWFP=y'; driver_reconfigure_flag = 1; os_security_settings_changed = $false }
    }
    # SbieDll_RunSandboxed serializes the caller environment; never forward CI credentials.
    [P02Bridge]::MinimizeProcessEnvironment($engineHome)
    Invoke-Case 'T01' 'Missing box rejects target before execution' {
        Require ($bridge.RejectMissingBox($approved[0])) 'UNEXPECTED_LAUNCH'
        Require (-not (Test-Path (Join-Path $fixture 'FORBIDDEN-HOST-EXECUTION.txt'))) 'HOST_FALLBACK_DETECTED'
        @{ launch_rejected = $true; synthetic_host_marker_absent = $true; no_automatic_replay = $true }
    }
    foreach ($exe in $approved) {
        $arch = [IO.Path]::GetFileNameWithoutExtension($exe).Replace('feasibility_probe_','')
        Invoke-Case 'T12' "Unboxed positive controls $arch" {
            $label = "$arch-host"
            $start = [Diagnostics.ProcessStartInfo]::new($exe); $start.UseShellExecute = $false; $start.WorkingDirectory = $engineHome
            foreach ($arg in (Probe-Args 'host' 'UNBOXED' $label)) { $start.ArgumentList.Add($arg) }
            $process = [Diagnostics.Process]::Start($start)
            Require ($process.WaitForExit(20000)) 'HOST_CONTROL_OUTCOME_UNKNOWN'
            Require ($process.ExitCode -eq 0) "HOST_CONTROL_EXIT_$($process.ExitCode)"
            $report = Get-Content (Join-Path $fixture "results/$label.json") -Raw | ConvertFrom-Json
            Require ((Net-All $report) -and $report.blocked_read_error -eq 0 -and $report.metadata_read_error -eq 0 -and $report.sibling_read_error -eq 0) 'POSITIVE_CONTROL_UNAVAILABLE'
            $reports[$label] = $report
            $report
        }
        # Restore the intentionally modified host positive-control canary even if that probe failed.
        'P02_HOST_CANARY' | Set-Content (Join-Path $fixture 'canaries/write.txt') -NoNewline
        foreach ($mode in @('online','offline')) {
            $box = if ($mode -eq 'online') { $boxOnline } else { $boxA }
            $label = "$arch-$mode"
            Invoke-Case 'T05' "Boxed parent child grandchild $label" {
                $receipt = $bridge.Launch($box,$exe,(Probe-Args 'exercise' $box $label))
                try {
                    Require ([P02Bridge]::Completed($receipt,30000)) 'PROBE_OUTCOME_UNKNOWN'
                    Require ([P02Bridge]::ExitCode($receipt) -eq 0) 'PROBE_EXIT_FAILED'
                } finally { [P02Bridge]::CloseReceipt($receipt) }
                $report = Read-Report $roots[$box] $label
                $child = Read-Report $roots[$box] "$label-child1"
                $grandchild = Read-Report $roots[$box] "$label-child0"
                Require ($report.member -and $child.member -and $grandchild.member -and $report.child_spawned -and $child.spawned) 'MEMBERSHIP_UNCONFIRMED'
                Require ($report.bits -eq $(if ($arch -eq 'x86') { 32 } else { 64 })) 'PROBE_ARCHITECTURE_MISMATCH'
                $reports[$label] = $report
                @{ parent = $report; child = $child; grandchild = $grandchild }
            }
            Invoke-Case 'T04' "Exact structured argument round trip $label" { Require ($reports.ContainsKey($label) -and $reports[$label].argument_round_trip) 'ARGUMENT_ROUND_TRIP_FAILED'; @{ exact_fixed_test_arguments = $true; raw_arguments_logged = $false } }
            Invoke-Case 'T08' "Write virtualization $label" {
                Require ($reports.ContainsKey($label) -and $reports[$label].write_ok -and $reports[$label].boxed_view_changed -and $reports[$label].mapped_is_boxed) 'WRITE_VIRTUALIZATION_UNCONFIRMED'
                Require ((Get-FileHash (Join-Path $fixture 'canaries/write.txt')).Hash -eq $hostHash) 'HOST_CANARY_CHANGED'
                @{ host_hash_unchanged = $true; engine_handle_mapping_boxed = $true }
            }
            Invoke-Case 'T09' "Read and manager metadata exclusions $label" { Require ($reports.ContainsKey($label) -and $reports[$label].blocked_read_error -eq 5 -and $reports[$label].metadata_read_error -eq 5) 'MANDATORY_READ_DENIAL_FAILED'; @{ synthetic_read_denied = $true; manager_metadata_denied = $true } }
            Invoke-Case 'T35' "Sibling physical storage denial $label" { Require ($reports.ContainsKey($label) -and $reports[$label].sibling_read_error -eq 5) 'SIBLING_READ_DENIAL_FAILED'; @{ sibling_storage_denied = $true } }
            Invoke-Case 'T12' "Controlled sockets $label" {
                Require ($reports.ContainsKey("$arch-host") -and $reports.ContainsKey($label)) 'POSITIVE_CONTROL_UNAVAILABLE'
                Require ($(if ($mode -eq 'online') { Net-All $reports[$label] } else { Net-None $reports[$label] }) ) 'NETWORK_POLICY_FAILED'
                @{ tcp4 = $reports[$label].tcp4; tcp6 = $reports[$label].tcp6; udp4 = $reports[$label].udp4; udp6 = $reports[$label].udp6; kernel_wfp_observed = (($bridge.Flags() -band 1) -ne 0); scope = 'Loopback representative smoke only; LAN/DNS/brokers not tested' }
            }
            $null = $bridge.StopHeld($box)
        }
    }
    Invoke-Case 'T33' 'Unapproved automation blocks cleanup dispatch' {
        $observed = @()
        foreach ($key in @('DeleteCommand','OnBoxDelete','OnBoxTerminate','OnFileRecovery')) {
            $bridge.Set($boxA,$key,'P02_UNAPPROVED_SYNTHETIC_COMMAND')
            Require ($bridge.CleanupReason($boxA) -eq 'UNAPPROVED_AUTOMATION') 'HOOK_GUARD_FAILED'
            $observed += $key
            $bridge.Set($boxA,$key,$null)
        }
        Require ($bridge.CleanupReason($boxA) -eq 'BUILTIN_CLEANUP_SCOPE_UNVERIFIED') 'CLEANUP_SCOPE_GUARD_FAILED'
        @{ dispatch_permitted = $false; hooks_checked = $observed; hook_never_executed = $true; builtin_cleanup_scope = 'BLOCKED_SOURCE_REVIEW' }
    }
    Invoke-Case 'T16' 'Password-protected engine configuration uses private IPC' { $bridge.ExerciseProtectedConfiguration($boxB) }
    Invoke-Case 'T02' 'Bounded source-backed configuration, entitlement and diagnostic observation' { $bridge.ReadOnlyInventory() }
    Invoke-Case 'T25' 'Remove only a fresh never-materialized owned definition' {
        $emptyBox = 'SRP02_EMPTY_' + $run.Substring(0,12)
        $bridge.Register($emptyBox); $bridge.Set($emptyBox,'Enabled','y'); $bridge.Set($emptyBox,'FileRootPath',(Join-Path $fixture "boxes/$emptyBox"))
        $bridge.RemoveFreshEmptyDefinition($emptyBox)
    }
    Invoke-Case 'T19' 'Private workspace mapping and boxed executable logical launch' {
        $receipt = $bridge.Launch($boxA,$approved[0],[string[]]@('workspace',$fixture,$boxA,'workspace',$engineHome))
        try { Require ([P02Bridge]::Completed($receipt,15000) -and [P02Bridge]::ExitCode($receipt) -eq 0) 'WORKSPACE_MAPPING_FAILED' }
        finally { [P02Bridge]::CloseReceipt($receipt) }
        $null = $bridge.StopHeld($boxA)
        $mapping = @(Get-ChildItem -LiteralPath $roots[$boxA] -Recurse -File -Filter workspace.mapping)
        Require ($mapping.Count -eq 1 -and $mapping[0].Length -le 8184) 'MAPPING_DESCRIPTOR_UNVERIFIED'
        $physical = $bridge.ResolveSyntheticMapping($boxA,[IO.File]::ReadAllText($mapping[0].FullName,[Text.Encoding]::Unicode))
        $boxedReceipt = $bridge.LaunchSyntheticBoxExecutable($boxA,$physical,[string[]]@('hold',$fixture,$boxA,'imported-exe',$engineHome))
        try { Start-Sleep -Milliseconds 750; Require ($bridge.ObserveLogicalExecutable($boxA)) 'BOX_EXECUTABLE_MEMBERSHIP_UNCONFIRMED'; $null = $bridge.StopHeld($boxA); Require ([P02Bridge]::Completed($boxedReceipt,5000)) 'STOP_INCOMPLETE' }
        finally { [P02Bridge]::CloseReceipt($boxedReceipt) }
        @{ mapping_source = 'SbieDll_GetHandlePath + SbieDll_TranslateNtToDosPath'; physical_hash_matched_original_probe = $true; host_logical_copy_absent = $true; launched_logical_boxed_path = $true; physical_storage_executed_as_host = $false; safe_production_transfer_primitive = 'P09_REQUIRED' }
    }
    Invoke-Case 'T62' 'Retained process handle termination and completed wait' {
        $receipt = $bridge.Launch($boxA,$approved[0],[string[]]@('hold',$fixture,$boxA,'hold',$engineHome))
        try { Start-Sleep -Milliseconds 500; $stopped = $bridge.StopHeld($boxA); Require ([P02Bridge]::Completed($receipt,5000) -and $bridge.Count($boxA) -eq 0) 'STOP_NOT_COMPLETE'; @{ stopped_objects = $stopped; numeric_pid_kill_fallback = $false; creation_time_matched = $true; completed_wait = $true } }
        finally { [P02Bridge]::CloseReceipt($receipt) }
    }
    Invoke-Case 'T36' 'Truncated successful native enumeration does not authorize Idle' {
        $receipt = $bridge.Launch($boxA,$approved[0],[string[]]@('hold',$fixture,$boxA,'enum-bound',$engineHome))
        try { Start-Sleep -Milliseconds 750; $result = $bridge.ExerciseTruncatedEnumeration($boxA); $null = $bridge.StopHeld($boxA); $result }
        finally { [P02Bridge]::CloseReceipt($receipt) }
    }
    Invoke-Case 'T36' 'All-session enumeration includes a real independent session and owner' {
        $taskName = 'SRP02_' + $run
        $nativeExe = Join-Path $probeHome ('feasibility_probe_' + $(if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }) + '.exe')
        $taskArguments = ([string[]]@('session-launch',$fixture,$boxB,'session-zero',$engineHome) | ForEach-Object { [P02Bridge]::Quote($_) }) -join ' '
        $action = New-ScheduledTaskAction -Execute $nativeExe -Argument $taskArguments -WorkingDirectory $engineHome
        $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
        $null = Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal
        try {
            Start-ScheduledTask -TaskName $taskName
            $deadline = [Diagnostics.Stopwatch]::StartNew()
            while ($bridge.Count($boxB) -eq 0 -and $deadline.ElapsedMilliseconds -lt 15000) { Start-Sleep -Milliseconds 250 }
            $result = $bridge.ObserveIndependentSession($boxB)
            while ($bridge.Count($boxB) -ne 0 -and $deadline.ElapsedMilliseconds -lt 35000) { Start-Sleep -Milliseconds 250 }
            Require ($bridge.Count($boxB) -eq 0) 'SECOND_SESSION_OUTCOME_UNKNOWN'
            $result
        } finally { Unregister-ScheduledTask -TaskName $taskName -Confirm:$false }
    }
    Invoke-Case 'T58' 'Boxed native control plane refuses operations' {
        $receipt = $bridge.Launch($boxA,$approved[0],[string[]]@('guard',$fixture,$boxA,'guard',$engineHome))
        try { Require ([P02Bridge]::Completed($receipt,10000) -and [P02Bridge]::ExitCode($receipt) -eq 43) 'BOXED_CONTEXT_NOT_REJECTED'; @{ boxed_context_detected = $true; control_operations_refused = $true; self_escape_attempted = $false } }
        finally { [P02Bridge]::CloseReceipt($receipt) }
        $null = $bridge.StopHeld($boxA)
    }
    Invoke-Case 'T58' 'Actual managed bridge refuses control operations when boxed' {
        # Separate fresh registration is forbidden; use a fresh guard definition.
        $guardBox = 'SRP02_GUARD_' + $run.Substring(0,12)
        $guardBridge.Register($guardBox); $guardBridge.Set($guardBox,'Enabled','y')
        $guardBridge.Set($guardBox,'FileRootPath',(Join-Path $fixture "boxes/$guardBox")); $guardBridge.Set($guardBox,'DropAdminRights','y')
        $guardRoot = $guardBridge.Root($guardBox)
        foreach ($box in $boxes) { $bridge.AppendClosed($box,($guardRoot+'\*')) }
        $null = New-Item -ItemType Directory -Path $guardRoot
        Set-Acl -LiteralPath $guardRoot -AclObject $metadataAcl
        $null = $guardBridge.CaptureRoot($guardBox)
        $receipt = $guardBridge.Launch($guardBox,$guardShell,[string[]]@('-NoLogo','-NoProfile','-NonInteractive','-File',(Join-Path $probeHome 'boxed_bridge_guard.ps1'),'-EngineHome',$engineHome,'-Fixture',$fixture))
        try { Require ([P02Bridge]::Completed($receipt,30000) -and [P02Bridge]::ExitCode($receipt) -eq 43) 'MANAGED_BOXED_CONTEXT_NOT_REJECTED' }
        finally { [P02Bridge]::CloseReceipt($receipt) }
        $report = Read-Report $guardRoot 'managed-guard'
        Require $report.boxed_context_rejected 'MANAGED_BOXED_CONTEXT_NOT_REJECTED'
        $null = $guardBridge.StopHeld($guardBox)
        $report
    }
    Invoke-Case 'T60' 'Stop affected box before future sibling rollout' {
        $receipt = $bridge.Launch($boxA,$approved[0],[string[]]@('hold',$fixture,$boxA,'rollout',$engineHome))
        try {
            Start-Sleep -Milliseconds 500
            Require (-not $bridge.MayMaterializeSibling([string[]]$boxes)) 'RUNNING_SIBLING_CREATION_ALLOWED'
            $futureBox = 'SRP02_NEW_' + $run.Substring(0,12)
            $futureRoot = Join-Path $fixture "boxes/$futureBox"
            Require (-not (Test-Path $futureRoot)) 'FUTURE_STORAGE_ALREADY_EXISTS'
            $null = $bridge.StopHeld($boxA)
            Require ([P02Bridge]::Completed($receipt,5000) -and $bridge.MayMaterializeSibling([string[]]$boxes)) 'STOP_NOT_COMPLETE'
            foreach ($existing in $boxes) { $bridge.AppendClosed($existing,($futureRoot+'\*')) }
            $bridge.Register($futureBox); $bridge.Set($futureBox,'Enabled','y'); $bridge.Set($futureBox,'FileRootPath',$futureRoot); $bridge.Set($futureBox,'DropAdminRights','y')
            $roots[$futureBox] = New-Root $futureBox
            'P02_FUTURE_PRIVATE_CANARY' | Set-Content (Join-Path $roots[$futureBox] 'private.txt')
            [IO.File]::WriteAllText((Join-Path $fixture 'sibling-probe.txt'),(Join-Path $roots[$futureBox] 'private.txt'),[Text.UnicodeEncoding]::new($false,$false))
            $futureReceipt = $bridge.Launch($boxA,$approved[0],(Probe-Args 'exercise' $boxA 'future-sibling'))
            try { Require ([P02Bridge]::Completed($futureReceipt,30000) -and [P02Bridge]::ExitCode($futureReceipt) -eq 0) 'FUTURE_PROBE_FAILED' }
            finally { [P02Bridge]::CloseReceipt($futureReceipt) }
            $futureReport = Read-Report $roots[$boxA] 'future-sibling'
            Require ($futureReport.sibling_read_error -eq 5) 'FUTURE_SIBLING_READ_DENIAL_FAILED'
            $null = $bridge.StopHeld($boxA)
            $alias = Join-Path $fixture 'future-sibling-alias'
            $null = New-Item -ItemType Junction -Path $alias -Target $roots[$futureBox]
            [IO.File]::WriteAllText((Join-Path $fixture 'sibling-probe.txt'),(Join-Path $alias 'private.txt'),[Text.UnicodeEncoding]::new($false,$false))
            $aliasReceipt = $bridge.Launch($boxA,$approved[0],(Probe-Args 'exercise' $boxA 'future-sibling-alias'))
            try { Require ([P02Bridge]::Completed($aliasReceipt,30000) -and [P02Bridge]::ExitCode($aliasReceipt) -eq 0) 'ALIAS_PROBE_FAILED' }
            finally { [P02Bridge]::CloseReceipt($aliasReceipt) }
            $aliasReport = Read-Report $roots[$boxA] 'future-sibling-alias'
            Require ($aliasReport.sibling_read_error -eq 5) 'FUTURE_SIBLING_ALIAS_DENIAL_FAILED'
            $null = $bridge.StopHeld($boxA)
            @{ running_creation_deferred = $true; private_data_absent_until_stopped_and_policy_applied = $true; newly_materialized_sibling_denied = $true; junction_alias_denied = $true; namespace_wide_parent_deny_assumed = $false }
        }
        finally { [P02Bridge]::CloseReceipt($receipt) }
    }
    Invoke-Case 'T35' 'Second standard Windows account root and metadata ACLs' {
        $userName = 'SRP02B_' + $run.Substring(0,10)
        $syntheticPassword = 'P02aA!' + [Guid]::NewGuid().ToString('N')
        $passwordObject = ConvertTo-SecureString $syntheticPassword -AsPlainText -Force
        $null = New-LocalUser -Name $userName -Password $passwordObject -AccountNeverExpires
        $usersGroup = ([Security.Principal.SecurityIdentifier]::new('S-1-5-32-545')).Translate([Security.Principal.NTAccount]).Value.Split('\')[-1]
        Add-LocalGroupMember -Group $usersGroup -Member $userName
        $access = $bridge.OtherUserAccess($userName,$syntheticPassword,$boxB)
        $syntheticPassword = $null; $passwordObject.Dispose()
        Require ($access.different_identity -and -not $access.administrator -and $access.positive_read_error -eq 0) 'SECOND_USER_POSITIVE_CONTROL_UNAVAILABLE'
        Require ($access.metadata_read_error -eq 5 -and $access.root_read_error -eq 5) 'SECOND_USER_ACL_DENIAL_FAILED'
        $access
    }
    Invoke-Case 'T57' 'Forged metadata cannot redirect the generated root scope' {
        $before = $bridge.Read($boxB,'FileRootPath',0x70000000)
        $rejected = $false
        try { $bridge.Set($boxB,'FileRootPath',$env:SystemRoot) } catch { $rejected = $_.Exception.Message -match 'PRIVILEGED_SCOPE_REJECTED' }
        Require ($rejected -and $bridge.Read($boxB,'FileRootPath',0x70000000) -eq $before) 'UNTRUSTED_ROOT_AUTHORITY_ACCEPTED'
        @{ metadata_root_rejected_before_mutation = $true; elevated_helper_present = $false }
    }
    Invoke-Case 'T24' 'Pinned native cleanup clears only the selected known root' {
        foreach ($box in $boxes) { $null = $bridge.StopHeld($box) }
        $siblingCanary = Join-Path $roots[$boxB] 'private.txt'
        $before = (Get-FileHash $siblingCanary).Hash
        $result = $bridge.ClearOwnedWithNative($boxA)
        Require ((Get-FileHash $siblingCanary).Hash -eq $before -and (Get-FileHash (Join-Path $fixture 'canaries/write.txt')).Hash -eq $hostHash) 'CLEANUP_HOST_CANARY_CHANGED'
        $result
    }
} finally {
    $endpoints.Dispose(); Pop-Location
    Save-Cases
}
$cases.Add(@{ id = 'T36'; case = 'Independent Windows interactive sessions'; status = 'BLOCKED'; diagnostic_code = 'SECOND_INTERACTIVE_SESSION_UNAVAILABLE'; source_route = 'SbieApi_EnumProcessEx all_sessions TRUE; capacity and owner validation'; current_session = $bridge.CurrentSession })
$cases.Add(@{ id = 'T57'; case = 'Elevated helper authority'; status = 'NOT_APPLICABLE'; reason = 'No elevated helper path exists in this prototype; protected enrollment design recorded for P05' })
Save-Cases
@{ phase = 'P02'; result = 'BLOCKED'; mandatory_cleanup = 'Pinned QSbieAPI native alternative under test; Start.exe broad phase2 not dispatched'; production_security_scenarios_passed = 0; passed_smoke_cases = @($cases | Where-Object status -EQ 'PASSED').Count; failed_smoke_cases = @($cases | Where-Object status -EQ 'FAILED').Count; os_security_settings_modified = $false; lab_engine_wfp_enabled = $true; teardown = 'DISCARD_ACTIONS_VM' } |
    ConvertTo-Json -Depth 6 | Set-Content (Join-Path $out 'phase-result.json') -Encoding utf8
