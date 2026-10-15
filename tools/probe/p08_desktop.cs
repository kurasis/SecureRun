// Fixed disposable Windows desktop interactions; never part of the product.
using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
public static class P08Desktop {
    delegate bool Visitor(IntPtr window,IntPtr parameter);
    [DllImport("user32.dll")] static extern bool EnumWindows(Visitor callback,IntPtr parameter);
    [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr parent,Visitor callback,IntPtr parameter);
    [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr window,StringBuilder text,int maximum);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr window,out uint process);
    [DllImport("user32.dll")] static extern IntPtr GetDlgItem(IntPtr window,int id);
    [DllImport("user32.dll",SetLastError=true)] static extern bool PostMessage(IntPtr window,uint message,IntPtr first,IntPtr second);
    [DllImport("user32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr SendMessageTimeout(IntPtr window,uint message,UIntPtr capacity,StringBuilder value,uint flags,uint timeout,out UIntPtr result);
    [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)]
    static extern bool QueryFullProcessImageName(Microsoft.Win32.SafeHandles.SafeProcessHandle process,uint flags,StringBuilder image,ref uint length);
    static void Scope(Process process,string executable) {
        if(Environment.GetEnvironmentVariable("GITHUB_ACTIONS")!="true" || Path.GetFileName(executable)!="securerun.exe" || !Path.GetFullPath(executable).StartsWith(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),"SecureRun-P08-"),StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException("P08_DESKTOP_SCOPE_REJECTED");
        if(process.HasExited)throw new InvalidOperationException("P08_DESKTOP_PROCESS_EXITED");
        // Query the held process object, not its not-yet-initialized module list.
        // This also works across the Windows ARM64/x64 emulation boundary.
        var image=new StringBuilder(32768);uint length=32768;
        if(!QueryFullProcessImageName(process.SafeHandle,0,image,ref length))throw new InvalidOperationException("P08_DESKTOP_IMAGE_QUERY_FAILED_"+Marshal.GetLastWin32Error());
        if(!String.Equals(image.ToString(),executable,StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException("P08_DESKTOP_SCOPE_REJECTED");
    }
    static IntPtr Window(Process process,string title,int milliseconds) {
        var clock=Stopwatch.StartNew();IntPtr found=IntPtr.Zero;
        while(clock.ElapsedMilliseconds<milliseconds && !process.HasExited){
            EnumWindows((window,state)=>{uint pid;GetWindowThreadProcessId(window,out pid);if(pid==(uint)process.Id){var text=new StringBuilder(1024);GetWindowText(window,text,1024);if(text.ToString()==title){found=window;return false;}}return true;},IntPtr.Zero);
            if(found!=IntPtr.Zero)return found;Thread.Sleep(100);
        }throw new InvalidOperationException("P08_DESKTOP_WINDOW_TIMEOUT");
    }
    public static void WaitNormalWindow(Process process,string executable) {
        Scope(process,executable);Window(process,"SecureRun",45000);Scope(process,executable);
    }
    public static void CloseNormalWindow(Process process,string executable) {
        Scope(process,executable);var window=Window(process,"SecureRun",45000);Scope(process,executable);
        if(!PostMessage(window,0x10,IntPtr.Zero,IntPtr.Zero)||!process.WaitForExit(20000))throw new InvalidOperationException("P08_NORMAL_WINDOW_CLOSE_FAILED");
    }
    public static void Confirm(Process process,string executable,string environment,bool accept,string intent) {
        Guid parsed;if(!Guid.TryParse(environment,out parsed))throw new InvalidOperationException("P08_CONFIRMATION_ENVIRONMENT_INVALID");
        Scope(process,executable);var window=Window(process,"SecureRun — environment confirmation",60000);
        string retention=intent=="RESET"?"Keep the environment definition and application records.":intent=="REMOVE"?"Keep an audit tombstone and the verified empty root identity.":null;
        if(retention==null)throw new InvalidOperationException("P08_CONFIRMATION_INTENT_INVALID");
        var clock=Stopwatch.StartNew();
        while(clock.ElapsedMilliseconds<10000){
            Scope(process,executable);uint pid;GetWindowThreadProcessId(window,out pid);if(pid!=(uint)process.Id)throw new InvalidOperationException("P08_DESKTOP_SCOPE_REJECTED");
            var content=new StringBuilder();
            EnumChildWindows(window,(child,state)=>{var text=new StringBuilder(4096);UIntPtr length;SendMessageTimeout(child,0x0d,(UIntPtr)4096,text,2,1000,out length);content.AppendLine(text.ToString());return true;},IntPtr.Zero);
            var body=content.ToString();var button=GetDlgItem(window,accept?1:2);
            if(body.Contains(environment,StringComparison.OrdinalIgnoreCase)&&body.Contains(retention,StringComparison.Ordinal)&&button!=IntPtr.Zero){
                GetWindowThreadProcessId(button,out pid);if(pid!=(uint)process.Id)throw new InvalidOperationException("P08_DESKTOP_SCOPE_REJECTED");
                // The pinned rfd default backend uses MessageBoxW. Send its exact
                // button's BN_CLICKED notification without relying on foreground focus.
                if(!PostMessage(window,0x0111,(IntPtr)(accept?1:2),button))throw new InvalidOperationException("P08_CONFIRMATION_BUTTON_NOT_FOUND");
                return;
            }
            Thread.Sleep(100);
        }throw new InvalidOperationException("P08_CONFIRMATION_BODY_NOT_READY");
    }
}
