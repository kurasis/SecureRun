// Synthetic packaging tests only. This assembly is never installed or bundled.
using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
public static class P11Native {
    delegate bool Visitor(IntPtr window,IntPtr parameter);
    [DllImport("user32.dll")] static extern bool EnumWindows(Visitor callback,IntPtr parameter);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr window,out uint pid);
    [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr window,StringBuilder title,int bound);
    [DllImport("user32.dll")] static extern bool PostMessage(IntPtr window,uint message,IntPtr w,IntPtr l);
    [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)]
    static extern bool QueryFullProcessImageName(Microsoft.Win32.SafeHandles.SafeProcessHandle process,uint flags,StringBuilder name,ref uint length);
    [DllImport("winsqlite3.dll",CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_open([MarshalAs(UnmanagedType.LPUTF8Str)]string path,out IntPtr db);
    [DllImport("winsqlite3.dll",CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_exec(IntPtr db,[MarshalAs(UnmanagedType.LPUTF8Str)]string sql,IntPtr callback,IntPtr user,out IntPtr error);
    [DllImport("winsqlite3.dll",CallingConvention=CallingConvention.Cdecl)] static extern int sqlite3_close(IntPtr db);
    [DllImport("winsqlite3.dll",CallingConvention=CallingConvention.Cdecl)] static extern void sqlite3_free(IntPtr error);
    public static void FixtureSchema(string path,bool future) {
        string profile=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"SecureRun","metadata");
        if(Environment.GetEnvironmentVariable("GITHUB_ACTIONS")!="true"||Path.GetFullPath(path)!=Path.Combine(profile,"policy.sqlite"))throw new Exception("P11_SQL_FIXTURE_SCOPE_REJECTED");
        IntPtr db,error;if(sqlite3_open(path,out db)!=0)throw new Exception("P11_SQL_FIXTURE_OPEN_FAILED");
        try{if(sqlite3_exec(db,future?"PRAGMA wal_checkpoint(TRUNCATE); PRAGMA user_version=2;":"PRAGMA wal_checkpoint(TRUNCATE); PRAGMA user_version=0;",IntPtr.Zero,IntPtr.Zero,out error)!=0){sqlite3_free(error);throw new Exception("P11_SQL_FIXTURE_WRITE_FAILED");}}finally{sqlite3_close(db);}
    }
    public static void NormalWindow(Process process,string executable) {
        string expected=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),"SecureRun Development","securerun.exe");
        if(Environment.GetEnvironmentVariable("GITHUB_ACTIONS")!="true"||!String.Equals(executable,expected,StringComparison.OrdinalIgnoreCase))throw new Exception("P11_GUI_SCOPE_REJECTED");
        var name=new StringBuilder(32768);uint length=32768;
        if(!QueryFullProcessImageName(process.SafeHandle,0,name,ref length)||!String.Equals(name.ToString(),expected,StringComparison.OrdinalIgnoreCase))throw new Exception("P11_GUI_IMAGE_CHANGED");
        var clock=Stopwatch.StartNew();IntPtr found=IntPtr.Zero;
        do{if(process.HasExited)throw new Exception("P11_GUI_EXITED");
            EnumWindows((w,p)=>{uint pid;GetWindowThreadProcessId(w,out pid);if(pid==(uint)process.Id){var title=new StringBuilder(128);GetWindowText(w,title,128);if(title.ToString()=="SecureRun"){found=w;return false;}}return true;},IntPtr.Zero);
            if(found!=IntPtr.Zero)break;Thread.Sleep(100);
        }while(clock.ElapsedMilliseconds<60000);
        if(found==IntPtr.Zero||!PostMessage(found,0x10,IntPtr.Zero,IntPtr.Zero)||!process.WaitForExit(30000)||process.ExitCode!=0)throw new Exception("P11_GUI_NOT_OBSERVED_OR_CLOSED");
    }
}
