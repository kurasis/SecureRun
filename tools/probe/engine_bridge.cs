// P02 lab-only native-ABI spike. No production command surface or upstream code.
using System;
using System.Collections;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Principal;
using System.Text;
using System.Text.RegularExpressions;
using System.Net;
using System.Net.Sockets;
using System.Threading.Tasks;
using Microsoft.Win32.SafeHandles;

public sealed class P02Bridge {
    [DllImport("kernel32", CharSet=CharSet.Unicode, SetLastError=true)] static extern IntPtr LoadLibraryEx(string path, IntPtr file, uint flags);
    [DllImport("kernel32", CharSet=CharSet.Ansi)] static extern IntPtr GetProcAddress(IntPtr module, string name);
    [DllImport("kernel32", SetLastError=true)] static extern bool SetDefaultDllDirectories(uint flags);
    [DllImport("kernel32", SetLastError=true)] static extern IntPtr OpenProcess(uint rights, bool inherit, uint pid);
    [DllImport("kernel32", SetLastError=true)] static extern bool GetProcessTimes(IntPtr process, out long created, out long exited, out long kernel, out long user);
    [DllImport("kernel32", SetLastError=true)] static extern bool TerminateProcess(IntPtr process, uint code);
    [DllImport("kernel32", SetLastError=true)] static extern bool IsProcessCritical(IntPtr process, out bool critical);
    [DllImport("kernel32")] static extern uint WaitForSingleObject(IntPtr process, uint ms);
    [DllImport("kernel32")] static extern bool CloseHandle(IntPtr handle);
    [DllImport("kernel32")] static extern bool GetExitCodeProcess(IntPtr handle, out uint code);
    [DllImport("kernel32")] static extern uint GetCurrentProcessId();
    [DllImport("kernel32",CharSet=CharSet.Unicode,SetLastError=true)] static extern SafeFileHandle CreateFile(string path,uint access,uint share,IntPtr security,uint disposition,uint flags,IntPtr template);
    [StructLayout(LayoutKind.Sequential,Pack=4)] public struct FileIdentity {
        public uint attributes; public long creation,access,write;
        public uint volume,sizeHigh,sizeLow,links,indexHigh,indexLow;
        public bool Same(FileIdentity other){return volume==other.volume&&indexHigh==other.indexHigh&&indexLow==other.indexLow;}
    }
    [DllImport("kernel32",SetLastError=true)] static extern bool GetFileInformationByHandle(SafeFileHandle file,out FileIdentity identity);
    [StructLayout(LayoutKind.Sequential)] struct NtName { public ushort length,maximum;public IntPtr buffer; }
    [StructLayout(LayoutKind.Sequential)] struct NtAttributes { public uint length;public IntPtr root,name;public uint flags;public IntPtr security,quality; }
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] [return:MarshalAs(UnmanagedType.U1)] delegate bool CleanupCallback(IntPtr information,IntPtr state);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int DeleteNative(ref NtAttributes attributes,CleanupCallback callback,IntPtr state);
    [DllImport("advapi32", CharSet=CharSet.Unicode, SetLastError=true)] static extern bool LogonUser(string user,string domain,string password,int kind,int provider,out SafeAccessTokenHandle token);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl, CharSet=CharSet.Unicode)] delegate int Version(StringBuilder output, out uint abi);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl, CharSet=CharSet.Unicode)] delegate int QueryProcess(IntPtr pid, uint imageChars, StringBuilder box, StringBuilder image, StringBuilder sid, out uint session, out long created);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl, CharSet=CharSet.Unicode)] delegate int EnumProcess(string box, [MarshalAs(UnmanagedType.U1)] bool allSessions, uint session, [Out] uint[] pids, ref uint count);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl, CharSet=CharSet.Unicode)] delegate int QueryConf(string section, string key, uint index, StringBuilder value, uint bytes);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl, CharSet=CharSet.Unicode)] delegate uint UpdateConf(char operation, string password, string section, string key, string value);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int Reload(uint session, uint flags);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int DriverInfo(uint kind, out uint flags, uint bytes);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl, CharSet=CharSet.Unicode)] delegate int QueryRoot(string box, StringBuilder file, IntPtr key, IntPtr ipc, ref uint fileBytes, IntPtr keyBytes, IntPtr ipcBytes);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl, CharSet=CharSet.Unicode)] [return: MarshalAs(UnmanagedType.U1)] delegate bool Translate(StringBuilder path);
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] struct Startup {
        public uint size; public IntPtr reserved, desktop, title;
        public uint x,y,width,height,xchars,ychars,fill,flags;
        public ushort show,reservedBytes; public IntPtr reservedData,input,output,error;
    }
    [StructLayout(LayoutKind.Sequential)] public struct Receipt { public IntPtr process, thread; public uint pid, tid; }
    [UnmanagedFunctionPointer(CallingConvention.Cdecl, CharSet=CharSet.Unicode, SetLastError=true)] [return: MarshalAs(UnmanagedType.Bool)] delegate bool RunSandboxed(string box, string command, string directory, uint flags, ref Startup startup, out Receipt receipt);
    readonly Version version;
    readonly QueryProcess query;
    readonly EnumProcess enumerate;
    readonly QueryConf conf;
    readonly UpdateConf update;
    readonly Reload reload;
    readonly DriverInfo info;
    readonly QueryRoot root;
    readonly Translate translate;
    readonly RunSandboxed run;
    readonly HashSet<string> owned = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
    readonly HashSet<string> probes = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
    readonly Dictionary<string,FileIdentity> rootIdentities=new Dictionary<string,FileIdentity>();
    readonly string sid = WindowsIdentity.GetCurrent().User.Value;
    public readonly string Home;
    public readonly string Base;
    public int LastLaunchError { get; private set; }
    public uint CurrentSession { get; private set; }
    T Bind<T>(IntPtr module, string name) where T : Delegate {
        IntPtr address = GetProcAddress(module, name);
        if (address == IntPtr.Zero) throw new InvalidOperationException("MISSING_PINNED_EXPORT");
        return Marshal.GetDelegateForFunctionPointer<T>(address);
    }
    public P02Bridge(string home, string fixture, string[] approvedProbes) {
        Home=Path.GetFullPath(home); Base=Path.GetFullPath(fixture);
        string expectedHome=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),"Sandboxie-Plus");
        string labParent=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),"SecureRunLab");
        if (!String.Equals(Home,expectedHome,StringComparison.OrdinalIgnoreCase) || !Base.StartsWith(labParent+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase)) throw new InvalidOperationException("LAB_SCOPE_REJECTED");
        Directory.SetCurrentDirectory(Home);
        if (!SetDefaultDllDirectories(0x800|0x400)) throw new Win32Exception();
        IntPtr module=LoadLibraryEx(Path.Combine(Home,"SbieDll.dll"),IntPtr.Zero,0x100|0x800);
        if (module==IntPtr.Zero) throw new Win32Exception();
        version=Bind<Version>(module,"SbieApi_GetVersionEx"); query=Bind<QueryProcess>(module,"SbieApi_QueryProcessEx2");
        enumerate=Bind<EnumProcess>(module,"SbieApi_EnumProcessEx"); conf=Bind<QueryConf>(module,"SbieApi_QueryConf");
        update=Bind<UpdateConf>(module,"SbieDll_UpdateConf"); reload=Bind<Reload>(module,"SbieApi_ReloadConf");
        info=Bind<DriverInfo>(module,"SbieApi_QueryDrvInfo"); root=Bind<QueryRoot>(module,"SbieApi_QueryBoxPath");
        translate=Bind<Translate>(module,"SbieDll_TranslateNtToDosPath"); run=Bind<RunSandboxed>(module,"SbieDll_RunSandboxed");
        RequireUnboxed();
        CurrentSession=(uint)Process.GetCurrentProcess().SessionId;
        foreach(string probe in approvedProbes) probes.Add(Path.GetFullPath(probe));
    }
    public void RequireUnboxed() {
        var v=new StringBuilder(16); uint abi;
        if (version(v,out abi)!=0 || v.ToString()!="5.73.6") throw new InvalidOperationException("ENGINE_UNVERIFIED");
        uint session; long created;
        int status=query((IntPtr)GetCurrentProcessId(),0,new StringBuilder(40),null,null,out session,out created);
        if (unchecked((uint)status)!=0xc000000bU) throw new InvalidOperationException("MANAGER_CONTEXT_UNSAFE");
    }
    public void Register(string box) {
        RequireUnboxed();
        if (!Regex.IsMatch(box,@"\ASRP02_[A-Za-z0-9_]{1,30}\z")) throw new InvalidOperationException("LAB_SCOPE_REJECTED");
        if(owned.Contains(box))return;
        if(Read(box,null,0x70000000U)!=null)throw new InvalidOperationException("PREEXISTING_BOX_NOT_ADOPTED");
        owned.Add(box);
    }
    void Scope(string box) { RequireUnboxed(); if(!owned.Contains(box)) throw new InvalidOperationException("UNOWNED_BOX"); }
    public string Read(string box,string key,uint index) {
        RequireUnboxed(); var text=new StringBuilder(2048);
        int status=conf(box,key,index,text,4096);
        if(unchecked((uint)status)==0xc000008bU)return null;
        if(status!=0)throw new InvalidOperationException("CONFIG_QUERY_FAILED_"+unchecked((uint)status).ToString("x8"));
        return text.ToString();
    }
    public void Set(string box,string key,string value) {
        Scope(box);
        if (value!=null && (value.IndexOfAny(new char[]{'\r','\n','\0',','})>=0)) throw new InvalidOperationException("INI_VALUE_REJECTED");
        if(!Regex.IsMatch(key,@"\A(Enabled|FileRootPath|DropAdminRights|BlockNetworkFiles|AllowNetworkAccess|BlockLocalLoop|AutoRecover|AutoDelete|ClosedFilePath|DeleteCommand|OnBoxDelete|OnBoxTerminate|OnFileRecovery|UseFileImage|NeverDelete)\z")) throw new InvalidOperationException("KEY_NOT_ALLOWED");
        if(Count(box)!=0) throw new InvalidOperationException("BOX_BUSY");
        if(key=="FileRootPath"&&!String.Equals(Path.GetFullPath(value),Path.Combine(Base,"boxes",box),StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException("PRIVILEGED_SCOPE_REJECTED");
        uint status=update('s',null,box,key,value);
        if(status!=0) throw new InvalidOperationException("CONFIG_UPDATE_FAILED_"+status.ToString("x8"));
        if(value!=null && Read(box,key,0x70000000U)!=value) throw new InvalidOperationException("CONFIG_READBACK_MISMATCH_"+key.ToUpperInvariant());
    }
    public void AppendClosed(string box,string path) {
        Scope(box); if(Count(box)!=0) throw new InvalidOperationException("BOX_BUSY");
        if(path.IndexOfAny(new char[]{'\r','\n','\0',',','%'})>=0) throw new InvalidOperationException("INI_VALUE_REJECTED");
        uint status=update('a',null,box,"ClosedFilePath",path);
        if(status!=0) throw new InvalidOperationException("CONFIG_APPEND_FAILED");
        bool found=false;
        for(uint index=0;index<64;index++){string value=Read(box,"ClosedFilePath",index|0x70000000U);if(value==null)break;if(value==path)found=true;}
        if(!found)throw new InvalidOperationException("CONFIG_APPEND_READBACK_FAILED");
    }
    public string CleanupReason(string box) {
        Scope(box);if(Count(box)!=0)return "BOX_BUSY";
        foreach(string key in new[]{"DeleteCommand","OnBoxDelete","OnBoxTerminate","OnFileRecovery"})
            for(uint index=0;index<64;index++){string value=Read(box,key,index|0x20000000U);if(value==null)break;if(value.Length!=0)return "UNAPPROVED_AUTOMATION";}
        return "BUILTIN_CLEANUP_SCOPE_UNVERIFIED";
    }
    public FileIdentity CaptureRoot(string box) {
        Scope(box);string path=Root(box);
        using(var handle=CreateFile(path,0x80,3,IntPtr.Zero,3,0x02000000|0x00200000,IntPtr.Zero)){
            FileIdentity identity;
            if(handle.IsInvalid||!GetFileInformationByHandle(handle,out identity)||(identity.attributes&0x400)!=0)throw new InvalidOperationException("ROOT_HANDLE_UNVERIFIED");
            rootIdentities[box]=identity;return identity;
        }
    }
    public Dictionary<string,object> ClearOwnedWithNative(string box) {
        Scope(box);
        string reason=CleanupReason(box);
        if(reason=="UNAPPROVED_AUTOMATION"||reason=="BOX_BUSY")throw new InvalidOperationException(reason);
        if(Read(box,"UseFileImage",0)=="y"||Read(box,"NeverDelete",0)=="y")throw new InvalidOperationException("LIFECYCLE_UNSUPPORTED");
        if(!rootIdentities.ContainsKey(box))throw new InvalidOperationException("ROOT_NOT_ENROLLED");
        string path=Root(box);
        using(var handle=CreateFile(path,0x81,3,IntPtr.Zero,3,0x02000000|0x00200000,IntPtr.Zero)){
            FileIdentity identity;
            if(handle.IsInvalid||!GetFileInformationByHandle(handle,out identity)||!identity.Same(rootIdentities[box])||(identity.attributes&0x400)!=0)throw new InvalidOperationException("ROOT_IDENTITY_CHANGED");
            int total=0;
            var queue=new Queue<string>();queue.Enqueue(path);
            while(queue.Count!=0){
                foreach(string entry in Directory.EnumerateFileSystemEntries(queue.Dequeue())){
                    if(++total>512)throw new InvalidOperationException("CLEANUP_FIXTURE_BOUND");
                    FileAttributes attrs=File.GetAttributes(entry);
                    if((attrs&FileAttributes.ReparsePoint)!=0)throw new InvalidOperationException("CLEANUP_REPARSE_REJECTED");
                    if((attrs&FileAttributes.Directory)!=0)queue.Enqueue(entry);
                    else using(var file=CreateFile(entry,0x80,3,IntPtr.Zero,3,0x00200000,IntPtr.Zero)){
                        FileIdentity fileId;if(file.IsInvalid||!GetFileInformationByHandle(file,out fileId)||fileId.links!=1)throw new InvalidOperationException("CLEANUP_LINK_REJECTED");
                    }
                }
            }
            RequireUnboxed();if(Count(box)!=0)throw new InvalidOperationException("BOX_BUSY");
            IntPtr module=LoadLibraryEx(Path.Combine(Home,"QSbieAPI.dll"),IntPtr.Zero,0x100|0x800);
            if(module==IntPtr.Zero)throw new InvalidOperationException("NATIVE_CLEANUP_MODULE_UNAVAILABLE");
            // Exact exports observed in both authenticated v1.18.6 distributions.
            var remove=Bind<DeleteNative>(module,"?NtIo_DeleteFolderRecursively@@YAJPEAU_OBJECT_ATTRIBUTES@@P6A_NPEB_WPEAX@Z2@Z");
            IntPtr name=Marshal.StringToHGlobalUni(".");IntPtr descriptor=Marshal.AllocHGlobal(Marshal.SizeOf<NtName>());
            try {
                Marshal.StructureToPtr(new NtName{length=2,maximum=4,buffer=name},descriptor,false);
                var attr=new NtAttributes{length=(uint)Marshal.SizeOf<NtAttributes>(),root=handle.DangerousGetHandle(),name=descriptor,flags=0x40};
                var clock=Stopwatch.StartNew();CleanupCallback callback=(text,state)=>clock.ElapsedMilliseconds<30000;
                int status=remove(ref attr,callback,IntPtr.Zero);GC.KeepAlive(callback);
                FileIdentity after;
                bool same=GetFileInformationByHandle(handle,out after)&&identity.Same(after);
                bool empty=Directory.Exists(path)&&Directory.GetFileSystemEntries(path).Length==0;
                if(!same||!empty)throw new InvalidOperationException("NATIVE_CLEANUP_POSTCONDITION_FAILED_"+unchecked((uint)status).ToString("x8"));
                // A no-delete-share lease deliberately prevents unlinking the retained root.
                // Accept only observed empty contents, the original identity, and the exact expected result.
                if(status!=0&&unchecked((uint)status)!=0xc0000043U)throw new InvalidOperationException("NATIVE_CLEANUP_STATUS_UNRESOLVED_"+unchecked((uint)status).ToString("x8"));
                return new Dictionary<string,object>{{"status",unchecked((uint)status).ToString("x8")},{"contents_empty",true},{"root_identity_retained",true},{"root_unlink_deliberately_blocked",status!=0},{"builtin","QSbieAPI.NtIo_DeleteFolderRecursively"},{"legacy_delete_command_dispatched",false}};
            } finally {Marshal.FreeHGlobal(descriptor);Marshal.FreeHGlobal(name);}
        }
    }
    public bool MayMaterializeSibling(string[] affected) {
        foreach(string box in affected){Scope(box);if(Count(box)!=0)return false;}
        return true;
    }
    public Dictionary<string,object> OtherUserAccess(string user,string password,string box) {
        Scope(box);string rootPath=Root(box);SafeAccessTokenHandle token;
        if(!LogonUser(user,".",password,2,0,out token))throw new InvalidOperationException("SECOND_USER_LOGON_FAILED_"+Marshal.GetLastWin32Error());
        using(token){
            return WindowsIdentity.RunImpersonated(token,()=>{
                var result=new Dictionary<string,object>();
                var identity=WindowsIdentity.GetCurrent();
                result["different_identity"]=identity.User.Value!=sid;
                result["administrator"]=new WindowsPrincipal(identity).IsInRole(WindowsBuiltInRole.Administrator);
                foreach(var item in new[]{new[]{"positive",Path.Combine(Base,"canaries","read-positive.txt")},new[]{"metadata",Path.Combine(Base,"metadata","manager.txt")},new[]{"root",Path.Combine(rootPath,"private.txt")}}){
                    try{using(var stream=File.Open(item[1],FileMode.Open,FileAccess.Read,FileShare.Read)){result[item[0]+"_read_error"]=0;}}
                    catch(UnauthorizedAccessException){result[item[0]+"_read_error"]=5;}
                    catch(IOException){result[item[0]+"_read_error"]=-1;}
                }
                return result;
            });
        }
    }
    public uint Flags() { RequireUnboxed(); uint flags; if(info(0,out flags,4)!=0) throw new InvalidOperationException("DRIVER_INFO_UNKNOWN");return flags; }
    public void EnableLabWfp() {
        RequireUnboxed();
        if(Environment.GetEnvironmentVariable("GITHUB_ACTIONS")!="true") throw new InvalidOperationException("DISPOSABLE_LAB_REQUIRED");
        if(update('s',null,"GlobalSettings","NetworkEnableWFP","y")!=0) throw new InvalidOperationException("LAB_WFP_UPDATE_FAILED");
        if(reload(CurrentSession,1)!=0 || (Flags()&1)==0) throw new InvalidOperationException("LAB_WFP_UNKNOWN");
    }
    public uint Count(string box) { ScopeRead(box); uint count=0;if(enumerate(box,true,UInt32.MaxValue,null,ref count)!=0) throw new InvalidOperationException("ENUMERATION_UNKNOWN");return count; }
    void ScopeRead(string box) { RequireUnboxed(); if(!owned.Contains(box))throw new InvalidOperationException("UNOWNED_BOX"); }
    public uint[] Pids(string box) {
        ScopeRead(box);uint total=Count(box);
        if(total>1024)throw new InvalidOperationException("ENUMERATION_BOUND");
        uint[] pids=new uint[1024];uint count=1024;
        if(enumerate(box,true,UInt32.MaxValue,pids,ref count)!=0 || count>=1024 || Count(box)>count)throw new InvalidOperationException("ENUMERATION_INCOMPLETE");
        Array.Resize(ref pids,(int)count);return pids;
    }
    public string Root(string box) {
        ScopeRead(box);uint bytes=0;
        if(root(box,null,IntPtr.Zero,IntPtr.Zero,ref bytes,IntPtr.Zero,IntPtr.Zero)!=0 || bytes==0 || bytes>8192)throw new InvalidOperationException("ROOT_QUERY_FAILED");
        var path=new StringBuilder(4096);uint capacity=8192;
        if(root(box,path,IntPtr.Zero,IntPtr.Zero,ref capacity,IntPtr.Zero,IntPtr.Zero)!=0 || !translate(path)) throw new InvalidOperationException("ROOT_TRANSLATION_FAILED");
        string resolved=Path.GetFullPath(path.ToString());
        string expected=Path.Combine(Base,"boxes",box);
        if(!String.Equals(resolved.TrimEnd('\\'),expected,StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException("ROOT_IDENTITY_UNEXPECTED");
        return resolved;
    }
    public static string Quote(string value) {
        if(value==null || value.IndexOf('\0')>=0 || value.IndexOf('\r')>=0 || value.IndexOf('\n')>=0)throw new InvalidOperationException("ARGUMENT_REJECTED");
        var b=new StringBuilder("\"");int slash=0;
        foreach(char c in value){if(c=='\\'){slash++;continue;}if(c=='\"'){b.Append('\\',slash*2+1);b.Append(c);}else{b.Append('\\',slash);b.Append(c);}slash=0;}
        b.Append('\\',slash*2);b.Append('"');return b.ToString();
    }
    public static void MinimizeProcessEnvironment(string engineHome) {
        var keep=new HashSet<string>(new[]{"SystemRoot","WINDIR","SystemDrive","ProgramFiles","ProgramFiles(x86)","ProgramW6432","ProgramData","USERPROFILE","APPDATA","LOCALAPPDATA","TEMP","TMP","OS","PROCESSOR_ARCHITECTURE","NUMBER_OF_PROCESSORS","GITHUB_ACTIONS"},StringComparer.OrdinalIgnoreCase);
        foreach(DictionaryEntry entry in Environment.GetEnvironmentVariables()){
            string name=(string)entry.Key;
            if(!keep.Contains(name))Environment.SetEnvironmentVariable(name,null);
        }
        Environment.SetEnvironmentVariable("PATH",engineHome+";"+Environment.GetFolderPath(Environment.SpecialFolder.System));
    }
    public Receipt Launch(string box,string exe,string[] arguments) {
        Scope(box);string full=Path.GetFullPath(exe);
        if(!probes.Contains(full))throw new InvalidOperationException("FIXED_PROBE_REQUIRED");
        if(Read(box,"Enabled",0)!="y")throw new InvalidOperationException("BOX_NOT_READY");
        string command=Quote(full);foreach(string arg in arguments)command+=" "+Quote(arg);
        var startup=new Startup();startup.size=(uint)Marshal.SizeOf<Startup>();Receipt receipt;
        // This API takes target CWD independently; the host remains in Home.
        bool ok=run(box,command,Base,0,ref startup,out receipt);
        LastLaunchError=Marshal.GetLastWin32Error();
        if(!ok)throw new InvalidOperationException("ENGINE_LAUNCH_FAILED_"+LastLaunchError);
        return receipt;
    }
    public bool RejectMissingBox(string exe) {
        RequireUnboxed();if(!probes.Contains(Path.GetFullPath(exe)))throw new InvalidOperationException("FIXED_PROBE_REQUIRED");
        var startup=new Startup();startup.size=(uint)Marshal.SizeOf<Startup>();Receipt receipt;
        bool started=run("SRP02_NONEXISTENT",Quote(exe)+" "+Quote("forbidden-host-marker")+" "+Quote(Base),Base,0,ref startup,out receipt);
        if(started){StopReceipt(receipt);return false;}return true;
    }
    public static bool Completed(Receipt receipt,uint ms) { return WaitForSingleObject(receipt.process,ms)==0; }
    public static uint ExitCode(Receipt receipt) { uint code;if(!GetExitCodeProcess(receipt.process,out code))throw new Win32Exception();return code; }
    public static void CloseReceipt(Receipt receipt) { CloseHandle(receipt.thread);CloseHandle(receipt.process); }
    public static void StopReceipt(Receipt receipt) { TerminateProcess(receipt.process,99);WaitForSingleObject(receipt.process,5000);CloseReceipt(receipt); }
    public int StopHeld(string box) {
        Scope(box);int stopped=0;
        for(int attempt=0;attempt<10;attempt++){
            uint[] pids=Pids(box);if(pids.Length==0)return stopped;
            foreach(uint pid in pids){
                IntPtr handle=OpenProcess(0x100000|0x1000|1,false,pid);
                if(handle==IntPtr.Zero)throw new InvalidOperationException("PROCESS_HANDLE_UNAVAILABLE");
                try {
                    long born,exit,kernel,user,engineBorn;uint session;var actualBox=new StringBuilder(40);var actualSid=new StringBuilder(96);
                    if(!GetProcessTimes(handle,out born,out exit,out kernel,out user))throw new Win32Exception();
                    bool critical;if(!IsProcessCritical(handle,out critical) || critical)throw new InvalidOperationException("CRITICAL_PROCESS_REJECTED");
                    if(WaitForSingleObject(handle,0)==0)continue;
                    int status=query((IntPtr)pid,0,actualBox,null,actualSid,out session,out engineBorn);
                    if(status!=0 || actualBox.ToString()!=box || actualSid.ToString()!=sid || born!=engineBorn)throw new InvalidOperationException("PROCESS_SCOPE_REJECTED");
                    if(!TerminateProcess(handle,99) || WaitForSingleObject(handle,5000)!=0)throw new InvalidOperationException("STOP_INCOMPLETE");
                    stopped++;
                } finally { CloseHandle(handle); }
            }
        }
        throw new InvalidOperationException("STOP_RECONCILIATION_REQUIRED");
    }
}

public sealed class P02Endpoints : IDisposable {
    readonly List<Action> closers=new List<Action>();
    public readonly int[] Ports=new int[4];
    public int Received;
    public P02Endpoints(){
        for(int i=0;i<4;i++){
            IPAddress address=i%2==0?IPAddress.Loopback:IPAddress.IPv6Loopback;
            if(i<2){
                var listener=new TcpListener(address,0);listener.Start();Ports[i]=((IPEndPoint)listener.LocalEndpoint).Port;closers.Add(listener.Stop);
                Task.Run(async ()=>{try{while(true){using(var client=await listener.AcceptTcpClientAsync()){var stream=client.GetStream();var b=new byte[1];int count=await stream.ReadAsync(b,0,1);if(count==1&&b[0]==80){System.Threading.Interlocked.Increment(ref Received);await stream.WriteAsync(new byte[]{82},0,1);}}}}catch(ObjectDisposedException){}catch(SocketException){}});
            } else {
                var udp=new UdpClient(new IPEndPoint(address,0));Ports[i]=((IPEndPoint)udp.Client.LocalEndPoint).Port;closers.Add(udp.Dispose);
                Task.Run(async ()=>{try{while(true){var message=await udp.ReceiveAsync();if(message.Buffer.Length==1&&message.Buffer[0]==80){System.Threading.Interlocked.Increment(ref Received);await udp.SendAsync(new byte[]{82},1,message.RemoteEndPoint);}}}catch(ObjectDisposedException){}catch(SocketException){}});
            }
        }
    }
    public void Dispose(){foreach(var close in closers)close();}
}
