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
using System.Security.Cryptography;
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
    [UnmanagedFunctionPointer(CallingConvention.Cdecl, CharSet=CharSet.Unicode)] delegate int EnumProcess(StringBuilder box, [MarshalAs(UnmanagedType.U1)] bool allSessions, uint session, [Out] uint[] pids, ref uint count);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl, CharSet=CharSet.Unicode)] delegate int QueryConf(string section, string key, uint index, StringBuilder value, uint bytes);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl, CharSet=CharSet.Unicode)] delegate uint UpdateConf(char operation, string password, string section, string key, string value);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int Reload(uint session, uint flags);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int DriverInfo(uint kind, out uint flags, uint bytes);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl,CharSet=CharSet.Unicode)] delegate uint Message(ref uint sequence,uint session,out uint message,out uint pid,StringBuilder buffer,uint bytes);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl, CharSet=CharSet.Unicode)] delegate int QueryRoot(StringBuilder box, StringBuilder file, IntPtr key, IntPtr ipc, ref uint fileBytes, IntPtr keyBytes, IntPtr ipcBytes);
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
    readonly Message message;
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
    public bool DiagnosticsAvailable { get; private set; }
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
        message=Bind<Message>(module,"SbieApi_GetMessage");
        translate=Bind<Translate>(module,"SbieDll_TranslateNtToDosPath"); run=Bind<RunSandboxed>(module,"SbieDll_RunSandboxed");
        RequireUnboxed();
        CurrentSession=(uint)Process.GetCurrentProcess().SessionId;
        foreach(string probe in approvedProbes) probes.Add(Path.GetFullPath(probe));
    }
    public void RequireUnboxed() {
        var v=new StringBuilder(16); uint abi;
        if (version(v,out abi)!=0 || v.ToString()!="5.73.6" || abi!=0x57230U) throw new InvalidOperationException("ENGINE_UNVERIFIED");
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
    public Dictionary<string,object> ReadOnlyInventory() {
        RequireUnboxed();var sections=new List<string>();bool ended=false;
        for(uint index=0;index<1024;index++){string section=Read(null,null,index|0x30000000U);if(section==null){ended=true;break;}sections.Add(section);}
        if(!ended)throw new InvalidOperationException("SECTION_ENUMERATION_INCOMPLETE");
        foreach(string box in owned)if(!sections.Contains(box))throw new InvalidOperationException("OWNED_SECTION_NOT_ENUMERATED");
        uint cert;int status=info(UInt32.MaxValue,out cert,4);
        if(status!=0)throw new InvalidOperationException("ENTITLEMENT_QUERY_UNKNOWN");
        uint sequence=0;var identifiers=new List<uint>();uint last=0;
        for(int index=0;index<8;index++){uint id,pid;var text=new StringBuilder(4096);last=message(ref sequence,CurrentSession,out id,out pid,text,8192);if(last!=0||id==0)break;identifiers.Add(id);text.Clear();}
        DiagnosticsAvailable=last==0||last==0x8000001aU;
        return new Dictionary<string,object>{{"configuration_sections",sections.Count},{"fresh_owned_sections_observed",owned.Count},{"driver_flags",Flags()},{"certificate_state_low32",cert},{"certificate_query_status",status},{"optional_paid_profiles_enabled",false},{"diagnostic_status",last.ToString("x8")},{"diagnostics_available",DiagnosticsAvailable},{"diagnostic_message_ids",identifiers.ToArray()},{"diagnostic_text_retained",false},{"signed_session_leader_registration_attempted",false}};
    }
    public Dictionary<string,object> RemoveFreshEmptyDefinition(string box) {
        Scope(box);if(Count(box)!=0||Directory.Exists(Root(box)))throw new InvalidOperationException("DEFINITION_HAS_STORAGE_OR_PROCESSES");
        uint status=update('s',null,box,"*",null);
        if(status!=0||Read(box,null,0x70000000U)!=null)throw new InvalidOperationException("DEFINITION_REMOVAL_UNCONFIRMED");
        owned.Remove(box);return new Dictionary<string,object>{{"upstream_status",status},{"section_absent",true},{"root_was_never_materialized",true},{"used_definition_requires_verified_cleanup",true}};
    }
    public Dictionary<string,object> ExerciseProtectedConfiguration(string box) {
        Scope(box);if(Count(box)!=0)throw new InvalidOperationException("BOX_BUSY");
        if(Read("GlobalSettings","EditPassword",0x70000000U)!=null)throw new InvalidOperationException("PREEXISTING_PASSWORD_NOT_CHANGED");
        string password="P02!"+Guid.NewGuid().ToString("N");
        byte[] salt=RandomNumberGenerator.GetBytes(16),plain=Encoding.Unicode.GetBytes(password);
        byte[] input=new byte[salt.Length+plain.Length];salt.CopyTo(input,0);plain.CopyTo(input,16);
        byte[] hash=SHA256.HashData(input),combined=new byte[48];salt.CopyTo(combined,0);hash.CopyTo(combined,16);
        uint installed=update('s',null,"GlobalSettings","EditPassword",Convert.ToBase64String(combined));
        Array.Clear(plain,0,plain.Length);Array.Clear(input,0,input.Length);Array.Clear(hash,0,hash.Length);Array.Clear(combined,0,combined.Length);
        if(installed!=0)throw new InvalidOperationException("PASSWORD_FIXTURE_SETUP_FAILED");
        try {
            string before=Read(box,"AutoRecover",0x70000000U);
            uint absent=update('s',null,box,"AutoRecover","y");
            uint wrong=update('s',"P02_WRONG_SYNTHETIC_PASSWORD",box,"AutoRecover","y");
            if(absent!=0xc000006aU||wrong!=0xc000006aU||Read(box,"AutoRecover",0x70000000U)!=before)throw new InvalidOperationException("PROTECTED_CONFIG_FAIL_CLOSED_UNCONFIRMED");
            uint accepted=update('s',password,box,"AutoRecover","y");
            if(accepted!=0||Read(box,"AutoRecover",0x70000000U)!="y")throw new InvalidOperationException("PROTECTED_CONFIG_POSITIVE_CONTROL_FAILED");
            if(update('s',password,box,"AutoRecover",before)!=0)throw new InvalidOperationException("PROTECTED_CONFIG_RESTORE_FAILED");
            return new Dictionary<string,object>{{"missing_password_status",absent.ToString("x8")},{"wrong_password_status",wrong.ToString("x8")},{"correct_password_status",accepted},{"rejected_writes_unchanged",true},{"transport","Original SbieDll_UpdateConf service IPC; no argv, environment or logs"},{"synthetic_password_recorded",false}};
        } finally {
            uint restored=update('s',password,"GlobalSettings","EditPassword",null);password=null;
            if(restored!=0)throw new InvalidOperationException("PASSWORD_FIXTURE_RESTORE_FAILED");
        }
    }
    public void Set(string box,string key,string value) {
        Scope(box);
        if(value==String.Empty)value=null; // PowerShell binds $null to an empty string.
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
            if(rootIdentities.ContainsKey(box)&&!identity.Same(rootIdentities[box]))throw new InvalidOperationException("ROOT_IDENTITY_CHANGED");
            rootIdentities[box]=identity;return identity;
        }
    }
    public Dictionary<string,object> ObserveSameOwnerSessions(string box) {
        Scope(box);var sessions=new HashSet<uint>();uint count=0;
        foreach(uint pid in Pids(box)){var actualBox=new StringBuilder(40);var actualSid=new StringBuilder(96);uint session;long born;
            if(query((IntPtr)pid,0,actualBox,null,actualSid,out session,out born)!=0||actualBox.ToString()!=box||actualSid.ToString()!=sid)throw new InvalidOperationException("SESSION_OWNER_UNKNOWN");
            sessions.Add(session);count++;
        }
        uint current=0;if(enumerate(BoxBuffer(box),false,CurrentSession,null,ref current)!=0)throw new InvalidOperationException("ENUMERATION_UNKNOWN");
        if(sessions.Count<2||!sessions.Contains(CurrentSession)||current==0||count<=current)throw new InvalidOperationException("SAME_SID_SECOND_SESSION_UNAVAILABLE");
        return new Dictionary<string,object>{{"same_owner_verified",true},{"simultaneous_session_count",sessions.Count},{"all_session_process_count",count},{"current_session_process_count",current},{"runner_session",CurrentSession},{"real_windows_sessions",true},{"terminal_desktop_ui_tested",false}};
    }
    public Dictionary<string,object> ManagerDiagnostics() {
        RequireUnboxed();var v=new StringBuilder(16);uint abi;
        int status=version(v,out abi);if(status!=0)throw new InvalidOperationException("ENGINE_HEALTH_UNKNOWN");
        return new Dictionary<string,object>{{"event_origin","MANAGER_OBSERVATION"},{"core_version",v.ToString()},{"abi",abi},{"driver_flags",Flags()},{"self_context","UNBOXED"},{"engine_access_events_available",DiagnosticsAvailable},{"native_engine_log_reason",DiagnosticsAvailable?"AVAILABLE":"SIGNED_SESSION_LEADER_REQUIRED"},{"raw_arguments_or_environment_retained",false}};
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
            // NT relative opens use an empty name to reopen RootDirectory; "." is invalid.
            IntPtr name=Marshal.StringToHGlobalUni("");IntPtr descriptor=Marshal.AllocHGlobal(Marshal.SizeOf<NtName>());
            try {
                Marshal.StructureToPtr(new NtName{length=0,maximum=2,buffer=name},descriptor,false);
                var attr=new NtAttributes{length=(uint)Marshal.SizeOf<NtAttributes>(),root=handle.DangerousGetHandle(),name=descriptor,flags=0x40};
                var clock=Stopwatch.StartNew();CleanupCallback callback=(text,state)=>clock.ElapsedMilliseconds<30000;
                int status=remove(ref attr,callback,IntPtr.Zero);GC.KeepAlive(callback);
                FileIdentity after;
                bool same=GetFileInformationByHandle(handle,out after)&&identity.Same(after);
                bool empty=Directory.Exists(path)&&Directory.GetFileSystemEntries(path).Length==0;
                if(!same||!empty)throw new InvalidOperationException("NATIVE_CLEANUP_POSTCONDITION_FAILED_"+unchecked((uint)status).ToString("X8"));
                // A no-delete-share lease deliberately prevents unlinking the retained root.
                // Accept only observed empty contents, the original identity, and the exact expected result.
                if(status!=0&&unchecked((uint)status)!=0xc0000043U)throw new InvalidOperationException("NATIVE_CLEANUP_STATUS_UNRESOLVED_"+unchecked((uint)status).ToString("X8"));
                return new Dictionary<string,object>{{"status",unchecked((uint)status).ToString("x8")},{"contents_empty",true},{"root_identity_retained",true},{"root_unlink_deliberately_blocked",status!=0},{"builtin","QSbieAPI.NtIo_DeleteFolderRecursively"},{"legacy_delete_command_dispatched",false}};
            } finally {Marshal.FreeHGlobal(descriptor);Marshal.FreeHGlobal(name);}
        }
    }
    public bool MayMaterializeSibling(string[] affected) {
        foreach(string box in affected){Scope(box);if(Count(box)!=0)return false;}
        return true;
    }
    public string ResolveSyntheticMapping(string box,string mapped) {
        Scope(box);if(Count(box)!=0||mapped.Length==0||mapped.Length>4092||mapped.IndexOfAny(new[]{'\0','\r','\n'})>=0)throw new InvalidOperationException("MAPPING_UNVERIFIED");
        var path=new StringBuilder(mapped,4096);if(!translate(path))throw new InvalidOperationException("MAPPING_TRANSLATION_FAILED");
        string full=Path.GetFullPath(path.ToString());string rootPath=Root(box);
        if(!full.StartsWith(rootPath+"\\",StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException("MAPPING_OUTSIDE_ROOT");
        // Prototype only: reject every reparse component and multiple hard links.
        string walk=full;while(!String.Equals(walk,rootPath,StringComparison.OrdinalIgnoreCase)){
            if((File.GetAttributes(walk)&FileAttributes.ReparsePoint)!=0)throw new InvalidOperationException("MAPPING_REPARSE_REJECTED");walk=Path.GetDirectoryName(walk);
        }
        using(var file=CreateFile(full,0x80,1,IntPtr.Zero,3,0x00200000,IntPtr.Zero)){FileIdentity identity;if(file.IsInvalid||!GetFileInformationByHandle(file,out identity)||identity.links!=1)throw new InvalidOperationException("MAPPING_IDENTITY_UNVERIFIED");}
        return full;
    }
    public Receipt LaunchSyntheticBoxExecutable(string box,string physical,string[] arguments) {
        Scope(box);string full=Path.GetFullPath(physical);string logical=Path.Combine(Base,"workspace","boxed-probe.exe");
        if(!full.StartsWith(Root(box)+"\\",StringComparison.OrdinalIgnoreCase)||!File.Exists(full)||File.Exists(logical))throw new InvalidOperationException("BOX_EXECUTABLE_UNVERIFIED");
        byte[] content=File.ReadAllBytes(full);bool matched=false;
        foreach(string probe in probes){if(!probe.EndsWith(".exe",StringComparison.OrdinalIgnoreCase))continue;byte[] expected=File.ReadAllBytes(probe);if(content.Length==expected.Length&&CryptographicOperations.FixedTimeEquals(SHA256.HashData(content),SHA256.HashData(expected)))matched=true;}
        if(!matched)throw new InvalidOperationException("BOX_EXECUTABLE_HASH_UNVERIFIED");
        // Service CreateProcess cannot see a host-absent logical EXE. Source Start.cpp
        // boxes the trusted Start.exe stage, whose hooked target launch can see it.
        string command=Quote(Path.Combine(Home,"Start.exe"))+" /wait "+Quote(logical);foreach(string arg in arguments)command+=" "+Quote(arg);
        var startup=new Startup();startup.size=(uint)Marshal.SizeOf<Startup>();Receipt receipt;
        if(!run(box,command,Base,0,ref startup,out receipt))throw new InvalidOperationException("BOX_LOGICAL_LAUNCH_FAILED_"+Marshal.GetLastWin32Error());return receipt;
    }
    public bool ObserveLogicalExecutable(string box) {
        Scope(box);foreach(uint pid in Pids(box)){var actualBox=new StringBuilder(40);var image=new StringBuilder(1024);uint session;long created;
            if(query((IntPtr)pid,1024,actualBox,image,null,out session,out created)==0&&actualBox.ToString()==box&&String.Equals(Path.GetFileName(image.ToString()),"boxed-probe.exe",StringComparison.OrdinalIgnoreCase))return true;
        }return false;
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
    static StringBuilder BoxBuffer(string box){if(box.Length>38)throw new InvalidOperationException("BOX_NAME_BOUND");return new StringBuilder(box,40);}
    public uint Count(string box) { ScopeRead(box); uint count=0;if(enumerate(BoxBuffer(box),true,UInt32.MaxValue,null,ref count)!=0) throw new InvalidOperationException("ENUMERATION_UNKNOWN");return count; }
    void ScopeRead(string box) { RequireUnboxed(); if(!owned.Contains(box))throw new InvalidOperationException("UNOWNED_BOX"); }
    public uint[] Pids(string box) {
        ScopeRead(box);uint total=Count(box);
        if(total>1024)throw new InvalidOperationException("ENUMERATION_BOUND");
        uint[] pids=new uint[1024];uint count=1024;
        if(enumerate(BoxBuffer(box),true,UInt32.MaxValue,pids,ref count)!=0 || count>=1024 || Count(box)>count)throw new InvalidOperationException("ENUMERATION_INCOMPLETE");
        Array.Resize(ref pids,(int)count);return pids;
    }
    public Dictionary<string,object> ExerciseTruncatedEnumeration(string box) {
        ScopeRead(box);uint before=Count(box);uint[] pids=new uint[1];uint count=1;
        if(before<2)throw new InvalidOperationException("ENUMERATION_POSITIVE_CONTROL_UNAVAILABLE");
        int status=enumerate(BoxBuffer(box),true,UInt32.MaxValue,pids,ref count);
        if(status!=0)throw new InvalidOperationException("ENUMERATION_UNKNOWN");
        uint after=Count(box);
        if(after<=count)throw new InvalidOperationException("ENUMERATION_POSITIVE_CONTROL_UNAVAILABLE");
        return new Dictionary<string,object>{{"upstream_status",status},{"requested_capacity",1},{"returned_count",count},{"authoritative_count_before",before},{"authoritative_count_after",after},{"partial_snapshot_rejected",true},{"idle_or_cleanup_authorized",false}};
    }
    public Dictionary<string,object> ObserveIndependentSession(string box) {
        ScopeRead(box);uint[] all=Pids(box);uint other=0;bool otherOwner=false;
        foreach(uint pid in all){var actualBox=new StringBuilder(40);var actualSid=new StringBuilder(96);uint session;long created;
            if(query((IntPtr)pid,0,actualBox,null,actualSid,out session,out created)!=0||actualBox.ToString()!=box)throw new InvalidOperationException("SESSION_MEMBERSHIP_UNKNOWN");
            if(session!=CurrentSession){other++;otherOwner|=actualSid.ToString()!=sid;}
        }
        uint current=0;if(enumerate(BoxBuffer(box),false,CurrentSession,null,ref current)!=0)throw new InvalidOperationException("ENUMERATION_UNKNOWN");
        if(other==0||!otherOwner||all.Length<=current)throw new InvalidOperationException("SECOND_SESSION_POSITIVE_CONTROL_UNAVAILABLE");
        return new Dictionary<string,object>{{"all_session_count",all.Length},{"current_session_count",current},{"other_session_count",other},{"different_owner_observed",otherOwner},{"all_sessions_coverage",true},{"interactive_logon_sessions_tested",false},{"scope","Real session-zero SYSTEM task and current runner session"}};
    }
    public string Root(string box) {
        ScopeRead(box);uint bytes=0;
        if(root(BoxBuffer(box),null,IntPtr.Zero,IntPtr.Zero,ref bytes,IntPtr.Zero,IntPtr.Zero)!=0 || bytes==0 || bytes>8192)throw new InvalidOperationException("ROOT_QUERY_FAILED");
        var path=new StringBuilder(4096);uint capacity=8192;
        if(root(BoxBuffer(box),path,IntPtr.Zero,IntPtr.Zero,ref capacity,IntPtr.Zero,IntPtr.Zero)!=0 || !translate(path)) throw new InvalidOperationException("ROOT_TRANSLATION_FAILED");
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
                if(handle==IntPtr.Zero){
                    // PID disappeared between snapshots. Never dispatch to that number;
                    // the next bounded sweep must reconcile current engine membership.
                    if(Marshal.GetLastWin32Error()==87)continue;
                    throw new InvalidOperationException("PROCESS_HANDLE_UNAVAILABLE");
                }
                try {
                    long born,exit,kernel,user,engineBorn;uint session;var actualBox=new StringBuilder(40);var actualSid=new StringBuilder(96);
                    if(!GetProcessTimes(handle,out born,out exit,out kernel,out user))throw new Win32Exception();
                    bool critical;if(!IsProcessCritical(handle,out critical) || critical)throw new InvalidOperationException("CRITICAL_PROCESS_REJECTED");
                    if(WaitForSingleObject(handle,0)==0)continue;
                    int status=query((IntPtr)pid,0,actualBox,null,actualSid,out session,out engineBorn);
                    if(status!=0 || actualBox.ToString()!=box || actualSid.ToString()!=sid || born!=engineBorn){
                        // A scope observation may race an exit. Never terminate on a
                        // mismatch; only the retained object's completed wait permits
                        // a fresh membership sweep, without acting on a reused PID.
                        if(WaitForSingleObject(handle,1000)==0)continue;
                        throw new InvalidOperationException("PROCESS_SCOPE_REJECTED_"+unchecked((uint)status).ToString("X8"));
                    }
                    // An object may naturally exit after authorization. Even if terminate
                    // reports failure, only a signalled retained handle proves completion.
                    TerminateProcess(handle,99);
                    if(WaitForSingleObject(handle,15000)!=0)throw new InvalidOperationException("STOP_INCOMPLETE");
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
