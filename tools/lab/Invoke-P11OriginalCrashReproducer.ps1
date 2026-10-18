# Original-engine isolation experiment only; never a manager/phase gate.
param([Parameter(Mandatory)][string]$PrivateDirectory,[switch]$CalibrationOnly,[ValidateRange(1,200)][int]$Rounds=200,[ValidateRange(1,45)][int]$BudgetMinutes=40,[switch]$ProductPolicy)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
if($env:GITHUB_ACTIONS -ne 'true' -or $env:PROCESSOR_ARCHITECTURE -ne 'ARM64'){throw 'DISPOSABLE_ARM_ACTIONS_VM_REQUIRED'}
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
. (Join-Path $PSScriptRoot 'Control-P11OriginalServiceLog.ps1')
. (Join-Path $PSScriptRoot 'Read-P11ExceptionDump.ps1')
Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $repo 'tools/probe/p05_lab.cs')))
Add-Type @'
using System;using System.Text;using System.Runtime.InteropServices;using System.Security.Principal;using System.IO;
public sealed class P11OriginalCrashEngine {
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode)]static extern IntPtr LoadLibraryExW(string path,IntPtr reserved,uint flags);
 [DllImport("kernel32.dll",CharSet=CharSet.Ansi)]static extern IntPtr GetProcAddress(IntPtr module,string name);
 [DllImport("kernel32.dll")]static extern uint WaitForSingleObject(IntPtr handle,uint wait);
 [DllImport("kernel32.dll",SetLastError=true)]static extern bool GetExitCodeProcess(IntPtr handle,out uint code);
 [DllImport("kernel32.dll")]static extern bool CloseHandle(IntPtr handle);
 [UnmanagedFunctionPointer(CallingConvention.Cdecl,CharSet=CharSet.Unicode)]delegate uint Update(char op,string password,string section,string key,string value);
 [UnmanagedFunctionPointer(CallingConvention.Cdecl,CharSet=CharSet.Unicode)]delegate int Conf(string section,string key,uint index,StringBuilder value,uint bytes);
 [UnmanagedFunctionPointer(CallingConvention.Cdecl)]delegate int Reload(uint session,uint flags);
 [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)]struct Startup {public uint size;public string reserved,desktop,title;public uint x,y,width,height,xchars,ychars,fill,flags;public ushort show,cb;public IntPtr reserved2,input,output,error;}
 [StructLayout(LayoutKind.Sequential)]struct Receipt {public IntPtr process,thread;public uint pid,tid;}
 [UnmanagedFunctionPointer(CallingConvention.Cdecl,CharSet=CharSet.Unicode)][return:MarshalAs(UnmanagedType.Bool)]delegate bool Run(string box,string command,string dir,uint flags,ref Startup startup,out Receipt receipt);
 readonly Update update;readonly Conf conf;readonly Reload reload;readonly Run run;readonly string code;
 readonly System.Collections.Generic.HashSet<string> boxes=new System.Collections.Generic.HashSet<string>();
 T Bind<T>(IntPtr m,string n) where T:Delegate {IntPtr p=GetProcAddress(m,n);if(p==IntPtr.Zero)throw new InvalidOperationException("DIAGNOSTIC_REPRO_EXPORT_MISSING");return Marshal.GetDelegateForFunctionPointer<T>(p);}
 public P11OriginalCrashEngine(string pinnedDll,string codeDirectory){IntPtr m=LoadLibraryExW(pinnedDll,IntPtr.Zero,0x100|0x800);if(m==IntPtr.Zero)throw new InvalidOperationException("DIAGNOSTIC_REPRO_LIBRARY_FAILED");update=Bind<Update>(m,"SbieDll_UpdateConf");conf=Bind<Conf>(m,"SbieApi_QueryConf");reload=Bind<Reload>(m,"SbieApi_ReloadConf");run=Bind<Run>(m,"SbieDll_RunSandboxed");code=codeDirectory;}
 public string Read(string section,string key,uint index){var value=new StringBuilder(4096);int status=conf(section,key,index,value,8192);if(unchecked((uint)status)==0xc000008bU||unchecked((uint)status)==0xc0000034U)return null;if(status!=0)throw new InvalidOperationException("DIAGNOSTIC_REPRO_QUERY_FAILED");return value.ToString();}
 void Set(string box,string key,string value){if(update('s',null,box,key,value)!=0)throw new InvalidOperationException("DIAGNOSTIC_REPRO_CONFIG_FAILED");}
 public string Fresh(string root,bool control){string id=Guid.NewGuid().ToString("N"),box="SR_"+id;if(Read(box,null,0x70000000U)!=null)throw new InvalidOperationException("DIAGNOSTIC_REPRO_PREEXISTING_BOX");Set(box,"Enabled","n");Set(box,"SecureRunOwner","v1:"+WindowsIdentity.GetCurrent().User.Value+":"+id);Set(box,"AutoDelete","n");Set(box,"AutoRecover","n");Set(box,"DropAdminRights","y");Set(box,"FileRootPath",root);Set(box,"EnableMiniDump","SandboxieRpcSs.exe,y");if(control&&update('a',null,box,"EnableMiniDump","p11-original-crash-probe-arm64.exe,y")!=0)throw new InvalidOperationException("DIAGNOSTIC_REPRO_CONFIG_FAILED");Set(box,"Enabled","y");if(reload((uint)System.Diagnostics.Process.GetCurrentProcess().SessionId,0)!=0)throw new InvalidOperationException("DIAGNOSTIC_REPRO_RELOAD_FAILED");boxes.Add(box);return box;}
 public uint Execute(string box,string architecture,bool crash,out uint processId){if((architecture!="arm64"&&architecture!="x64"&&architecture!="x86")||(crash&&architecture!="arm64"))throw new InvalidOperationException("DIAGNOSTIC_REPRO_SCOPE_REFUSED");return ExecuteImage(box,"p11-original-crash-probe-"+architecture+".exe",crash?"crash":null,out processId);}
 public uint ExecuteImage(string box,string name,string argument,out uint processId){processId=0;if(!boxes.Contains(box)||name.IndexOfAny(new[]{'\\','/',':','"'})>=0||(argument!=null&&!System.Text.RegularExpressions.Regex.IsMatch(argument,"^(?:crash|[0-9a-f]{2,16384})$")))throw new InvalidOperationException("DIAGNOSTIC_REPRO_SCOPE_REFUSED");string image=Path.Combine(code,name);if(!File.Exists(image))throw new InvalidOperationException("DIAGNOSTIC_REPRO_IMAGE_MISSING");var startup=new Startup{size=(uint)Marshal.SizeOf<Startup>()};Receipt receipt;if(!run(box,"\""+image+"\""+(argument!=null?" "+argument:""),code,0x08000000U,ref startup,out receipt))throw new InvalidOperationException("DIAGNOSTIC_REPRO_DISPATCH_REFUSED");processId=receipt.pid;try{if(WaitForSingleObject(receipt.process,45000)!=0)return 0xffffffffU;uint exit;if(!GetExitCodeProcess(receipt.process,out exit))throw new InvalidOperationException("DIAGNOSTIC_REPRO_EXIT_UNKNOWN");return exit;}finally{CloseHandle(receipt.thread);CloseHandle(receipt.process);}}
 // Product-compiled section (from the production compile function) plus only the
 // image-scoped original crash filter. Pairs alternate key,value; repeats append.
 public string FreshPolicy(string id,string[] pairs){if(!System.Text.RegularExpressions.Regex.IsMatch(id,"^[0-9a-f]{32}$")||pairs.Length%2!=0)throw new InvalidOperationException("DIAGNOSTIC_REPRO_SCOPE_REFUSED");string box="SR_"+id;if(Read(box,null,0x70000000U)!=null)throw new InvalidOperationException("DIAGNOSTIC_REPRO_PREEXISTING_BOX");Set(box,"Enabled","n");Set(box,"ConfigLevel","10");var seen=new System.Collections.Generic.HashSet<string>{"Enabled","ConfigLevel"};for(int i=0;i<pairs.Length;i+=2){string key=pairs[i],value=pairs[i+1];if(key=="Enabled"||key=="ConfigLevel"||key=="EnableMiniDump")continue;if(update(seen.Add(key)?'s':'a',null,box,key,value)!=0)throw new InvalidOperationException("DIAGNOSTIC_REPRO_CONFIG_FAILED");}Set(box,"EnableMiniDump","SandboxieRpcSs.exe,y");Set(box,"Enabled","y");if(reload((uint)System.Diagnostics.Process.GetCurrentProcess().SessionId,0)!=0)throw new InvalidOperationException("DIAGNOSTIC_REPRO_RELOAD_FAILED");boxes.Add(box);return box;}
}
'@
function New-PrivateDirectory([string]$Path,[switch]$Executable){
 if(Test-Path -LiteralPath $Path){throw 'DIAGNOSTIC_REPRO_PREEXISTING_DIRECTORY'}
 $null=New-Item -ItemType Directory -Path $Path
 $acl=[Security.AccessControl.DirectorySecurity]::new();$acl.SetAccessRuleProtection($true,$false)
 foreach($sid in @('S-1-5-18','S-1-5-32-544',[Security.Principal.WindowsIdentity]::GetCurrent().User.Value)|Select-Object -Unique){$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new($sid),'FullControl','ContainerInherit,ObjectInherit','None','Allow'))}
 if($Executable){$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new('S-1-5-32-545'),'ReadAndExecute','ContainerInherit,ObjectInherit','None','Allow'))}
 Set-Acl -LiteralPath $Path -AclObject $acl
}
$out=Join-Path $repo 'artifacts/p11-diagnostics';$null=New-Item -ItemType Directory -Path $out -Force
$report=@{classification='ORIGINAL_ENGINE_CRASH_FILTER_EXPERIMENT_NO_PHASE_GATE';result='IN_PROGRESS';production_policy_changed=$false;global_sandbox_settings_changed=$false;windows_security_or_wer_settings_changed=$false;debugger_attachment_requested=$false;original_filter_changes_fault_delivery=$true;raw_dump_upload_allowed=$false;calibration_only=[bool]$CalibrationOnly;synthetic_exception_confirmed=$false;completed_parent_child_pairs=0;planned_parent_child_pairs=$(if($CalibrationOnly){0}elseif($ProductPolicy){6*$Rounds}else{3*$Rounds});time_budget_minutes=$BudgetMinutes;time_budget_reached=$false;rpcss_alive_after_probe_cases=0;product_policy=[bool]$ProductPolicy;policy_probe_nonzero_exits=0;cases=[Collections.Generic.List[object]]::new();dumps=[Collections.Generic.List[object]]::new()}
$logger=$null;$leases=[Collections.Generic.List[object]]::new();$activeBox=$null;$lab=$null;$root=$null;$caseRoots=[Collections.Generic.List[string]]::new()
try{
 $report.tested_source_commit=(& git -C $repo rev-parse HEAD).Trim()
 $report.engine_source_commit=(Get-Content (Join-Path $repo 'docs/engine-candidate.json') -Raw|ConvertFrom-Json).source_commit
 $report.synthetic_source_sha256=(Get-FileHash (Join-Path $PSScriptRoot 'p11-original-crash-probe.c')).Hash.ToLowerInvariant()
 $report.probe_builds=[Collections.Generic.List[object]]::new()
 $logger=New-P11OriginalServiceLog $PrivateDirectory $repo;Update-P11OriginalServiceLog $logger
 if(-not $logger.ready -or $logger.failed){throw 'DIAGNOSTIC_REPRO_LOG_CALIBRATION_FAILED'}
 $engineHome=Join-Path $env:ProgramFiles 'Sandboxie-Plus'
 foreach($name in @('SandboxieRpcSs.exe','SandboxieDcomLaunch.exe')){
  $installed=Join-Path $engineHome $name;$reference=Join-Path $repo ('artifacts/p02/authenticated-payload/'+$name)
  $a=Open-P11PinnedFile $installed;$leases.Add($a);$b=Open-P11PinnedFile $reference;$leases.Add($b)
  if((Get-P11StreamHash $a) -cne (Get-P11StreamHash $b) -or (Get-AuthenticodeSignature $installed).Status -ne 'Valid'){throw 'DIAGNOSTIC_REPRO_ORIGINAL_HELPER_PIN_FAILED'}
 }
 $nonce=[Guid]::NewGuid().ToString('N');$root=Join-Path $env:ProgramData ('SecureRunLab/p02-p11-crash-'+$nonce);New-PrivateDirectory $root
 $code=Join-Path $env:ProgramFiles ('SecureRun-P11-CrashProbe-'+$env:GITHUB_RUN_ID+'-'+$env:GITHUB_RUN_ATTEMPT);New-PrivateDirectory $code -Executable
 $vswhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe';$vs=& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
 if($LASTEXITCODE -ne 0 -or -not $vs){throw 'DIAGNOSTIC_REPRO_COMPILER_MISSING'}
 Import-Module (Join-Path $vs 'Common7/Tools/Microsoft.VisualStudio.DevShell.dll');Enter-VsDevShell -VsInstallPath $vs -SkipAutomaticLocation -DevCmdArguments '-arch=arm64 -host_arch=arm64'|Out-Null
 $vc=$env:VCToolsInstallDir;$sdk=$env:WindowsSdkDir;$version=$env:WindowsSDKVersion.TrimEnd('\','/')
 foreach($arch in @('arm64','x64','x86')){
  $env:LIB=@((Join-Path $vc "lib/$arch"),(Join-Path $sdk "Lib/$version/ucrt/$arch"),(Join-Path $sdk "Lib/$version/um/$arch")) -join ';'
  $exe=Join-Path $code ('p11-original-crash-probe-'+$arch+'.exe');Push-Location $code
  try{& (Join-Path $vc "bin/Hostarm64/$arch/cl.exe") /nologo /W4 /WX /wd4204 /O2 /DUNICODE /D_UNICODE (Join-Path $PSScriptRoot 'p11-original-crash-probe.c') ole32.lib "/Fe:$exe" /link "/MACHINE:$($arch.ToUpperInvariant())";if($LASTEXITCODE -ne 0){throw 'DIAGNOSTIC_REPRO_BUILD_FAILED'}}finally{Pop-Location}
  $bytes=[IO.File]::ReadAllBytes($exe);$pe=[BitConverter]::ToInt32($bytes,0x3c);if([BitConverter]::ToUInt16($bytes,$pe+4) -ne @{arm64=0xaa64;x64=0x8664;x86=0x014c}[$arch]){throw 'DIAGNOSTIC_REPRO_PE_MISMATCH'}
  $binary=Open-P11PinnedFile $exe;$leases.Add($binary)
  $report.probe_builds.Add(@{architecture=$arch;pe_machine=([BitConverter]::ToUInt16($bytes,$pe+4)).ToString('x4');sha256=(Get-P11StreamHash $binary)})
 }
 if($ProductPolicy){
  # Product-compiled scopes: exact production compile output and the actual
  # policy canary, built from this commit for all three architectures.
  $rustTarget='aarch64-pc-windows-msvc';$env:RUSTUP_TOOLCHAIN="1.90.0-$rustTarget"
  rustup toolchain install $env:RUSTUP_TOOLCHAIN --profile minimal;if($LASTEXITCODE -ne 0){throw 'DIAGNOSTIC_REPRO_RUST_INSTALL_FAILED'}
  Push-Location $repo
  try{
   cargo build --locked -p securerun-sandboxie-adapter --example p11_compiled_policy --target $rustTarget;if($LASTEXITCODE -ne 0){throw 'DIAGNOSTIC_REPRO_POLICY_BUILD_FAILED'}
   $compiler=Join-Path $code 'p11-compiled-policy.exe';Copy-Item (Join-Path $repo "target/$rustTarget/debug/examples/p11_compiled_policy.exe") $compiler
   foreach($probe in @(@{architecture='arm64';target=$rustTarget;name='securerun-policy-probe.exe'},@{architecture='x64';target='x86_64-pc-windows-msvc';name='securerun-policy-probe-x64.exe'},@{architecture='x86';target='i686-pc-windows-msvc';name='securerun-policy-probe-x86.exe'})){
    rustup target add $probe.target;if($LASTEXITCODE -ne 0){throw 'DIAGNOSTIC_REPRO_RUST_TARGET_FAILED'}
    cargo build --locked --release -p securerun-sandboxie-adapter --bin securerun-policy-probe --target $probe.target;if($LASTEXITCODE -ne 0){throw 'DIAGNOSTIC_REPRO_POLICY_PROBE_BUILD_FAILED'}
    $exe=Join-Path $code $probe.name;Copy-Item (Join-Path $repo ('target/'+$probe.target+'/release/securerun-policy-probe.exe')) $exe
    $binary=Open-P11PinnedFile $exe;$leases.Add($binary);$report.probe_builds.Add(@{architecture=$probe.architecture;kind='policy-canary';sha256=(Get-P11StreamHash $binary)})
   }
  }finally{Pop-Location}
  # Same lab WFP prerequisite as P05/P09; offline product scopes depend on it.
  Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $repo 'tools/probe/engine_bridge.cs')))
  $bridge=[P02Bridge]::new($engineHome,$root,[string[]]@());$bridge.EnableLabWfp();$report.lab_wfp_prerequisite='NetworkEnableWFP=y'
  $labMetadata=Join-Path $root 'metadata';$labSibling=Join-Path $root 'sibling';$labManager=Join-Path $root 'manager.bin'
  New-PrivateDirectory $labMetadata;New-PrivateDirectory $labSibling;[IO.File]::WriteAllText($labManager,'SYNTHETIC_MANAGER_PLACEHOLDER')
  [IO.File]::WriteAllText((Join-Path $labMetadata 'canary.txt'),'SYNTHETIC_MANAGER_CANARY');[IO.File]::WriteAllText((Join-Path $labSibling 'canary.txt'),'SYNTHETIC_SIBLING_CANARY')
 }
 $api=[P11OriginalCrashEngine]::new((Join-Path $engineHome 'SbieDll.dll'),$code);$lab=[P05Lab]::new($engineHome,$root,$code)
 # The positive control must reach the original in-process filter without any debugger.
 $controlRoot=Join-Path $root 'control';$caseRoots.Add($controlRoot);$activeBox=$api.Fresh($controlRoot,$true);$lab.Register($activeBox)
 $pidValue=[uint32]0;$exitCode=$api.Execute($activeBox,'arm64',$true,[ref]$pidValue)
 Update-P11OriginalServiceLog $logger
 $files=@(Get-ChildItem -LiteralPath $controlRoot -File -Filter 'p11-original-crash-probe-arm64.exe.*.dmp')
 if($files.Count -ne 1){throw 'DIAGNOSTIC_REPRO_CONTROL_DUMP_MISSING'}
 $proof=[P11ExceptionDump]::Read($files[0].FullName,$pidValue);$proof['classification']='SYNTHETIC_ORIGINAL_FILTER_CALIBRATION_NO_PHASE_GATE'
 if($proof.exception_code_hex -cne 'e0424242'){throw 'DIAGNOSTIC_REPRO_CONTROL_EXCEPTION_MISMATCH'}
 $report.synthetic_exception_confirmed=$true;$report.control_exception=$proof;$report.control_exit_code_hex=$exitCode.ToString('x8')
 $lab.FenceFixture($activeBox);$activeBox=$null;Update-P11OriginalServiceLog $logger
 if($logger.reader.crash_report_counts.Keys -match '^SandboxieRpcSs.exe/'){$report.result='RPCSS_CRASH_REPRODUCED'}
 if(-not $CalibrationOnly -and $report.result -ne 'RPCSS_CRASH_REPRODUCED'){
  # Retained traces show about 0.5-0.8% of original RpcSs starts fault on ARM64,
  # so 24 pairs would usually miss it. Bound by rounds and wall time instead.
  $budget=[Diagnostics.Stopwatch]::StartNew()
  for($index=0;$index -lt $Rounds;$index++){
   if($budget.Elapsed.TotalMinutes -ge $BudgetMinutes){$report.time_budget_reached=$true;break}
   foreach($kind in $(if($ProductPolicy){@('com','canary')}else{@('com')})){
   foreach($arch in @('arm64','x64','x86')){
    $caseRoot=Join-Path $root ('case-'+$index+'-'+$kind+'-'+$arch);$caseRoots.Add($caseRoot)
    if($ProductPolicy){
     $id=[Guid]::NewGuid().ToString('N');$marker='v1:'+[Security.Principal.WindowsIdentity]::GetCurrent().User.Value+':'+$id
     $json=& $compiler 'STANDARD_OFFLINE' $caseRoot $labMetadata $labManager $labSibling $marker;if($LASTEXITCODE -ne 0){throw 'DIAGNOSTIC_REPRO_POLICY_COMPILE_FAILED'}
     $section=$json|ConvertFrom-Json -AsHashtable;$pairs=[Collections.Generic.List[string]]::new()
     foreach($key in $section.Keys){foreach($value in $section[$key]){$pairs.Add($key);$pairs.Add($value)}}
     $canaryBase=Join-Path $root ('canary-'+$index+'-'+$kind+'-'+$arch);$null=New-Item -ItemType Directory -Path $canaryBase
     foreach($leaf in @('write.txt','delete.txt','blocked.txt','readonly.txt')){[IO.File]::WriteAllText((Join-Path $canaryBase $leaf),'SYNTHETIC_HOST_CANARY')}
     # The verification scope also narrows its own blocked/read-only canaries.
     foreach($rule in @(@('ClosedFilePath','blocked.txt'),@('ReadFilePath','readonly.txt'))){$path=Join-Path $canaryBase $rule[1];$pairs.Add($rule[0]);$pairs.Add($path);$pairs.Add($rule[0]);$pairs.Add($path+'\*')}
     $activeBox=$api.FreshPolicy($id,$pairs.ToArray())
    }else{$activeBox=$api.Fresh($caseRoot,$false)}
    $lab.Register($activeBox)
    $started=[DateTime]::Now;$pidValue=[uint32]0
    if($kind -eq 'canary'){
     $ports=@(1..6|ForEach-Object {Get-Random -Minimum 49152 -Maximum 65535})
     $canary=[ordered]@{box_name=$activeBox;write=(Join-Path $canaryBase 'write.txt');delete=(Join-Path $canaryBase 'delete.txt');blocked=(Join-Path $canaryBase 'blocked.txt');read_only=(Join-Path $canaryBase 'readonly.txt');metadata=(Join-Path $labMetadata 'canary.txt');sibling=(Join-Path $labSibling 'canary.txt');metadata_alias=(Join-Path $canaryBase 'metadata-alias.txt');sibling_alias=(Join-Path $canaryBase 'sibling-alias.txt');metadata_short=$null;sibling_short=$null;output=(Join-Path $canaryBase 'report.json');incoming_output=(Join-Path $canaryBase 'incoming.json');registry_leaf=[Guid]::NewGuid().ToString('N');ports=$ports;dns_target='target-p11-stress.test';dns_cached='control-p11-stress.test';mapped_share=$false;lan_address=@(127,0,0,1);child=$false;offline=$true}
     $hex=[Convert]::ToHexString([Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject $canary -Compress))).ToLowerInvariant()
     $name=@{arm64='securerun-policy-probe.exe';x64='securerun-policy-probe-x64.exe';x86='securerun-policy-probe-x86.exe'}[$arch]
     $exitCode=$api.ExecuteImage($activeBox,$name,$hex,[ref]$pidValue)
    }else{$exitCode=$api.Execute($activeBox,$arch,$false,[ref]$pidValue)}
    # Name/start-time observation only; it authorizes no process action.
    $rpcss=@(Get-Process -Name 'SandboxieRpcSs' -ErrorAction SilentlyContinue|Where-Object {try{$_.StartTime -ge $started}catch{$false}}).Count -gt 0
    if($rpcss){$report.rpcss_alive_after_probe_cases++}
    Update-P11OriginalServiceLog $logger
    $report.cases.Add(@{ordinal=$report.cases.Count+1;kind=$kind;architecture=$arch;exit_code_hex=$exitCode.ToString('x8');rpcss_alive_after_probe=$rpcss})
    if($logger.reader.crash_report_counts.Keys -match '^SandboxieRpcSs.exe/'){
     $report.result='RPCSS_CRASH_REPRODUCED'
     break
    }
    # The canary's own assertions are not under test here; only bounded setup errors stop the sample.
    if($exitCode -ne 0 -and $kind -eq 'canary'){$report.policy_probe_nonzero_exits++;if($report.policy_probe_nonzero_exits -gt 24){throw 'DIAGNOSTIC_REPRO_POLICY_PROBE_SETUP_FAILED'}}elseif($exitCode -ne 0){throw 'DIAGNOSTIC_REPRO_PAIR_FAILED'}
    $report.completed_parent_child_pairs++;$lab.FenceFixture($activeBox);$activeBox=$null
   }
   if($report.result -eq 'RPCSS_CRASH_REPRODUCED'){break}
   }
   if($report.result -eq 'RPCSS_CRASH_REPRODUCED'){break}
  }
 }
 if($report.result -ne 'RPCSS_CRASH_REPRODUCED'){$report.result=if($CalibrationOnly){'CALIBRATION_PASSED'}else{'NOT_REPRODUCED_IN_BOUNDED_SAMPLE'}}
}catch{
 $report.result='FAILED';$message=$_.Exception.GetBaseException().Message
 $report.code=if($message -cmatch '^(?:DIAGNOSTIC_|PRIVATE_DUMP_|LAB_)[A-Z0-9_]{1,100}$'){$message}else{'DIAGNOSTIC_REPRO_FAILED'}
 $report.exception_type=$_.Exception.GetBaseException().GetType().FullName;$report.script_line=$_.InvocationInfo.ScriptLineNumber
}finally{
 if($null -ne $activeBox -and $null -ne $lab){try{$lab.FenceFixture($activeBox)}catch{$report.cleanup_refused=$true;$report.cleanup_code='DIAGNOSTIC_REPRO_CLEANUP_REFUSED';if($report.result -ne 'RPCSS_CRASH_REPRODUCED'){$report.result='FAILED'}}}
 if($null -ne $logger){Stop-P11OriginalServiceLog $logger;$log=Get-P11OriginalServiceLogReport $logger;$log|ConvertTo-Json -Depth 8|Set-Content (Join-Path $out 'original-service-log.json') -Encoding utf8;$report.original_service_log_restored=$log.previous_registry_value_restored;if($log.failed -or -not $log.previous_registry_value_restored){$report.result='FAILED';$report.code='DIAGNOSTIC_REPRO_LOG_INCOMPLETE'}}
 try{
  foreach($caseRoot in $caseRoots){
   if(-not(Test-Path -LiteralPath $caseRoot)){continue}
   foreach($file in @(Get-ChildItem -LiteralPath $caseRoot -File -Filter 'SandboxieRpcSs.exe.*.dmp')){
    if($report.dumps.Count -ge 8){throw 'DIAGNOSTIC_REPRO_DUMP_COUNT_BOUND'}
    $report.dumps.Add([P11ExceptionDump]::ReadPublisherDump($file.FullName))
   }
  }
 }catch{$report.dump_read_failed=$true;$report.dump_read_code='DIAGNOSTIC_REPRO_PRIVATE_DUMP_UNREADABLE'}
 foreach($lease in $leases){$lease.Dispose()}
 $report|ConvertTo-Json -Depth 10|Set-Content (Join-Path $out 'original-crash-reproducer.json') -Encoding utf8
}
if($report.result -eq 'FAILED'){throw 'P11_ORIGINAL_ENGINE_REPRODUCER_FAILED'}
Write-Host ('Original-engine diagnostic result: '+$report.result+'; never phase completion evidence')
