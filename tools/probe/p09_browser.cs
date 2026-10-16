// Original SDK membership plus exact live loopback socket attribution.
using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Security.Principal;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
public sealed class P09Browser : IDisposable {
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr LoadLibraryEx(string file,IntPtr reserved,uint flags);
 [DllImport("kernel32.dll",CharSet=CharSet.Ansi)] static extern IntPtr GetProcAddress(IntPtr module,string name);
 [DllImport("kernel32.dll")] static extern bool FreeLibrary(IntPtr module);
 [DllImport("kernel32.dll",SetLastError=true)] static extern IntPtr OpenProcess(uint rights,bool inherit,uint pid);
 [DllImport("kernel32.dll")] static extern uint WaitForSingleObject(IntPtr process,uint ms);
 [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
 [DllImport("kernel32.dll")] static extern bool GetProcessTimes(IntPtr process,out long created,out long exit,out long kernel,out long user);
 [DllImport("advapi32.dll")] static extern bool OpenProcessToken(IntPtr process,uint access,out IntPtr token);
 [DllImport("advapi32.dll")] static extern bool GetTokenInformation(IntPtr token,int kind,IntPtr data,uint size,out uint needed);
 [DllImport("iphlpapi.dll")] static extern uint GetExtendedTcpTable(IntPtr table,ref int length,bool sorted,int family,int tableClass,uint reserved);
 [UnmanagedFunctionPointer(CallingConvention.Cdecl,CharSet=CharSet.Unicode)] delegate int Query(IntPtr pid,uint imageChars,StringBuilder box,StringBuilder image,StringBuilder sid,out uint session,out long born);
 readonly IntPtr module;readonly Query query;readonly TcpListener listener;readonly Thread thread;readonly string box,sid,nonce;
 string protocolNonce="";readonly List<Dictionary<string,object>> records=new List<Dictionary<string,object>>();volatile bool stopping;
 public int Port {get{return ((IPEndPoint)listener.LocalEndpoint).Port;}}
 public string MainUri {get{return "http://127.0.0.1:"+Port+"/main/"+nonce;}}
 public string ProtocolPage(string token){if(!Guid.TryParse(token,out _))throw new InvalidOperationException("P09_PROTOCOL_NONCE_INVALID");lock(records)protocolNonce=token;return "http://127.0.0.1:"+Port+"/protocol/"+token;}
 public P09Browser(string home,string expectedBox,string token) {
  if(Environment.GetEnvironmentVariable("GITHUB_ACTIONS")!="true"||!System.Text.RegularExpressions.Regex.IsMatch(expectedBox,@"\ASR_[0-9a-f]{32}\z")||!Guid.TryParse(token,out _))throw new InvalidOperationException("P09_BROWSER_LAB_SCOPE_REQUIRED");
  box=expectedBox;nonce=token;sid=WindowsIdentity.GetCurrent().User.Value;module=LoadLibraryEx(Path.Combine(home,"SbieDll.dll"),IntPtr.Zero,0x900);if(module==IntPtr.Zero)throw new InvalidOperationException("P09_ORIGINAL_SDK_MISSING");
  IntPtr address=GetProcAddress(module,"SbieApi_QueryProcessEx2");if(address==IntPtr.Zero)throw new InvalidOperationException("P09_ORIGINAL_ABI_MISSING");query=Marshal.GetDelegateForFunctionPointer<Query>(address);
  listener=new TcpListener(IPAddress.Loopback,0);listener.Start();thread=new Thread(Serve){IsBackground=true};thread.Start();
 }
 static int PortNumber(int value){return ((value&255)<<8)|((value>>8)&255);}
 uint Owner(int clientPort,int serverPort) {
  int length=0;uint status=GetExtendedTcpTable(IntPtr.Zero,ref length,false,2,5,0);if(status!=122||length<4||length>8*1024*1024)throw new InvalidOperationException("P09_TCP_TABLE_UNKNOWN");
  IntPtr table=Marshal.AllocHGlobal(length);try{if(GetExtendedTcpTable(table,ref length,false,2,5,0)!=0)throw new InvalidOperationException("P09_TCP_TABLE_UNKNOWN");int count=Marshal.ReadInt32(table);if(count<0||count>(length-4)/24)throw new InvalidOperationException("P09_TCP_TABLE_BOUND");
   uint pid=0;for(int i=0;i<count;i++){int offset=4+i*24;if(Marshal.ReadInt32(table,offset)==5&&unchecked((uint)Marshal.ReadInt32(table,offset+4))==0x0100007fU&&unchecked((uint)Marshal.ReadInt32(table,offset+12))==0x0100007fU&&PortNumber(Marshal.ReadInt32(table,offset+8))==clientPort&&PortNumber(Marshal.ReadInt32(table,offset+16))==serverPort){uint current=unchecked((uint)Marshal.ReadInt32(table,offset+20));if(pid!=0&&pid!=current)throw new InvalidOperationException("P09_TCP_OWNER_AMBIGUOUS");pid=current;}}if(pid==0)throw new InvalidOperationException("P09_TCP_OWNER_UNKNOWN");return pid;
  }finally{Marshal.FreeHGlobal(table);}
 }
 bool SameOwner(IntPtr process) {IntPtr token;if(!OpenProcessToken(process,8,out token))return false;try{uint needed;GetTokenInformation(token,1,IntPtr.Zero,0,out needed);if(needed==0||needed>16384)return false;IntPtr data=Marshal.AllocHGlobal((int)needed);try{return GetTokenInformation(token,1,data,needed,out needed)&&new SecurityIdentifier(Marshal.ReadIntPtr(data)).Value==sid;}finally{Marshal.FreeHGlobal(data);}}finally{CloseHandle(token);}}
 Dictionary<string,object> Attribution(uint pid,bool expectedBoxed) {
  IntPtr process=OpenProcess(0x101000,false,pid);if(process==IntPtr.Zero)throw new InvalidOperationException("P09_HTTP_PROCESS_UNKNOWN");
  try{long actual,exit,kernel,user;if(!GetProcessTimes(process,out actual,out exit,out kernel,out user))throw new InvalidOperationException("P09_HTTP_IDENTITY_UNKNOWN");var name=new StringBuilder(40);var owner=new StringBuilder(96);uint session;long born;int status=query((IntPtr)pid,0,name,null,owner,out session,out born);
   bool alive=WaitForSingleObject(process,0)==258,boxed=status==0&&name.ToString()==box&&owner.ToString()==sid&&born==actual;
   bool unboxed=unchecked((uint)status)==0xc000000bU&&SameOwner(process);
   return new Dictionary<string,object>{{"source_scope_verified",alive&&(expectedBoxed?boxed:unboxed)},{"source_boxed",boxed},{"source_unboxed",unboxed},{"held_live_process_identity",alive},{"original_driver_query",true},{"socket_owner_attributed",true}};
  }finally{CloseHandle(process);}
 }
 void Serve(){
  while(!stopping){try{using(TcpClient client=listener.AcceptTcpClient()){
   client.ReceiveTimeout=5000;client.SendTimeout=5000;var remote=(IPEndPoint)client.Client.RemoteEndPoint;using(NetworkStream stream=client.GetStream()){
    byte[] buffer=new byte[8192];int size=0;while(size<buffer.Length){int n=stream.Read(buffer,size,buffer.Length-size);if(n==0)break;size+=n;if(Encoding.ASCII.GetString(buffer,0,size).Contains("\r\n\r\n"))break;}
    string request=Encoding.ASCII.GetString(buffer,0,size),path=request.Split(' ').Length>1?request.Split(' ')[1]:"";string challenge;lock(records)challenge=protocolNonce;bool host=path=="/host/"+nonce,main=path=="/main/"+nonce,child=path=="/child/"+nonce,protocol=challenge!=""&&path=="/protocol/"+challenge;var record=(host||main||child||protocol)?Attribution(Owner(remote.Port,Port),!host):new Dictionary<string,object>();
    record["request_kind"]=host?"HOST_POSITIVE_CONTROL":main?"BOXED_MAIN":child?"BOXED_CHILD":protocol?"BOXED_PROTOCOL_PAGE":"AUXILIARY";record["host_profile_cookie_present"]=request.Contains("P09_HOST_COOKIE=");
    if(host||main||child||protocol)lock(records)records.Add(record);
    string page=protocol?"<!doctype html><meta charset=utf-8><title>P09 protocol canary</title><h1>P09 protocol canary</h1><a href=securerun-p09:"+challenge+">Open synthetic handler</a>":"<!doctype html><meta charset=utf-8><title>P09 browser canary</title><h1>P09 browser canary</h1><a target=_blank href=/child/"+nonce+">Open boxed child</a>";
    string header="HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nCache-Control: no-store\r\nConnection: close\r\n"+(host?"Set-Cookie: P09_HOST_COOKIE=CANARY; Path=/; SameSite=Lax\r\n":"")+"Content-Length: "+Encoding.UTF8.GetByteCount(page)+"\r\n\r\n";
    byte[] response=Encoding.UTF8.GetBytes(header+page);stream.Write(response,0,response.Length);
   }
  }}catch(Exception){if(!stopping)lock(records)records.Add(new Dictionary<string,object>{{"request_kind","ATTRIBUTION_FAILED"},{"source_scope_verified",false}});}}
 }
 public Dictionary<string,object>[] Snapshot(){lock(records)return records.ToArray();}
 public void Dispose(){stopping=true;listener.Stop();if(!thread.Join(6000))throw new InvalidOperationException("P09_BROWSER_LISTENER_DID_NOT_STOP");FreeLibrary(module);}
}
