if(-not('P11ExceptionDump' -as [type])){Add-Type @'
using System;using System.IO;using System.Text;using System.Collections.Generic;using System.Security.Cryptography;
public static class P11ExceptionDump {
 const int Limit=67108864;
 static void Bound(byte[] data,long offset,long count){if(offset<0||count<0||offset>data.LongLength-count)throw new InvalidDataException("PRIVATE_DUMP_BOUNDS");}
 static uint U32(byte[] d,long p){Bound(d,p,4);return BitConverter.ToUInt32(d,(int)p);}
 static ulong U64(byte[] d,long p){Bound(d,p,8);return BitConverter.ToUInt64(d,(int)p);}
 static string Name(byte[] d,uint rva){uint n=U32(d,rva);if(n>2048||(n&1)!=0)throw new InvalidDataException("PRIVATE_DUMP_NAME_BOUND");Bound(d,(long)rva+4,n);string s=Encoding.Unicode.GetString(d,(int)rva+4,(int)n);int i=s.LastIndexOfAny(new[]{'/','\\'});return s.Substring(i+1);}
 public static Dictionary<string,object> Parse(byte[] data,uint expectedProcess){
  if(data==null||data.Length>Limit||U32(data,0)!=0x504d444d)throw new InvalidDataException("PRIVATE_DUMP_HEADER");
  uint count=U32(data,8),directory=U32(data,12);if(count>128)throw new InvalidDataException("PRIVATE_DUMP_STREAM_BOUND");Bound(data,directory,(long)count*12);
  var streams=new Dictionary<uint,uint[]>();for(uint i=0;i<count;i++){long p=(long)directory+i*12;uint kind=U32(data,p),size=U32(data,p+4),rva=U32(data,p+8);Bound(data,rva,size);if(kind!=4&&kind!=6&&kind!=7&&kind!=15)continue;if(streams.ContainsKey(kind))throw new InvalidDataException("PRIVATE_DUMP_DUPLICATE_STREAM");streams[kind]=new[]{rva,size};}
  if(!streams.ContainsKey(6)||streams[6][1]<168||!streams.ContainsKey(4)||streams[4][1]<4||!streams.ContainsKey(15)||streams[15][1]<12)throw new InvalidDataException("PRIVATE_DUMP_REQUIRED_STREAM_MISSING");
  long misc=streams[15][0];if(U32(data,misc)<12||(U32(data,misc+4)&1)==0||U32(data,misc+8)!=expectedProcess)throw new InvalidDataException("PRIVATE_DUMP_PROCESS_BINDING_FAILED");
  long exception=streams[6][0];uint code=U32(data,exception+8);ulong address=U64(data,exception+24);
  long modules=streams[4][0];uint moduleCount=U32(data,modules);if(moduleCount>1024||(long)moduleCount*108+4>streams[4][1])throw new InvalidDataException("PRIVATE_DUMP_MODULE_BOUND");
  string module="WITHHELD",offset="WITHHELD";string[] allowed={"SandboxieRpcSs.exe","SandboxieDcomLaunch.exe","SbieDll.dll","rpcss.dll","rpcrt4.dll","ntdll.dll","KERNELBASE.dll","kernel32.dll","ucrtbase.dll","ole32.dll","combase.dll","sechost.dll","advapi32.dll","wow64.dll","wow64win.dll","wow64cpu.dll","wowarmhw.dll","xtajit.dll"};
  for(uint i=0;i<moduleCount;i++){long p=modules+4+i*108;ulong start=U64(data,p);uint size=U32(data,p+8);if(address>=start&&address-start<size){string name=Name(data,U32(data,p+20));foreach(string known in allowed)if(String.Equals(name,known,StringComparison.OrdinalIgnoreCase)){module=known;offset=(address-start).ToString("x16");break;}break;}}
  string architecture="WITHHELD";if(streams.ContainsKey(7)&&streams[7][1]>=2){ushort arch=BitConverter.ToUInt16(data,(int)streams[7][0]);architecture=arch==12?"ARM64":arch==9?"X64":arch==0?"X86":"WITHHELD";}
  string hash;using(var sha=SHA256.Create()){hash=BitConverter.ToString(sha.ComputeHash(data)).Replace("-","").ToLowerInvariant();}
  return new Dictionary<string,object>{{"classification","DEBUGGER_DIAGNOSTIC_ONLY_NO_PHASE_GATE"},{"exception_code_hex",code.ToString("x8")},{"fault_module_kind",module},{"module_relative_offset_hex",offset},{"process_architecture",architecture},{"dump_target_id_matched",true},{"private_dump_sha256",hash},{"private_dump_size",data.Length},{"raw_dump_paths_ids_arguments_and_addresses_uploaded",false}};
 }
 public static Dictionary<string,object> Read(string file,uint expectedProcess){using(var stream=new FileStream(file,FileMode.Open,FileAccess.Read,FileShare.Read)){if(stream.Length>Limit)throw new InvalidDataException("PRIVATE_DUMP_SIZE_BOUND");using(var reader=new BinaryReader(stream)){byte[] data=reader.ReadBytes((int)stream.Length);if(data.Length!=stream.Length)throw new InvalidDataException("PRIVATE_DUMP_SHORT_READ");return Parse(data,expectedProcess);}}}
}
'@}
