// Disposable Actions fixtures only. Never compiled into the product or its helper.
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Principal;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;

public sealed class P05Lab {
    [DllImport("kernel32",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr LoadLibraryEx(string file,IntPtr reserved,uint flags);
    [DllImport("kernel32",CharSet=CharSet.Ansi)] static extern IntPtr GetProcAddress(IntPtr module,string name);
    [DllImport("kernel32",SetLastError=true)] static extern bool GetExitCodeProcess(IntPtr process,out uint code);
    [DllImport("kernel32")] static extern uint WaitForSingleObject(IntPtr handle,uint time);
    [DllImport("kernel32",SetLastError=true)] static extern bool TerminateProcess(IntPtr process,uint code);
    [DllImport("kernel32")] static extern bool CloseHandle(IntPtr handle);
    [DllImport("kernel32",SetLastError=true)] static extern IntPtr OpenProcess(uint access,bool inherit,uint pid);
    [DllImport("kernel32",SetLastError=true)] static extern bool GetProcessTimes(IntPtr process,out long created,out long exited,out long kernel,out long user);
    [DllImport("kernel32",SetLastError=true)] static extern bool IsProcessCritical(IntPtr process,[MarshalAs(UnmanagedType.Bool)]out bool critical);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl,CharSet=CharSet.Unicode)] delegate uint Update(char op,string password,string section,string key,string value);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl,CharSet=CharSet.Unicode)] delegate int Conf(string section,string key,uint index,StringBuilder value,uint size);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int Reload(uint session,uint flags);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl,CharSet=CharSet.Unicode)] delegate int Query(IntPtr pid,uint imageChars,StringBuilder box,StringBuilder image,StringBuilder sid,out uint session,out long born);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl,CharSet=CharSet.Unicode)] delegate int Enumerate(StringBuilder box,[MarshalAs(UnmanagedType.U1)]bool allSessions,uint session,[Out]uint[] pids,ref uint count);
    [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)] struct Startup {
        public uint size;public string reserved,desktop,title;public uint x,y,width,height,xchars,ychars,fill,flags;public ushort show,cb;public IntPtr reserved2,input,output,error;
    }
    [StructLayout(LayoutKind.Sequential)] public struct Receipt {public IntPtr process,thread;public uint pid,tid;}
    [UnmanagedFunctionPointer(CallingConvention.Cdecl,CharSet=CharSet.Unicode)] [return:MarshalAs(UnmanagedType.Bool)] delegate bool Run(string box,string command,string directory,uint flags,ref Startup startup,out Receipt receipt);
    readonly Update update;readonly Conf conf;readonly Reload reload;readonly Run run;readonly Query query;readonly Enumerate enumerate;
    readonly string engine,fixture,code;readonly HashSet<string> boxes=new HashSet<string>();
    T Bind<T>(IntPtr module,string name) where T:Delegate {var p=GetProcAddress(module,name);if(p==IntPtr.Zero)throw new InvalidOperationException("LAB_EXPORT_MISSING");return Marshal.GetDelegateForFunctionPointer<T>(p);}
    public P05Lab(string engine,string fixture,string code) {
        if(Environment.GetEnvironmentVariable("GITHUB_ACTIONS")!="true")throw new InvalidOperationException("DISPOSABLE_ACTIONS_VM_REQUIRED");
        this.engine=Path.GetFullPath(engine);this.fixture=Path.GetFullPath(fixture);this.code=Path.GetFullPath(code);
        if(this.engine!=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),"Sandboxie-Plus")||!this.fixture.StartsWith(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),"SecureRunLab","p02-"),StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException("LAB_SCOPE_REJECTED");
        var module=LoadLibraryEx(Path.Combine(engine,"SbieDll.dll"),IntPtr.Zero,0x100|0x800);if(module==IntPtr.Zero)throw new Win32Exception();
        update=Bind<Update>(module,"SbieDll_UpdateConf");conf=Bind<Conf>(module,"SbieApi_QueryConf");reload=Bind<Reload>(module,"SbieApi_ReloadConf");run=Bind<Run>(module,"SbieDll_RunSandboxed");
        query=Bind<Query>(module,"SbieApi_QueryProcessEx2");enumerate=Bind<Enumerate>(module,"SbieApi_EnumProcessEx");
    }
    public string Read(string section,string key,uint flags) {var output=new StringBuilder(2048);int status=conf(section,key,flags,output,4096);if(unchecked((uint)status)==0xc000008bU)return null;if(status!=0)throw new InvalidOperationException("LAB_READ_FAILED");return output.ToString();}
    public void Register(string box) {
        if(!Regex.IsMatch(box,@"\ASR_[0-9a-f]{32}\z"))throw new InvalidOperationException("LAB_SCOPE_REJECTED");
        string marker=Read(box,"SecureRunOwner",0x70000000U),sid=WindowsIdentity.GetCurrent().User.Value;
        if(marker!="v1:"+sid+":"+box.Substring(3))throw new InvalidOperationException("LAB_OWNER_MISMATCH");boxes.Add(box);
    }
    public void Set(string box,string key,string value) {
        if(!boxes.Contains(box)||!Regex.IsMatch(key,@"\A(Enabled|AutoDelete|AutoRecover|OnBoxDelete|OnBoxTerminate|DeleteCommand|ClosedFilePath|ReadFilePath|OpenFilePath|FileRootPath|Template)\z"))throw new InvalidOperationException("LAB_SCOPE_REJECTED");
        if(update('s',null,box,key,value)!=0)throw new InvalidOperationException("LAB_WRITE_REFUSED");
    }
    // P08 disposable fixtures only; current owned marker remains mandatory.
    public void LifecycleSetting(string box,string key,string value) {
        if(!boxes.Contains(box)||!Regex.IsMatch(key,@"\A(UseFileImage|NeverDelete)\z")||!(value=="y"||value=="n"))throw new InvalidOperationException("LAB_SCOPE_REJECTED");
        if(update('s',null,box,key,value)!=0)throw new InvalidOperationException("LAB_WRITE_REFUSED");
    }
    public string LifecycleHookCommand() {
        return "\""+Path.Combine(Environment.SystemDirectory,"cmd.exe")+"\" /d /c \"\""+Path.Combine(fixture,"p08-hook.cmd")+"\"\"";
    }
    public void LifecycleHookTemplate(string box,bool enabled) {
        if(!boxes.Contains(box)||Environment.GetEnvironmentVariable("GITHUB_ACTIONS")!="true")throw new InvalidOperationException("LAB_SCOPE_REJECTED");
        const string name="SecureRunP08LifecycleHook";string section="Template_"+name,command=LifecycleHookCommand();
        string current=Read("GlobalSettings","Template",0x70000000U),hook=Read(section,"OnBoxDelete",0x70000000U);
        if(enabled?(current!=null||hook!=null):(current!=name||hook!=command))throw new InvalidOperationException("UNEXPECTED_GLOBAL_HOOK_NOT_CHANGED");
        if(enabled && update('s',null,section,"OnBoxDelete",command)!=0)throw new InvalidOperationException("LAB_TEMPLATE_FIXTURE_FAILED");
        if(update('s',null,"GlobalSettings","Template",enabled?name:null)!=0)throw new InvalidOperationException("LAB_TEMPLATE_FIXTURE_FAILED");
        if(!enabled && update('s',null,section,"*",null)!=0)throw new InvalidOperationException("LAB_TEMPLATE_FIXTURE_FAILED");
        if(reload((uint)Process.GetCurrentProcess().SessionId,1)!=0)throw new InvalidOperationException("LAB_TEMPLATE_RELOAD_FAILED");
    }
    public void Wfp(bool enabled) {
        if(update('s',null,"GlobalSettings","NetworkEnableWFP",enabled?"y":"n")!=0||reload((uint)Process.GetCurrentProcess().SessionId,1)!=0)throw new InvalidOperationException("LAB_WFP_FIXTURE_FAILED");
    }
    public void GlobalTemplate(string name,bool enabled) {
        if(!Regex.IsMatch(name,@"\AP05Unsafe_[0-9a-f]{32}\z"))throw new InvalidOperationException("LAB_SCOPE_REJECTED");
        if(enabled){if(Read("GlobalSettings","Template",0x70000000U)!=null)throw new InvalidOperationException("PREEXISTING_GLOBAL_TEMPLATE_NOT_CHANGED");if(update('s',null,"Template_"+name,"OpenFilePath",fixture+"\\*")!=0)throw new InvalidOperationException("LAB_TEMPLATE_FIXTURE_FAILED");}
        if(update('s',null,"GlobalSettings","Template",enabled?name:null)!=0)throw new InvalidOperationException("LAB_TEMPLATE_FIXTURE_FAILED");
    }
    public string InstallPassword() {
        if(Read("GlobalSettings","EditPassword",0x70000000U)!=null)throw new InvalidOperationException("PREEXISTING_PASSWORD_NOT_CHANGED");
        string password="P05!"+Guid.NewGuid().ToString("N");byte[] salt=RandomNumberGenerator.GetBytes(16),plain=Encoding.Unicode.GetBytes(password);
        byte[] input=new byte[salt.Length+plain.Length];salt.CopyTo(input,0);plain.CopyTo(input,16);
        byte[] hash=SHA256.HashData(input),combined=new byte[48];salt.CopyTo(combined,0);hash.CopyTo(combined,16);
        uint status=update('s',null,"GlobalSettings","EditPassword",Convert.ToBase64String(combined));
        Array.Clear(plain,0,plain.Length);Array.Clear(input,0,input.Length);Array.Clear(hash,0,hash.Length);Array.Clear(combined,0,combined.Length);
        if(status!=0)throw new InvalidOperationException("PASSWORD_FIXTURE_SETUP_FAILED");return password;
    }
    public void ClearPassword(string password) {if(update('s',password,"GlobalSettings","EditPassword",null)!=0)throw new InvalidOperationException("PASSWORD_FIXTURE_RESTORE_FAILED");}
    public Receipt Hold(string box,string probe) {
        if(!boxes.Contains(box)||Path.GetDirectoryName(Path.GetFullPath(probe))!=code||!Regex.IsMatch(Path.GetFileName(probe),@"\Afeasibility_probe_(x86|x64|arm64)\.exe\z"))throw new InvalidOperationException("LAB_SCOPE_REJECTED");
        Set(box,"Enabled","y");var startup=new Startup{size=(uint)Marshal.SizeOf<Startup>()};Receipt receipt;
        string command=Quote(probe)+" hold-session "+Quote(fixture)+" "+box+" p05-hold "+Quote(engine);
        if(!run(box,command,engine,0,ref startup,out receipt))throw new InvalidOperationException("LAB_HOLD_REFUSED");return receipt;
    }
    // P07/P08 synthetic external actor. The P02 fixture requires inherited
    // ProgramData; this fixed production probe establishes membership itself
    // and uses only the explicitly supplied synthetic report path.
    public Receipt HoldProductionProbe(string box) {
        if(!boxes.Contains(box))throw new InvalidOperationException("LAB_SCOPE_REJECTED");
        string probe=Path.Combine(code,"securerun-launch-probe.exe");
        if(!File.Exists(probe))throw new InvalidOperationException("LAB_FIXED_PROBE_MISSING");
        Set(box,"Enabled","y");var startup=new Startup{size=(uint)Marshal.SizeOf<Startup>()};Receipt receipt;
        string command=Quote(probe)+" hold "+Quote(Path.Combine(fixture,"external-held.jsonl"));
        if(!run(box,command,engine,0x08000000U,ref startup,out receipt))throw new InvalidOperationException("LAB_HOLD_REFUSED");
        return receipt;
    }
    public bool HeldMemberAlive(Receipt receipt,string expectedBox) {
        long born,exited,kernel,user,driverBorn;uint session;var box=new StringBuilder(40);var sid=new StringBuilder(96);
        return boxes.Contains(expectedBox)&&WaitForSingleObject(receipt.process,100)==258
            &&GetProcessTimes(receipt.process,out born,out exited,out kernel,out user)
            &&query((IntPtr)receipt.pid,0,box,null,sid,out session,out driverBorn)==0
            &&box.ToString()==expectedBox&&sid.ToString()==WindowsIdentity.GetCurrent().User.Value
            &&born!=0&&born==driverBorn;
    }
    static string Quote(string value) {
        if(value.IndexOfAny(new[]{'\0','\r','\n','"'})>=0||value.EndsWith("\\",StringComparison.Ordinal))throw new InvalidOperationException("LAB_ARGUMENT_REJECTED");
        return "\""+value+"\"";
    }
    public static void Stop(Receipt receipt) {if(WaitForSingleObject(receipt.process,0)==258){if(!TerminateProcess(receipt.process,99)||WaitForSingleObject(receipt.process,10000)!=0)throw new InvalidOperationException("LAB_STOP_INCOMPLETE");}CloseHandle(receipt.thread);CloseHandle(receipt.process);}
    // Restore the managed dispatch fence without stopping the held test member.
    public void FenceNewFixtureDispatch(string box) {
        Register(box);Set(box,"Enabled","n");
        if(reload((uint)Process.GetCurrentProcess().SessionId,0)!=0||Read(box,"Enabled",0x70000000U)!="n")throw new InvalidOperationException("LAB_FENCE_FAILED");
    }
    public void FenceFixture(string box) {
        // Lab-owned synthetic targets may leave original service companions.
        // This fixture has no product command and never stops a numeric PID.
        Register(box);Set(box,"Enabled","n");
        if(reload((uint)Process.GetCurrentProcess().SessionId,0)!=0)throw new InvalidOperationException("LAB_FENCE_FAILED");
        string owner=WindowsIdentity.GetCurrent().User.Value;
        for(int attempt=0;attempt<4;attempt++){
            uint count=0;if(enumerate(new StringBuilder(box,40),true,UInt32.MaxValue,null,ref count)!=0||count>=32)throw new InvalidOperationException("LAB_ENUMERATION_UNKNOWN");if(count==0)return;
            uint[] pids=new uint[32];uint actual=32,after=0;if(enumerate(new StringBuilder(box,40),true,UInt32.MaxValue,pids,ref actual)!=0||actual>=32||enumerate(new StringBuilder(box,40),true,UInt32.MaxValue,null,ref after)!=0||after>actual)throw new InvalidOperationException("LAB_ENUMERATION_UNKNOWN");
            for(int i=0;i<actual;i++){
                IntPtr held=OpenProcess(0x100001|0x1000,false,pids[i]);if(held==IntPtr.Zero){if(Marshal.GetLastWin32Error()==87)continue;throw new InvalidOperationException("LAB_PROCESS_HANDLE_UNKNOWN");}
                try{if(WaitForSingleObject(held,0)==0)continue;
                    long birth,exit,kernel,user,observed=0;bool critical;uint session;var name=new StringBuilder(40);var sid=new StringBuilder(96);
                    bool birthKnown=GetProcessTimes(held,out birth,out exit,out kernel,out user);
                    bool criticalKnown=IsProcessCritical(held,out critical);
                    bool queryAttempted=birthKnown&&criticalKnown&&!critical;
                    int queryStatus=queryAttempted?query((IntPtr)pids[i],0,name,null,sid,out session,out observed):-1;
                    // A default birth never substitutes for a successful query.
                    bool sameBirth=queryAttempted&&queryStatus==0&&observed==birth;
                    bool sameBox=queryAttempted&&queryStatus==0&&name.ToString()==box;
                    bool sameOwner=queryAttempted&&queryStatus==0&&sid.ToString()==owner;
                    if(!birthKnown||!criticalKnown||critical||queryStatus!=0||!sameBox||!sameOwner||!sameBirth){
                        // Driver membership may vanish before this retained
                        // object signals exit. Completion permits only skipping
                        // this object, never terminating an unverified live one.
                        uint waited=WaitForSingleObject(held,1000);if(waited==0)continue;
                        var failure=new InvalidOperationException("LAB_PROCESS_IDENTITY_CHANGED");
                        failure.Data["birth_known"]=birthKnown;failure.Data["critical_state_known"]=criticalKnown;
                        failure.Data["critical"]=critical;failure.Data["driver_query_attempted"]=queryAttempted;
                        if(queryAttempted)failure.Data["driver_query_status"]=queryStatus;
                        failure.Data["same_box"]=sameBox;failure.Data["same_owner"]=sameOwner;
                        failure.Data["same_birth"]=sameBirth;failure.Data["completion_wait_status"]=waited;
                        throw failure;
                    }
                    // A concurrent exit can make TerminateProcess fail. Only
                    // signaling of this same held object confirms completion.
                    TerminateProcess(held,99);
                    if(WaitForSingleObject(held,5000)!=0)throw new InvalidOperationException("LAB_STOP_INCOMPLETE");
                }finally{CloseHandle(held);}
            }
        }
        throw new InvalidOperationException("LAB_STOP_RECONCILIATION_REQUIRED");
    }
    public Receipt View(string box,string mode,string nonce,string label) {
        if(!boxes.Contains(box)||!Regex.IsMatch(mode,@"\A(write|read|shadow)\z")||!Regex.IsMatch(nonce,@"\A[0-9a-f]{32}\z")||!Regex.IsMatch(label,@"\A(before|readonly|restored)\z"))throw new InvalidOperationException("LAB_SCOPE_REJECTED");
        Set(box,"Enabled","y");var startup=new Startup{size=(uint)Marshal.SizeOf<Startup>()};Receipt receipt;
        string command=Quote(Path.Combine(code,"p05-view-probe.exe"))+" "+mode+" "+Quote(fixture)+" "+box+" "+nonce+" "+label;
        if(!run(box,command,engine,0,ref startup,out receipt))throw new InvalidOperationException("LAB_VIEW_DISPATCH_REFUSED");return receipt;
    }
    public static bool Success(Receipt receipt) {uint exitCode;return WaitForSingleObject(receipt.process,15000)==0&&GetExitCodeProcess(receipt.process,out exitCode)&&exitCode==0;}
    public Receipt FutureSibling(string box,string sibling,string nonce) {
        Register(sibling);
        if(!boxes.Contains(box)||box==sibling||!Regex.IsMatch(nonce,@"\A[0-9a-f]{32}\z"))throw new InvalidOperationException("LAB_SCOPE_REJECTED");
        string root=Read(sibling,"FileRootPath",0x70000000U),expected=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"SecureRun","boxes",sibling.Substring(3));
        if(!String.Equals(root,expected,StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException("LAB_SIBLING_ROOT_REJECTED");
        string canary=Path.Combine(root,"canary-"+nonce+".txt");File.WriteAllText(canary,"SYNTHETIC_FUTURE_SIBLING");
        if(File.ReadAllText(canary)!="SYNTHETIC_FUTURE_SIBLING")throw new InvalidOperationException("LAB_SIBLING_POSITIVE_FAILED");
        Set(box,"Enabled","y");var startup=new Startup{size=(uint)Marshal.SizeOf<Startup>()};Receipt receipt;
        string command=Quote(Path.Combine(code,"p05-view-probe.exe"))+" sibling "+Quote(fixture)+" "+box+" "+nonce+" before "+Quote(root);
        if(!run(box,command,engine,0,ref startup,out receipt))throw new InvalidOperationException("LAB_SIBLING_DISPATCH_REFUSED");return receipt;
    }
}
