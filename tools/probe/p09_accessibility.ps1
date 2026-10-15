# Windows PowerShell 5.1 uses the installed Windows UI Automation provider.
param([ValidateSet('READY','KEYBOARD','DISPLAY_SCALE','DISPLAY_CONTROLLER','DISPLAY_SERVER','PICKER','EDITOR','BROWSER_PROTOCOL','BROWSER_CHILD','BROWSER_SANDBOX','CONFIRM')][string]$Mode,[int]$ManagerPid,[string]$Coordination,[string]$ResultFile,[string]$SelectedPath,[string]$ProtocolUri,[switch]$AllowOverwrite,[string]$EnvironmentId,[string]$Intent,[ValidateSet(100,150,200)][int]$Scale=100,[switch]$CloseSettings,[string]$DisplayEvents)
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
public static class P09Access {
 public delegate bool Visit(IntPtr hwnd,IntPtr data);
 [DllImport("user32.dll")]public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
 public static bool OwnedWindow(IntPtr window,uint expected){uint pid=0;GetWindowThreadProcessId(window,out pid);if(pid==expected)return true;IntPtr root=GetAncestor(window,2);if(root!=IntPtr.Zero){GetWindowThreadProcessId(root,out pid);if(pid==expected)return true;}return RootOwnerPid(window)==expected;}
 [DllImport("user32.dll")]public static extern IntPtr WindowFromPoint(P09Point point);
 [DllImport("user32.dll")]public static extern IntPtr GetAncestor(IntPtr window,uint flags);
 [DllImport("user32.dll")]public static extern bool SetWindowPos(IntPtr window,IntPtr after,int x,int y,int width,int height,uint flags);
 public static uint RootOwnerPid(IntPtr window){uint pid=0;IntPtr root=GetAncestor(window,3);if(root!=IntPtr.Zero)GetWindowThreadProcessId(root,out pid);return pid;}
 [DllImport("user32.dll")]public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")]public static extern void mouse_event(uint flags,uint x,uint y,uint data,UIntPtr extra);
 [DllImport("user32.dll")]public static extern bool EnumWindows(Visit visit,IntPtr data);
 [DllImport("user32.dll")]public static extern uint GetWindowThreadProcessId(IntPtr hwnd,out uint pid);
 [DllImport("user32.dll")]public static extern bool IsWindowVisible(IntPtr hwnd);
 [DllImport("user32.dll")]public static extern uint GetDpiForWindow(IntPtr hwnd);
 [DllImport("user32.dll")]public static extern bool SetForegroundWindow(IntPtr hwnd);
 [DllImport("user32.dll")]public static extern IntPtr GetForegroundWindow();
}
'@
if([P09Access]::SetThreadDpiAwarenessContext([IntPtr]::new(-4)) -eq [IntPtr]::Zero){throw 'P09_HELPER_DPI_CONTEXT_FAILED'}
$script:displayRoot=$null;$script:displayWindow=[IntPtr]::Zero
$result=@{status='IN_PROGRESS';mode=$Mode;real_windows_uia=$true;synthetic_fixture_only=$true;helper_per_monitor_dpi_aware=$true};$stage='INITIALIZED'
function Need([bool]$ok){if(-not $ok){throw 'P09_NATIVE_ACCESSIBILITY_FAILED'}}
function Window([int]$id,[bool]$dialog=$false){
 $script:found=[IntPtr]::Zero;$script:foundArea=0
 $null=[P09Access]::EnumWindows({param($hwnd,$data);$owner=0;$null=[P09Access]::GetWindowThreadProcessId($hwnd,[ref]$owner);if($owner -eq $id -and [P09Access]::IsWindowVisible($hwnd)){
  $e=[Windows.Automation.AutomationElement]::FromHandle($hwnd)
  if($dialog -and $e.Current.ClassName -eq '#32770'){$script:found=$hwnd;return $false};if(-not $dialog -and $e.Current.ClassName -ne '#32770'){$rectangle=$e.Current.BoundingRectangle;$area=$rectangle.Width*$rectangle.Height;if($area -gt $script:foundArea){$script:found=$hwnd;$script:foundArea=$area}}
 };return $true},[IntPtr]::Zero)
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
function Focus-OwnedProvider($element,$root,[IntPtr]$hwnd,[int]$id){
$script:stage='FINDING_ENABLED_EDITOR_PROVIDER';$result.editor_provider_present=($null -ne $element)
 Need ($null -ne $element -and $element.Current.IsEnabled)
 $root.GetCurrentPattern([Windows.Automation.WindowPattern]::Pattern).SetWindowVisualState([Windows.Automation.WindowVisualState]::Normal)
 Need ([P09Access]::SetWindowPos($hwnd,[IntPtr]::Zero,0,0,0,0,0x13));$null=[P09Access]::SetForegroundWindow($hwnd);$element.SetFocus();Start-Sleep -Milliseconds 100
 $clickable=$element.GetClickablePoint();$point=[P09Point]::new();$point.X=[int]$clickable.X;$point.Y=[int]$clickable.Y
$script:stage='VERIFYING_EDITOR_CLICK_POINT';$result.editor_point_owned=[P09Access]::OwnedWindow([P09Access]::WindowFromPoint($point),$id);$result.editor_exact_provider_hit=(In-Provider ([Windows.Automation.AutomationElement]::FromPoint($clickable)) $element)
 Need ($result.editor_point_owned -and $result.editor_exact_provider_hit)
 Need ([P09Access]::SetCursorPos($point.X,$point.Y));try{[P09Access]::mouse_event(2,0,0,0,[UIntPtr]::Zero)}finally{[P09Access]::mouse_event(4,0,0,0,[UIntPtr]::Zero)}
 $script:stage='VERIFYING_EDITOR_FOREGROUND_AND_FOCUS'
 $clock=[Diagnostics.Stopwatch]::StartNew();do{if([P09Access]::OwnedWindow([P09Access]::GetForegroundWindow(),$id) -and (In-Provider ([Windows.Automation.AutomationElement]::FocusedElement) $element)){break};Start-Sleep -Milliseconds 50}while($clock.ElapsedMilliseconds -lt 5000)
 Need ([P09Access]::OwnedWindow([P09Access]::GetForegroundWindow(),$id) -and (In-Provider ([Windows.Automation.AutomationElement]::FocusedElement) $element))
}
function Owned-Link([int]$id,[string]$name){
 $script:matchedLink=$null
 $null=[P09Access]::EnumWindows({param($window,$data);$owner=0;$null=[P09Access]::GetWindowThreadProcessId($window,[ref]$owner)
  if($owner -eq $id -and [P09Access]::IsWindowVisible($window)){$candidate=[Windows.Automation.AutomationElement]::FromHandle($window);$link=Find $candidate ([Windows.Automation.ControlType]::Hyperlink) $name;if($null -ne $link){$script:matchedLink=$link;return $false}}
  return $true
 },[IntPtr]::Zero)
 return $script:matchedLink
}
function Click($element){Need ($null -ne $element -and $element.Current.IsEnabled);$pattern=$element.GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern);$pattern.Invoke()}
function Picker([int]$id,[string]$path){
 $script:stage='WAITING_FOR_NATIVE_PICKER'
 Need ([IO.Path]::IsPathRooted($path));$clock=[Diagnostics.Stopwatch]::StartNew();$window=[IntPtr]::Zero
 while($window -eq [IntPtr]::Zero -and $clock.ElapsedMilliseconds -lt 45000){$window=Window $id $true;if($window -eq [IntPtr]::Zero){Start-Sleep -Milliseconds 100}}
 Need ($window -ne [IntPtr]::Zero);$root=[Windows.Automation.AutomationElement]::FromHandle($window);$title=$root.Current.Name;$script:stage='VERIFYING_NATIVE_PICKER_TITLE'
 if($title.StartsWith('[#] ') -and $title.EndsWith(' [#]')){$title=$title.Substring(4,$title.Length-8)}
 $result.native_picker_title_recognized=($title -in @('SecureRun resource selection','SecureRun file selection','Save reviewed diagnostics','Save As','Save as','Save File'))
 Need ($title -in @('SecureRun resource selection','SecureRun file selection','Save reviewed diagnostics','Save As','Save as','Save File'))
 $edits=$root.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::ControlTypeProperty,[Windows.Automation.ControlType]::Edit));$edit=$null
 foreach($item in $edits){if($item.Current.AutomationId -eq '1148' -or $item.Current.Name -in @('File name:','File name','Folder:','Folder')){$edit=$item;break}}
 Need ($null -ne $edit);$value=$edit.GetCurrentPattern([Windows.Automation.ValuePattern]::Pattern);$value.SetValue($path)
 $button=Find $root ([Windows.Automation.ControlType]::Button) 'Open';if($null -eq $button){$button=Find $root ([Windows.Automation.ControlType]::Button) 'Save'};if($null -eq $button){$button=Find $root ([Windows.Automation.ControlType]::Button) 'Select Folder'};Click $button
 if($AllowOverwrite){Start-Sleep -Milliseconds 300;$confirm=Window $id $true;if($confirm -ne [IntPtr]::Zero){$confirmRoot=[Windows.Automation.AutomationElement]::FromHandle($confirm);Need ($confirmRoot.Current.Name -eq 'Confirm Save As');Click (Find $confirmRoot ([Windows.Automation.ControlType]::Button) 'Yes')}}
 return @{real_native_picker=$true;value_pattern_used=$true;explicit_button_invoked=$true;overwrite_prompt_authorized=[bool]$AllowOverwrite}
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
   Need ($null -ne $best -and $height -ge 1200);$best.GetCurrentPattern([Windows.Automation.SelectionItemPattern]::Pattern).Select();Start-Sleep -Seconds 1
   $keep=Find $settingsRoot ([Windows.Automation.ControlType]::Button) 'Keep changes';if($null -ne $keep){Click $keep}
   $script:stage='SELECTING_REAL_WINDOWS_SCALE';$combo=$settingsRoot.FindFirst([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::AutomationIdProperty,'SystemSettings_Display_Scaling_ItemSizeOverride_ComboBox'))
   Need ($null -ne $combo -and $combo.Current.IsEnabled);$combo.GetCurrentPattern([Windows.Automation.ExpandCollapsePattern]::Pattern).Expand();Start-Sleep -Milliseconds 300
   $choice=$null;$choices=$settingsRoot.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::ControlTypeProperty,[Windows.Automation.ControlType]::ListItem))
   foreach($item in $choices){if($item.Current.Name -match '^([0-9]{2,3})\s*%' -and [int]$Matches[1] -eq $Scale){$choice=$item;break}}
   if($null -eq $choice){$container=$combo.GetCurrentPattern([Windows.Automation.ItemContainerPattern]::Pattern);foreach($label in @("$Scale%","$Scale% (Recommended)")){$candidate=$container.FindItemByProperty($null,[Windows.Automation.AutomationElement]::NameProperty,$label);if($null -ne $candidate){$choice=$candidate;break}};if($null -ne $choice){$virtual=$null;if($choice.TryGetCurrentPattern([Windows.Automation.VirtualizedItemPattern]::Pattern,[ref]$virtual)){$virtual.Realize()};$scroll=$null;if($choice.TryGetCurrentPattern([Windows.Automation.ScrollItemPattern]::Pattern,[ref]$scroll)){$scroll.ScrollIntoView()}}}
   Need ($null -ne $choice);$choice.GetCurrentPattern([Windows.Automation.SelectionItemPattern]::Pattern).Select()

 $clock.Restart();do{$dpi=[P09Access]::GetDpiForWindow($script:displayWindow);if($dpi -eq 96*$Scale/100){break};Start-Sleep -Milliseconds 100}while($clock.ElapsedMilliseconds -lt 15000);Need ($dpi -eq 96*$Scale/100)
 $window=$null;if($CloseSettings -and $settingsRoot.TryGetCurrentPattern([Windows.Automation.WindowPattern]::Pattern,[ref]$window)){$window.Close();$script:displayRoot=$null;$script:displayWindow=[IntPtr]::Zero}
}
if($Mode -eq 'DISPLAY_SERVER'){
 Need ($DisplayEvents -cmatch '^Local\\SecureRunP09Display-[0-9a-f]{32}$' -and [IO.Path]::IsPathRooted($ResultFile))
 $events=@();$serverClock=[Diagnostics.Stopwatch]::StartNew();$requests=0
 try{
  $script:stage='OPENING_OWNER_RESTRICTED_EVENTS'
  $rights=[Security.AccessControl.EventWaitHandleRights]::Synchronize -bor [Security.AccessControl.EventWaitHandleRights]::Modify
  foreach($suffix in @('100','150','200','done','failed')){$events+=,[Threading.EventWaitHandle]::OpenExisting($DisplayEvents+'-'+$suffix,$rights)}
  Server-Status 'EVENTS_OPENED'
  $prepared=@{mode='DISPLAY_PREPARATION';requested_windows_scale=100;status='FAILED';real_windows_uia=$true;synthetic_fixture_only=$true;os_security_settings_modified=$false;excluded_from_product_startup_measurement=$true}
  try{Set-ActualDisplayScale 100;$prepared.status='PASSED'}catch{$prepared.stage=$script:stage;$prepared.exception_type=$_.Exception.GetBaseException().GetType().FullName}
  $prepared|ConvertTo-Json|Set-Content -LiteralPath ($ResultFile+'.preparation.json') -Encoding UTF8
  if($prepared.status -ne 'PASSED'){$null=$events[4].Set();exit 1}
  Server-Status 'READY'
  $null=$events[3].Set() # Parent consumes readiness before starting the actor.
  while($serverClock.ElapsedMilliseconds -lt 3000000){
   $index=[Threading.WaitHandle]::WaitAny([Threading.WaitHandle[]]$events[0..2],1000)
   if($index -ge 3){continue}
   $requests++;if($requests -gt 8){$null=$events[4].Set();break}
   $record=@{mode='DISPLAY_CONTROLLER';requested_windows_scale=@(100,150,200)[$index];status='FAILED';real_windows_uia=$true;synthetic_fixture_only=$true;os_security_settings_modified=$false}
   try{$script:CloseSettings=($index -eq 0 -and $requests -gt 1);Set-ActualDisplayScale $record.requested_windows_scale;$record.status='PASSED'}
   catch{$record.code='P09_NATIVE_ACCESSIBILITY_FAILED';$record.stage=$script:stage;$record.exception_type=$_.Exception.GetBaseException().GetType().FullName}
   $record|ConvertTo-Json|Set-Content -LiteralPath ($ResultFile+'.'+$requests+'.json') -Encoding UTF8
   if($record.status -eq 'PASSED'){$null=$events[3].Set()}else{$null=$events[4].Set()}
  }
 }finally{foreach($event in $events){$event.Dispose()}}
 exit 0
}
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
 Need ($hwnd -ne [IntPtr]::Zero);if($Mode -eq 'READY'){$result.native_window_present_ms=([Diagnostics.Stopwatch]::GetTimestamp()-[long]$start.ticks)*1000.0/[Diagnostics.Stopwatch]::Frequency};$result.native_window_dpi=[P09Access]::GetDpiForWindow($hwnd);$root=[Windows.Automation.AutomationElement]::FromHandle($hwnd)
 switch($Mode){
  'DISPLAY_SCALE' {
   $stage='REQUESTING_LAB_DISPLAY_CONTROLLER';$prefix=$env:SECURERUN_P09_DISPLAY_EVENTS
   Need ($prefix -cmatch '^Local\\SecureRunP09Display-[0-9a-f]{32}$')
   $request=$null;$done=$null;$failed=$null
   try{$rights=[Security.AccessControl.EventWaitHandleRights]::Synchronize -bor [Security.AccessControl.EventWaitHandleRights]::Modify;$request=[Threading.EventWaitHandle]::OpenExisting($prefix+'-'+$Scale,$rights);$done=[Threading.EventWaitHandle]::OpenExisting($prefix+'-done',$rights);$failed=[Threading.EventWaitHandle]::OpenExisting($prefix+'-failed',$rights);$null=$request.Set();$index=[Threading.WaitHandle]::WaitAny([Threading.WaitHandle[]]@($done,$failed),120000);Need ($index -eq 0)}
   finally{foreach($event in @($request,$done,$failed)){if($null -ne $event){$event.Dispose()}}}
   $stage='VERIFYING_ACTUAL_MANAGER_WINDOW_DPI';$clock.Restart()
   do{$dpi=[P09Access]::GetDpiForWindow($hwnd);if($dpi -eq 96*$Scale/100){break};Start-Sleep -Milliseconds 100}while($clock.ElapsedMilliseconds -lt 15000)
   Need ($dpi -eq 96*$Scale/100);$root.GetCurrentPattern([Windows.Automation.WindowPattern]::Pattern).SetWindowVisualState([Windows.Automation.WindowVisualState]::Maximized);$null=[P09Access]::SetForegroundWindow($hwnd)
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
  'EDITOR' {$stage='EDITING_SYNTHETIC_DOCUMENT';$editor=$root.FindFirst([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.AndCondition]::new([Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::ClassNameProperty,'Scintilla'),[Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::IsOffscreenProperty,$false)));Focus-OwnedProvider $editor $root $hwnd $ManagerPid;$result.exact_editor_focus_verified=$true;[Windows.Forms.SendKeys]::SendWait('^a');[Windows.Forms.SendKeys]::SendWait('P09_EDITOR_CANARY');[Windows.Forms.SendKeys]::SendWait('^+s');$result.picker=Picker $ManagerPid $SelectedPath;$result.real_keyboard_edit=$true}
  'BROWSER_PROTOCOL' {$stage='REQUESTING_SYNTHETIC_PROTOCOL';Need ($ProtocolUri -cmatch '^securerun-p09:[0-9a-f-]{36}$');Need ([P09Access]::SetForegroundWindow($hwnd));Start-Sleep -Milliseconds 200;[Windows.Forms.SendKeys]::SendWait('^l');[Windows.Forms.SendKeys]::SendWait($ProtocolUri);[Windows.Forms.SendKeys]::SendWait('{ENTER}');$result.actual_browser_address_action=$true
   # Preserve Firefox's protocol warning. Confirm only this synthetic protocol,
   # through its owned native provider; never toggle a persistent permission.
   $stage='CONFIRMING_SYNTHETIC_PROTOCOL_PROMPT';$clock=[Diagnostics.Stopwatch]::StartNew();$result.browser_protocol_confirmation_invoked=$false
   do{
    $open=Find $root ([Windows.Automation.ControlType]::Button) 'Open Link'
    if($null -ne $open -and $open.Current.IsEnabled){
     $labels=$root.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.Condition]::TrueCondition)
     Need ($labels.Count -le 10000);$content=($labels|ForEach-Object {$_.Current.Name}) -join "`n"
     Need ($content.Contains('securerun-p09'));Click $open;$result.browser_protocol_confirmation_invoked=$true;break
    }
    Start-Sleep -Milliseconds 100
   }while($clock.ElapsedMilliseconds -lt 10000)
  }
  'BROWSER_CHILD' {
   $stage='BROWSER_OWN_CHILD_ACTION';$clock=[Diagnostics.Stopwatch]::StartNew();$link=$null
   do{$link=Owned-Link $ManagerPid 'Open boxed child';if($null -ne $link){break};Start-Sleep -Milliseconds 100}while($clock.ElapsedMilliseconds -lt 30000)
   Need ($null -ne $link -and $link.Current.IsEnabled);$pattern=$null
   if($link.TryGetCurrentPattern([Windows.Automation.InvokePattern]::Pattern,[ref]$pattern)){$pattern.Invoke();$result.native_link_invoke_used=$true}
   else{Need ($link.TryGetCurrentPattern([Windows.Automation.LegacyIAccessiblePattern]::Pattern,[ref]$pattern));$pattern.DoDefaultAction();$result.native_legacy_default_action_used=$true}
   $result.actual_browser_child_action=$true
  }
  'BROWSER_SANDBOX' {
   $stage='READING_BROWSER_SANDBOX_STATE';Need ([P09Access]::SetForegroundWindow($hwnd));[Windows.Forms.Clipboard]::Clear();[Windows.Forms.SendKeys]::SendWait('^l');[Windows.Forms.SendKeys]::SendWait('about:support');[Windows.Forms.SendKeys]::SendWait('{ENTER}')
   $clock=[Diagnostics.Stopwatch]::StartNew();$copy=$null
   do{$copy=Find $root ([Windows.Automation.ControlType]::Button) 'Copy raw data to clipboard';if($null -ne $copy){break};Start-Sleep -Milliseconds 100}while($clock.ElapsedMilliseconds -lt 30000)
   Click $copy;$clock=[Diagnostics.Stopwatch]::StartNew();$data=$null
   do{$text=[Windows.Forms.Clipboard]::GetText();Need ($text.Length -le 2097152);if($text.StartsWith('{')){$data=$text|ConvertFrom-Json;break};Start-Sleep -Milliseconds 100}while($clock.ElapsedMilliseconds -lt 10000)
   Need ($null -ne $data -and $null -ne $data.sandbox);$result.observed_sandbox_property_names=@($data.sandbox.PSObject.Properties.Name)
   Need ($null -ne $data.sandbox.PSObject.Properties['effectiveContentSandboxLevel']);$level=[int]$data.sandbox.effectiveContentSandboxLevel;Need ($level -gt 0)
   $result.effective_content_sandbox_level=$level;$result.browser_own_sandbox_enabled=$true;$result.real_about_support=$true
   [Windows.Forms.Clipboard]::Clear()
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
    $stage='FOCUSING_OWNED_MANAGER';$root.GetCurrentPattern([Windows.Automation.WindowPattern]::Pattern).SetWindowVisualState([Windows.Automation.WindowVisualState]::Normal);Need ([P09Access]::SetWindowPos($hwnd,[IntPtr]::Zero,0,0,0,0,0x13));$null=[P09Access]::SetForegroundWindow($hwnd);$navigation.SetFocus();Start-Sleep -Milliseconds 100
    $clickable=$navigation.GetClickablePoint();$point=[P09Point]::new();$point.X=[int]$clickable.X;$point.Y=[int]$clickable.Y
    $hit=[P09Access]::WindowFromPoint($point);$hitOwner=[P09Access]::RootOwnerPid($hit);$result.keyboard_point_hits_window=($hit -ne [IntPtr]::Zero);$result.keyboard_native_root_owner_matches_manager=($hitOwner -eq $ManagerPid);$result.keyboard_native_window_owned=[P09Access]::OwnedWindow($hit,$ManagerPid);$result.keyboard_exact_navigation_provider_verified=(In-Provider ([Windows.Automation.AutomationElement]::FromPoint($clickable)) $navigation);$result.keyboard_click_hit_owned_window=($result.keyboard_native_window_owned -and $result.keyboard_exact_navigation_provider_verified)
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
}catch{$result.status='FAILED';$result.code='P09_NATIVE_ACCESSIBILITY_FAILED';$result.stage=$stage;$result.exception_type=$_.Exception.GetBaseException().GetType().FullName}
if($ResultFile){$result|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $ResultFile -Encoding UTF8}else{Write-Host ('P09_NATIVE_ACCESSIBILITY_FAILED '+$script:stage)}
if($result.status -ne 'PASSED'){exit 1}
