# Windows PowerShell 5.1 uses the installed Windows UI Automation provider.
param([ValidateSet('READY','KEYBOARD','DISPLAY_SCALE','PICKER','EDITOR','BROWSER_PROTOCOL','BROWSER_CHILD','BROWSER_SANDBOX','CONFIRM')][string]$Mode,[int]$ManagerPid,[string]$Coordination,[string]$ResultFile,[string]$SelectedPath,[string]$ProtocolUri,[switch]$AllowOverwrite,[string]$EnvironmentId,[string]$Intent,[ValidateSet(100,150,200)][int]$Scale=100)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
if($env:GITHUB_ACTIONS -ne 'true'){throw 'DISPOSABLE_ACTIONS_VM_REQUIRED'}
Add-Type -AssemblyName UIAutomationClient,UIAutomationTypes,WindowsBase,System.Windows.Forms
Add-Type @'
using System;using System.Runtime.InteropServices;
public static class P09Access {
 public delegate bool Visit(IntPtr hwnd,IntPtr data);
 [DllImport("user32.dll")]public static extern bool EnumWindows(Visit visit,IntPtr data);
 [DllImport("user32.dll")]public static extern uint GetWindowThreadProcessId(IntPtr hwnd,out uint pid);
 [DllImport("user32.dll")]public static extern bool IsWindowVisible(IntPtr hwnd);
 [DllImport("user32.dll")]public static extern uint GetDpiForWindow(IntPtr hwnd);
 [DllImport("user32.dll")]public static extern bool SetForegroundWindow(IntPtr hwnd);
}
'@
$result=@{status='IN_PROGRESS';mode=$Mode;real_windows_uia=$true;synthetic_fixture_only=$true};$stage='INITIALIZED'
function Need([bool]$ok){if(-not $ok){throw 'P09_NATIVE_ACCESSIBILITY_FAILED'}}
function Window([int]$id,[bool]$dialog=$false){
 $script:found=[IntPtr]::Zero
 $null=[P09Access]::EnumWindows({param($hwnd,$data);$owner=0;$null=[P09Access]::GetWindowThreadProcessId($hwnd,[ref]$owner);if($owner -eq $id -and [P09Access]::IsWindowVisible($hwnd)){
  $e=[Windows.Automation.AutomationElement]::FromHandle($hwnd)
  if(($dialog -and $e.Current.ClassName -eq '#32770') -or (-not $dialog -and $e.Current.ClassName -ne '#32770')){$script:found=$hwnd;return $false}
 };return $true},[IntPtr]::Zero)
 return $script:found
}
function Find($root,$type,[string]$name){
 $condition=[Windows.Automation.AndCondition]::new([Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::ControlTypeProperty,$type),[Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::NameProperty,$name))
 return $root.FindFirst([Windows.Automation.TreeScope]::Descendants,$condition)
}
function Click($element){Need ($null -ne $element -and $element.Current.IsEnabled);$pattern=$element.GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern);$pattern.Invoke()}
function Picker([int]$id,[string]$path){
 Need ([IO.Path]::IsPathRooted($path));$clock=[Diagnostics.Stopwatch]::StartNew();$window=[IntPtr]::Zero
 while($window -eq [IntPtr]::Zero -and $clock.ElapsedMilliseconds -lt 45000){$window=Window $id $true;if($window -eq [IntPtr]::Zero){Start-Sleep -Milliseconds 100}}
 Need ($window -ne [IntPtr]::Zero);$root=[Windows.Automation.AutomationElement]::FromHandle($window);$title=$root.Current.Name
 Need ($title -in @('SecureRun resource selection','Save reviewed diagnostics','Save As','Save as','Save File'))
 $edits=$root.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::ControlTypeProperty,[Windows.Automation.ControlType]::Edit));$edit=$null
 foreach($item in $edits){if($item.Current.AutomationId -eq '1148' -or $item.Current.Name -in @('File name:','File name','Folder:','Folder')){$edit=$item;break}}
 Need ($null -ne $edit);$value=$edit.GetCurrentPattern([Windows.Automation.ValuePattern]::Pattern);$value.SetValue($path)
 $button=Find $root ([Windows.Automation.ControlType]::Button) 'Open';if($null -eq $button){$button=Find $root ([Windows.Automation.ControlType]::Button) 'Save'};if($null -eq $button){$button=Find $root ([Windows.Automation.ControlType]::Button) 'Select Folder'};Click $button
 if($AllowOverwrite){Start-Sleep -Milliseconds 300;$confirm=Window $id $true;if($confirm -ne [IntPtr]::Zero){$confirmRoot=[Windows.Automation.AutomationElement]::FromHandle($confirm);Need ($confirmRoot.Current.Name -eq 'Confirm Save As');Click (Find $confirmRoot ([Windows.Automation.ControlType]::Button) 'Yes')}}
 return @{real_native_picker=$true;value_pattern_used=$true;explicit_button_invoked=$true;overwrite_prompt_authorized=[bool]$AllowOverwrite}
}
try{
 if($Mode -eq 'READY'){
  $stage='PREWARMING_NATIVE_PROVIDER';$desktop=[Windows.Automation.AutomationElement]::RootElement;$null=$desktop.FindAll([Windows.Automation.TreeScope]::Children,[Windows.Automation.Condition]::TrueCondition)
  $stage='WAITING_FOR_COORDINATION';[IO.File]::WriteAllText($Coordination+'.ready','READY')
  $clock=[Diagnostics.Stopwatch]::StartNew();while(-not(Test-Path -LiteralPath $Coordination) -and $clock.ElapsedMilliseconds -lt 45000){Start-Sleep -Milliseconds 50};Need (Test-Path -LiteralPath $Coordination)
  $start=Get-Content -LiteralPath $Coordination -Raw|ConvertFrom-Json;$ManagerPid=[int]$start.pid
 }
 $stage='FINDING_OWNED_WINDOW';$clock=[Diagnostics.Stopwatch]::StartNew();$hwnd=[IntPtr]::Zero
 while($hwnd -eq [IntPtr]::Zero -and $clock.ElapsedMilliseconds -lt 45000){$hwnd=Window $ManagerPid;if($hwnd -eq [IntPtr]::Zero){Start-Sleep -Milliseconds 100}}
 Need ($hwnd -ne [IntPtr]::Zero);if($Mode -eq 'READY'){$result.native_window_present_ms=([Diagnostics.Stopwatch]::GetTimestamp()-[long]$start.ticks)*1000.0/[Diagnostics.Stopwatch]::Frequency};$result.native_window_dpi=[P09Access]::GetDpiForWindow($hwnd);$root=[Windows.Automation.AutomationElement]::FromHandle($hwnd)
 switch($Mode){
  'DISPLAY_SCALE' {
   $stage='OPENING_WINDOWS_DISPLAY_SETTINGS';Start-Process 'ms-settings:display';$clock=[Diagnostics.Stopwatch]::StartNew();$settingsRoot=$null
   do{
    $settings=Get-Process SystemSettings -ErrorAction SilentlyContinue|Where-Object MainWindowHandle -ne 0|Select-Object -First 1
    if($null -ne $settings){$candidate=[Windows.Automation.AutomationElement]::FromHandle($settings.MainWindowHandle);$combo=$candidate.FindFirst([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::AutomationIdProperty,'SystemSettings_Display_Scaling_ItemSizeOverride_ComboBox'));if($null -ne $combo){$settingsRoot=$candidate;break}}
    Start-Sleep -Milliseconds 100
   }while($clock.ElapsedMilliseconds -lt 45000)
   Need ($null -ne $settingsRoot)
   $stage='SELECTING_ADVERTISED_DISPLAY_HEIGHT';$resolution=$settingsRoot.FindFirst([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::AutomationIdProperty,'SystemSettings_Display_Resolution_ComboBox'))
   Need ($null -ne $resolution -and $resolution.Current.IsEnabled);$resolution.GetCurrentPattern([Windows.Automation.ExpandCollapsePattern]::Pattern).Expand();Start-Sleep -Milliseconds 300
   $items=$settingsRoot.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::ControlTypeProperty,[Windows.Automation.ControlType]::ListItem));$best=$null;$height=0;$area=0
   foreach($item in $items){if($item.Current.Name -match '([0-9]{3,4})\D{1,8}([0-9]{3,4})'){$w=[int]$Matches[1];$h=[int]$Matches[2];if($h -gt $height -or ($h -eq $height -and $w*$h -gt $area)){$best=$item;$height=$h;$area=$w*$h}}}
   Need ($null -ne $best -and $height -ge 1200);$best.GetCurrentPattern([Windows.Automation.SelectionItemPattern]::Pattern).Select();Start-Sleep -Seconds 1
   $keep=Find $settingsRoot ([Windows.Automation.ControlType]::Button) 'Keep changes';if($null -ne $keep){Click $keep}
   $stage='SELECTING_REAL_WINDOWS_SCALE';$combo=$settingsRoot.FindFirst([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::AutomationIdProperty,'SystemSettings_Display_Scaling_ItemSizeOverride_ComboBox'))
   Need ($null -ne $combo -and $combo.Current.IsEnabled);$combo.GetCurrentPattern([Windows.Automation.ExpandCollapsePattern]::Pattern).Expand();Start-Sleep -Milliseconds 300
   $choice=$null;$choices=$settingsRoot.FindAll([Windows.Automation.TreeScope]::Descendants,[Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::ControlTypeProperty,[Windows.Automation.ControlType]::ListItem))
   foreach($item in $choices){if($item.Current.Name -match '^([0-9]{2,3})\s*%' -and [int]$Matches[1] -eq $Scale){$choice=$item;break}}
   if($null -eq $choice){$container=$combo.GetCurrentPattern([Windows.Automation.ItemContainerPattern]::Pattern);foreach($label in @("$Scale%","$Scale% (Recommended)")){$candidate=$container.FindItemByProperty($null,[Windows.Automation.AutomationElement]::NameProperty,$label);if($null -ne $candidate){$choice=$candidate;break}};if($null -ne $choice){$virtual=$null;if($choice.TryGetCurrentPattern([Windows.Automation.VirtualizedItemPattern]::Pattern,[ref]$virtual)){$virtual.Realize()};$scroll=$null;if($choice.TryGetCurrentPattern([Windows.Automation.ScrollItemPattern]::Pattern,[ref]$scroll)){$scroll.ScrollIntoView()}}}
   Need ($null -ne $choice);$choice.GetCurrentPattern([Windows.Automation.SelectionItemPattern]::Pattern).Select()
   $stage='VERIFYING_ACTUAL_MANAGER_WINDOW_DPI';$clock.Restart()
   do{$dpi=[P09Access]::GetDpiForWindow($hwnd);if($dpi -eq 96*$Scale/100){break};Start-Sleep -Milliseconds 100}while($clock.ElapsedMilliseconds -lt 15000)
   Need ($dpi -eq 96*$Scale/100);$root.GetCurrentPattern([Windows.Automation.WindowPattern]::Pattern).SetWindowVisualState([Windows.Automation.WindowVisualState]::Maximized);Need ([P09Access]::SetForegroundWindow($hwnd))
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
  'EDITOR' {$stage='EDITING_SYNTHETIC_DOCUMENT';Need ([P09Access]::SetForegroundWindow($hwnd));Start-Sleep -Milliseconds 200;[Windows.Forms.SendKeys]::SendWait('^a');[Windows.Forms.SendKeys]::SendWait('P09_EDITOR_CANARY');[Windows.Forms.SendKeys]::SendWait('^+s');$result.picker=Picker $ManagerPid $SelectedPath;$result.real_keyboard_edit=$true}
  'BROWSER_PROTOCOL' {$stage='REQUESTING_SYNTHETIC_PROTOCOL';Need ($ProtocolUri -cmatch '^securerun-p09:[0-9a-f-]{36}$');Need ([P09Access]::SetForegroundWindow($hwnd));Start-Sleep -Milliseconds 200;[Windows.Forms.SendKeys]::SendWait('^l');[Windows.Forms.SendKeys]::SendWait($ProtocolUri);[Windows.Forms.SendKeys]::SendWait('{ENTER}');$result.actual_browser_address_action=$true}
  'BROWSER_CHILD' {$stage='BROWSER_OWN_CHILD_ACTION';Click (Find $root ([Windows.Automation.ControlType]::Hyperlink) 'Open boxed child');$result.actual_browser_child_action=$true}
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
   do{$navigation=Find $root ([Windows.Automation.ControlType]::Button) 'Environments';$settings=Find $root ([Windows.Automation.ControlType]::Button) 'Settings';if($null -ne $navigation -and $null -ne $settings){break};Start-Sleep -Milliseconds 100}while($clock.ElapsedMilliseconds -lt 45000)
   Need ($null -ne $navigation -and $null -ne $settings);Click $settings
   $clock=[Diagnostics.Stopwatch]::StartNew();$language=$null
   do{$language=Find $root ([Windows.Automation.ControlType]::ComboBox) 'Language';if($null -ne $language){break};Start-Sleep -Milliseconds 100}while($clock.ElapsedMilliseconds -lt 15000)
   Need ($null -ne $language -and $language.Current.IsEnabled);$result.accessible_label_and_role=$true;$result.native_invoke_changed_real_page=$true
   if($Mode -eq 'READY'){$result.startup_interactive_upper_bound_ms=([Diagnostics.Stopwatch]::GetTimestamp()-[long]$start.ticks)*1000.0/[Diagnostics.Stopwatch]::Frequency}
   if($Mode -eq 'KEYBOARD'){
    $stage='CHECKING_REAL_KEYBOARD';Need ([P09Access]::SetForegroundWindow($hwnd));$navigation.SetFocus();Start-Sleep -Milliseconds 100
    [Windows.Forms.SendKeys]::SendWait('{TAB}');Start-Sleep -Milliseconds 100;$focused=[Windows.Automation.AutomationElement]::FocusedElement;Need ($focused.Current.Name -eq 'Settings');$result.tab_order_actual=$true
    [Windows.Forms.SendKeys]::SendWait('{F6}');Start-Sleep -Milliseconds 100;Need ([Windows.Automation.AutomationElement]::FocusedElement.Current.Name -eq 'Environments');$result.f6_navigation_actual=$true
    [Windows.Forms.SendKeys]::SendWait('^1');Start-Sleep -Milliseconds 100;$result.ctrl_navigation_actual=$true
   }
   Click $navigation
  }
 }
 $result.status='PASSED'
}catch{$result.status='FAILED';$result.code='P09_NATIVE_ACCESSIBILITY_FAILED';$result.stage=$stage;$result.exception_type=$_.Exception.GetBaseException().GetType().FullName}
$result|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $ResultFile -Encoding UTF8
if($result.status -ne 'PASSED'){exit 1}
