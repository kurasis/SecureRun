// Disposable Windows measurement fixture. No product privilege or security switch.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
public sealed class P09Desktop : IDisposable {
 [StructLayout(LayoutKind.Sequential)] struct Security {public int length;public IntPtr descriptor;public int inherit;}
 [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)] struct Startup {public uint size;public string reserved,desktop,title;public uint x,y,width,height,xchars,ychars,fill,flags;public ushort show,reservedSize;public IntPtr reservedBytes,input,output,error;}
 [StructLayout(LayoutKind.Sequential)] struct Info {public IntPtr process,thread;public uint pid,tid;}
 [StructLayout(LayoutKind.Sequential)] struct Accounting {public long user,kernel,periodUser,periodKernel;public uint faults,total,active,terminated;}
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr CreateJobObject(IntPtr attributes,string name);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool AssignProcessToJobObject(IntPtr job,IntPtr process);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool QueryInformationJobObject(IntPtr job,int kind,IntPtr data,uint size,out uint returned);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool CreateProcess(string application,StringBuilder command,IntPtr processAttributes,IntPtr threadAttributes,bool inherit,uint flags,IntPtr environment,string cwd,ref Startup startup,out Info info);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr CreateFile(string path,uint access,uint sharing,ref Security security,uint creation,uint flags,IntPtr template);
 [DllImport("kernel32.dll")] static extern uint ResumeThread(IntPtr thread);
 [DllImport("kernel32.dll")] static extern bool TerminateJobObject(IntPtr job,uint code);
 [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
 [DllImport("kernel32.dll")] static extern uint WaitForSingleObject(IntPtr handle,uint ms);
 [DllImport("kernel32.dll")] static extern bool TerminateProcess(IntPtr handle,uint code);
 [DllImport("user32.dll")] static extern bool PostMessage(IntPtr hwnd,uint message,IntPtr wp,IntPtr lp);
 [DllImport("user32.dll")] static extern bool EnumWindows(Visit visit,IntPtr parameter);
 [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd,out uint pid);
 delegate bool Visit(IntPtr hwnd,IntPtr parameter);
 readonly IntPtr job,process;readonly bool hostFixture;public readonly int ProcessId;public readonly long StartedTicks;
 public P09Desktop(string executable,string cwd,string trace,int port):this(executable,cwd,trace,port,null) {}
 static string Quote(string value){if(value.IndexOfAny(new[]{'"','\0','\r','\n'})>=0||value.EndsWith("\\",StringComparison.Ordinal))throw new InvalidOperationException("P09_LAB_ARGUMENT_INVALID");return "\""+value+"\"";}
 public P09Desktop(string executable,string cwd,string trace,int port,string[] arguments) {
  if(Environment.GetEnvironmentVariable("GITHUB_ACTIONS")!="true"||!Path.GetFullPath(executable).StartsWith(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles)+"\\SecureRun-P09-",StringComparison.OrdinalIgnoreCase))throw new InvalidOperationException("P09_LAB_IMAGE_REQUIRED");
  hostFixture=Path.GetFileName(executable).Equals("firefox.exe",StringComparison.OrdinalIgnoreCase);
  if(hostFixture?(arguments==null||arguments.Length!=4||arguments[0]!="-no-remote"||arguments[1]!="-profile"||!arguments[3].StartsWith("http://127.0.0.1:",StringComparison.Ordinal)||port!=0):(Path.GetFileName(executable)!="securerun.exe"||arguments!=null))throw new InvalidOperationException("P09_FIXED_GUI_ROUTE_REQUIRED");
  job=CreateJobObject(IntPtr.Zero,null);if(job==IntPtr.Zero)throw new InvalidOperationException("P09_JOB_CREATE_FAILED");
  var security=new Security{length=Marshal.SizeOf<Security>(),inherit=1};IntPtr log=CreateFile(trace,0x40000000,3,ref security,1,0x00200000,IntPtr.Zero),input=CreateFile("NUL",0x80000000,3,ref security,3,0,IntPtr.Zero);
  if(log==new IntPtr(-1)||input==new IntPtr(-1))throw new InvalidOperationException("P09_TRACE_OPEN_FAILED");
  var values=new SortedDictionary<string,string>(StringComparer.OrdinalIgnoreCase);
  foreach(string key in new[]{"SystemRoot","WINDIR","PATH","TEMP","TMP","USERPROFILE","LOCALAPPDATA","APPDATA"}){string value=Environment.GetEnvironmentVariable(key);if(value!=null)values[key]=value;}
  values["GITHUB_ACTIONS"]="true";if(!hostFixture)values["SECURERUN_P09_SECRET"]="P09_ENV_SECRET_CANARY";
  if(port!=0){if(port<1024||port>65535)throw new InvalidOperationException("P09_PORT_INVALID");values["WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS"]="--remote-debugging-port="+port;}
  string block=String.Join("\0",values.Select(pair=>pair.Key+"="+pair.Value))+"\0\0";IntPtr environment=Marshal.StringToHGlobalUni(block);
  var startup=new Startup{size=(uint)Marshal.SizeOf<Startup>(),desktop="winsta0\\default",flags=0x100,input=input,output=log,error=log};Info info;
  StartedTicks=Stopwatch.GetTimestamp();
  try{if(!CreateProcess(executable,new StringBuilder(Quote(executable)+(arguments==null?"":" "+String.Join(" ",arguments.Select(Quote)))),IntPtr.Zero,IntPtr.Zero,true,0x00000404,environment,cwd,ref startup,out info))throw new InvalidOperationException("P09_GUI_CREATE_FAILED");}
  finally{Marshal.FreeHGlobal(environment);CloseHandle(log);CloseHandle(input);}
  process=info.process;ProcessId=(int)info.pid;
  if(!AssignProcessToJobObject(job,process)){TerminateProcess(process,90);WaitForSingleObject(process,10000);CloseHandle(info.thread);throw new InvalidOperationException("P09_JOB_ASSIGN_FAILED");}
  if(ResumeThread(info.thread)==uint.MaxValue){TerminateProcess(process,90);WaitForSingleObject(process,10000);CloseHandle(info.thread);throw new InvalidOperationException("P09_GUI_RESUME_FAILED");}CloseHandle(info.thread);
 }
 long Cpu() {IntPtr data=Marshal.AllocHGlobal(64);try{uint count;if(!QueryInformationJobObject(job,1,data,64,out count))throw new InvalidOperationException("P09_ACCOUNTING_FAILED");var value=Marshal.PtrToStructure<Accounting>(data);return value.user+value.kernel;}finally{Marshal.FreeHGlobal(data);}}
 public Dictionary<string,object> Sample() {
  IntPtr data=Marshal.AllocHGlobal(8+256*IntPtr.Size);try{uint returned;if(!QueryInformationJobObject(job,3,data,(uint)(8+256*IntPtr.Size),out returned))throw new InvalidOperationException("P09_PROCESS_GROUP_INCOMPLETE");
   int assigned=Marshal.ReadInt32(data),count=Marshal.ReadInt32(data,4);if(assigned!=count||count>256)throw new InvalidOperationException("P09_PROCESS_GROUP_INCOMPLETE");long memory=0;int webviews=0,observed=0;
   for(int i=0;i<count;i++){long pid=IntPtr.Size==8?Marshal.ReadInt64(data,8+i*IntPtr.Size):Marshal.ReadInt32(data,8+i*IntPtr.Size);try{using(var p=Process.GetProcessById((int)pid)){
    try{if(p.HasExited)continue;long workingSet=p.WorkingSet64;bool webview=p.ProcessName.Equals("msedgewebview2",StringComparison.OrdinalIgnoreCase);memory+=workingSet;observed++;if(webview)webviews++;}
    catch(InvalidOperationException){if(!p.HasExited)throw new InvalidOperationException("P09_LIVE_PROCESS_MEASUREMENT_FAILED");}
    catch(System.ComponentModel.Win32Exception){if(!p.HasExited)throw new InvalidOperationException("P09_LIVE_PROCESS_MEASUREMENT_FAILED");}
   }}catch(ArgumentException){}}
   return new Dictionary<string,object>{{"working_set_bytes",memory},{"process_count",observed},{"webview_processes",webviews},{"job_group_complete",true}};
  }finally{Marshal.FreeHGlobal(data);}
 }
 public Dictionary<string,object> MeasureIdle() {
  if(hostFixture)throw new InvalidOperationException("P09_MEASUREMENT_SCOPE_REJECTED");
  long begin=Cpu(),total=0,peak=0;int samples=0,webviews=0,processes=0;var clock=Stopwatch.StartNew();
  while(clock.Elapsed.TotalSeconds<60){var s=Sample();long memory=(long)s["working_set_bytes"];total+=memory;peak=Math.Max(peak,memory);webviews=Math.Max(webviews,(int)s["webview_processes"]);processes=Math.Max(processes,(int)s["process_count"]);samples++;Thread.Sleep(250);}
  long cpu=Cpu()-begin;return new Dictionary<string,object>{{"duration_ms",clock.ElapsedMilliseconds},{"cpu_percent",100.0*cpu/10000000.0/clock.Elapsed.TotalSeconds/Environment.ProcessorCount},{"cpu_denominator_logical_processors",Environment.ProcessorCount},{"average_working_set_bytes",total/samples},{"peak_working_set_bytes",peak},{"samples",samples},{"webview_processes",webviews},{"peak_process_count",processes},{"includes_exited_child_cpu",true},{"job_group_complete",true},{"target_and_engine_processes_excluded",true}};
 }
 public void Dispose(){
  if(hostFixture){TerminateJobObject(job,99);WaitForSingleObject(process,10000);CloseHandle(process);CloseHandle(job);return;}
  EnumWindows((window,p)=>{uint pid;GetWindowThreadProcessId(window,out pid);if(pid==(uint)ProcessId)PostMessage(window,0x10,IntPtr.Zero,IntPtr.Zero);return true;},IntPtr.Zero);
  if(WaitForSingleObject(process,20000)!=0){TerminateProcess(process,90);WaitForSingleObject(process,10000);}CloseHandle(process);CloseHandle(job);
 }
}
