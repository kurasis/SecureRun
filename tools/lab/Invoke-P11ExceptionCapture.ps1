# Privileged disposable diagnostics only. Never used by the shipped manager.
if(-not('P11DebugScope' -as [type])){Add-Type @'
using System;using System.Text;using System.Runtime.InteropServices;using System.Text.RegularExpressions;using System.IO;using System.Threading.Tasks;
public sealed class P11DebugPrivilege : IDisposable {
 [StructLayout(LayoutKind.Sequential)]struct Luid {public uint low;public int high;}
 [StructLayout(LayoutKind.Sequential)]struct Privileges {public uint count;public Luid luid;public uint attributes;}
 [DllImport("kernel32.dll")]static extern IntPtr GetCurrentProcess();
 [DllImport("kernel32.dll")]static extern bool CloseHandle(IntPtr value);
 [DllImport("advapi32.dll",SetLastError=true)]static extern bool OpenProcessToken(IntPtr process,uint access,out IntPtr token);
 [DllImport("advapi32.dll",CharSet=CharSet.Unicode,SetLastError=true)]static extern bool LookupPrivilegeValueW(string system,string name,out Luid luid);
 [DllImport("advapi32.dll",SetLastError=true)]static extern bool AdjustTokenPrivileges(IntPtr token,bool disableAll,ref Privileges value,uint size,out Privileges previous,out uint returned);
 IntPtr token;Privileges previous;
 public static P11DebugPrivilege EnableExisting(){IntPtr token;if(!OpenProcessToken(GetCurrentProcess(),0x28,out token))throw new InvalidOperationException("DIAGNOSTIC_EXISTING_DEBUG_PRIVILEGE_UNAVAILABLE");try{Luid luid;if(!LookupPrivilegeValueW(null,"SeDebugPrivilege",out luid))throw new InvalidOperationException("DIAGNOSTIC_EXISTING_DEBUG_PRIVILEGE_UNAVAILABLE");Privileges desired=new Privileges{count=1,luid=luid,attributes=2},old;uint returned;if(!AdjustTokenPrivileges(token,false,ref desired,(uint)Marshal.SizeOf<Privileges>(),out old,out returned)||Marshal.GetLastWin32Error()!=0)throw new InvalidOperationException("DIAGNOSTIC_EXISTING_DEBUG_PRIVILEGE_UNAVAILABLE");return new P11DebugPrivilege{token=token,previous=old};}catch{CloseHandle(token);throw;}}
 public void Dispose(){if(token==IntPtr.Zero)return;try{if(previous.count!=0){Privileges discarded;uint returned;if(!AdjustTokenPrivileges(token,false,ref previous,(uint)Marshal.SizeOf<Privileges>(),out discarded,out returned)||Marshal.GetLastWin32Error()!=0)throw new InvalidOperationException("DIAGNOSTIC_DEBUG_PRIVILEGE_RESTORE_FAILED");}}finally{CloseHandle(token);token=IntPtr.Zero;}}
}
public sealed class P11PrivateToolOutput {
 public long character_count,nul_characters_seen;public int overlong_lines;public bool monitoring_target_matched;
 public readonly System.Collections.Generic.Dictionary<string,int> statuses=new System.Collections.Generic.Dictionary<string,int>();
 public readonly System.Collections.Generic.Dictionary<string,int> exception_codes=new System.Collections.Generic.Dictionary<string,int>();
 static void Add(System.Collections.Generic.Dictionary<string,int> table,string key){if(table.Count>=64&&!table.ContainsKey(key))key="BOUND_REACHED";int n;table.TryGetValue(key,out n);table[key]=n+1;}
 void Line(string raw,uint expected){
  string line=Regex.Replace(raw.Trim(),@"^\[\d{2}:\d{2}:\d{2}\]\s*", "");
  var pid=Regex.Match(line,@"^Monitoring PID:\s*(\d{1,10})$");uint parsed;
  if(pid.Success&&UInt32.TryParse(pid.Groups[1].Value,out parsed)&&parsed==expected){monitoring_target_matched=true;Add(statuses,"MONITOR_HEADER_MATCH");}
  var ex=Regex.Match(line,@"^(Exception|Unhandled): ([0-9a-fA-F]{8})(?:[ .]|$)");
  if(ex.Success)Add(exception_codes,(ex.Groups[1].Value=="Unhandled"?"UNHANDLED_":"OBSERVED_")+ex.Groups[2].Value.ToLowerInvariant());
  string state=null;
  if(line.StartsWith("Error debugging process:",StringComparison.Ordinal))state="DEBUG_ERROR";
  else if(line.StartsWith("Error opening ",StringComparison.Ordinal))state="OPEN_ERROR";
  else if(line.StartsWith("Error writing dump file:",StringComparison.Ordinal))state="DUMP_WRITE_ERROR";
  else if(line.StartsWith("Error",StringComparison.Ordinal))state="OTHER_ERROR_LINE";
  else if(line=="Access is denied.")state="ACCESS_DENIED";
  else if(line=="The parameter is incorrect.")state="INVALID_PARAMETER";
  else if(line=="The handle is invalid.")state="INVALID_HANDLE";
  else if(line=="The system cannot find the file specified.")state="FILE_NOT_FOUND";
  else if(line=="The specified process is being debugged.")state="ALREADY_DEBUGGED";
  else if(line=="Process terminated before capture.")state="PROCESS_EXITED_BEFORE_CAPTURE";
  else if(line=="Dump count not reached.")state="DUMP_COUNT_NOT_REACHED";
  else if(line=="Dump count reached.")state="DUMP_COUNT_REACHED";
  else if(line=="Capture Usage:"||line=="Install Usage:"||line=="Uninstall Usage:")state="USAGE_PRINTED";
  else if(line=="Press Ctrl-C to end monitoring without terminating the process.")state="MONITOR_INSTRUCTIONS_PRINTED";
  if(state!=null)Add(statuses,state);
 }
 public static async Task<P11PrivateToolOutput> Read(TextReader reader,uint expected){var result=new P11PrivateToolOutput();var line=new StringBuilder();char[] buffer=new char[1024];bool overflow=false;int n;while((n=await reader.ReadAsync(buffer,0,buffer.Length).ConfigureAwait(false))!=0){result.character_count=Math.Min(65537,result.character_count+n);for(int i=0;i<n;i++){char c=buffer[i];if(c=='\0'){result.nul_characters_seen=Math.Min(65537,result.nul_characters_seen+1);continue;}if(c=='\n'||c=='\r'){if(overflow)result.overlong_lines++;else if(line.Length>0)result.Line(line.ToString(),expected);line.Clear();overflow=false;}else if(line.Length<2048)line.Append(c);else overflow=true;}}if(overflow)result.overlong_lines++;else if(line.Length>0)result.Line(line.ToString(),expected);return result;}
}
public sealed class P11DebugScope {
 [DllImport("kernel32.dll",SetLastError=true)]static extern IntPtr OpenProcess(uint access,bool inherit,uint id);
 [DllImport("kernel32.dll")]static extern bool CloseHandle(IntPtr value);
 [DllImport("kernel32.dll",SetLastError=true)]static extern bool GetProcessTimes(IntPtr process,out long created,out long exited,out long kernel,out long user);
 [DllImport("kernel32.dll",SetLastError=true)]static extern bool CheckRemoteDebuggerPresent(IntPtr process,[MarshalAs(UnmanagedType.Bool)]out bool present);
 public static long ReadBirth(uint id){IntPtr h=OpenProcess(0x400,false,id);if(h==IntPtr.Zero)return 0;try{long c,e,k,u;return GetProcessTimes(h,out c,out e,out k,out u)?c:0;}finally{CloseHandle(h);}}
 public static bool TryDebugger(uint id,long birth,out bool present){present=false;IntPtr h=OpenProcess(0x400,false,id);if(h==IntPtr.Zero)return false;try{long c,e,k,u;return GetProcessTimes(h,out c,out e,out k,out u)&&c==birth&&CheckRemoteDebuggerPresent(h,out present);}finally{CloseHandle(h);}}
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)]static extern IntPtr LoadLibraryExW(string file,IntPtr reserved,uint flags);
 [DllImport("kernel32.dll",CharSet=CharSet.Ansi)]static extern IntPtr GetProcAddress(IntPtr module,string name);
 [DllImport("kernel32.dll")]static extern bool ProcessIdToSessionId(uint id,out uint session);
 [UnmanagedFunctionPointer(CallingConvention.Cdecl,CharSet=CharSet.Unicode)]delegate int Query(IntPtr pid,uint imageChars,StringBuilder box,StringBuilder image,StringBuilder sid,out uint session,out long born);
 [UnmanagedFunctionPointer(CallingConvention.Cdecl,CharSet=CharSet.Unicode)]delegate int Conf(string section,string key,uint index,StringBuilder value,uint size);
 readonly Query query;readonly Conf conf;readonly IntPtr module;
 public P11DebugScope(string authenticatedDll){module=LoadLibraryExW(authenticatedDll,IntPtr.Zero,0x100|0x800);if(module==IntPtr.Zero)throw new InvalidOperationException("DIAGNOSTIC_DRIVER_LIBRARY_FAILED");var q=GetProcAddress(module,"SbieApi_QueryProcessEx2");var c=GetProcAddress(module,"SbieApi_QueryConf");if(q==IntPtr.Zero||c==IntPtr.Zero)throw new InvalidOperationException("DIAGNOSTIC_DRIVER_EXPORT_FAILED");query=Marshal.GetDelegateForFunctionPointer<Query>(q);conf=Marshal.GetDelegateForFunctionPointer<Conf>(c);}
 public string Owner(uint id,long expectedBirth){uint session,kernelSession;long born;var box=new StringBuilder(40);var sid=new StringBuilder(96);if(query(new IntPtr((long)id),0,box,null,sid,out session,out born)!=0||born!=expectedBirth||!ProcessIdToSessionId(id,out kernelSession)||session!=kernelSession||!Regex.IsMatch(box.ToString(),@"\ASR_[0-9a-f]{32}\z"))return null;var marker=new StringBuilder(2048);if(conf(box.ToString(),"SecureRunOwner",0x70000000U,marker,4096)!=0||marker.ToString()!="v1:"+sid+":"+box.ToString().Substring(3))return null;var enabled=new StringBuilder(16);if(conf(box.ToString(),"Enabled",0x70000000U,enabled,32)!=0||enabled.ToString()!="y")return null;return sid.ToString();}
 [DllImport("kernel32.dll")]static extern IntPtr GetConsoleWindow();
 [DllImport("kernel32.dll",SetLastError=true)]static extern bool AttachConsole(uint pid);
 [DllImport("kernel32.dll")]static extern bool FreeConsole();
 [DllImport("kernel32.dll")]static extern bool SetConsoleCtrlHandler(IntPtr handler,bool add);
 [DllImport("kernel32.dll")]static extern bool GenerateConsoleCtrlEvent(uint kind,uint group);
 [DllImport("kernel32.dll")]static extern uint GetConsoleProcessList([Out]uint[] ids,uint count);
 public static bool StopOwnMonitor(uint toolId,uint observerId){
  // A separate console must contain only this observer and its own pinned tool.
  // Never signal another console or terminate a tool/debuggee by numeric PID.
  if(GetConsoleWindow()!=IntPtr.Zero||!AttachConsole(toolId))return false;
  bool ignore=false;try{uint[] ids=new uint[16];uint n=GetConsoleProcessList(ids,16);if(n==0||n>16)return false;for(int i=0;i<n;i++)if(ids[i]!=toolId&&ids[i]!=observerId)return false;ignore=SetConsoleCtrlHandler(IntPtr.Zero,true);return ignore&&GenerateConsoleCtrlEvent(0,0);}finally{FreeConsole();if(ignore)SetConsoleCtrlHandler(IntPtr.Zero,false);}
 }
}
'@}

function Get-P11StreamHash($Stream){$hash=[Security.Cryptography.SHA256]::Create();try{$Stream.Position=0;return [Convert]::ToHexString($hash.ComputeHash($Stream)).ToLowerInvariant()}finally{$hash.Dispose()}}
function Open-P11PinnedFile([string]$Path){
 $walk=[IO.Path]::GetPathRoot($Path)
 foreach($part in $Path.Substring($walk.Length).Split([char[]]@('\','/'),[StringSplitOptions]::RemoveEmptyEntries)){$walk=Join-Path $walk $part;$item=Get-Item -LiteralPath $walk -Force;if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'DIAGNOSTIC_PIN_REPARSE_REFUSED'}}
 return [IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
}
function New-P11ExceptionCapture([string]$ToolHome,[string]$Repo,[datetime]$Since){
 if(-not $ToolHome){return $null}
 if($env:GITHUB_ACTIONS -ne 'true' -or $ToolHome -ine (Join-Path $env:ProgramFiles ('SecureRun-P11-Diagnostics-'+$env:GITHUB_RUN_ID+'-'+$env:GITHUB_RUN_ATTEMPT))){throw 'DIAGNOSTIC_TOOL_SCOPE_INVALID'}
 $pin=(Get-Content (Join-Path $Repo 'tools/lab/p11-diagnostic-tools.json') -Raw|ConvertFrom-Json).procdump
 $exe=Join-Path $ToolHome $pin.arm64_name;$lease=Open-P11PinnedFile $exe
 if((Get-P11StreamHash $lease) -cne $pin.arm64_sha256){$lease.Dispose();throw 'DIAGNOSTIC_TOOL_PIN_CHANGED'}
 $sig=Get-AuthenticodeSignature -LiteralPath $exe
 if($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch '(?:^|,\s*)O=Microsoft Corporation(?:,|$)'){$lease.Dispose();throw 'DIAGNOSTIC_TOOL_SIGNATURE_CHANGED'}
 $release=Get-Content (Join-Path $Repo 'docs/engine-candidate.json') -Raw|ConvertFrom-Json
 $compat=Get-Content (Join-Path $Repo 'crates/sandboxie-adapter/compatibility-v1.json') -Raw|ConvertFrom-Json
 $dllPin=(@($compat.targets|Where-Object architecture -CEQ 'aarch64')[0].components|Where-Object name -CEQ 'SbieDll.dll').sha256
 $debugPrivilege=[P11DebugPrivilege]::EnableExisting()
 $public=@{
  classification='DEBUGGER_DIAGNOSTIC_ONLY_NO_PHASE_GATE';debugger_mode_enabled=$true;observer_existing_debug_privilege_enabled=$true
  process_memory_dumping_enabled=$true;debugging_changes_fault_delivery=$true
  tool_authenticode='Valid';tool_pinned=$true;engine_payload_pins_ready=$false
  pin_preparation_failures=0;pin_failure_codes=@{};pin_preparation_refused_after_actor_creation=$false
  attach_requests=0;scope_refusals=0;scope_refusal_codes=@{};tool_failures=0;tool_exit_codes=@{};dump_parser_failure_codes=@{}
  completed_without_exception_dump=0;debugger_present_target_count=0;debugger_presence_query_failures=0;tool_status_counts=@{};tool_observed_exception_codes=@{};completed_with_live_undebugged_target=0;active_session_limit=8;attachment_limit=512;attachment_bound_reached=$false
  exceptions=[Collections.Generic.List[object]]::new();explicit_termination_requests_dispatched=$false
  dump_and_tool_output_upload_allowed=$false;capture_cleanup_failed=$false
 }
 return @{
  home=$ToolHome;exe=$exe;repo=$Repo;since=$Since;candidate=$release.lab_installer;dll_pin=$dllPin
  leases=[Collections.Generic.List[object]]::new();tool_lease=$lease;debug_privilege_lease=$debugPrivilege;ready=$false;actors=@{};next_refresh_ms=0
  active=[Collections.Generic.List[object]]::new();seen=@{};guard=$null;public=$public
  helper_path=[IO.Path]::GetFullPath((Join-Path $env:ProgramFiles 'Sandboxie-Plus/SandboxieRpcSs.exe'))
 }
}
function Add-P11CaptureCode($Table,[string]$Code,[string]$Fallback){
 if($Code -cnotmatch '^(?:DIAGNOSTIC_|PRIVATE_DUMP_)[A-Z0-9_]{1,80}$'){$Code=$Fallback}
 if($Table.Count -ge 32 -and -not $Table.ContainsKey($Code)){$Code=$Fallback}
 if(-not $Table.ContainsKey($Code)){$Table[$Code]=0};$Table[$Code]++
}
function Update-P11ExceptionCapture($Context,[long]$Elapsed){
 if($null -eq $Context){return}
 if($Elapsed -ge $Context.next_refresh_ms){
  $Context.next_refresh_ms=$Elapsed+1000
  try{
   $fixtures=@(Get-ChildItem -LiteralPath (Join-Path $env:ProgramData 'SecureRunLab') -Directory -ErrorAction SilentlyContinue|Where-Object {$_.Name -cmatch '^p02-p09-[0-9a-f]{32}$' -and $_.CreationTimeUtc -ge $Context.since.ToUniversalTime()})
   foreach($fixture in $fixtures){$nonce=$fixture.Name.Substring('p02-p09-'.Length);$name='SRP09_'+$nonce.Substring(0,10);$account=Get-LocalUser -Name $name -ErrorAction SilentlyContinue;if($null -ne $account){$Context.actors[$account.SID.Value]=$name}}
   if(-not $Context.ready){
    if($Context.public.pin_preparation_refused_after_actor_creation -or $Context.actors.Count -gt 0 -or @(Get-LocalUser|Where-Object Name -CMatch '^SRP09_[0-9a-f]{10}$').Count -gt 0){$Context.public.pin_preparation_refused_after_actor_creation=$true}
    elseif((Test-Path -LiteralPath $Context.helper_path) -and (Test-Path -LiteralPath (Join-Path $Context.repo 'artifacts/p02/installation.json'))){
     $held=[Collections.Generic.List[object]]::new()
     try{
      $installer=Join-Path $Context.repo ('artifacts/p02/'+$Context.candidate.name);$inputLease=Open-P11PinnedFile $installer;$held.Add($inputLease)
      if($inputLease.Length -ne $Context.candidate.size -or (Get-P11StreamHash $inputLease) -cne $Context.candidate.sha256 -or (Get-AuthenticodeSignature $installer).Status -ne 'Valid'){throw 'DIAGNOSTIC_ORIGINAL_INSTALLER_PIN_FAILED'}
      $reference=Join-Path $Context.repo 'artifacts/p02/authenticated-payload/SandboxieRpcSs.exe';$original=Open-P11PinnedFile $reference;$held.Add($original);$image=Open-P11PinnedFile $Context.helper_path;$held.Add($image)
      $expected=Get-P11StreamHash $original
      if((Get-P11StreamHash $image) -cne $expected -or (Get-AuthenticodeSignature $Context.helper_path).Status -ne 'Valid'){throw 'DIAGNOSTIC_ORIGINAL_HELPER_PIN_FAILED'}
      $dll=Join-Path $env:ProgramFiles 'Sandboxie-Plus/SbieDll.dll';$dllLease=Open-P11PinnedFile $dll;$held.Add($dllLease)
      if((Get-P11StreamHash $dllLease) -cne $Context.dll_pin){throw 'DIAGNOSTIC_ORIGINAL_DRIVER_LIBRARY_PIN_FAILED'}
      if(@(Get-LocalUser|Where-Object Name -CMatch '^SRP09_[0-9a-f]{10}$').Count -gt 0){throw 'DIAGNOSTIC_ACTOR_CREATED_DURING_PIN_PREPARATION'}
      $Context.guard=[P11DebugScope]::new($dll);foreach($file in $held){$Context.leases.Add($file)};$held.Clear();$Context.ready=$true;$Context.public.engine_payload_pins_ready=$true;$Context.public.authenticated_original_helper_sha256=$expected
     }catch{$Context.public.pin_preparation_failures++;Add-P11CaptureCode $Context.public.pin_failure_codes $_.Exception.GetBaseException().Message 'DIAGNOSTIC_PIN_PREPARATION_FAILED'}finally{foreach($file in $held){$file.Dispose()}}
    }
   }
  }catch{$Context.public.pin_preparation_failures++;Add-P11CaptureCode $Context.public.pin_failure_codes $_.Exception.GetBaseException().Message 'DIAGNOSTIC_PIN_PREPARATION_FAILED'}
 }
 foreach($entry in @($Context.active.ToArray())){
  if(-not $entry.hold.HasExited){$debugged=$false;if([P11DebugScope]::TryDebugger([uint32]$entry.id,$entry.hold.Birth,[ref]$debugged)){if($debugged -and -not $entry.debugger_seen){$entry.debugger_seen=$true;$Context.public.debugger_present_target_count++}}else{$Context.public.debugger_presence_query_failures++}}
  if(-not $entry.process.HasExited){continue}
  try{
   $stdout=$entry.stdout.GetAwaiter().GetResult();$stderr=$entry.stderr.GetAwaiter().GetResult()
   foreach($part in @($stdout,$stderr)){foreach($key in $part.statuses.Keys){if(-not $Context.public.tool_status_counts.ContainsKey($key)){$Context.public.tool_status_counts[$key]=0};$Context.public.tool_status_counts[$key]+=$part.statuses[$key]};foreach($originalCode in $part.exception_codes.Keys){$key=$originalCode;if($Context.public.tool_observed_exception_codes.Count -ge 64 -and -not $Context.public.tool_observed_exception_codes.ContainsKey($key)){$key='BOUND_REACHED'};if(-not $Context.public.tool_observed_exception_codes.ContainsKey($key)){$Context.public.tool_observed_exception_codes[$key]=0};$Context.public.tool_observed_exception_codes[$key]+=$part.exception_codes[$originalCode]}}
   if(-not $entry.hold.HasExited -and -not $entry.debugger_seen){$Context.public.completed_with_live_undebugged_target++}
   $recognizedStates=@($stdout.statuses.Keys)+@($stderr.statuses.Keys)
   if(@($recognizedStates|Where-Object {$_ -match 'ERROR|DENIED|INVALID|NOT_FOUND|ALREADY_DEBUGGED|USAGE_PRINTED'}).Count -gt 0){$Context.public.tool_failures++}
   if($stdout.character_count -gt 65536 -or $stderr.character_count -gt 65536){throw 'DIAGNOSTIC_TOOL_OUTPUT_BOUND'}
   $exitKey=[string]$entry.process.ExitCode;if(-not $Context.public.tool_exit_codes.ContainsKey($exitKey)){$Context.public.tool_exit_codes[$exitKey]=0};$Context.public.tool_exit_codes[$exitKey]++
   $dumps=@(Get-ChildItem -LiteralPath $entry.directory -Filter '*.dmp' -File)
   if($dumps.Count -eq 1){$parsed=[P11ExceptionDump]::Read($dumps[0].FullName,[uint32]$entry.id);$parsed['original_helper_image_authenticated']=$true;$parsed['driver_owner_birth_session_marker_confirmed']=$true;$Context.public.exceptions.Add($parsed)}
   elseif($dumps.Count -eq 0){if($entry.process.ExitCode -eq 0){$Context.public.completed_without_exception_dump++}else{$Context.public.tool_failures++}}else{throw 'DIAGNOSTIC_DUMP_COUNT_BOUND'}
  }catch{$Context.public.tool_failures++;Add-P11CaptureCode $Context.public.dump_parser_failure_codes $_.Exception.GetBaseException().Message 'DIAGNOSTIC_DUMP_COLLECTION_FAILED'}finally{$entry.hold.Dispose();$entry.process.Dispose();$null=$Context.active.Remove($entry)}
 }
}
function New-P11PrivateMonitorStartInfo([string]$Exe,[string]$MonitorHome,[string]$Directory,[uint32]$Id){
 $start=[Diagnostics.ProcessStartInfo]::new($Exe);$start.UseShellExecute=$false;$start.WorkingDirectory=$MonitorHome;$start.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
 $start.Environment.Clear();foreach($name in @('SystemRoot','WINDIR','SystemDrive','ProgramFiles','ProgramW6432','ProgramData','RUNNER_TRACKING_ID')){$value=[Environment]::GetEnvironmentVariable($name);if($null -ne $value){$start.Environment[$name]=$value}};$start.Environment['PATH']=Join-Path $env:SystemRoot 'System32';$start.Environment['TEMP']=$Directory;$start.Environment['TMP']=$Directory
 foreach($argument in @('-accepteula','-e','-mm','-n','1',[string]$Id,($Directory+[IO.Path]::DirectorySeparatorChar))){$start.ArgumentList.Add($argument)}
 return $start
}
function Start-P11KnownHelperCapture($Context,[uint32]$Id,$Observed){
 if($null -eq $Context -or -not $Context.ready -or $Context.public.exceptions.Count -gt 0){return}
 $key=[string]$Id+':'+[string]$Observed.Birth;if($Context.seen.ContainsKey($key)){return};$Context.seen[$key]=$true
 if($Context.active.Count -ge 8 -or $Context.public.attach_requests -ge 512){$Context.public.attachment_bound_reached=$true;return}
 $hold=$null
 try{
  $path=$null
  if(-not $Observed.ReadNoncriticalImage([ref]$path) -or $path -ine $Context.helper_path){throw 'DIAGNOSTIC_HELPER_IMAGE_SCOPE_REFUSED'}
  $owner=$Context.guard.Owner($Id,$Observed.Birth)
  if($null -eq $owner -or -not $Context.actors.ContainsKey($owner)){throw 'DIAGNOSTIC_HELPER_OWNER_SCOPE_REFUSED'}
  $hold=[P11ObservedProcess]::Open($Id)
  if($null -eq $hold -or $hold.Birth -ne $Observed.Birth -or $hold.HasExited){throw 'DIAGNOSTIC_HELPER_BIRTH_CHANGED'}
  $number=1+[int]$Context.public.attach_requests;$directory=Join-Path $Context.home ('private-capture-'+$number)
  if(Test-Path -LiteralPath $directory){throw 'DIAGNOSTIC_PRIVATE_OUTPUT_ALREADY_EXISTS'};$null=New-Item -ItemType Directory -Path $directory
  $alreadyDebugged=$false
  if(-not [P11DebugScope]::TryDebugger($Id,$Observed.Birth,[ref]$alreadyDebugged) -or $alreadyDebugged){throw 'DIAGNOSTIC_DEBUGGER_INITIAL_STATE_REFUSED'}
  $start=New-P11PrivateMonitorStartInfo $Context.exe $Context.home $directory $Id
  $tool=[Diagnostics.Process]::Start($start);$Context.public.attach_requests++;$Context.active.Add(@{id=$Id;hold=$hold;process=$tool;directory=$directory;debugger_seen=$false;stdout=[P11PrivateToolOutput]::Read($tool.StandardOutput,$Id);stderr=[P11PrivateToolOutput]::Read($tool.StandardError,$Id)});$hold=$null
 }catch{$Context.public.scope_refusals++;Add-P11CaptureCode $Context.public.scope_refusal_codes $_.Exception.GetBaseException().Message 'DIAGNOSTIC_SCOPE_CHECK_FAILED'}finally{if($null -ne $hold){$hold.Dispose()}}
}
function Stop-P11ExceptionCapture($Context){
 if($null -eq $Context){return}
 $Context.next_refresh_ms=[long]::MaxValue
 foreach($entry in $Context.active){if(-not $entry.process.HasExited){$null=[P11DebugScope]::StopOwnMonitor([uint32]$entry.process.Id,[uint32][Diagnostics.Process]::GetCurrentProcess().Id)}}
 $clock=[Diagnostics.Stopwatch]::StartNew()
 do{Update-P11ExceptionCapture $Context ([long]::MaxValue-10000);if($Context.active.Count -eq 0){break};Start-Sleep -Milliseconds 100}while($clock.ElapsedMilliseconds -lt 5000)
 $Context.public.active_monitors_left_for_vm_cleanup=$Context.active.Count
 foreach($entry in $Context.active){$entry.hold.Dispose()};foreach($lease in $Context.leases){$lease.Dispose()};$Context.tool_lease.Dispose();$Context.debug_privilege_lease.Dispose()
}
