# Windows PowerShell 5.1 uses the installed Windows UI Automation provider.
param([ValidateSet('DESKTOP_DIAGNOSTIC','DESKTOP_INPUT','DESKTOP_PREPARE','READY','KEYBOARD','DISPLAY_SCALE','DISPLAY_CONTROLLER','DISPLAY_SERVER','PICKER','EDITOR','BROWSER_WELCOME','BROWSER_DIAGNOSTIC','BROWSER_PROTOCOL','BROWSER_CHILD','BROWSER_SANDBOX','CONFIRM')][string]$Mode,[int]$ManagerPid,[string]$Coordination,[string]$ResultFile,[string]$SelectedPath,[string]$ProtocolUri,[switch]$AllowOverwrite,[string]$EnvironmentId,[string]$Intent,[string]$ExpectedBox,[ValidateSet(100,150,200)][int]$Scale=100,[switch]$CloseSettings,[string]$DisplayEvents,[switch]$PrepareInput)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$script:stage='LOADING_NATIVE_PROVIDER'
trap {
 if($ResultFile){$failure=@{status='FAILED';mode=$Mode;stage=$script:stage;exception_type=$_.Exception.GetBaseException().GetType().FullName;line=$_.InvocationInfo.ScriptLineNumber;code='P09_ACCESSIBILITY_INITIALIZATION_FAILED'};$path=if($Mode -eq 'DISPLAY_SERVER'){$ResultFile+'.initialization.json'}else{$ResultFile};$failure|ConvertTo-Json|Set-Content -LiteralPath $path -Encoding UTF8}
 exit 1
}
function Server-Status([string]$value){if($Mode -eq 'DISPLAY_SERVER'){@{status='IN_PROGRESS';mode=$Mode;stage=$value}|ConvertTo-Json|Set-Content -LiteralPath ($ResultFile+'.initialization.json') -Encoding UTF8}}
Server-Status 'LOADING_NATIVE_PROVIDER'
if($env:GITHUB_ACTIONS -ne 'true'){throw 'DISPOSABLE_ACTIONS_VM_REQUIRED'}
Add-Type -AssemblyName UIAutomationClient,UIAutomationTypes,WindowsBase,System.Windows.Forms
Add-Type @'
using System;using System.Runtime.InteropServices;
public struct P09Point { public int X,Y; }
public struct P09Rect { public int Left,Top,Right,Bottom; }
[StructLayout(LayoutKind.Sequential)] public struct P09GuiInfo { public uint Size,Flags;public IntPtr Active,Focus,Capture,MenuOwner,MoveSize,Caret;public P09Rect CaretRect; }
public static class P09Access {
 public delegate bool Visit(IntPtr hwnd,IntPtr data);
 [StructLayout(LayoutKind.Sequential)]struct KeyInput{public ushort Key,Scan;public uint Flags,Time;public UIntPtr Extra;}
 [StructLayout(LayoutKind.Sequential)]struct MouseInput{public int X,Y;public uint Data,Flags,Time;public UIntPtr Extra;}
 [StructLayout(LayoutKind.Explicit)]struct InputData{[FieldOffset(0)]public KeyInput Keyboard;[FieldOffset(0)]public MouseInput Mouse;}
 [StructLayout(LayoutKind.Sequential)]struct Input{public uint Type;public InputData Data;}
 [DllImport("user32.dll",SetLastError=true)]static extern uint SendInput(uint count,Input[] input,int size);
 [DllImport("user32.dll")]static extern uint MapVirtualKey(uint code,uint kind);
 static bool ExactForeground(IntPtr root,uint expected){return root!=IntPtr.Zero&&OwnedWindow(root,expected)&&GetAncestor(GetForegroundWindow(),2)==root;}
 static Input Key(ushort scan,uint flags){return new Input{Type=1,Data=new InputData{Keyboard=new KeyInput{Scan=scan,Flags=flags}}};}
 public static bool Chord(IntPtr root,uint expected,ushort key,ushort modifier){
  if(!ExactForeground(root,expected))return false;ushort scan=(ushort)MapVirtualKey(key,0),mod=(ushort)MapVirtualKey(modifier,0);if(scan==0||(modifier!=0&&mod==0))return false;
  Input[] keys=modifier==0?new[]{Key(scan,8),Key(scan,10)}:new[]{Key(mod,8),Key(scan,8),Key(scan,10),Key(mod,10)};int size=Marshal.SizeOf(typeof(Input));
  if(SendInput((uint)keys.Length,keys,size)==keys.Length)return true;
  Input[] release=modifier==0?new[]{Key(scan,10)}:new[]{Key(scan,10),Key(mod,10)};SendInput((uint)release.Length,release,size);return false;
 }
 public static bool TypeText(IntPtr root,uint expected,string text){
  if(!ExactForeground(root,expected)||text.Length>512||text.IndexOfAny(new[]{'\0','\r','\n'})>=0)return false;
  var keys=new Input[text.Length*2];for(int i=0;i<text.Length;i++){keys[2*i]=Key(text[i],4);keys[2*i+1]=Key(text[i],6);}int size=Marshal.SizeOf(typeof(Input));uint count=SendInput((uint)keys.Length,keys,size);
  if(count==keys.Length)return true;if((count&1)!=0){Input release=keys[count-1];release.Data.Keyboard.Flags|=2;SendInput(1,new[]{release},size);}return false;
 }
 [DllImport("user32.dll")]static extern IntPtr GetKeyboardLayout(uint thread);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]static extern short VkKeyScanEx(char value,IntPtr layout);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]static extern uint MapVirtualKeyEx(uint code,uint kind,IntPtr layout);
 public static bool TypeAscii(IntPtr root,uint expected,string text){
  if(!ExactForeground(root,expected)||text.Length>512)return false;uint ignored;IntPtr layout=GetKeyboardLayout(GetWindowThreadProcessId(root,out ignored));if(layout==IntPtr.Zero)return false;
  var keys=new System.Collections.Generic.List<Input>();ushort shift=(ushort)MapVirtualKeyEx(16,0,layout);if(shift==0)return false;
  foreach(char value in text){if(value<32||value>126)return false;short mapped=VkKeyScanEx(value,layout);if(mapped<0||((mapped>>8)&255)>1)return false;ushort scan=(ushort)MapVirtualKeyEx((uint)(mapped&255),0,layout);if(scan==0)return false;bool shifted=(mapped&256)!=0;if(shifted)keys.Add(Key(shift,8));keys.Add(Key(scan,8));keys.Add(Key(scan,10));if(shifted)keys.Add(Key(shift,10));}
  if(!ExactForeground(root,expected))return false;Input[] input=keys.ToArray();return SendInput((uint)input.Length,input,Marshal.SizeOf(typeof(Input)))==input.Length;
 }
 [DllImport("user32.dll")]public static extern bool ShowWindow(IntPtr window,int command);
 [DllImport("user32.dll")]public static extern bool GetWindowRect(IntPtr window,out P09Rect rectangle);
 [DllImport("user32.dll")]public static extern bool PrintWindow(IntPtr window,IntPtr dc,uint flags);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]static extern int GetWindowText(IntPtr window,System.Text.StringBuilder value,int count);
 public static string Caption(IntPtr window){var value=new System.Text.StringBuilder(1025);GetWindowText(window,value,value.Capacity);return value.ToString();}
 [DllImport("user32.dll")]public static extern bool IsChild(IntPtr parent,IntPtr child);
 [DllImport("user32.dll")]public static extern bool IsWindowEnabled(IntPtr window);
 [DllImport("user32.dll")]public static extern bool EnumChildWindows(IntPtr parent,Visit visit,IntPtr data);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]public static extern int GetClassName(IntPtr window,System.Text.StringBuilder name,int maximum);
 [DllImport("user32.dll")]static extern bool GetGUIThreadInfo(uint thread,ref P09GuiInfo info);
 public static bool FocusWithin(IntPtr window){uint pid;uint thread=GetWindowThreadProcessId(window,out pid);var info=new P09GuiInfo{Size=(uint)Marshal.SizeOf(typeof(P09GuiInfo))};return GetGUIThreadInfo(thread,ref info)&&(info.Focus==window||IsChild(window,info.Focus));}
 public static IntPtr Editor(IntPtr root,uint expected,string box){IntPtr found=IntPtr.Zero;long area=0;EnumChildWindows(root,delegate(IntPtr window,IntPtr data){uint pid;GetWindowThreadProcessId(window,out pid);var name=new System.Text.StringBuilder(64);GetClassName(window,name,64);P09Rect rectangle;if(pid==expected&&(String.Equals(name.ToString(),"Scintilla",StringComparison.OrdinalIgnoreCase)||String.Equals(name.ToString(),"Sandbox:"+box+":Scintilla",StringComparison.OrdinalIgnoreCase))&&IsWindowVisible(window)&&IsWindowEnabled(window)&&GetWindowRect(window,out rectangle)){long current=(long)(rectangle.Right-rectangle.Left)*(rectangle.Bottom-rectangle.Top);if(current>area){area=current;found=window;}}return true;},IntPtr.Zero);return found;}

 [DllImport("user32.dll")]public static extern int GetDlgCtrlID(IntPtr window);
 [DllImport("user32.dll")]static extern IntPtr GetParent(IntPtr window);
 [DllImport("user32.dll")]static extern IntPtr GetDlgItem(IntPtr dialog,int id);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]static extern IntPtr SendMessage(IntPtr window,uint message,IntPtr parameter,string value);
 [DllImport("user32.dll",CharSet=CharSet.Unicode,EntryPoint="SendMessageW")]static extern IntPtr ReadMessage(IntPtr window,uint message,IntPtr size,System.Text.StringBuilder value);
 [DllImport("user32.dll")]static extern bool PostMessage(IntPtr window,uint message,IntPtr parameter,IntPtr value);
 public static bool ClassIs(IntPtr window,string expected,string box){var name=new System.Text.StringBuilder(128);GetClassName(window,name,128);return String.Equals(name.ToString(),expected,StringComparison.OrdinalIgnoreCase)||(!String.IsNullOrEmpty(box)&&String.Equals(name.ToString(),"Sandbox:"+box+":"+expected,StringComparison.OrdinalIgnoreCase));}
 static bool FilenameEdit(IntPtr window,string box){return ClassIs(window,"Edit",box)||ClassIs(window,"RichEdit20W",box)||ClassIs(window,"RICHEDIT50W",box)||ClassIs(window,"RichEditD2DPT",box);}
 public static int FilenameKinds(IntPtr root,uint expected,string box){int mask=0;EnumChildWindows(root,delegate(IntPtr window,IntPtr data){if(!OwnedWindow(window,expected))return true;int id=GetDlgCtrlID(window);if(id==1152)mask|=1;if(id==1148)mask|=2;if(id==1001)mask|=4;if(FilenameEdit(window,box))mask|=8;return true;},IntPtr.Zero);return mask;}
 public static IntPtr Filename(IntPtr root,uint expected,string box){IntPtr found=IntPtr.Zero;EnumChildWindows(root,delegate(IntPtr window,IntPtr data){if(!OwnedWindow(window,expected)||!IsWindowVisible(window)||!IsWindowEnabled(window)||!FilenameEdit(window,box))return true;int id=GetDlgCtrlID(window);bool known=id==1152;IntPtr parent=GetParent(window);for(int depth=0;!known&&depth<16&&parent!=IntPtr.Zero&&parent!=root;depth++,parent=GetParent(parent))known=GetDlgCtrlID(parent)==1148;if(known){found=window;return false;}return true;},IntPtr.Zero);return found;}
 public static bool FilenameEquals(IntPtr field,string value){var read=new System.Text.StringBuilder(32768);ReadMessage(field,13,(IntPtr)read.Capacity,read);return read.ToString()==value;}
 [DllImport("kernel32.dll")]static extern uint GetCurrentThreadId();
 [DllImport("user32.dll")]static extern IntPtr GetThreadDesktop(uint thread);
 [DllImport("user32.dll")]static extern IntPtr GetProcessWindowStation();
 [DllImport("kernel32.dll")]public static extern uint WTSGetActiveConsoleSessionId();
 public static bool InteractiveStation(){uint needed;var name=new System.Text.StringBuilder(256);return GetUserObjectInformation(GetProcessWindowStation(),2,name,512,out needed)&&String.Equals(name.ToString(),"WinSta0",StringComparison.OrdinalIgnoreCase);}
 public static bool ThreadDesktopDefault(){uint needed;var name=new System.Text.StringBuilder(256);return GetUserObjectInformation(GetThreadDesktop(GetCurrentThreadId()),2,name,512,out needed)&&String.Equals(name.ToString(),"Default",StringComparison.OrdinalIgnoreCase);}
 public static bool SetFilename(IntPtr field,string value){if(value.Length>32767||value.IndexOfAny(new[]{'\0','\r','\n'})>=0)return false;if(SendMessage(field,12,IntPtr.Zero,value)==IntPtr.Zero)return false;var read=new System.Text.StringBuilder(32768);ReadMessage(field,13,(IntPtr)read.Capacity,read);return read.ToString()==value;}
 public static bool AcceptPicker(IntPtr root,uint expected,string box){IntPtr button=GetDlgItem(root,1);if(button==IntPtr.Zero)EnumChildWindows(root,delegate(IntPtr window,IntPtr data){uint owner;GetWindowThreadProcessId(window,out owner);if(OwnedWindow(window,expected)&&GetDlgCtrlID(window)==1&&IsWindowVisible(window)&&IsWindowEnabled(window)&&ClassIs(window,"Button",box)){button=window;return false;}return true;},IntPtr.Zero);uint pid;GetWindowThreadProcessId(button,out pid);return button!=IntPtr.Zero&&OwnedWindow(button,expected)&&IsChild(root,button)&&IsWindowEnabled(button)&&ClassIs(button,"Button",box)&&PostMessage(button,245,IntPtr.Zero,IntPtr.Zero);}
 [DllImport("user32.dll")]public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
 public static bool OwnedWindow(IntPtr window,uint expected){uint pid=0;GetWindowThreadProcessId(window,out pid);if(pid==expected)return true;IntPtr root=GetAncestor(window,2);if(root!=IntPtr.Zero){GetWindowThreadProcessId(root,out pid);if(pid==expected)return true;}return RootOwnerPid(window)==expected;}
 [DllImport("user32.dll")]public static extern IntPtr WindowFromPhysicalPoint(P09Point point);
 [DllImport("user32.dll")]public static extern IntPtr WindowFromPoint(P09Point point);
 [DllImport("user32.dll",EntryPoint="WindowFromPoint")]public static extern IntPtr WindowFromPackedPoint(long point);
 public static IntPtr PackedPoint(P09Point point){return WindowFromPackedPoint(unchecked((long)(((ulong)(uint)point.Y<<32)|(uint)point.X)));}
 [DllImport("dwmapi.dll")]static extern int DwmGetWindowAttribute(IntPtr window,uint attribute,out uint value,uint size);
 public static int Cloaked(IntPtr window){uint value;return DwmGetWindowAttribute(window,14,out value,4)==0?(int)value:-1;}
 [DllImport("kernel32.dll",SetLastError=true)]static extern IntPtr OpenProcess(uint access,bool inherit,uint pid);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode)]static extern bool QueryFullProcessImageName(IntPtr process,uint flags,System.Text.StringBuilder image,ref uint size);
 [DllImport("kernel32.dll")]static extern bool CloseHandle(IntPtr handle);
 [DllImport("advapi32.dll")]static extern bool OpenProcessToken(IntPtr process,uint access,out IntPtr token);
 [DllImport("kernel32.dll")]static extern bool GetProcessTimes(IntPtr process,out long created,out long exited,out long kernel,out long user);
 public static string HitBirthKey(IntPtr window){uint pid;GetWindowThreadProcessId(window,out pid);IntPtr held=OpenProcess(0x1000,false,pid);if(held==IntPtr.Zero)return null;try{long created,exited,kernel,user;return GetProcessTimes(held,out created,out exited,out kernel,out user)&&created>0?pid.ToString(System.Globalization.CultureInfo.InvariantCulture)+":"+created.ToString(System.Globalization.CultureInfo.InvariantCulture):null;}finally{CloseHandle(held);}}
 public static bool SameUser(IntPtr window){uint pid;GetWindowThreadProcessId(window,out pid);IntPtr process=OpenProcess(0x1000,false,pid);if(process==IntPtr.Zero)return false;try{IntPtr token;if(!OpenProcessToken(process,8,out token))return false;try{using(var identity=new System.Security.Principal.WindowsIdentity(token))using(var current=System.Security.Principal.WindowsIdentity.GetCurrent())return identity.User!=null&&current.User!=null&&identity.User.Value==current.User.Value;}finally{CloseHandle(token);}}finally{CloseHandle(process);}}
 public static IntPtr FocusedFilename(IntPtr root,uint expected,string box){uint pid;uint thread=GetWindowThreadProcessId(root,out pid);var info=new P09GuiInfo{Size=(uint)Marshal.SizeOf(typeof(P09GuiInfo))};return pid==expected&&GetGUIThreadInfo(thread,ref info)&&IsChild(root,info.Focus)&&OwnedWindow(info.Focus,expected)&&FilenameEdit(info.Focus,box)&&IsWindowVisible(info.Focus)&&IsWindowEnabled(info.Focus)?info.Focus:IntPtr.Zero;}
 public static int InputSize(){return Marshal.SizeOf(typeof(Input));}
 [DllImport("user32.dll")]static extern IntPtr GetTopWindow(IntPtr parent);
 [DllImport("user32.dll")]static extern IntPtr GetWindow(IntPtr window,uint relation);
 public static IntPtr[] VisibleProcessWindows(System.Collections.Generic.HashSet<int> pids,out bool complete){return ProcessWindows(pids,true,out complete);}
 public static IntPtr[] ProcessWindows(System.Collections.Generic.HashSet<int> pids,bool visibleOnly,out bool complete){
  var found=new System.Collections.Generic.List<IntPtr>();var seen=new System.Collections.Generic.HashSet<IntPtr>();IntPtr window=GetTopWindow(IntPtr.Zero);int scanned=0;
  while(window!=IntPtr.Zero&&scanned++<4096&&seen.Add(window)){uint pid;GetWindowThreadProcessId(window,out pid);if(!visibleOnly||IsWindowVisible(window)){bool owned=pids.Contains((int)pid);if(!owned)foreach(int expected in pids)if(RootOwnerPid(window)==(uint)expected){owned=true;break;}if(owned)found.Add(window);}window=GetWindow(window,2);}
  complete=window==IntPtr.Zero;IntPtr foreground=GetAncestor(GetForegroundWindow(),2);uint owner;GetWindowThreadProcessId(foreground,out owner);if(pids.Contains((int)owner)&&(!visibleOnly||IsWindowVisible(foreground))&&!found.Contains(foreground))found.Add(foreground);return found.ToArray();
 }
 [DllImport("user32.dll")]static extern bool EnumThreadWindows(uint thread,Visit visit,IntPtr data);
 public static IntPtr[] ThreadProcessWindows(System.Collections.Generic.HashSet<int> pids,out bool complete){
  var found=new System.Collections.Generic.HashSet<IntPtr>();bool all=true;
  foreach(int expected in pids){
   try{using(var process=System.Diagnostics.Process.GetProcessById(expected)){
    var threads=process.Threads;if(threads.Count>256){all=false;continue;}
    foreach(System.Diagnostics.ProcessThread thread in threads){try{EnumThreadWindows((uint)thread.Id,delegate(IntPtr window,IntPtr data){uint pid;GetWindowThreadProcessId(window,out pid);if(pid==(uint)expected)found.Add(window);return true;},IntPtr.Zero);}finally{thread.Dispose();}}
   }}catch(System.ComponentModel.Win32Exception){all=false;}catch(InvalidOperationException){all=false;}catch(ArgumentException){all=false;}
  }
  complete=all;var windows=new IntPtr[found.Count];found.CopyTo(windows);return windows;
 }
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]static extern IntPtr FindWindowEx(IntPtr parent,IntPtr after,string kind,string title);
 public static IntPtr[] ImmersiveWindows(out bool complete){
  var found=new System.Collections.Generic.HashSet<IntPtr>();bool all=true;
  foreach(string kind in new[]{"Windows.UI.Core.CoreWindow","ApplicationFrameWindow","Xaml_WindowedPopupClass","WinUIDesktopWin32WindowClass","Microsoft.UI.Content.DesktopChildSiteBridge","Windows.UI.Composition.DesktopWindowContentBridge","Shell_SystemDim"}){
   IntPtr window=IntPtr.Zero;var seen=new System.Collections.Generic.HashSet<IntPtr>();int scanned=0;
   while((window=FindWindowEx(IntPtr.Zero,window,kind,null))!=IntPtr.Zero){if(scanned++>=64||!seen.Add(window)){all=false;break;}found.Add(window);}
  }
  complete=all;var windows=new IntPtr[found.Count];found.CopyTo(windows);return windows;
 }
 [DllImport("kernel32.dll")]static extern IntPtr GetCurrentProcess();
 [DllImport("kernel32.dll")]static extern bool IsWow64Process2(IntPtr process,out ushort processMachine,out ushort nativeMachine);
 public static string MachineKinds(){ushort process,native;return IsWow64Process2(GetCurrentProcess(),out process,out native)?process.ToString("x4")+":"+native.ToString("x4"):"UNAVAILABLE";}
 public static bool CancelInitialWindow(IntPtr window){return PostMessage(window,16,IntPtr.Zero,IntPtr.Zero);}

 public static string HitImage(IntPtr window){uint pid;GetWindowThreadProcessId(window,out pid);IntPtr held=OpenProcess(0x1000,false,pid);if(held==IntPtr.Zero)return null;try{uint size=32768;var image=new System.Text.StringBuilder((int)size);return QueryFullProcessImageName(held,0,image,ref size)?image.ToString():null;}finally{CloseHandle(held);}}
 [DllImport("user32.dll")]public static extern IntPtr GetAncestor(IntPtr window,uint flags);
 [DllImport("user32.dll",SetLastError=true)]static extern IntPtr OpenInputDesktop(uint flags,bool inherit,uint access);
 [DllImport("user32.dll")]static extern bool CloseDesktop(IntPtr desktop);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]static extern bool GetUserObjectInformation(IntPtr desktop,int index,System.Text.StringBuilder value,uint size,out uint needed);
 public static int DefaultInputDesktop(){IntPtr desktop=OpenInputDesktop(0,false,1);if(desktop==IntPtr.Zero)return -1;try{uint needed;var name=new System.Text.StringBuilder(256);return GetUserObjectInformation(desktop,2,name,512,out needed)?(String.Equals(name.ToString(),"Default",StringComparison.OrdinalIgnoreCase)?1:0):-1;}finally{CloseDesktop(desktop);}}
 [DllImport("user32.dll",EntryPoint="GetWindowLongW")]public static extern int GetWindowLong(IntPtr window,int index);
 [DllImport("user32.dll")]public static extern bool SetWindowPos(IntPtr window,IntPtr after,int x,int y,int width,int height,uint flags);
 public static uint RootOwnerPid(IntPtr window){uint pid=0;IntPtr root=GetAncestor(window,3);if(root!=IntPtr.Zero)GetWindowThreadProcessId(root,out pid);return pid;}
 [DllImport("user32.dll")]public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")]public static extern void mouse_event(uint flags,uint x,uint y,uint data,UIntPtr extra);
 [DllImport("user32.dll")]public static extern bool EnumWindows(Visit visit,IntPtr data);
 [DllImport("user32.dll")]public static extern uint GetWindowThreadProcessId(IntPtr hwnd,out uint pid);
 [DllImport("user32.dll")]public static extern bool IsWindowVisible(IntPtr hwnd);
 [DllImport("user32.dll")]public static extern bool IsWindow(IntPtr hwnd);
 [DllImport("user32.dll",CharSet=CharSet.Unicode,SetLastError=true)]static extern IntPtr SendMessageTimeout(IntPtr window,uint message,IntPtr wparam,IntPtr lparam,uint flags,uint timeout,out UIntPtr result);
 public static int Responsive(IntPtr window){UIntPtr result;return SendMessageTimeout(window,0,IntPtr.Zero,IntPtr.Zero,2,500,out result)!=IntPtr.Zero?0:Marshal.GetLastWin32Error();}

 [DllImport("user32.dll")]public static extern bool IsIconic(IntPtr hwnd);
 [DllImport("user32.dll")]public static extern uint GetDpiForWindow(IntPtr hwnd);
 [DllImport("user32.dll")]public static extern bool SetForegroundWindow(IntPtr hwnd);
 [DllImport("user32.dll",SetLastError=true)]static extern bool AttachThreadInput(uint from,uint to,bool attach);
 [DllImport("user32.dll")]static extern bool BringWindowToTop(IntPtr window);
 public static bool ActivateOwned(IntPtr window,uint expected){
  if(!OwnedWindow(window,expected))return false;
  uint ignored,current=GetCurrentThreadId(),target=GetWindowThreadProcessId(window,out ignored),foreground=GetWindowThreadProcessId(GetForegroundWindow(),out ignored);bool attachedForeground=false,attachedTarget=false;
  try{
   if(foreground!=0&&foreground!=current)attachedForeground=AttachThreadInput(current,foreground,true);
   if(target!=0&&target!=current&&target!=foreground)attachedTarget=AttachThreadInput(current,target,true);
   BringWindowToTop(window);SetForegroundWindow(window);return ExactForeground(window,expected);
  }finally{if(attachedTarget)AttachThreadInput(current,target,false);if(attachedForeground)AttachThreadInput(current,foreground,false);}
 }

 [DllImport("user32.dll")]public static extern IntPtr GetForegroundWindow();
}
'@
if([P09Access]::SetThreadDpiAwarenessContext([IntPtr]::new(-4)) -eq [IntPtr]::Zero){throw 'P09_HELPER_DPI_CONTEXT_FAILED'}
$script:displayRoot=$null;$script:displayWindow=[IntPtr]::Zero;$script:raisedWindows=[Collections.Generic.List[IntPtr]]::new()
$result=@{status='IN_PROGRESS';mode=$Mode;real_windows_uia=$true;synthetic_fixture_only=$true;helper_per_monitor_dpi_aware=$true;default_input_desktop=[P09Access]::DefaultInputDesktop()};$stage='INITIALIZED'
function Need([bool]$ok){if(-not $ok){throw 'P09_NATIVE_ACCESSIBILITY_FAILED'}}
function Known-PickerTitle([string]$title){
 if($title.StartsWith('[#] ') -and $title.EndsWith(' [#]')){$title=$title.Substring(4,$title.Length-8)}
 return ($title -in @('SecureRun resource selection','SecureRun file selection','Save reviewed diagnostics','Save As','Save as','Save File','Выбор ресурса SecureRun','Сохранить просмотренную диагностику'))
}
function Window([int]$id,[bool]$dialog=$false){
 $script:found=[IntPtr]::Zero;$script:foundArea=0;$complete=$false;$ids=[Collections.Generic.HashSet[int]]::new();$null=$ids.Add($id)
 $windows=@([P09Access]::VisibleProcessWindows($ids,[ref]$complete));Need $complete
 $script:ownedCandidateWindows=[Collections.Generic.List[IntPtr]]::new();foreach($candidate in $windows){$script:ownedCandidateWindows.Add($candidate)}
 # Include actual modal windows owned by the target, including OS broker windows.
 $null=[P09Access]::EnumWindows({param($hwnd,$data);if([P09Access]::IsWindowVisible($hwnd) -and [P09Access]::OwnedWindow($hwnd,$id)){$script:ownedCandidateWindows.Add($hwnd)};return $true},[IntPtr]::Zero)
 $windows=@($script:ownedCandidateWindows|Select-Object -Unique)
 foreach($hwnd in $windows){
  $caption=[P09Access]::Caption($hwnd);$isDialog=([P09Access]::ClassIs($hwnd,'#32770',$ExpectedBox) -or (Known-PickerTitle $caption))
  if($dialog -and $isDialog -and [P09Access]::IsWindowEnabled($hwnd)){return $hwnd}
  if(-not $dialog -and -not $isDialog -and $Mode.StartsWith('BROWSER_') -and ([P09Access]::GetWindowLong($hwnd,-16) -band 0x00c00000) -ne 0x00c00000){continue}
  if(-not $dialog -and -not $isDialog){$rectangle=[P09Rect]::new();if(-not [P09Access]::GetWindowRect($hwnd,[ref]$rectangle)){continue};$area=([long]$rectangle.Right-$rectangle.Left)*($rectangle.Bottom-$rectangle.Top);if($area -gt $script:foundArea){$script:found=$hwnd;$script:foundArea=$area}}
 }
 if($dialog){$result.picker_owned_visible_window_count=$windows.Count}
 return $script:found
}
function In-Provider($element,$ancestor){
 for($depth=0;$depth -lt 64 -and $null -ne $element;$depth++){
  if([Windows.Automation.Automation]::Compare($element,$ancestor)){return $true}
  $element=[Windows.Automation.TreeWalker]::ControlViewWalker.GetParent($element)
 }
 return $false
}
function Find($root,$type,[string]$name){
 $condition=[Windows.Automation.AndCondition]::new([Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::ControlTypeProperty,$type),[Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::NameProperty,$name))
 return $root.FindFirst([Windows.Automation.TreeScope]::Descendants,$condition)
}
function Native-HitKind([IntPtr]$window){
 $owner=0;$null=[P09Access]::GetWindowThreadProcessId($window,[ref]$owner);if($owner -eq 0){return 'UNKNOWN'}
 try{$process=[Diagnostics.Process]::GetProcessById($owner);try{
  switch($process.ProcessName.ToLowerInvariant()){
   'msedgewebview2'{return 'WEBVIEW_RUNTIME'};'securerun'{return 'MANAGER_BINARY'};'firefox'{return 'BROWSER'};'notepad++'{return 'EDITOR'}
   'systemsettings'{return 'DISPLAY_SETTINGS'};'applicationframehost'{return 'APPLICATION_FRAME_HOST'};'textinputhost'{return 'TEXT_INPUT_HOST'}
   'explorer'{return 'DESKTOP_SHELL'};'shellexperiencehost'{return 'DESKTOP_SHELL'};'dwm'{return 'DESKTOP_COMPOSITOR'}
   'powershell'{return 'POWERSHELL_HOST'};'pwsh'{return 'POWERSHELL_HOST'};'conhost'{return 'CONSOLE_HOST'};'windowsterminal'{return 'TERMINAL_HOST'}
   'werfault'{return 'ERROR_REPORTER'};'logonui'{return 'WINDOWS_LOGON_UI'};'lockapp'{return 'WINDOWS_LOCK_UI'};'sandman'{return 'ORIGINAL_ENGINE_UI'};'sbiectrl'{return 'ORIGINAL_ENGINE_UI'};'runner.worker'{return 'ACTIONS_RUNNER'};'runner.listener'{return 'ACTIONS_RUNNER'};'openconsole'{return 'CONSOLE_HOST'};'cmd'{return 'COMMAND_HOST'};'runtimebroker'{return 'WINDOWS_APP_BROKER'};'pickerhost'{return 'WINDOWS_PICKER_HOST'};'wwahost'{return 'WINDOWS_WEB_APP_HOST'};'startmenuexperiencehost'{return 'WINDOWS_START_MENU'};'searchhost'{return 'WINDOWS_SEARCH'};default{
    $nativeName=$process.ProcessName.ToLowerInvariant();$hash=[Security.Cryptography.SHA256]::Create();try{$result.native_hit_name_sha256=([BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($nativeName)))).Replace('-','').ToLowerInvariant()}finally{$hash.Dispose()}
    $image=[P09Access]::HitImage($window);$windows=[Environment]::GetFolderPath([Environment+SpecialFolder]::Windows)
    if($image -and ($image.StartsWith($windows+'\System32\',[StringComparison]::OrdinalIgnoreCase) -or $image.StartsWith($windows+'\SysWOW64\',[StringComparison]::OrdinalIgnoreCase) -or $image.StartsWith($windows+'\SystemApps\',[StringComparison]::OrdinalIgnoreCase))){
     $signature=Get-AuthenticodeSignature -LiteralPath $image
     if($signature.Status -eq 'Valid' -and $null -ne $signature.SignerCertificate -and $signature.SignerCertificate.Subject -match '(?:^|,\s*)O=Microsoft Corporation(?:,|$)'){$result.native_hit_microsoft_system_component=[IO.Path]::GetFileName($image);return 'SIGNED_MICROSOFT_SYSTEM_COMPONENT'}
    }
    return 'OTHER_WITHHELD'
   }
  }
 }finally{$process.Dispose()}}catch{return 'UNAVAILABLE'}
}
$result.native_machine_kinds=[P09Access]::MachineKinds();$result.powershell_major=$PSVersionTable.PSVersion.Major;try{$null=[ushort]1;$result.ushort_alias_available=$true}catch{$result.ushort_alias_available=$false}
$result.helper_interactive_station=[P09Access]::InteractiveStation();$result.helper_thread_desktop_default=[P09Access]::ThreadDesktopDefault();$result.helper_session_zero=([Diagnostics.Process]::GetCurrentProcess().SessionId -eq 0);$result.helper_active_console_session=([Diagnostics.Process]::GetCurrentProcess().SessionId -eq [P09Access]::WTSGetActiveConsoleSessionId())
$script:enrolledInitialPickers=[Collections.Generic.HashSet[string]]::new()
function Prepare-InitialDesktopPass{
 $result=@{mode='DESKTOP_PREPARE';real_windows_uia=$true;synthetic_fixture_only=$true;default_input_desktop=[P09Access]::DefaultInputDesktop();helper_interactive_station=[P09Access]::InteractiveStation();helper_thread_desktop_default=[P09Access]::ThreadDesktopDefault();helper_session_zero=([Diagnostics.Process]::GetCurrentProcess().SessionId -eq 0);helper_active_console_session=([Diagnostics.Process]::GetCurrentProcess().SessionId -eq [P09Access]::WTSGetActiveConsoleSessionId())}
 $script:stage='PREPARING_INITIAL_CI_DESKTOP';$result.process_termination_dispatched=$false;$result.os_security_settings_modified=$false;$result.initial_picker_cancelled=$false;$result.cancelled_window_count=0
 try{
  Need ($env:GITHUB_ACTIONS -eq 'true' -and $ManagerPid -eq 0 -and $result.default_input_desktop -ne 0)
  $noProductProcesses=(@(Get-Process -Name securerun,firefox,notepad++ -ErrorAction SilentlyContinue).Count -eq 0);$result.product_process_present=(-not $noProductProcesses)
  $script:initialPickers=[Collections.Generic.List[IntPtr]]::new();$script:initialPickerIds=[Collections.Generic.HashSet[int]]::new();$result.fixed_candidate_process_counts=@{};foreach($fixed in @('PickerHost','WWAHost','StartMenuExperienceHost','SearchHost')){$result.fixed_candidate_process_counts[$fixed]=@(Get-Process -Name $fixed -ErrorAction SilentlyContinue).Count}
  foreach($candidate in @(Get-Process -Name PickerHost,WWAHost,StartMenuExperienceHost,SearchHost -ErrorAction SilentlyContinue)){try{$null=$script:initialPickerIds.Add($candidate.Id)}finally{$candidate.Dispose()}}
  $null=[P09Access]::EnumWindows({param($window,$data);$owner=0;$null=[P09Access]::GetWindowThreadProcessId($window,[ref]$owner);if($script:initialPickerIds.Contains($owner) -and [P09Access]::IsWindowVisible($window)){$script:initialPickers.Add($window)};return $true},[IntPtr]::Zero)
  $script:pickerChildren=0;$script:visiblePickerChildren=0;$script:pickerTopLevels=0;$script:scannedChildren=0
  $null=[P09Access]::EnumWindows({param($top,$data);$owner=0;$null=[P09Access]::GetWindowThreadProcessId($top,[ref]$owner);if($script:initialPickerIds.Contains($owner)){$script:pickerTopLevels++};$null=[P09Access]::EnumChildWindows($top,{param($child,$data);$script:scannedChildren++;if($script:scannedChildren -gt 8192){return $false};$owner=0;$null=[P09Access]::GetWindowThreadProcessId($child,[ref]$owner);if($script:initialPickerIds.Contains($owner)){$script:pickerChildren++;if([P09Access]::IsWindowVisible($child)){$script:visiblePickerChildren++}};return $true},[IntPtr]::Zero);return ($script:scannedChildren -le 8192)},[IntPtr]::Zero)
  $result.picker_all_top_level_windows=$script:pickerTopLevels;$result.picker_child_windows=$script:pickerChildren;$result.picker_visible_child_windows=$script:visiblePickerChildren;$result.picker_child_enumeration_complete=($script:scannedChildren -le 8192);$result.controller_foreground_kind=Native-HitKind ([P09Access]::GetForegroundWindow())
  $zComplete=$false;$zWindows=@([P09Access]::ProcessWindows($script:initialPickerIds,(-not $noProductProcesses),[ref]$zComplete));$result.picker_z_order_enumeration_complete=$zComplete;Need $zComplete
  foreach($candidateWindow in $zWindows){$candidateOwner=0;$null=[P09Access]::GetWindowThreadProcessId($candidateWindow,[ref]$candidateOwner);if($script:initialPickerIds.Contains($candidateOwner) -and -not $script:initialPickers.Contains($candidateWindow)){$script:initialPickers.Add($candidateWindow)}}
  # EnumWindows on Windows 8+ omits some immersive app surfaces. Query only
  # threads belonging to the fixed candidate process names, then apply the
  # unchanged user, image, signature and creation-time checks before any action.
  $threadComplete=$false;$threadWindows=@([P09Access]::ThreadProcessWindows($script:initialPickerIds,[ref]$threadComplete));$result.initial_thread_window_query_complete=$threadComplete;$result.initial_thread_windows=$threadWindows.Count
  foreach($candidateWindow in $threadWindows){if(($noProductProcesses -or [P09Access]::IsWindowVisible($candidateWindow)) -and -not $script:initialPickers.Contains($candidateWindow)){$script:initialPickers.Add($candidateWindow)}}
  $immersiveComplete=$false;$immersiveWindows=@([P09Access]::ImmersiveWindows([ref]$immersiveComplete));$result.initial_immersive_query_complete=$immersiveComplete;$result.initial_immersive_windows=$immersiveWindows.Count;Need $immersiveComplete
  foreach($candidateWindow in $immersiveWindows){
   $candidateImage=[P09Access]::HitImage($candidateWindow)
   if($candidateImage -and [IO.Path]::GetFileName($candidateImage) -iin @('PickerHost.exe','WWAHost.exe','StartMenuExperienceHost.exe','SearchHost.exe') -and ($noProductProcesses -or [P09Access]::IsWindowVisible($candidateWindow)) -and -not $script:initialPickers.Contains($candidateWindow)){$script:initialPickers.Add($candidateWindow)}
  }
  $result.picker_z_order_visible_windows=@($zWindows|Where-Object {[P09Access]::IsWindowVisible($_)}).Count;$result.initial_component_windows=$script:initialPickers.Count;Need ($script:initialPickers.Count -le 32)
  $result.initial_picker_window_count=$script:initialPickers.Count
  $result.cancelled_window_count=0
  foreach($window in $script:initialPickers){
   if(-not [P09Access]::IsWindow($window)){continue};$result.preparation_stage='WINDOW_OWNER'
   if(-not [P09Access]::IsWindowVisible($window) -and -not ($noProductProcesses -and $Mode -eq 'DISPLAY_SERVER')){continue}
   $result.same_user=[P09Access]::SameUser($window);Need $result.same_user;$result.preparation_stage='PROCESS_BIRTH'
   $birthKey=[P09Access]::HitBirthKey($window);Need (-not [string]::IsNullOrEmpty($birthKey))
   $enrolled=($Mode -eq 'DISPLAY_SERVER' -and $script:enrolledInitialPickers.Contains($birthKey));$result.enrolled_initial_process=$enrolled
   Need ($noProductProcesses -or $enrolled)
   $result.preparation_stage='IMAGE_TRUST';$image=[P09Access]::HitImage($window);Need ($image -and [IO.Path]::GetFileName($image) -iin @('PickerHost.exe','WWAHost.exe','StartMenuExperienceHost.exe','SearchHost.exe'))
   $windows=[Environment]::GetFolderPath([Environment+SpecialFolder]::Windows);$programs=[Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFiles)
   $protected=$image.StartsWith($windows+'\SystemApps\',[StringComparison]::OrdinalIgnoreCase) -or $image.StartsWith($windows+'\System32\',[StringComparison]::OrdinalIgnoreCase) -or $image.StartsWith($programs+'\WindowsApps\',[StringComparison]::OrdinalIgnoreCase)
   Need $protected;$trusted=$false;$signature=Get-AuthenticodeSignature -LiteralPath $image
   if($signature.Status -eq 'Valid' -and $null -ne $signature.SignerCertificate -and $signature.SignerCertificate.Subject -match '(?:^|,\s*)O=Microsoft Corporation(?:,|$)'){$trusted=$true}
   if(-not $trusted){foreach($package in @(Get-AppxPackage -ErrorAction Stop)){if($package.InstallLocation -and $image.StartsWith($package.InstallLocation+'\',[StringComparison]::OrdinalIgnoreCase) -and $package.SignatureKind -eq 'System' -and $package.Status -eq 'Ok' -and $package.Publisher -match '(?:^|,\s*)O=Microsoft Corporation(?:,|$)'){$trusted=$true;break}}}
   $result.authenticated_windows_component=$trusted;Need $trusted;Need ([P09Access]::HitBirthKey($window) -ceq $birthKey)
   if($noProductProcesses -and $Mode -eq 'DISPLAY_SERVER'){$null=$script:enrolledInitialPickers.Add($birthKey)}
   if(-not [P09Access]::IsWindowVisible($window)){continue}
   $result.preparation_stage='VISIBLE_ROOT_OWNER';Need ([P09Access]::SameUser([P09Access]::GetAncestor($window,3)))
   if([IO.Path]::GetFileName($image) -iin @('StartMenuExperienceHost.exe','SearchHost.exe') -or [P09Access]::ClassIs($window,'Shell_SystemDim',$null)){
    Need ([P09Access]::SameUser($window) -and [P09Access]::HitBirthKey($window) -ceq $birthKey);$null=[P09Access]::ShowWindow($window,0);$clock=[Diagnostics.Stopwatch]::StartNew()
    while([P09Access]::IsWindowVisible($window) -and $clock.ElapsedMilliseconds -lt 5000){Start-Sleep -Milliseconds 50}
    Need (-not [P09Access]::IsWindowVisible($window));$result.close_mechanism='SCOPED_INITIAL_SHELL_WINDOW_HIDE';$result.initial_picker_cancelled=$true;$result.cancelled_window_count++;continue
   }
   $result.preparation_stage='CLOSE_AND_INVISIBILITY';$element=[Windows.Automation.AutomationElement]::FromHandle($window);$pattern=$null;$closeDispatched=$false
   if($element.TryGetCurrentPattern([Windows.Automation.WindowPattern]::Pattern,[ref]$pattern)){
    try{$pattern.Close();$closeDispatched=$true;$result.close_mechanism='UIA_WINDOW_CLOSE'}
    catch{$cause=$_.Exception.GetBaseException();if($cause -isnot [NotImplementedException] -and $cause -isnot [NotSupportedException]){throw};$result.uia_close_not_implemented=$true}
   }
   if(-not $closeDispatched){Need ([P09Access]::SameUser($window) -and [P09Access]::HitBirthKey($window) -ceq $birthKey);Need ([P09Access]::CancelInitialWindow($window));$result.close_mechanism='SCOPED_WM_CLOSE'}
   $clock=[Diagnostics.Stopwatch]::StartNew();while([P09Access]::IsWindowVisible($window) -and $clock.ElapsedMilliseconds -lt 5000){Start-Sleep -Milliseconds 50}
   if([P09Access]::IsWindowVisible($window)){
    Need ([P09Access]::SameUser($window) -and [P09Access]::HitBirthKey($window) -ceq $birthKey);Need ([P09Access]::CancelInitialWindow($window));$result.uia_close_returned_without_closing=$true;$result.close_mechanism='SCOPED_WM_CLOSE_AFTER_UIA_NOOP';$clock.Restart()
    while([P09Access]::IsWindowVisible($window) -and $clock.ElapsedMilliseconds -lt 5000){Start-Sleep -Milliseconds 50}
   }
   Need (-not [P09Access]::IsWindowVisible($window));$result.initial_picker_cancelled=$true;$result.cancelled_window_count++
  }
  foreach($candidateWindow in $script:initialPickers){Need (-not [P09Access]::IsWindowVisible($candidateWindow))}
  $result.status='OBSERVED'
 }catch{$result.status='BLOCKED';$result.code='P09_INITIAL_DESKTOP_PREPARATION_FAILED';$result.failure_line=$_.InvocationInfo.ScriptLineNumber;$kind=$_.FullyQualifiedErrorId.Split(',')[0];$result.error_record_kind=if($kind -cmatch '^[A-Za-z][A-Za-z0-9_.]{0,100}$'){$kind}else{'WITHHELD'}}
 return $result
}
function Prepare-InitialDesktop{
 $passes=[Collections.Generic.List[object]]::new();$cancelled=0
 for($attempt=0;$attempt -lt 4;$attempt++){
  $pass=Prepare-InitialDesktopPass;$passes.Add($pass.Clone());$cancelled+=[int]$pass.cancelled_window_count
  if($pass.status -ne 'OBSERVED' -or $pass.cancelled_window_count -eq 0){
   $pass.preparation_passes=$passes.ToArray();$pass.cancelled_window_count=$cancelled;$pass.initial_picker_cancelled=($cancelled -gt 0);return $pass
  }
  # Closing an initial shell surface may reveal another already running one.
  # Re-enumerate before product startup, with all original identity/trust checks.
  Start-Sleep -Milliseconds 250
 }
 $pass.status='BLOCKED';$pass.code='P09_INITIAL_DESKTOP_DID_NOT_SETTLE';$pass.preparation_passes=$passes.ToArray();$pass.cancelled_window_count=$cancelled;return $pass
}
if($Mode -eq 'DESKTOP_PREPARE'){$result=Prepare-InitialDesktop;$result|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $ResultFile -Encoding UTF8;if($result.status -ne 'OBSERVED'){exit 1};exit 0}
if($Mode -eq 'DESKTOP_INPUT'){
 $form=$null;$script:initialPickers=[Collections.Generic.List[IntPtr]]::new()
 try{
  if($PrepareInput){$preparation=Prepare-InitialDesktop;$preparation|ConvertTo-Json -Depth 5|Set-Content -LiteralPath ($ResultFile+'.preparation.json') -Encoding UTF8;Need ($preparation.status -eq 'OBSERVED');$result.initial_preparation_observed=$true}
  $form=[Windows.Forms.Form]::new();$form.Text='SecureRun synthetic native input probe';$form.StartPosition='CenterScreen';$form.Width=640;$form.Height=480;$form.TopMost=$true
  $field=[Windows.Forms.TextBox]::new();$field.Left=40;$field.Top=60;$field.Width=400;$form.Controls.Add($field);$form.Show();[Windows.Forms.Application]::DoEvents();Start-Sleep -Milliseconds 300
  if($PrepareInput){$revealed=Prepare-InitialDesktop;$revealed|ConvertTo-Json -Depth 5|Set-Content -LiteralPath ($ResultFile+'.revealed.json') -Encoding UTF8;Need ($revealed.status -eq 'OBSERVED')}
  $root=$form.Handle;$result.owned_activation_accepted=[P09Access]::ActivateOwned($root,[Diagnostics.Process]::GetCurrentProcess().Id);$field.Focus()|Out-Null;[Windows.Forms.Application]::DoEvents()
  $rect=[P09Rect]::new();Need ([P09Access]::GetWindowRect($field.Handle,[ref]$rect));$point=[P09Point]::new();$point.X=[int](($rect.Left+$rect.Right)/2);$point.Y=[int](($rect.Top+$rect.Bottom)/2)
  $hit=[P09Access]::WindowFromPoint($point);$packed=[P09Access]::PackedPoint($point);$expected=[Diagnostics.Process]::GetCurrentProcess().Id
  $result.struct_point_owned=[P09Access]::OwnedWindow($hit,$expected);$result.packed_point_owned=[P09Access]::OwnedWindow($packed,$expected);$result.point_apis_agree=($hit -eq $packed);$result.struct_point_kind=Native-HitKind $hit;$result.packed_point_kind=Native-HitKind $packed;$result.struct_root_cloaked=[P09Access]::Cloaked([P09Access]::GetAncestor($hit,2));$result.packed_root_cloaked=[P09Access]::Cloaked([P09Access]::GetAncestor($packed,2));$result.foreground_owned=[P09Access]::OwnedWindow([P09Access]::GetForegroundWindow(),$expected)
  $hitRoot=[P09Access]::GetAncestor($hit,2);$hitRect=[P09Rect]::new();$result.hit_root_iconic=[P09Access]::IsIconic($hitRoot);$result.hit_is_prepared_window=$script:initialPickers.Contains($hit);$result.hit_root_is_prepared_window=$script:initialPickers.Contains($hitRoot)
  $class=[Text.StringBuilder]::new(128);$null=[P09Access]::GetClassName($hitRoot,$class,128);$result.hit_root_class=if($result.struct_point_kind -in @('WINDOWS_START_MENU','WINDOWS_SEARCH','WINDOWS_WEB_APP_HOST','WINDOWS_PICKER_HOST') -and $class.ToString() -cmatch '^[A-Za-z0-9_.#:-]{1,128}$'){$class.ToString()}else{'WITHHELD'}
  if([P09Access]::GetWindowRect($hitRoot,[ref]$hitRect)){$result.hit_root_contains_test_point=($point.X -ge $hitRect.Left -and $point.X -lt $hitRect.Right -and $point.Y -ge $hitRect.Top -and $point.Y -lt $hitRect.Bottom);$result.hit_root_width=$hitRect.Right-$hitRect.Left;$result.hit_root_height=$hitRect.Bottom-$hitRect.Top}
  $provider=[Windows.Automation.AutomationElement]::FromPoint([Windows.Point]::new($point.X,$point.Y));$result.uia_point_owned=($provider.Current.ProcessId -eq $expected)
  $result.status='OBSERVED';$result.product_acceptance_claimed=$false;$result.input_dispatched=$false;$result.os_security_settings_modified=$false
  if($result.struct_point_owned -and -not $result.foreground_owned){
   Need ([P09Access]::SetCursorPos($point.X,$point.Y));try{[P09Access]::mouse_event(2,0,0,0,[UIntPtr]::Zero)}finally{[P09Access]::mouse_event(4,0,0,0,[UIntPtr]::Zero)}
   $focusClock=[Diagnostics.Stopwatch]::StartNew();do{[Windows.Forms.Application]::DoEvents();if([P09Access]::OwnedWindow([P09Access]::GetForegroundWindow(),$expected)){break};Start-Sleep -Milliseconds 50}while($focusClock.ElapsedMilliseconds -lt 5000);$result.foreground_owned=[P09Access]::OwnedWindow([P09Access]::GetForegroundWindow(),$expected)
  }
  if($result.struct_point_owned -and $result.foreground_owned){
   Need ([P09Access]::Chord($root,$expected,[uint16]65,[uint16]17));Need ([P09Access]::TypeText($root,$expected,'P09_NATIVE_INPUT_CANARY'));$result.input_dispatched=$true;$clock=[Diagnostics.Stopwatch]::StartNew()
   do{[Windows.Forms.Application]::DoEvents();if($field.Text -ceq 'P09_NATIVE_INPUT_CANARY'){break};Start-Sleep -Milliseconds 25}while($clock.ElapsedMilliseconds -lt 5000)
   $result.native_keyboard_text_matched=($field.Text -ceq 'P09_NATIVE_INPUT_CANARY')
  }

 }catch{$result.status='FAILED';$result.exception_type=$_.Exception.GetBaseException().GetType().FullName}
 finally{if($null -ne $form){$form.Close();$form.Dispose()}}
 $result|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $ResultFile -Encoding UTF8;if($result.status -ne 'OBSERVED'){exit 1};exit 0
}
if($Mode -eq 'DESKTOP_DIAGNOSTIC'){$result.status='OBSERVED';$result.foreground_kind=Native-HitKind ([P09Access]::GetForegroundWindow());$result.os_security_settings_modified=$false;$result|ConvertTo-Json|Set-Content -LiteralPath $ResultFile -Encoding UTF8;exit 0}
function Observe-NativePoint([IntPtr]$hit,[IntPtr]$target){
 $top=[P09Access]::GetAncestor($hit,2);$foreground=[P09Access]::GetAncestor([P09Access]::GetForegroundWindow(),2)
 $result.native_hit_is_root=($hit -eq $top);$result.native_hit_visible=[P09Access]::IsWindowVisible($hit);$result.native_hit_root_visible=[P09Access]::IsWindowVisible($top)
 $result.native_hit_root_kind=Native-HitKind $top;$result.native_hit_root_owner_kind=Native-HitKind ([P09Access]::GetAncestor($hit,3));$result.native_foreground_kind=Native-HitKind $foreground
 $result.native_foreground_is_target=($foreground -eq $target);$result.native_hit_root_is_target=($top -eq $target);$result.native_hit_root_is_foreground=($top -eq $foreground)
 $class=[Text.StringBuilder]::new(128);$null=[P09Access]::GetClassName($hit,$class,128)
 $known=@('ApplicationFrameWindow','Windows.UI.Core.CoreWindow','Progman','WorkerW','Xaml_WindowedPopupClass','#32770','Chrome_WidgetWin_0','Chrome_WidgetWin_1','Chrome_RenderWidgetHostHWND')
 $result.native_hit_class=if($class.ToString() -cin $known){$class.ToString()}else{'WITHHELD'}
 $rootClass=[Text.StringBuilder]::new(129);$null=[P09Access]::GetClassName($top,$rootClass,129);$fixedShell=($result.native_hit_root_kind -in @('WINDOWS_PICKER_HOST','WINDOWS_WEB_APP_HOST','WINDOWS_START_MENU','WINDOWS_SEARCH'));$result.native_hit_root_class=if($fixedShell -and $rootClass.ToString() -cmatch '^[A-Za-z0-9_.#:-]{1,128}$'){$rootClass.ToString()}else{'WITHHELD'};$result.native_hit_root_same_user=[P09Access]::SameUser($top)
}
function Send-LiteralKeys([string]$value){
 Need ($value.Length -le 1024 -and $value.IndexOfAny([char[]]@([char]0,[char]10,[char]13)) -lt 0)
 $escaped=[regex]::Replace($value,'[+^%~(){}]',{param($match);'{'+$match.Value+'}'})
 [Windows.Forms.SendKeys]::SendWait($escaped)
}
function Request-EnrolledPickerCancellation{
 $prefix=$env:SECURERUN_P09_DISPLAY_EVENTS;Need ($prefix -cmatch '^Local\\SecureRunP09Display-[0-9a-f]{32}$')
 $request=$null;$done=$null;$failed=$null
 try{$rights=[Security.AccessControl.EventWaitHandleRights]::Synchronize -bor [Security.AccessControl.EventWaitHandleRights]::Modify;$request=[Threading.EventWaitHandle]::OpenExisting($prefix+'-prepare',$rights);$done=[Threading.EventWaitHandle]::OpenExisting($prefix+'-done',$rights);$failed=[Threading.EventWaitHandle]::OpenExisting($prefix+'-failed',$rights);$null=$request.Set();Need ([Threading.WaitHandle]::WaitAny([Threading.WaitHandle[]]@($done,$failed),15000) -eq 0);$result.enrolled_initial_picker_cancellation_acknowledged=$true}
 finally{foreach($event in @($request,$done,$failed)){if($null -ne $event){$event.Dispose()}}}
}
function Owned-Point($point,[IntPtr]$target,[int]$id){
 $hit=[P09Access]::WindowFromPoint($point)
 if(-not ([P09Access]::OwnedWindow($hit,$id) -and [P09Access]::GetAncestor($hit,2) -eq $target) -and (Native-HitKind $hit) -in @('WINDOWS_PICKER_HOST','WINDOWS_WEB_APP_HOST','WINDOWS_START_MENU','WINDOWS_SEARCH')){
  Request-EnrolledPickerCancellation;$result.owned_activation_accepted=[P09Access]::ActivateOwned($target,$id);$clock=[Diagnostics.Stopwatch]::StartNew()
  do{$hit=[P09Access]::WindowFromPoint($point);if([P09Access]::OwnedWindow($hit,$id) -and [P09Access]::GetAncestor($hit,2) -eq $target){break};Start-Sleep -Milliseconds 50}while($clock.ElapsedMilliseconds -lt 5000)
 }
 Observe-NativePoint $hit $target;$result.native_hit_root_cloaked=[P09Access]::Cloaked([P09Access]::GetAncestor($hit,2));$result.native_packed_point_agrees=($hit -eq [P09Access]::PackedPoint($point))
 Need ([P09Access]::OwnedWindow($hit,$id) -and [P09Access]::GetAncestor($hit,2) -eq $target)
 return $hit
}
function Focus-OwnedWindow([IntPtr]$hwnd,[int]$id){
 Need ([P09Access]::OwnedWindow($hwnd,$id))
 # Only this exact owned fixture window is raised. Keep it above unrelated
 # desktop overlays during the action, then restore its original z-order band.
 if(([P09Access]::GetWindowLong($hwnd,-20) -band 8) -eq 0){Need ([P09Access]::SetWindowPos($hwnd,[IntPtr]::new(-1),0,0,0,0,0x13));$script:raisedWindows.Add($hwnd);$result.owned_window_temporarily_raised=$true}
 $null=[P09Access]::ShowWindow($hwnd,9);Need ([P09Access]::SetWindowPos($hwnd,[IntPtr]::new(-1),0,0,0,0,0x13));$result.owned_activation_accepted=[P09Access]::ActivateOwned($hwnd,$id)
 if(-not ([P09Access]::OwnedWindow([P09Access]::GetForegroundWindow(),$id) -and [P09Access]::GetAncestor([P09Access]::GetForegroundWindow(),2) -eq $hwnd)){
  $bounds=[P09Rect]::new();Need ([P09Access]::GetWindowRect($hwnd,[ref]$bounds));$point=[P09Point]::new();$point.X=[int](($bounds.Left+$bounds.Right)/2);$point.Y=$bounds.Top+12
  $visible=[Diagnostics.Stopwatch]::StartNew();do{$hit=[P09Access]::WindowFromPoint($point);if([P09Access]::OwnedWindow($hit,$id) -and [P09Access]::GetAncestor($hit,2) -eq $hwnd){break};Start-Sleep -Milliseconds 50}while($visible.ElapsedMilliseconds -lt 5000)
  if((Native-HitKind $hit) -in @('WINDOWS_PICKER_HOST','WINDOWS_WEB_APP_HOST','WINDOWS_START_MENU','WINDOWS_SEARCH')){
   # Only the controller's independently enrolled, same-user initial process
   # may be cancelled. No target/product dialog is enrolled after GUI startup.
   Request-EnrolledPickerCancellation
   $result.owned_activation_accepted=[P09Access]::ActivateOwned($hwnd,$id);$visible.Restart()
   do{$hit=[P09Access]::WindowFromPoint($point);if([P09Access]::OwnedWindow($hit,$id) -and [P09Access]::GetAncestor($hit,2) -eq $hwnd){break};Start-Sleep -Milliseconds 50}while($visible.ElapsedMilliseconds -lt 5000)
  }
  Observe-NativePoint $hit $hwnd
  $result.focus_native_hit_kind=Native-HitKind $hit
  $result.native_point_api_agree=($hit -eq [P09Access]::WindowFromPhysicalPoint($point))
  Need ([P09Access]::OwnedWindow($hit,$id) -and [P09Access]::GetAncestor($hit,2) -eq $hwnd);Need ([P09Access]::SetCursorPos($point.X,$point.Y))
  try{[P09Access]::mouse_event(2,0,0,0,[UIntPtr]::Zero)}finally{[P09Access]::mouse_event(4,0,0,0,[UIntPtr]::Zero)}
 }
 $clock=[Diagnostics.Stopwatch]::StartNew();do{if([P09Access]::OwnedWindow([P09Access]::GetForegroundWindow(),$id) -and [P09Access]::GetAncestor([P09Access]::GetForegroundWindow(),2) -eq $hwnd){return};Start-Sleep -Milliseconds 50}while($clock.ElapsedMilliseconds -lt 5000)
 Need $false
}
function Focus-NativeEditor([IntPtr]$hwnd,[int]$id){
 $script:stage='WAITING_FOR_NATIVE_EDITOR_CONTROL';Need ($ExpectedBox -cmatch '^SR_[0-9a-f]{32}$');Focus-OwnedWindow $hwnd $id;$clock=[Diagnostics.Stopwatch]::StartNew();$editor=[IntPtr]::Zero
 do{$editor=[P09Access]::Editor($hwnd,$id,$ExpectedBox);if($editor -ne [IntPtr]::Zero){break};Start-Sleep -Milliseconds 100}while($clock.ElapsedMilliseconds -lt 15000)
 Need ($editor -ne [IntPtr]::Zero -and [P09Access]::IsChild($hwnd,$editor));$result.native_editor_class_verified=$true
 $bounds=[P09Rect]::new();Need ([P09Access]::GetWindowRect($editor,[ref]$bounds));$point=[P09Point]::new();$point.X=[int](($bounds.Left+$bounds.Right)/2);$point.Y=[int](($bounds.Top+$bounds.Bottom)/2)
 $script:stage='VERIFYING_NATIVE_EDITOR_CLICK_POINT';$hit=Owned-Point $point $hwnd $id;Need ($hit -eq $editor -or [P09Access]::IsChild($editor,$hit));Need ([P09Access]::SetCursorPos($point.X,$point.Y))
 try{[P09Access]::mouse_event(2,0,0,0,[UIntPtr]::Zero)}finally{[P09Access]::mouse_event(4,0,0,0,[UIntPtr]::Zero)}
 $clock.Restart();do{if([P09Access]::FocusWithin($editor)){break};Start-Sleep -Milliseconds 50}while($clock.ElapsedMilliseconds -lt 5000)
 Need ([P09Access]::OwnedWindow([P09Access]::GetForegroundWindow(),$id) -and [P09Access]::FocusWithin($editor));$result.exact_editor_focus_verified=$true
}
function Browser-Key([int]$id,[int]$key,[int]$modifier=0){
 $rootWindow=[P09Access]::GetAncestor([P09Access]::GetForegroundWindow(),2)
 Need ([P09Access]::OwnedWindow($rootWindow,$id))
 Need ($modifier -in @(0,17) -and $key -in @(9,13,65,67,76,86))
 Need ([P09Access]::Chord($rootWindow,$id,[uint16]$key,[uint16]$modifier))
}
function Focus-BrowserDocument($root,[IntPtr]$hwnd,[int]$id){
 Focus-OwnedWindow $hwnd $id;$result.browser_focus_before_document_click=[P09Access]::FocusWithin($hwnd)
 $caption=[P09Access]::Caption($hwnd)
 if($caption.Contains('P09 browser canary') -or $caption.Contains('P09 protocol canary')){
  $bounds=[P09Rect]::new();Need ([P09Access]::GetWindowRect($hwnd,[ref]$bounds));Need ($bounds.Right-$bounds.Left -ge 480 -and $bounds.Bottom-$bounds.Top -ge 360)
  $point=[P09Point]::new();$point.X=$bounds.Left+[int](($bounds.Right-$bounds.Left)*2/3);$point.Y=$bounds.Top+[int](($bounds.Bottom-$bounds.Top)*3/4)
  $hit=Owned-Point $point $hwnd $id;Need ([P09Access]::SetCursorPos($point.X,$point.Y));try{[P09Access]::mouse_event(2,0,0,0,[UIntPtr]::Zero)}finally{[P09Access]::mouse_event(4,0,0,0,[UIntPtr]::Zero)};$result.browser_owned_document_click_verified=$true
 }
 $clock=[Diagnostics.Stopwatch]::StartNew();do{if([P09Access]::FocusWithin($hwnd)){break};Start-Sleep -Milliseconds 50}while($clock.ElapsedMilliseconds -lt 5000);Need ([P09Access]::FocusWithin($hwnd))
}
function Browser-Address($root,[IntPtr]$hwnd,[int]$id,[string]$address){
 Need ($address -in @('about:blank','about:support') -or $address -cmatch '^http://127\.0\.0\.1:[0-9]{4,5}/(?:main|protocol)/[0-9a-f-]{36}$')
 Focus-BrowserDocument $root $hwnd $id
 try{
  [Windows.Forms.Clipboard]::Clear();Browser-Key $id 76 17;Start-Sleep -Milliseconds 200;Need ([P09Access]::TypeText($hwnd,$id,$address));Start-Sleep -Milliseconds 200;Browser-Key $id 65 17;Browser-Key $id 67 17
  $clock=[Diagnostics.Stopwatch]::StartNew();do{if([Windows.Forms.Clipboard]::GetText() -ceq $address){break};Start-Sleep -Milliseconds 50}while($clock.ElapsedMilliseconds -lt 5000)
  $result.address_text_verified=([Windows.Forms.Clipboard]::GetText() -ceq $address);if(-not $result.address_text_verified){Browser-Key $id 76 17;Start-Sleep -Milliseconds 200;Need ([P09Access]::TypeAscii($hwnd,$id,$address));$result.ascii_scancode_uri_used=$true;Start-Sleep -Milliseconds 200};Browser-Key $id 13
 }finally{[Windows.Forms.Clipboard]::Clear()}
 $result.native_keyboard_delivery_checked=$true;$result.navigation_input='NATIVE_KEYBOARD_WITH_EXACT_SYNTHETIC_ADDRESS_READBACK'
}
function Browser-Document($root,[IntPtr]$hwnd,[int]$id,[string]$address,[string]$title){
 Browser-Address $root $hwnd $id 'about:blank';$clock=[Diagnostics.Stopwatch]::StartNew()
 do{$caption=[P09Access]::Caption($hwnd);if($caption -notmatch 'P09 browser canary|P09 protocol canary|Troubleshooting Information'){break};Start-Sleep -Milliseconds 100}while($clock.ElapsedMilliseconds -lt 15000)
 $result.blank_document_title_changed=($caption -notmatch 'P09 browser canary|P09 protocol canary|Troubleshooting Information');Need $result.blank_document_title_changed;Browser-Address $root $hwnd $id $address;$clock.Restart()
 do{if(([P09Access]::Caption($hwnd)).Contains($title)){$result.requested_document_title_observed=$true;return};Start-Sleep -Milliseconds 100}while($clock.ElapsedMilliseconds -lt 30000)
 Need $false
}
function Activate-CanaryLink($root,[IntPtr]$hwnd,[int]$id,[string]$name){
 Need ($name -in @('Open boxed child','Open synthetic handler'));Focus-BrowserDocument $root $hwnd $id
 # Each freshly loaded controlled document has exactly one focusable link.
 Browser-Key $id 9;Start-Sleep -Milliseconds 100;Browser-Key $id 13;return 'NATIVE_SCANCODE_SINGLE_CANARY_LINK'
}
function Click($element){Need ($null -ne $element -and $element.Current.IsEnabled);$pattern=$element.GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern);$pattern.Invoke()}
function Picker([int]$id,[string]$path){
 $script:stage='WAITING_FOR_NATIVE_PICKER'
 Need ([IO.Path]::IsPathRooted($path));$clock=[Diagnostics.Stopwatch]::StartNew();$window=[IntPtr]::Zero
 while($window -eq [IntPtr]::Zero -and $clock.ElapsedMilliseconds -lt 45000){$window=Window $id $true;if($window -eq [IntPtr]::Zero){Start-Sleep -Milliseconds 100}}
 Need ($window -ne [IntPtr]::Zero);$root=[Windows.Automation.AutomationElement]::FromHandle($window);$title=$root.Current.Name;$script:stage='VERIFYING_NATIVE_PICKER_TITLE'
 if($title.StartsWith('[#] ') -and $title.EndsWith(' [#]')){$title=$title.Substring(4,$title.Length-8)}
 $result.native_picker_title_recognized=Known-PickerTitle $title;$result.selected_picker_enabled=[P09Access]::IsWindowEnabled($window)
 Need $result.native_picker_title_recognized
 $script:stage='WAITING_FOR_ENABLED_NATIVE_FILENAME';$clock.Restart();$edit=$null;$nativeField=[IntPtr]::Zero;$activationTried=$false
 do{
  $edits=$root.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.OrCondition]::new([Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::ControlTypeProperty,[Windows.Automation.ControlType]::Edit),[Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::ControlTypeProperty,[Windows.Automation.ControlType]::ComboBox)))
  foreach($item in $edits){$known=($item.Current.AutomationId -eq '1148' -or $item.Current.Name -in @('File name:','File name','Folder:','Folder'));if(-not $known -and $item.Current.AutomationId -eq '1001'){$parent=[Windows.Automation.TreeWalker]::ControlViewWalker.GetParent($item);$known=($null -ne $parent -and ($parent.Current.AutomationId -eq '1148' -or $parent.Current.Name -in @('File name:','File name','Folder:','Folder')))};if($item.Current.IsEnabled -and $known){$candidateValue=$null;if($item.TryGetCurrentPattern([Windows.Automation.ValuePattern]::Pattern,[ref]$candidateValue) -and -not $candidateValue.Current.IsReadOnly){$edit=$item;break}}}
  if($null -ne $edit){break};$nativeField=[P09Access]::Filename($window,$id,$ExpectedBox);if($nativeField -ne [IntPtr]::Zero){break};if(-not $activationTried -and $clock.ElapsedMilliseconds -ge 1000){$activationTried=$true;Focus-OwnedWindow $window $id;Need ([P09Access]::Chord($window,$id,[uint16]78,[uint16]18))};if($activationTried){$nativeField=[P09Access]::FocusedFilename($window,$id,$ExpectedBox);if($nativeField -ne [IntPtr]::Zero){$result.native_filename_mnemonic_focus_verified=$true;break}};Start-Sleep -Milliseconds 100
 }while($clock.ElapsedMilliseconds -lt 15000)
 $usedValue=($null -ne $edit);$result.native_filename_control_kinds=[P09Access]::FilenameKinds($window,$id,$ExpectedBox);$result.native_filename_field_present=($nativeField -ne [IntPtr]::Zero)
 if($Mode -eq 'EDITOR'){
  $usedValue=$false;Focus-OwnedWindow $window $id;[Windows.Forms.SendKeys]::SendWait('%n');Start-Sleep -Milliseconds 150;$nativeField=[P09Access]::FocusedFilename($window,$id,$ExpectedBox);Need ($nativeField -ne [IntPtr]::Zero)
  [Windows.Forms.SendKeys]::SendWait('^a');Send-LiteralKeys $path;Need ([P09Access]::FilenameEquals($nativeField,$path));$result.editor_filename_actual_keyboard=$true;$result.native_filename_field_present=$true;$result.native_filename_mnemonic_focus_verified=$true
 }elseif($usedValue){$value=$edit.GetCurrentPattern([Windows.Automation.ValuePattern]::Pattern);$value.SetValue($path);Need ($value.Current.Value -ceq $path)}else{
  Need ($nativeField -ne [IntPtr]::Zero);$result.native_filename_message_verified=[P09Access]::SetFilename($nativeField,$path)
  if(-not $result.native_filename_message_verified){
   $script:stage='TYPING_EXACT_NATIVE_FILENAME';Focus-OwnedWindow $window $id;Need ([P09Access]::Chord($window,$id,[uint16]78,[uint16]18));Start-Sleep -Milliseconds 100
   $nativeField=[P09Access]::FocusedFilename($window,$id,$ExpectedBox);Need ($nativeField -ne [IntPtr]::Zero);Need ([P09Access]::Chord($window,$id,[uint16]65,[uint16]17));Need ([P09Access]::TypeText($window,$id,$path));Need ([P09Access]::FilenameEquals($nativeField,$path));$result.native_filename_keyboard_verified=$true
  }
 }
 if($Mode -eq 'EDITOR'){[Windows.Forms.SendKeys]::SendWait('{ENTER}')}else{
 $script:stage='ACCEPTING_EXACT_NATIVE_PICKER';$saving=($title -in @('Save reviewed diagnostics','Сохранить просмотренную диагностику','Save As','Save as','Save File'))
 $buttonName=if($saving){'Save'}else{'Open'};$button=Find $root ([Windows.Automation.ControlType]::Button) $buttonName
 if($null -eq $button -and -not $saving){$buttonName='Select Folder';$button=Find $root ([Windows.Automation.ControlType]::Button) $buttonName}
 $result.native_accept_button_kind=if($null -ne $button){$buttonName}else{'NATIVE_IDOK'};$result.native_save_dialog=$saving
 if($null -ne $button){Click $button}else{Need ([P09Access]::AcceptPicker($window,$id,$ExpectedBox))}
 }
 if($AllowOverwrite){Start-Sleep -Milliseconds 300;$confirm=Window $id $true;if($confirm -ne [IntPtr]::Zero){$confirmRoot=[Windows.Automation.AutomationElement]::FromHandle($confirm);Need ($confirmRoot.Current.Name -eq 'Confirm Save As');Click (Find $confirmRoot ([Windows.Automation.ControlType]::Button) 'Yes')}}
 $script:stage='WAITING_FOR_NATIVE_PICKER_CLOSE';$clock.Restart();while([P09Access]::IsWindowVisible($window) -and $clock.ElapsedMilliseconds -lt 10000){Start-Sleep -Milliseconds 50};Need (-not [P09Access]::IsWindowVisible($window));$result.picker_window_closed=$true
 return @{real_native_picker=$true;value_pattern_used=$usedValue;native_filename_control_used=(-not $usedValue);explicit_button_invoked=($Mode -ne 'EDITOR');native_enter_accept=($Mode -eq 'EDITOR');picker_window_closed=$true;overwrite_prompt_authorized=[bool]$AllowOverwrite}
}
function Collapse-DisplayCombo($root,[string]$automationId){
 $combo=$root.FindFirst([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::AutomationIdProperty,$automationId));Need ($null -ne $combo)
 $pattern=$combo.GetCurrentPattern([Windows.Automation.ExpandCollapsePattern]::Pattern)
 if($pattern.Current.ExpandCollapseState -ne [Windows.Automation.ExpandCollapseState]::Collapsed){$pattern.Collapse()}
 $clock=[Diagnostics.Stopwatch]::StartNew();while($pattern.Current.ExpandCollapseState -ne [Windows.Automation.ExpandCollapseState]::Collapsed -and $clock.ElapsedMilliseconds -lt 5000){Start-Sleep -Milliseconds 50}
 Need ($pattern.Current.ExpandCollapseState -eq [Windows.Automation.ExpandCollapseState]::Collapsed)
}
function Set-ActualDisplayScale([int]$Scale){
   $script:stage='OPENING_WINDOWS_DISPLAY_SETTINGS';$settingsRoot=$script:displayRoot
   $clock=[Diagnostics.Stopwatch]::StartNew()
   if($null -eq $settingsRoot){
    Start-Process 'ms-settings:display'
    do{
     $settings=Get-Process SystemSettings -ErrorAction SilentlyContinue|Where-Object MainWindowHandle -ne 0|Select-Object -First 1
     if($null -ne $settings){$candidate=[Windows.Automation.AutomationElement]::FromHandle($settings.MainWindowHandle);$combo=$candidate.FindFirst([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::AutomationIdProperty,'SystemSettings_Display_Scaling_ItemSizeOverride_ComboBox'));if($null -ne $combo){$settingsRoot=$candidate;$script:displayRoot=$candidate;$script:displayWindow=$settings.MainWindowHandle;break}}
     Start-Sleep -Milliseconds 100
    }while($clock.ElapsedMilliseconds -lt 45000)
   }
   Need ($null -ne $settingsRoot)
   $pattern=$null;if($settingsRoot.TryGetCurrentPattern([Windows.Automation.WindowPattern]::Pattern,[ref]$pattern)){$pattern.SetWindowVisualState([Windows.Automation.WindowVisualState]::Normal)}
   $null=[P09Access]::SetForegroundWindow($script:displayWindow)
   $script:stage='SELECTING_ADVERTISED_DISPLAY_HEIGHT';$resolution=$settingsRoot.FindFirst([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::AutomationIdProperty,'SystemSettings_Display_Resolution_ComboBox'))
   Need ($null -ne $resolution -and $resolution.Current.IsEnabled);$resolution.GetCurrentPattern([Windows.Automation.ExpandCollapsePattern]::Pattern).Expand();Start-Sleep -Milliseconds 300
   $items=$settingsRoot.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::ControlTypeProperty,[Windows.Automation.ControlType]::ListItem));$best=$null;$height=0;$area=0
   foreach($item in $items){if($item.Current.Name -match '([0-9]{3,4})\D{1,8}([0-9]{3,4})'){$w=[int]$Matches[1];$h=[int]$Matches[2];if($h -gt $height -or ($h -eq $height -and $w*$h -gt $area)){$best=$item;$height=$h;$area=$w*$h}}}
   Need ($null -ne $best -and $height -ge 1200);$best.GetCurrentPattern([Windows.Automation.SelectionItemPattern]::Pattern).Select();Collapse-DisplayCombo $settingsRoot 'SystemSettings_Display_Resolution_ComboBox';Start-Sleep -Seconds 1
   $keep=Find $settingsRoot ([Windows.Automation.ControlType]::Button) 'Keep changes';if($null -ne $keep){Click $keep}
   $script:stage='SELECTING_REAL_WINDOWS_SCALE';$combo=$settingsRoot.FindFirst([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::AutomationIdProperty,'SystemSettings_Display_Scaling_ItemSizeOverride_ComboBox'))
   Need ($null -ne $combo -and $combo.Current.IsEnabled);$combo.GetCurrentPattern([Windows.Automation.ExpandCollapsePattern]::Pattern).Expand();Start-Sleep -Milliseconds 300
   $choice=$null;$choices=$settingsRoot.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::ControlTypeProperty,[Windows.Automation.ControlType]::ListItem))
   foreach($item in $choices){if($item.Current.Name -match '^([0-9]{2,3})\s*%' -and [int]$Matches[1] -eq $Scale){$choice=$item;break}}
   if($null -eq $choice){$container=$combo.GetCurrentPattern([Windows.Automation.ItemContainerPattern]::Pattern);foreach($label in @("$Scale%","$Scale% (Recommended)")){$candidate=$container.FindItemByProperty($null,[Windows.Automation.AutomationElement]::NameProperty,$label);if($null -ne $candidate){$choice=$candidate;break}};if($null -ne $choice){$virtual=$null;if($choice.TryGetCurrentPattern([Windows.Automation.VirtualizedItemPattern]::Pattern,[ref]$virtual)){$virtual.Realize()};$scroll=$null;if($choice.TryGetCurrentPattern([Windows.Automation.ScrollItemPattern]::Pattern,[ref]$scroll)){$scroll.ScrollIntoView()}}}
   Need ($null -ne $choice);$choice.GetCurrentPattern([Windows.Automation.SelectionItemPattern]::Pattern).Select();Collapse-DisplayCombo $settingsRoot 'SystemSettings_Display_Scaling_ItemSizeOverride_ComboBox'

 $clock.Restart();do{$dpi=[P09Access]::GetDpiForWindow($script:displayWindow);if($dpi -eq 96*$Scale/100){break};Start-Sleep -Milliseconds 100}while($clock.ElapsedMilliseconds -lt 15000);Need ($dpi -eq 96*$Scale/100)
 $window=$null;if($CloseSettings -and $settingsRoot.TryGetCurrentPattern([Windows.Automation.WindowPattern]::Pattern,[ref]$window)){$window.Close();$script:displayRoot=$null;$script:displayWindow=[IntPtr]::Zero;$script:raisedWindows=[Collections.Generic.List[IntPtr]]::new()}
 elseif($settingsRoot.TryGetCurrentPattern([Windows.Automation.WindowPattern]::Pattern,[ref]$window) -and $window.Current.CanMinimize){$window.SetWindowVisualState([Windows.Automation.WindowVisualState]::Minimized)}
}
if($Mode -eq 'DISPLAY_SERVER'){
 Need ($DisplayEvents -cmatch '^Local\\SecureRunP09Display-[0-9a-f]{32}$' -and [IO.Path]::IsPathRooted($ResultFile))
 $events=@();$serverClock=[Diagnostics.Stopwatch]::StartNew();$requests=0;$desktopRequests=0
 try{
  $script:stage='OPENING_OWNER_RESTRICTED_EVENTS'
  $rights=[Security.AccessControl.EventWaitHandleRights]::Synchronize -bor [Security.AccessControl.EventWaitHandleRights]::Modify
  foreach($suffix in @('100','150','200','prepare','done','failed')){$events+=,[Threading.EventWaitHandle]::OpenExisting($DisplayEvents+'-'+$suffix,$rights)}
  Server-Status 'EVENTS_OPENED'
  $prepared=@{mode='DISPLAY_PREPARATION';requested_windows_scale=100;status='FAILED';real_windows_uia=$true;synthetic_fixture_only=$true;os_security_settings_modified=$false;excluded_from_product_startup_measurement=$true}
  try{Set-ActualDisplayScale 100;$prepared.status='PASSED'}catch{$prepared.stage=$script:stage;$prepared.exception_type=$_.Exception.GetBaseException().GetType().FullName}
  $prepared|ConvertTo-Json|Set-Content -LiteralPath ($ResultFile+'.preparation.json') -Encoding UTF8
  if($prepared.status -ne 'PASSED'){$null=$events[5].Set();exit 1}
  Server-Status 'READY'
  $null=$events[4].Set() # Parent consumes readiness before starting the actor.
  while($serverClock.ElapsedMilliseconds -lt 3000000){
   $index=[Threading.WaitHandle]::WaitAny([Threading.WaitHandle[]]$events[0..3],1000)
   if($index -ge 4){continue}
   if($index -eq 3){
    $desktopRequests++
    if($desktopRequests -gt 8){$null=$events[5].Set();break}
    $record=Prepare-InitialDesktop
    $record.controller_same_user_preparation=$true
    $record|ConvertTo-Json -Depth 5|Set-Content -LiteralPath ($ResultFile+'.desktop-preparation-'+$desktopRequests+'.json') -Encoding UTF8
    if($record.status -eq 'OBSERVED'){$null=$events[4].Set()}else{$null=$events[5].Set()}
    continue
   }
   $requests++;if($requests -gt 8){$null=$events[5].Set();break}
   $record=@{mode='DISPLAY_CONTROLLER';requested_windows_scale=@(100,150,200)[$index];status='FAILED';real_windows_uia=$true;synthetic_fixture_only=$true;os_security_settings_modified=$false}
   try{$script:CloseSettings=($index -eq 0 -and $requests -gt 1);Set-ActualDisplayScale $record.requested_windows_scale;$record.status='PASSED'}
   catch{$record.code='P09_NATIVE_ACCESSIBILITY_FAILED';$record.stage=$script:stage;$record.exception_type=$_.Exception.GetBaseException().GetType().FullName}
   $record|ConvertTo-Json|Set-Content -LiteralPath ($ResultFile+'.'+$requests+'.json') -Encoding UTF8
   if($record.status -eq 'PASSED'){$null=$events[4].Set()}else{$null=$events[5].Set()}
  }
 }finally{foreach($event in $events){$event.Dispose()}}
 exit 0
}
$hwnd=[IntPtr]::Zero
try{
 if($Mode -eq 'DISPLAY_CONTROLLER'){Set-ActualDisplayScale $Scale;$result.status='PASSED';$result.requested_windows_scale=$Scale;$result.os_security_settings_modified=$false;if($ResultFile){$result|ConvertTo-Json|Set-Content -LiteralPath $ResultFile -Encoding UTF8};Write-Host 'P09_DISPLAY_CONTROLLER_COMPLETE';exit 0}
 if($Mode -eq 'READY'){
  $stage='PREWARMING_NATIVE_PROVIDER';$null=[Windows.Automation.AutomationElement]::RootElement
  $stage='WAITING_FOR_COORDINATION';[IO.File]::WriteAllText($Coordination+'.ready','READY')
  $clock=[Diagnostics.Stopwatch]::StartNew();while(-not(Test-Path -LiteralPath $Coordination) -and $clock.ElapsedMilliseconds -lt 45000){Start-Sleep -Milliseconds 50};Need (Test-Path -LiteralPath $Coordination)
  $start=Get-Content -LiteralPath $Coordination -Raw|ConvertFrom-Json;$ManagerPid=[int]$start.pid
 }
 $stage='FINDING_OWNED_WINDOW';$clock=[Diagnostics.Stopwatch]::StartNew();$hwnd=[IntPtr]::Zero
 while($hwnd -eq [IntPtr]::Zero -and $clock.ElapsedMilliseconds -lt 45000){$hwnd=Window $ManagerPid;if($hwnd -eq [IntPtr]::Zero){Start-Sleep -Milliseconds 100}}
 Need ($hwnd -ne [IntPtr]::Zero);if($Mode -eq 'READY'){$result.native_window_present_ms=([Diagnostics.Stopwatch]::GetTimestamp()-[long]$start.ticks)*1000.0/[Diagnostics.Stopwatch]::Frequency};$result.native_window_dpi=[P09Access]::GetDpiForWindow($hwnd);$nativeBrowser=$Mode.StartsWith('BROWSER_');$root=$null;if($nativeBrowser){$result.real_windows_uia=$false;$result.native_window_interaction=$true;$result.uia_browser_provider_queried=$false}else{$root=[Windows.Automation.AutomationElement]::FromHandle($hwnd)}
 switch($Mode){
  'DISPLAY_SCALE' {
   $stage='REQUESTING_LAB_DISPLAY_CONTROLLER';$prefix=$env:SECURERUN_P09_DISPLAY_EVENTS
   Need ($prefix -cmatch '^Local\\SecureRunP09Display-[0-9a-f]{32}$')
   $request=$null;$done=$null;$failed=$null
   try{$rights=[Security.AccessControl.EventWaitHandleRights]::Synchronize -bor [Security.AccessControl.EventWaitHandleRights]::Modify;$request=[Threading.EventWaitHandle]::OpenExisting($prefix+'-'+$Scale,$rights);$done=[Threading.EventWaitHandle]::OpenExisting($prefix+'-done',$rights);$failed=[Threading.EventWaitHandle]::OpenExisting($prefix+'-failed',$rights);$null=$request.Set();$index=[Threading.WaitHandle]::WaitAny([Threading.WaitHandle[]]@($done,$failed),120000);Need ($index -eq 0)}
   finally{foreach($event in @($request,$done,$failed)){if($null -ne $event){$event.Dispose()}}}
   $stage='VERIFYING_ACTUAL_MANAGER_WINDOW_DPI';$clock.Restart()
   do{$dpi=[P09Access]::GetDpiForWindow($hwnd);if($dpi -eq 96*$Scale/100){break};Start-Sleep -Milliseconds 100}while($clock.ElapsedMilliseconds -lt 15000)
   Need ($dpi -eq 96*$Scale/100);$root.GetCurrentPattern([Windows.Automation.WindowPattern]::Pattern).SetWindowVisualState([Windows.Automation.WindowVisualState]::Maximized);$result.owned_activation_accepted=[P09Access]::ActivateOwned($hwnd,$ManagerPid)
   $result.requested_windows_scale=$Scale;$result.native_window_dpi=$dpi;$result.actual_windows_display_change=$true;$result.production_manager_window_measured=$true;$result.os_security_settings_modified=$false
  }
  'CONFIRM' {
   $stage='CONFIRMING_EXACT_ENVIRONMENT';Need ($EnvironmentId -cmatch '^[0-9a-f-]{36}$');$expected=switch($Intent){'ARCHIVE'{'Keep the definition, applications and all data.'};'UNARCHIVE'{'Keep all data. Revalidate ownership, roots and policy'};'RESET'{'Keep the environment definition and application records.'};default{throw 'P09_CONFIRMATION_INTENT_INVALID'}}
   $clock=[Diagnostics.Stopwatch]::StartNew();$confirm=[IntPtr]::Zero
   do{$confirm=Window $ManagerPid $true;if($confirm -ne [IntPtr]::Zero){break};Start-Sleep -Milliseconds 100}while($clock.ElapsedMilliseconds -lt 45000)
   Need ($confirm -ne [IntPtr]::Zero);$dialog=[Windows.Automation.AutomationElement]::FromHandle($confirm);Need ($dialog.Current.Name -eq 'SecureRun — environment confirmation')
   $elements=$dialog.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.Condition]::TrueCondition);$content=($elements|ForEach-Object {$_.Current.Name}) -join "`n";Need ($content.Contains($EnvironmentId) -and $content.Contains($expected));Click (Find $dialog ([Windows.Automation.ControlType]::Button) 'OK');$result.exact_environment_and_retention_verified=$true;$result.native_confirmation_accepted=$true
  }
  'PICKER' {$stage='SELECTING_KNOWN_FIXTURE';$result.picker=Picker $ManagerPid $SelectedPath}
  'EDITOR' {$stage='EDITING_SYNTHETIC_DOCUMENT';Focus-NativeEditor $hwnd $ManagerPid;[Windows.Forms.SendKeys]::SendWait('^a');[Windows.Forms.SendKeys]::SendWait('P09_EDITOR_CANARY');[Windows.Forms.SendKeys]::SendWait('^%s');$result.picker=Picker $ManagerPid $SelectedPath;$result.real_keyboard_edit=$true}
  'BROWSER_WELCOME' {
   $stage='OBSERVING_OFFICIAL_FIREFOX_WELCOME';Need (([P09Access]::Caption($hwnd)).Contains('P09 browser canary'));Focus-OwnedWindow $hwnd $ManagerPid
   $root=[Windows.Automation.AutomationElement]::FromHandle($hwnd);$result.uia_browser_provider_queried=$true;$result.real_windows_uia=$true
   $elements=$root.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.Condition]::TrueCondition);Need ($elements.Count -le 10000)
   $heading=@($elements|Where-Object {$_.Current.Name -ceq 'Welcome to Firefox'});$continue=@($elements|Where-Object {$_.Current.ControlType -eq [Windows.Automation.ControlType]::Button -and $_.Current.Name -ceq 'Continue'})
   $terms=@($elements|Where-Object {$_.Current.Name.Contains('Terms of Use')}).Count -gt 0;$privacy=@($elements|Where-Object {$_.Current.Name.Contains('Privacy Notice')}).Count -gt 0
   $result.official_welcome_heading_observed=($heading.Count -gt 0);$result.terms_notice_observed=$terms;$result.privacy_notice_observed=$privacy;$result.exact_continue_buttons=$continue.Count;$result.official_welcome_continue_invoked=$false
   if($heading.Count -gt 0){
    Need ($terms -and $privacy -and $continue.Count -eq 1 -and $continue[0].Current.IsEnabled -and (In-Provider $continue[0] $root))
    $manage=@($elements|Where-Object {$_.Current.Name -ceq 'Manage diagnostic and interaction data'})
    if($manage.Count -eq 1){$pattern=$null;if($manage[0].TryGetCurrentPattern([Windows.Automation.ExpandCollapsePattern]::Pattern,[ref]$pattern)){$pattern.Expand()}elseif($manage[0].TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern,[ref]$pattern)){$pattern.Invoke()};Start-Sleep -Milliseconds 200}
    $checks=$root.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::ControlTypeProperty,[Windows.Automation.ControlType]::CheckBox));Need ($checks.Count -le 32);$disabled=0
    foreach($check in $checks){if($check.Current.Name -match '(?i)diagnostic|interaction|technical'){$toggle=$null;Need ($check.TryGetCurrentPattern([Windows.Automation.TogglePattern]::Pattern,[ref]$toggle));if($toggle.Current.ToggleState -eq [Windows.Automation.ToggleState]::On){$toggle.Toggle()};Need ($toggle.Current.ToggleState -eq [Windows.Automation.ToggleState]::Off);$disabled++}}
    $result.diagnostic_data_choices_observed_off=$disabled;$stage='CONTINUING_RECOGNIZED_FIREFOX_WELCOME';$pattern=$null
    if($continue[0].TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern,[ref]$pattern)){$pattern.Invoke()}else{$continue[0].SetFocus();Browser-Key $ManagerPid 13};$result.official_welcome_continue_invoked=$true
    $clock=[Diagnostics.Stopwatch]::StartNew();do{$remaining=$root.FindFirst([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::NameProperty,'Welcome to Firefox'));if($null -eq $remaining){break};Start-Sleep -Milliseconds 100}while($clock.ElapsedMilliseconds -lt 15000)
    $result.known_welcome_dismissed=($null -eq $remaining);Need $result.known_welcome_dismissed
   }else{. (Join-Path $PSScriptRoot 'p09_ocr.ps1');Continue-VisualFirefoxWelcome $hwnd $ManagerPid}
  }
  'BROWSER_DIAGNOSTIC' {
   $stage='OBSERVING_SYNTHETIC_BROWSER_CHROME';Need (([P09Access]::Caption($hwnd)).Contains('P09 browser canary'))
   $result.native_window_response_error=[P09Access]::Responsive($hwnd);$result.native_browser_has_caption=(([P09Access]::GetWindowLong($hwnd,-16) -band 0x00c00000) -eq 0x00c00000)
   $work=[Windows.Forms.Screen]::PrimaryScreen.WorkingArea;$width=[Math]::Min(1000,$work.Width-40);$height=[Math]::Min(700,$work.Height-40);Need ($width -ge 480 -and $height -ge 360);Need ([P09Access]::SetWindowPos($hwnd,[IntPtr]::new(-1),$work.Left+20,$work.Top+20,$width,$height,0x50));$script:raisedWindows.Add($hwnd);$result.synthetic_window_geometry_controlled=$true;Start-Sleep -Milliseconds 300

   $rect=[P09Rect]::new();Need ([P09Access]::GetWindowRect($hwnd,[ref]$rect));$width=$rect.Right-$rect.Left;$height=$rect.Bottom-$rect.Top;Need ($width -gt 0 -and $height -gt 0 -and $width -le 4096 -and $height -le 4096)
   $bitmap=[Drawing.Bitmap]::new($width,$height);$graphics=$null;$dc=[IntPtr]::Zero
   try{$graphics=[Drawing.Graphics]::FromImage($bitmap);$dc=$graphics.GetHdc();$result.synthetic_browser_window_captured=[P09Access]::PrintWindow($hwnd,$dc,2);$graphics.ReleaseHdc($dc);$dc=[IntPtr]::Zero;if($result.synthetic_browser_window_captured){$bitmap.Save($ResultFile+'.png',[Drawing.Imaging.ImageFormat]::Png)}}
   finally{if($null -ne $graphics){if($dc -ne [IntPtr]::Zero){$graphics.ReleaseHdc($dc)};$graphics.Dispose()};$bitmap.Dispose()}
   $class=[Text.StringBuilder]::new(128);$null=[P09Access]::GetClassName($hwnd,$class,128);$baseClass=$class.ToString() -replace '^Sandbox:SR_[0-9a-f]{32}:','';$result.browser_native_window_class=if($baseClass -cin @('MozillaWindowClass','MozillaDialogClass','MozillaCompositorWindowClass','MozillaHiddenWindowClass')){$baseClass}else{'WITHHELD'}
   Focus-OwnedWindow $hwnd $ManagerPid;Need ([P09Access]::SetWindowPos($hwnd,[IntPtr]::new(-1),$work.Left+20,$work.Top+20,[Math]::Min(1000,$work.Width-40),[Math]::Min(700,$work.Height-40),0x50));Need ([P09Access]::GetWindowRect($hwnd,[ref]$rect));$width=$rect.Right-$rect.Left;$height=$rect.Bottom-$rect.Top;$allOwned=$true
   foreach($fx in @(0.1,0.5,0.9)){foreach($fy in @(0.1,0.5,0.9)){$sample=[P09Point]::new();$sample.X=$rect.Left+[int]($width*$fx);$sample.Y=$rect.Top+[int]($height*$fy);$sampleHit=[P09Access]::WindowFromPoint($sample);if(-not ([P09Access]::OwnedWindow($sampleHit,$ManagerPid) -and [P09Access]::GetAncestor($sampleHit,2) -eq $hwnd)){$allOwned=$false}}}
   $result.screen_capture_points_owned=$allOwned;$result.synthetic_browser_screen_captured=$false
   if($allOwned -and $width -gt 40 -and $height -gt 40){
    $screen=[Drawing.Bitmap]::new($width-20,$height-20);$draw=$null
    try{$draw=[Drawing.Graphics]::FromImage($screen);$draw.CopyFromScreen($rect.Left+10,$rect.Top+10,0,0,$screen.Size);$screen.Save($ResultFile+'.screen.png',[Drawing.Imaging.ImageFormat]::Png);$result.synthetic_browser_screen_captured=$true}finally{if($null -ne $draw){$draw.Dispose()};$screen.Dispose()}
   }
   $result.synthetic_canary_title_verified=$true;$result.raw_support_content_captured=$false;$result.uia_browser_provider_queried=$false
  }
  'BROWSER_PROTOCOL' {
   $stage='REQUESTING_SYNTHETIC_PROTOCOL_LINK';Need ($ProtocolUri -cmatch '^http://127\.0\.0\.1:[0-9]{4,5}/protocol/[0-9a-f-]{36}$');Need (([Uri]$ProtocolUri).Port -ge 1024 -and ([Uri]$ProtocolUri).Port -le 65535)
   Browser-Document $root $hwnd $ManagerPid $ProtocolUri 'P09 protocol canary';$result.protocol_link_action=Activate-CanaryLink $root $hwnd $ManagerPid 'Open synthetic handler';$result.actual_browser_address_action=$true
   $stage='CONFIRMING_SYNTHETIC_PROTOCOL_PROMPT';Start-Sleep -Milliseconds 1500
   Need ([P09Access]::OwnedWindow([P09Access]::GetForegroundWindow(),$ManagerPid));Browser-Key $ManagerPid 13;$result.synthetic_protocol_confirmation_keyboard_sent=$true

  }
  'BROWSER_CHILD' {
   $stage='ACTIVATING_SYNTHETIC_BROWSER_DOCUMENT';Need ($ProtocolUri -cmatch '^http://127\.0\.0\.1:[0-9]{4,5}/main/[0-9a-f-]{36}$');Need (([Uri]$ProtocolUri).Port -ge 1024 -and ([Uri]$ProtocolUri).Port -le 65535)
   Browser-Document $root $hwnd $ManagerPid $ProtocolUri 'P09 browser canary';$stage='BROWSER_OWN_CHILD_ACTION';$result.canary_link_action=Activate-CanaryLink $root $hwnd $ManagerPid 'Open boxed child';$result.actual_browser_child_action=$true
  }
  'BROWSER_SANDBOX' {
   $stage='READING_BROWSER_SANDBOX_STATE';[Windows.Forms.Clipboard]::Clear()
   try{
    Browser-Document $root $hwnd $ManagerPid 'about:support' 'Troubleshooting Information'
    Need ([P09Access]::OwnedWindow([P09Access]::GetForegroundWindow(),$ManagerPid));Browser-Key $ManagerPid 65 17;Start-Sleep -Milliseconds 100;Browser-Key $ManagerPid 67 17;$result.sandbox_source='ABOUT_SUPPORT_RENDERED_TEXT'
    $clock=[Diagnostics.Stopwatch]::StartNew();$level=0
    do{
     $text=[Windows.Forms.Clipboard]::GetText();Need ($text.Length -le 2097152)
     if($text.StartsWith('{')){$data=$text|ConvertFrom-Json;Need ($null -ne $data.sandbox -and $null -ne $data.sandbox.PSObject.Properties['effectiveContentSandboxLevel']);$level=[int]$data.sandbox.effectiveContentSandboxLevel;break}
     elseif($text -match '(?im)^\s*Effective Content (?:Process )?Sandbox Level[ \t]*(?:\r?\n)?[ \t]*([0-9]{1,3})[ \t]*$'){$level=[int]$Matches[1];break}
     Start-Sleep -Milliseconds 100
    }while($clock.ElapsedMilliseconds -lt 10000)
    Need ($level -gt 0);$result.effective_content_sandbox_level=$level;$result.browser_own_sandbox_enabled=$true;$result.real_about_support=$true
   }finally{[Windows.Forms.Clipboard]::Clear()}
  }
  default {
   $stage='WAITING_FOR_ACCESSIBLE_NAVIGATION';$clock=[Diagnostics.Stopwatch]::StartNew();$navigation=$null;$settings=$null
   do{if($Mode -eq 'KEYBOARD'){$navigation=Find $root ([Windows.Automation.ControlType]::Button) 'Environments'};$settings=Find $root ([Windows.Automation.ControlType]::Button) 'Settings';if($null -ne $settings -and ($Mode -eq 'READY' -or $null -ne $navigation)){break};Start-Sleep -Milliseconds 100}while($clock.ElapsedMilliseconds -lt 45000)
   $result.navigation_lookup_ms=$clock.Elapsed.TotalMilliseconds
   Need ($null -ne $settings -and ($Mode -eq 'READY' -or $null -ne $navigation));$invokeClock=[Diagnostics.Stopwatch]::StartNew();Click $settings;$result.settings_invoke_ms=$invokeClock.Elapsed.TotalMilliseconds
   $clock=[Diagnostics.Stopwatch]::StartNew();$language=$null
   do{$language=Find $root ([Windows.Automation.ControlType]::ComboBox) 'Language';if($null -ne $language){break};Start-Sleep -Milliseconds 100}while($clock.ElapsedMilliseconds -lt 15000)
   $result.language_lookup_ms=$clock.Elapsed.TotalMilliseconds
   Need ($null -ne $language -and $language.Current.IsEnabled);$result.accessible_label_and_role=$true;$result.native_invoke_changed_real_page=$true
   if($Mode -eq 'READY'){$result.startup_interactive_upper_bound_ms=([Diagnostics.Stopwatch]::GetTimestamp()-[long]$start.ticks)*1000.0/[Diagnostics.Stopwatch]::Frequency}
   if($Mode -eq 'KEYBOARD'){
    $stage='FOCUSING_OWNED_MANAGER';$root.GetCurrentPattern([Windows.Automation.WindowPattern]::Pattern).SetWindowVisualState([Windows.Automation.WindowVisualState]::Normal);Focus-OwnedWindow $hwnd $ManagerPid;$navigation.SetFocus();Start-Sleep -Milliseconds 100
    $pointClock=[Diagnostics.Stopwatch]::StartNew()
    do {
     $clickable=$navigation.GetClickablePoint();$point=[P09Point]::new();$point.X=[int]$clickable.X;$point.Y=[int]$clickable.Y
    $hit=Owned-Point $point $hwnd $ManagerPid;$hitOwner=[P09Access]::RootOwnerPid($hit);$result.keyboard_point_hits_window=($hit -ne [IntPtr]::Zero);$result.keyboard_native_root_owner_matches_manager=($hitOwner -eq $ManagerPid);$result.keyboard_native_window_owned=[P09Access]::OwnedWindow($hit,$ManagerPid);$result.keyboard_exact_navigation_provider_verified=(In-Provider ([Windows.Automation.AutomationElement]::FromPoint($clickable)) $navigation);$result.keyboard_click_hit_owned_window=($result.keyboard_native_window_owned -and $result.keyboard_exact_navigation_provider_verified)
     if($result.keyboard_click_hit_owned_window){break};Start-Sleep -Milliseconds 100
    }while($pointClock.ElapsedMilliseconds -lt 5000)
    $bounds=[P09Rect]::new();Need ([P09Access]::GetWindowRect($hwnd,[ref]$bounds));$result.keyboard_point_inside_native_window=($point.X -ge $bounds.Left -and $point.X -lt $bounds.Right -and $point.Y -ge $bounds.Top -and $point.Y -lt $bounds.Bottom)
    $class=[Text.StringBuilder]::new(64);$null=[P09Access]::GetClassName($hit,$class,64);$result.keyboard_hit_is_console=($class.ToString() -in @('ConsoleWindowClass','CASCADIA_HOSTING_WINDOW_CLASS'));$result.keyboard_hit_is_browser_surface=($class.ToString() -in @('Chrome_WidgetWin_0','Chrome_WidgetWin_1','Chrome_RenderWidgetHostHWND'));$result.keyboard_native_hit_kind=Native-HitKind $hit
    Need $result.keyboard_click_hit_owned_window;Need ([P09Access]::SetCursorPos($point.X,$point.Y));try{[P09Access]::mouse_event(2,0,0,0,[UIntPtr]::Zero)}finally{[P09Access]::mouse_event(4,0,0,0,[UIntPtr]::Zero)}
    $focusClock=[Diagnostics.Stopwatch]::StartNew()
    do{if([P09Access]::OwnedWindow([P09Access]::GetForegroundWindow(),$ManagerPid) -and (In-Provider ([Windows.Automation.AutomationElement]::FocusedElement) $navigation)){break};Start-Sleep -Milliseconds 50}while($focusClock.ElapsedMilliseconds -lt 5000)
    $result.keyboard_foreground_owned=[P09Access]::OwnedWindow([P09Access]::GetForegroundWindow(),$ManagerPid);$result.keyboard_navigation_focused=(In-Provider ([Windows.Automation.AutomationElement]::FocusedElement) $navigation)
    Need ($result.keyboard_foreground_owned -and $result.keyboard_navigation_focused)
    $stage='CHECKING_TAB_FOCUS';[Windows.Forms.SendKeys]::SendWait('{TAB}');$focusClock.Restart();do{$focused=[Windows.Automation.AutomationElement]::FocusedElement;if($focused.Current.Name -eq 'Settings'){break};Start-Sleep -Milliseconds 50}while($focusClock.ElapsedMilliseconds -lt 5000);Need ($focused.Current.Name -eq 'Settings');$result.tab_order_actual=$true
    $stage='CHECKING_F6_FOCUS';[Windows.Forms.SendKeys]::SendWait('{F6}');$focusClock.Restart();do{if([Windows.Automation.AutomationElement]::FocusedElement.Current.Name -eq 'Environments'){break};Start-Sleep -Milliseconds 50}while($focusClock.ElapsedMilliseconds -lt 5000);Need ([Windows.Automation.AutomationElement]::FocusedElement.Current.Name -eq 'Environments');$result.f6_navigation_actual=$true
    $stage='CHECKING_SETTINGS_SHORTCUT';[Windows.Forms.SendKeys]::SendWait('^,');$focusClock.Restart();$shortcut=$null
    do{$shortcut=Find $root ([Windows.Automation.ControlType]::ComboBox) 'Language';if($null -ne $shortcut){break};Start-Sleep -Milliseconds 50}while($focusClock.ElapsedMilliseconds -lt 5000);Need ($null -ne $shortcut -and $shortcut.Current.IsEnabled);$result.ctrl_settings_changed_page=$true
    $stage='CHECKING_ENVIRONMENTS_SHORTCUT';[Windows.Forms.SendKeys]::SendWait('^1');$focusClock.Restart();$shortcut=$null
    do{$shortcut=Find $root ([Windows.Automation.ControlType]::Edit) 'Find an environment';if($null -ne $shortcut){break};Start-Sleep -Milliseconds 50}while($focusClock.ElapsedMilliseconds -lt 5000);Need ($null -ne $shortcut -and $shortcut.Current.IsEnabled);$result.ctrl_navigation_actual=$true
   }
   if($null -eq $navigation){$navigation=Find $root ([Windows.Automation.ControlType]::Button) 'Environments'};Click $navigation
  }
 }
 $result.status='PASSED'
}catch{$kind=$_.FullyQualifiedErrorId.Split(',')[0];$result.error_record_kind=if($kind -cmatch '^[A-Za-z][A-Za-z0-9_.]{0,100}$'){$kind}else{'WITHHELD'};$result.native_input_structure_bytes=[P09Access]::InputSize();$result.native_pointer_bytes=[IntPtr]::Size;$result.status='FAILED';$result.code='P09_NATIVE_ACCESSIBILITY_FAILED';$result.stage=$stage;$result.exception_type=$_.Exception.GetBaseException().GetType().FullName;$result.source_lines=@([regex]::Matches($_.ScriptStackTrace,'line ([0-9]+)')|Select-Object -First 12|ForEach-Object {[int]$_.Groups[1].Value})}
if($result.status -eq 'FAILED' -and $hwnd -ne [IntPtr]::Zero -and -not $Mode.StartsWith('BROWSER_')){try{$provider=[Windows.Automation.AutomationElement]::FromHandle($hwnd);$result.owned_root_accessible_children=$provider.FindAll([Windows.Automation.TreeScope]::Children,[Windows.Automation.Condition]::TrueCondition).Count;$result.owned_window_visible=[P09Access]::IsWindowVisible($hwnd);$result.owned_window_enabled=[P09Access]::IsWindowEnabled($hwnd)}catch{$result.owned_root_provider_available=$false}}
foreach($raised in $script:raisedWindows){$raisedOwner=0;$null=[P09Access]::GetWindowThreadProcessId($raised,[ref]$raisedOwner);if($raisedOwner -eq $ManagerPid){$null=[P09Access]::SetWindowPos($raised,[IntPtr]::new(-2),0,0,0,0,0x13)}}
if($ResultFile){$result|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $ResultFile -Encoding UTF8}else{Write-Host ('P09_NATIVE_ACCESSIBILITY_FAILED '+$script:stage)}
if($result.status -ne 'PASSED'){exit 1}
