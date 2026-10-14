// Disposable Actions fixtures only. Never compiled into the product or its helper.
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Principal;
using System.Text;
using System.Text.RegularExpressions;

public sealed class P05Lab {
    [DllImport("kernel32",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr LoadLibraryEx(string file,IntPtr reserved,uint flags);
    [DllImport("kernel32",CharSet=CharSet.Ansi)] static extern IntPtr GetProcAddress(IntPtr module,string name);
    [DllImport("kernel32",SetLastError=true)] static extern bool GetExitCodeProcess(IntPtr process,out uint code);
    [DllImport("kernel32")] static extern uint WaitForSingleObject(IntPtr handle,uint time);
    [DllImport("kernel32",SetLastError=true)] static extern bool TerminateProcess(IntPtr process,uint code);
    [DllImport("kernel32")] static extern bool CloseHandle(IntPtr handle);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl,CharSet=CharSet.Unicode)] delegate uint Update(char op,string password,string section,string key,string value);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl,CharSet=CharSet.Unicode)] delegate int Conf(string section,string key,uint index,StringBuilder value,uint size);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int Reload(uint session,uint flags);
    [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)] struct Startup {
        public uint size;public string reserved,desktop,title;public uint x,y,width,height,xchars,ychars,fill,flags;public ushort show,cb;public IntPtr reserved2,input,output,error;
    }
    [StructLayout(LayoutKind.Sequential)] public struct Receipt {public IntPtr process,thread;public uint pid,tid;}
    [UnmanagedFunctionPointer(CallingConvention.Cdecl,CharSet=CharSet.Unicode)] [return:MarshalAs(UnmanagedType.Bool)] delegate bool Run(string box,string command,string directory,uint flags,ref Startup startup,out Receipt receipt);
    readonly Update update;readonly Conf conf;readonly Reload reload;readonly Run run;
    readonly string engine,fixture,code;readonly HashSet<string> boxes=new HashSet<string>();
    T Bind<T>(IntPtr module,string name) where T:Delegate {var p=GetProcAddress(module,name);if(p==IntPtr.Zero)throw new InvalidOperationException("LAB_EXPORT_MISSING");return Marshal.GetDelegateForFunctionPointer<T>(p);}
    public P05Lab(string engine,string fixture,string code) {
        if(Environment.GetEnvironmentVariable("GITHUB_ACTIONS")!="true")throw new InvalidOperationException("DISPOSABLE_ACTIONS_VM_REQUIRED");
        this.engine=Path.GetFullPath(engine);this.fixture=Path.GetFullPath(fixture);this.code=Path.GetFullPath(code);
        if(this.engine!=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),"Sandboxie-Plus")||!this.fixture.StartsWith(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),"SecureRunLab","p02-"),StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException("LAB_SCOPE_REJECTED");
        var module=LoadLibraryEx(Path.Combine(engine,"SbieDll.dll"),IntPtr.Zero,0x100|0x800);if(module==IntPtr.Zero)throw new Win32Exception();
        update=Bind<Update>(module,"SbieDll_UpdateConf");conf=Bind<Conf>(module,"SbieApi_QueryConf");reload=Bind<Reload>(module,"SbieApi_ReloadConf");run=Bind<Run>(module,"SbieDll_RunSandboxed");
    }
    public string Read(string section,string key,uint flags) {var output=new StringBuilder(2048);int status=conf(section,key,flags,output,4096);if(unchecked((uint)status)==0xc000008bU)return null;if(status!=0)throw new InvalidOperationException("LAB_READ_FAILED");return output.ToString();}
    public void Register(string box) {
        if(!Regex.IsMatch(box,@"\ASR_[0-9a-f]{32}\z"))throw new InvalidOperationException("LAB_SCOPE_REJECTED");
        string marker=Read(box,"SecureRunOwner",0x70000000U),sid=WindowsIdentity.GetCurrent().User.Value;
        if(marker!="v1:"+sid+":"+box.Substring(3))throw new InvalidOperationException("LAB_OWNER_MISMATCH");boxes.Add(box);
    }
    public void Set(string box,string key,string value) {
        if(!boxes.Contains(box)||!Regex.IsMatch(key,@"\A(Enabled|AutoDelete|AutoRecover|OnBoxDelete|ClosedFilePath|ReadFilePath|OpenFilePath|FileRootPath|Template)\z"))throw new InvalidOperationException("LAB_SCOPE_REJECTED");
        if(update('s',null,box,key,value)!=0)throw new InvalidOperationException("LAB_WRITE_REFUSED");
    }
    public void Wfp(bool enabled) {
        if(update('s',null,"GlobalSettings","NetworkEnableWFP",enabled?"y":"n")!=0||reload((uint)Process.GetCurrentProcess().SessionId,1)!=0)throw new InvalidOperationException("LAB_WFP_FIXTURE_FAILED");
    }
    public void GlobalTemplate(string name,bool enabled) {
        if(!Regex.IsMatch(name,@"\AP05Unsafe_[0-9a-f]{32}\z"))throw new InvalidOperationException("LAB_SCOPE_REJECTED");
        if(enabled){if(Read("GlobalSettings","Template",0x70000000U)!=null)throw new InvalidOperationException("PREEXISTING_GLOBAL_TEMPLATE_NOT_CHANGED");if(update('s',null,"Template_"+name,"OpenFilePath",fixture+"\\*")!=0)throw new InvalidOperationException("LAB_TEMPLATE_FIXTURE_FAILED");}
        if(update('s',null,"GlobalSettings","Template",enabled?name:null)!=0)throw new InvalidOperationException("LAB_TEMPLATE_FIXTURE_FAILED");
    }
    public Receipt Hold(string box,string probe) {
        if(!boxes.Contains(box)||Path.GetDirectoryName(Path.GetFullPath(probe))!=code||!Regex.IsMatch(Path.GetFileName(probe),@"\Afeasibility_probe_(x86|x64|arm64)\.exe\z"))throw new InvalidOperationException("LAB_SCOPE_REJECTED");
        Set(box,"Enabled","y");var startup=new Startup{size=(uint)Marshal.SizeOf<Startup>()};Receipt receipt;
        string command=Quote(probe)+" hold-session "+Quote(fixture)+" "+box+" p05-hold "+Quote(engine);
        if(!run(box,command,engine,0,ref startup,out receipt))throw new InvalidOperationException("LAB_HOLD_REFUSED");return receipt;
    }
    static string Quote(string value) {
        if(value.IndexOfAny(new[]{'\0','\r','\n','"'})>=0||value.EndsWith("\\",StringComparison.Ordinal))throw new InvalidOperationException("LAB_ARGUMENT_REJECTED");
        return "\""+value+"\"";
    }
    public static void Stop(Receipt receipt) {if(WaitForSingleObject(receipt.process,0)==258){if(!TerminateProcess(receipt.process,99)||WaitForSingleObject(receipt.process,10000)!=0)throw new InvalidOperationException("LAB_STOP_INCOMPLETE");}CloseHandle(receipt.thread);CloseHandle(receipt.process);}
}
