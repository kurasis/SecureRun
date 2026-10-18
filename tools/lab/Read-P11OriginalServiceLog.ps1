# Original publisher log parser only. Names/messages never grant process authority.
if(-not('P11OriginalLog' -as [type])){Add-Type @'
using System;using System.IO;using System.Text;using System.Text.RegularExpressions;using System.Collections.Generic;using System.Security.Cryptography;
public sealed class P11OriginalLog {
 public const string Marker="P11_SYNTHETIC_DIAGNOSTIC_LOG_CALIBRATION";
 public bool calibration_confirmed,bound_reached;public long bytes_read;public int overlong_lines;
 public readonly Dictionary<string,int> message_counts=new Dictionary<string,int>();
 public readonly List<Dictionary<string,object>> sxs_statuses=new List<Dictionary<string,object>>();
 public readonly Dictionary<string,int> ffs_function_counts=new Dictionary<string,int>();
 public readonly Dictionary<string,int> crash_report_counts=new Dictionary<string,int>();
 public readonly Dictionary<string,int> startup_report_counts=new Dictionary<string,int>();
 readonly HashSet<string> allowedFunctions;
 static void Count(Dictionary<string,int> table,string key){int count;table.TryGetValue(key,out count);table[key]=count+1;}
 public P11OriginalLog():this(new string[0]){}
 public P11OriginalLog(string[] allowed){if(allowed.Length>1024)throw new InvalidDataException("DIAGNOSTIC_LOG_SYMBOL_BOUND");allowedFunctions=new HashSet<string>(StringComparer.Ordinal);foreach(string symbol in allowed){if(!Regex.IsMatch(symbol,@"\A[A-Za-z_][A-Za-z0-9_]{0,95}\z"))throw new InvalidDataException("DIAGNOSTIC_LOG_SYMBOL_FORMAT");allowedFunctions.Add(symbol);}}
 readonly Dictionary<string,Dictionary<string,object>> grouped=new Dictionary<string,Dictionary<string,object>>();
 readonly StringBuilder line=new StringBuilder();bool overflow;
 public void ParseLine(string text){
  text=text.TrimStart('\ufeff');
  if(text.Contains(Marker)){if(Regex.IsMatch(text,@"^\s*SBIE2301(?:\s|:)"))calibration_confirmed=true;return;}
  var msg=Regex.Match(text,@"^\s*SBIE([0-9]{4})(?:\s|:)");if(!msg.Success)return;
  string code="SBIE"+msg.Groups[1].Value;if(message_counts.Count>=128&&!message_counts.ContainsKey(code)){bound_reached=true;return;}
  int n;message_counts.TryGetValue(code,out n);message_counts[code]=n+1;
  if(code=="SBIE2329"){
   var hook=Regex.Match(text,@"\b([A-Za-z_][A-Za-z0-9_]{0,95}) \(1\)\s*$");string symbol=hook.Success&&allowedFunctions.Contains(hook.Groups[1].Value)?hook.Groups[1].Value:"WITHHELD";
   if(ffs_function_counts.Count>=128&&!ffs_function_counts.ContainsKey(symbol)){bound_reached=true;return;}Count(ffs_function_counts,symbol);return;
  }
  if(code=="SBIE2224"){
   string[] known={"SandboxieRpcSs.exe","SandboxieDcomLaunch.exe","SbieSvc.exe","securerun-policy-probe.exe","securerun-policy-probe-x86.exe","securerun-policy-probe-x64.exe","securerun-launch-probe.exe","securerun-launch-probe-x86.exe","securerun-launch-probe-x64.exe"};string kind="WITHHELD",exception="UNAVAILABLE";
   foreach(string image in known){var crash=Regex.Match(text,@"\b"+Regex.Escape(image)+@"(?: \(0x([0-9a-fA-F]{8})\))?(?:\s|$)",RegexOptions.IgnoreCase);if(crash.Success){kind=image;if(crash.Groups[1].Success)exception=crash.Groups[1].Value.ToLowerInvariant();break;}}
   string key=kind+"/"+exception;if(crash_report_counts.Count>=128&&!crash_report_counts.ContainsKey(key)){bound_reached=true;return;}Count(crash_report_counts,key);return;
  }
  if(code=="SBIE2204"){
   var start=Regex.Match(text,@"\b(RpcSs|DcomLaunch) \((-?[0-9a-fA-F]{1,10})\)\s*$",RegexOptions.IgnoreCase);
   string key="WITHHELD";if(start.Success)key=(start.Groups[1].Value.Equals("RpcSs",StringComparison.OrdinalIgnoreCase)?"RpcSs":"DcomLaunch")+"/"+start.Groups[2].Value.ToLowerInvariant();
   if(startup_report_counts.Count>=128&&!startup_report_counts.ContainsKey(key)){bound_reached=true;return;}Count(startup_report_counts,key);return;
  }
  if(code!="SBIE2203")return;
  var status=Regex.Match(text,@"RPCSS_SXS - \(Sandboxie RpcSs\) \[([0-9a-fA-F]{2})/([0-9a-fA-F]{8})\]");
  if(status.Success){string level=status.Groups[1].Value.ToLowerInvariant(),value=status.Groups[2].Value.ToLowerInvariant(),key=level+"/"+value;Dictionary<string,object> record;if(grouped.TryGetValue(key,out record)){record["count"]=(int)record["count"]+1;return;}if(sxs_statuses.Count>=128){bound_reached=true;return;}record=new Dictionary<string,object>{{"component_kind","RPCSS_SXS"},{"level_hex",level},{"status_hex",value},{"count",1},{"name_match_is_not_target_authentication",true}};grouped[key]=record;sxs_statuses.Add(record);}
 }
 public void ReadAppend(string file){
  using(var stream=new FileStream(file,FileMode.Open,FileAccess.Read,FileShare.ReadWrite|FileShare.Delete)){
   if(stream.Length>4194304||stream.Length<bytes_read){bound_reached=true;return;}
   stream.Position=bytes_read;int count=(int)Math.Min(32768,stream.Length-bytes_read);count-=count%2;if(count==0)return;
   byte[] data=new byte[count];int got=stream.Read(data,0,count);got-=got%2;bytes_read+=got;
   string text=Encoding.Unicode.GetString(data,0,got);foreach(char c in text){if(c=='\r'||c=='\n'){if(overflow)overlong_lines++;else if(line.Length>0)ParseLine(line.ToString());line.Clear();overflow=false;}else if(line.Length<8192)line.Append(c);else overflow=true;}
  }
 }
}
'@}
