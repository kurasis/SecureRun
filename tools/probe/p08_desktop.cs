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
    static void Scope(Process process,string executable) {
        if(Environment.GetEnvironmentVariable("GITHUB_ACTIONS")!="true" || process.HasExited || Path.GetFileName(executable)!="securerun.exe" || !Path.GetFullPath(executable).StartsWith(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),"SecureRun-P08-"),StringComparison.OrdinalIgnoreCase) || !String.Equals(process.MainModule.FileName,executable,StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException("P08_DESKTOP_SCOPE_REJECTED");
    }
    static IntPtr Window(Process process,string title,int milliseconds) {
        var clock=Stopwatch.StartNew();IntPtr found=IntPtr.Zero;
        while(clock.ElapsedMilliseconds<milliseconds && !process.HasExited){
            EnumWindows((window,state)=>{uint pid;GetWindowThreadProcessId(window,out pid);if(pid==(uint)process.Id){var text=new StringBuilder(1024);GetWindowText(window,text,1024);if(text.ToString()==title){found=window;return false;}}return true;},IntPtr.Zero);
            if(found!=IntPtr.Zero)return found;Thread.Sleep(100);
        }throw new InvalidOperationException("P08_DESKTOP_WINDOW_TIMEOUT");
    }
    public static void CloseNormalWindow(Process process,string executable) {
        Scope(process,executable);var window=Window(process,"SecureRun",45000);Scope(process,executable);
        if(!PostMessage(window,0x10,IntPtr.Zero,IntPtr.Zero)||!process.WaitForExit(20000))throw new InvalidOperationException("P08_NORMAL_WINDOW_CLOSE_FAILED");
    }
    public static void Confirm(Process process,string executable,string environment,bool accept) {
        Guid parsed;if(!Guid.TryParse(environment,out parsed))throw new InvalidOperationException("P08_CONFIRMATION_ENVIRONMENT_INVALID");
        Scope(process,executable);var window=Window(process,"SecureRun — environment confirmation",60000);bool named=false;
        EnumChildWindows(window,(child,state)=>{var text=new StringBuilder(4096);UIntPtr length;SendMessageTimeout(child,0x0d,(UIntPtr)4096,text,2,1000,out length);if(text.ToString().Contains(environment,StringComparison.OrdinalIgnoreCase))named=true;return true;},IntPtr.Zero);
        if(!named)throw new InvalidOperationException("P08_CONFIRMATION_ENVIRONMENT_NOT_VISIBLE");
        Scope(process,executable);var button=GetDlgItem(window,accept?1:2);
        if(button==IntPtr.Zero||!PostMessage(button,0x00f5,IntPtr.Zero,IntPtr.Zero))throw new InvalidOperationException("P08_CONFIRMATION_BUTTON_NOT_FOUND");
    }
}
