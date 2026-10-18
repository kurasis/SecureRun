# Disposable diagnosis only. Parsed fields never grant process authority.
if(-not('P11LiveWer' -as [type])){Add-Type @'
using System;using System.Collections.Generic;using System.IO;using System.Security.Cryptography;using System.Text;using System.Text.RegularExpressions;using System.Xml;
public static class P11LiveWer {
 static readonly string[] Modules={"SandboxieRpcSs.exe","SandboxieDcomLaunch.exe","SbieDll.dll","rpcss.dll","rpcrt4.dll","ntdll.dll","KERNELBASE.dll","kernel32.dll","ucrtbase.dll","ole32.dll","combase.dll","sechost.dll","advapi32.dll","wow64.dll","wow64win.dll","wow64cpu.dll","wowarmhw.dll","xtajit.dll"};
 static string Leaf(string value){value=(value??"").Trim().Trim('"');int i=value.LastIndexOfAny(new[]{'/','\\'});return value.Substring(i+1);}
 static string Field(Dictionary<string,string> fields,string name){string value;return fields.TryGetValue(name,out value)?value:"";}
 static string Hex(string value,int minimum,int maximum){var m=Regex.Match(value??"","\\A(?:0x)?([0-9a-fA-F]{"+minimum+","+maximum+"})\\z");return m.Success?m.Groups[1].Value.ToLowerInvariant():"WITHHELD";}
 static Dictionary<string,object> Finish(Dictionary<string,string> fields,byte[] data,string source){
  if(!String.Equals(Leaf(Field(fields,"app")),"SandboxieRpcSs.exe",StringComparison.OrdinalIgnoreCase))return null;
  string module="WITHHELD",leaf=Leaf(Field(fields,"module"));foreach(string known in Modules)if(String.Equals(leaf,known,StringComparison.OrdinalIgnoreCase)){module=known;break;}
  string version=Field(fields,"version"),kind=Field(fields,"event");
  if(!Regex.IsMatch(version,@"\A\d{1,10}\.\d{1,10}\.\d{1,10}\.\d{1,10}\z"))version="WITHHELD";
  if(kind!="APPCRASH"&&kind!="BEX"&&kind!="BEX64"&&kind!="AppHangB1"&&kind!="AppHangXProcB1")kind="WITHHELD";
  string hash;using(var sha=SHA256.Create()){hash=BitConverter.ToString(sha.ComputeHash(data)).Replace("-","").ToLowerInvariant();}
  return new Dictionary<string,object>{{"application_kind","SandboxieRpcSs.exe"},{"fault_module_kind",module},{"event_kind",kind},{"exception_code_hex",Hex(Field(fields,"exception"),8,8)},{"exception_offset_hex",Hex(Field(fields,"offset"),8,16)},{"application_version",version},{"source_kind",source},{"private_source_sha256",hash},{"raw_source_retained",false},{"association_authorizes_no_action",true}};
 }
 public static Dictionary<string,object> ParseXml(byte[] data){
  if(data==null||data.Length>262144)throw new InvalidDataException("LIVE_WER_SIZE_BOUND");
  var settings=new XmlReaderSettings{DtdProcessing=DtdProcessing.Prohibit,XmlResolver=null,MaxCharactersInDocument=262144,MaxCharactersFromEntities=0};
  var document=new XmlDocument{XmlResolver=null};using(var memory=new MemoryStream(data))using(var reader=XmlReader.Create(memory,settings)){document.Load(reader);}
  var fields=new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase);
  foreach(XmlNode node in document.SelectNodes("//*[local-name()='ProblemSignatures']/*")){
   string value=node.InnerText;if(value.Length>256)continue;fields[node.LocalName]=value.Trim();
  }
  var output=new Dictionary<string,string>{{"app",Field(fields,"Parameter0")},{"module",Field(fields,"Parameter3")},{"version",Field(fields,"Parameter1")},{"event",Field(fields,"EventType")}};
  // Only APPCRASH has this documented parameter layout. Other events do not
  // acquire a guessed exception code from an unrelated numeric parameter.
  if(Field(fields,"EventType")=="APPCRASH"){output["exception"]=Field(fields,"Parameter6");output["offset"]=Field(fields,"Parameter7");}
  if(output["app"]==""){
   var eventFields=new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase);
   foreach(XmlNode node in document.SelectNodes("//*[local-name()='EventData']/*[local-name()='Data']")){
    var name=node.Attributes["Name"];if(name!=null&&node.InnerText.Length<=256)eventFields[name.Value]=node.InnerText.Trim();
   }
   output["app"]=Field(eventFields,"AppName");output["module"]=Field(eventFields,"ModuleName");output["version"]=Field(eventFields,"AppVersion");output["exception"]=Field(eventFields,"ExceptionCode");output["offset"]=Field(eventFields,"FaultingOffset");
  }
  return Finish(output,data,"LIVE_WER_XML_OR_EXISTING_EVENT");
 }
 public static Dictionary<string,object> ParseWer(byte[] data){
  if(data==null||data.Length>262144)throw new InvalidDataException("LIVE_WER_SIZE_BOUND");
  string text;using(var memory=new MemoryStream(data))using(var reader=new StreamReader(memory,Encoding.UTF8,true)){text=reader.ReadToEnd();}
  var raw=new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase);foreach(string line in text.Split('\n')){int i=line.IndexOf('=');if(i>0&&i<100&&line.Length<=2048)raw[line.Substring(0,i).Trim()]=line.Substring(i+1).Trim();}
  var fields=new Dictionary<string,string>{{"app",Field(raw,"AppName")},{"event",Field(raw,"EventType")}};if(fields["app"]=="")fields["app"]=Field(raw,"AppPath");
  for(int i=0;i<32;i++){string name=Field(raw,"Sig["+i+"].Name"),value=Field(raw,"Sig["+i+"].Value");switch(name){case "Application Name":fields["app"]=value;break;case "Application Version":fields["version"]=value;break;case "Fault Module Name":fields["module"]=value;break;case "Exception Code":fields["exception"]=value;break;case "Exception Offset":fields["offset"]=value;break;}}
  return Finish(fields,data,"LIVE_WER_REPORT");
 }
}
'@}

function Get-P11LiveFaultMetadata([datetime]$Since){
 $ErrorActionPreference='Stop'
 $roots=[Collections.Generic.List[string]]::new();$reports=[Collections.Generic.List[object]]::new();$seen=@{};$failures=0;$visited=0;$read=0;$bytes=0;$bounded=$false;$channels=0;$enabledChannels=0
 $clock=[Diagnostics.Stopwatch]::StartNew()
 function Add-PlainRoot([string]$Path){
  $current=[IO.Path]::GetPathRoot($Path)
  foreach($part in $Path.Substring($current.Length).Split([char[]]@('\','/'),[StringSplitOptions]::RemoveEmptyEntries)){
   $current=Join-Path $current $part;$item=Get-Item -LiteralPath $current -Force -ErrorAction SilentlyContinue
   if($null -eq $item -or -not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)){return}
  }
  if($roots.Count -lt 1024 -and $Path -notin $roots){$roots.Add($Path)}
 }
 try{
  $lab=Join-Path $env:ProgramData 'SecureRunLab'
  $fixtures=@(Get-ChildItem -LiteralPath $lab -Directory -ErrorAction SilentlyContinue|Where-Object {$_.Name -cmatch '^p02-p09-[0-9a-f]{32}$' -and $_.CreationTimeUtc -ge $Since.ToUniversalTime() -and -not($_.Attributes -band [IO.FileAttributes]::ReparsePoint)}|Sort-Object CreationTimeUtc -Descending|Select-Object -First 2)
  $profiles=@(Get-CimInstance Win32_UserProfile -OperationTimeoutSec 3)
  foreach($fixture in $fixtures){
   $nonce=$fixture.Name.Substring('p02-p09-'.Length);$name='SRP09_'+$nonce.Substring(0,10)
   foreach($profile in @($profiles|Where-Object {$_.Loaded -and (Split-Path $_.LocalPath -Leaf) -ieq $name})){
    $local=Join-Path $profile.LocalPath 'AppData/Local';$boxes=Join-Path $local 'SecureRun/boxes'
    foreach($box in @(Get-ChildItem -LiteralPath $boxes -Directory -ErrorAction SilentlyContinue|Where-Object {-not($_.Attributes -band [IO.FileAttributes]::ReparsePoint)}|Sort-Object CreationTimeUtc -Descending|Select-Object -First 64)){
     foreach($relative in @('user/current/AppData/Local/Microsoft/Windows/WER','user/current/AppData/Local/Temp','user/current/Local Settings/Temp','user/all/Microsoft/Windows/WER','user/all/Application Data/Microsoft/Windows/WER',('drive/'+$env:SystemDrive.Substring(0,1)+'/ProgramData/Microsoft/Windows/WER'),('drive/'+$env:SystemDrive.Substring(0,1)+'/Windows/Temp'),('drive/'+$env:SystemDrive.Substring(0,1)+'/Windows/System32/config/systemprofile/AppData/Local/Microsoft/Windows/WER'),('drive/'+$env:SystemDrive.Substring(0,1)+'/Windows/System32/config/systemprofile/AppData/Local/Temp'),('drive/'+$env:SystemDrive.Substring(0,1)+'/ProgramData/SecureRunLab/'+$fixture.Name+'/owner/temp'))){Add-PlainRoot (Join-Path $box.FullName $relative)}
    }
    Add-PlainRoot (Join-Path $local 'Microsoft/Windows/WER');Add-PlainRoot (Join-Path $local 'Temp')
   }
   Add-PlainRoot (Join-Path $fixture.FullName 'owner/temp')
  }
  Add-PlainRoot (Join-Path $env:ProgramData 'Microsoft/Windows/WER');Add-PlainRoot (Join-Path $env:SystemRoot 'Temp')
  $queue=[Collections.Generic.Queue[object]]::new();foreach($root in $roots){$queue.Enqueue(@{path=$root;depth=0})};$clock.Restart()
  while($queue.Count -gt 0 -and $reports.Count -lt 8){
   if($visited -ge 4096 -or $read -ge 128 -or $bytes -ge 4194304 -or $clock.ElapsedMilliseconds -ge 3000){$bounded=$true;break}
   $entry=$queue.Dequeue()
   try{foreach($path in [IO.Directory]::EnumerateFileSystemEntries($entry.path)){
    $visited++;if($visited -ge 4096 -or $read -ge 128 -or $bytes -ge 4194304 -or $clock.ElapsedMilliseconds -ge 3000){$bounded=$true;break}
    $item=Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue;if($null -eq $item -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)){continue}
    if($item.PSIsContainer){if($entry.depth -lt 2){if($queue.Count -lt 1024){$queue.Enqueue(@{path=$path;depth=$entry.depth+1})}else{$bounded=$true}};continue}
    if($item.Name -notmatch '^(?:WER.*\.xml|WER.*\.wer|Report\.wer)$' -or $item.Length -gt 262144 -or $item.CreationTimeUtc -lt $Since.ToUniversalTime()){continue}
    $read++;$stream=$null
    try{
     $stream=[IO.File]::Open($item.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
     $buffer=[byte[]]::new([Math]::Min(262145,4194304-$bytes));$count=0
     do{$received=$stream.Read($buffer,$count,$buffer.Length-$count);$count+=$received}while($received -gt 0 -and $count -lt $buffer.Length)
     $bytes+=$count;if($count -eq $buffer.Length -and $buffer.Length -lt 262145){$bounded=$true;continue};if($count -gt 262144){continue};$data=[byte[]]::new($count);[Array]::Copy($buffer,$data,$count)
    }finally{if($null -ne $stream){$stream.Dispose()}}
    try{$parsed=if($item.Extension -ieq '.wer'){[P11LiveWer]::ParseWer($data)}else{[P11LiveWer]::ParseXml($data)}}catch{$failures++;continue}
    if($null -ne $parsed -and -not $seen.ContainsKey($parsed['private_source_sha256'])){$seen[$parsed['private_source_sha256']]=$true;$reports.Add($parsed);if($reports.Count -ge 8){break}}
   }}catch{$failures++}
  }
 }catch{$failures++}
 # Read existing channels only. No channel or WER configuration is enabled.
 foreach($channel in @('Microsoft-Windows-WER-Diag/Operational','Microsoft-Windows-WindowsErrorReporting/Operational')){
  try{
   $info=Get-WinEvent -ListLog $channel -ErrorAction Stop;$channels++;if(-not $info.IsEnabled){continue};$enabledChannels++
   foreach($event in @(Get-WinEvent -FilterHashtable @{LogName=$channel;StartTime=$Since} -MaxEvents 32 -ErrorAction SilentlyContinue)){
    try{$parsed=[P11LiveWer]::ParseXml([Text.Encoding]::UTF8.GetBytes($event.ToXml()));if($null -ne $parsed -and -not $seen.ContainsKey($parsed['private_source_sha256']) -and $reports.Count -lt 8){$seen[$parsed['private_source_sha256']]=$true;$reports.Add($parsed)}}catch{$failures++}
   }
  }catch{}
 }
 return @{classification='DIAGNOSTIC_ONLY_NO_PHASE_GATE';reports=@($reports.ToArray());records_are_name_matched_not_target_authenticated=$true;exact_target_association_confirmed=$false;plain_roots_found=$roots.Count;directory_entries_visited=$visited;candidate_files_read=$read;candidate_bytes_read=$bytes;read_or_parse_failures=$failures;scan_bound_reached=$bounded;descendant_depth_limit=2;candidate_file_limit=128;per_file_byte_limit=262144;total_byte_limit=4194304;directory_entry_limit=4096;traversal_time_limit_ms=3000;existing_wer_channels_found=$channels;existing_wer_channels_enabled=$enabledChannels;raw_paths_ids_arguments_and_reports_retained=$false;windows_or_reporting_settings_modified=$false}
}
