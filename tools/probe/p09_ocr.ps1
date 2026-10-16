# Lab-only in-memory OCR of an owned synthetic browser surface. No OCR text is persisted.
function Read-OwnedBrowserWords([IntPtr]$window,[int]$owner,[switch]$Support){
 $requiredTitle=if($Support){'Troubleshooting Information'}else{'P09 browser canary'};Need (([P09Access]::Caption($window)).Contains($requiredTitle))
 Need ([P09Access]::OwnedWindow($window,$owner));Focus-OwnedWindow $window $owner
 $rect=[P09Rect]::new();Need ([P09Access]::GetWindowRect($window,[ref]$rect));$width=$rect.Right-$rect.Left;$height=$rect.Bottom-$rect.Top
 Need ($width -ge 480 -and $height -ge 360 -and $width -le 4096 -and $height -le 4096)
 foreach($fx in @(0.1,0.5,0.9)){foreach($fy in @(0.1,0.5,0.9)){$point=[P09Point]::new();$point.X=$rect.Left+[int]($width*$fx);$point.Y=$rect.Top+[int]($height*$fy);$null=Owned-Point $point $window $owner}}
 Add-Type -AssemblyName System.Runtime.WindowsRuntime
 $null=[Windows.Media.Ocr.OcrEngine,Windows.Foundation,ContentType=WindowsRuntime]
 $null=[Windows.Graphics.Imaging.SoftwareBitmap,Windows.Foundation,ContentType=WindowsRuntime]
 $null=[Windows.Globalization.Language,Windows.Foundation,ContentType=WindowsRuntime]
 $engine=[Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage([Windows.Globalization.Language]::new('en-US'));Need ($null -ne $engine)
 $image=[Drawing.Bitmap]::new($width,$height,[Drawing.Imaging.PixelFormat]::Format32bppArgb);$draw=$null;$locked=$null;$software=$null
 try{
  $draw=[Drawing.Graphics]::FromImage($image);$draw.CopyFromScreen($rect.Left,$rect.Top,0,0,[Drawing.Size]::new($width,$height));$draw.Dispose();$draw=$null
  $locked=$image.LockBits([Drawing.Rectangle]::new(0,0,$width,$height),[Drawing.Imaging.ImageLockMode]::ReadOnly,[Drawing.Imaging.PixelFormat]::Format32bppArgb);Need ($locked.Stride -eq $width*4)
  $pixels=New-Object byte[] ($width*$height*4);[Runtime.InteropServices.Marshal]::Copy($locked.Scan0,$pixels,0,$pixels.Length);$image.UnlockBits($locked);$locked=$null
  $buffer=[Runtime.InteropServices.WindowsRuntime.WindowsRuntimeBufferExtensions]::AsBuffer($pixels)
  $software=[Windows.Graphics.Imaging.SoftwareBitmap]::CreateCopyFromBuffer($buffer,[Windows.Graphics.Imaging.BitmapPixelFormat]::Bgra8,$width,$height,[Windows.Graphics.Imaging.BitmapAlphaMode]::Ignore)
  $method=@([System.WindowsRuntimeSystemExtensions].GetMethods()|Where-Object {$_.Name -eq 'AsTask' -and $_.IsGenericMethodDefinition -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'});Need ($method.Count -eq 1)
  $task=$method[0].MakeGenericMethod([Windows.Media.Ocr.OcrResult]).Invoke($null,@($engine.RecognizeAsync($software)));Need ($task.Wait(15000));$recognized=$task.Result;$result.ocr_result_expected_type=($recognized -is [Windows.Media.Ocr.OcrResult]);Need $result.ocr_result_expected_type
  $lines=@($recognized.Lines);$result.ocr_line_count=$lines.Count;Need ($lines.Count -le 128);return @{lines=$lines;left=$rect.Left;top=$rect.Top;owned_window=$window}
 }finally{if($null -ne $software){$software.Dispose()};if($null -ne $locked){$image.UnlockBits($locked)};if($null -ne $draw){$draw.Dispose()};$image.Dispose()}
}
function Continue-VisualFirefoxWelcome([IntPtr]$window,[int]$owner){
 $script:stage='RECOGNIZING_OFFICIAL_FIREFOX_WELCOME';$view=Read-OwnedBrowserWords $window $owner;$result.native_windows_ocr_queried=$true
 $lines=@($view.lines);$heading=@($lines|Where-Object {$_.Text.Trim() -ceq 'Welcome to Firefox'});$continue=@($lines|Where-Object {$_.Text.Trim() -ceq 'Continue'})
 $text=($lines|ForEach-Object {$_.Text}) -join "`n";$terms=$text.Contains('Terms of Use');$privacy=$text.Contains('Privacy Notice')
 $result.visual_welcome_heading_observed=($heading.Count -eq 1);$result.visual_terms_notice_observed=$terms;$result.visual_privacy_notice_observed=$privacy;$result.visual_exact_continue_buttons=$continue.Count
 if($heading.Count -eq 0){return}
 Need ($heading.Count -eq 1 -and $terms -and $privacy -and $continue.Count -eq 1 -and @($continue[0].Words).Count -eq 1)
 $box=$continue[0].Words[0].BoundingRect;$point=[P09Point]::new();$point.X=$view.left+[int]($box.X+$box.Width/2);$point.Y=$view.top+[int]($box.Y+$box.Height/2)
 $script:stage='CONTINUING_VISUALLY_RECOGNIZED_FIREFOX_WELCOME';$null=Owned-Point $point $window $owner;Need ([P09Access]::SetCursorPos($point.X,$point.Y))
 try{[P09Access]::mouse_event(2,0,0,0,[UIntPtr]::Zero)}finally{[P09Access]::mouse_event(4,0,0,0,[UIntPtr]::Zero)};$result.official_welcome_continue_invoked=$true;$result.welcome_input='NATIVE_CLICK_WITH_EXACT_WINDOWS_OCR'
 Start-Sleep -Milliseconds 300;$clock=[Diagnostics.Stopwatch]::StartNew()
 do{$after=Read-OwnedBrowserWords $window $owner;$remaining=@($after.lines|Where-Object {$_.Text.Trim() -ceq 'Welcome to Firefox'});if($remaining.Count -eq 0){break};Start-Sleep -Milliseconds 200}while($clock.ElapsedMilliseconds -lt 15000)
 $result.known_welcome_dismissed=($remaining.Count -eq 0);Need $result.known_welcome_dismissed
}

function Copy-ActualAboutSupportData([IntPtr]$window,[int]$owner){
 # This reads the official diagnostic page transiently. Never save its pixels/text.
 $script:stage='LOCATING_NATIVE_ABOUT_SUPPORT_RAW_COPY';$view=Read-OwnedBrowserWords $window $owner -Support
 $heading=@($view.lines|Where-Object {$_.Text.Contains('Troubleshooting Information')});Need ($heading.Count -ge 1)
 $matches=[Collections.Generic.List[object]]::new()
 foreach($line in $view.lines){
  $words=@($line.Words);Need ($words.Count -le 128)
  for($index=0;$index -le $words.Count-5;$index++){
   $phrase=($words[$index..($index+4)]|ForEach-Object {$_.Text}) -join ' '
   if($phrase -ieq 'Copy raw data to clipboard'){$matches.Add(@($words[$index..($index+4)]))}
  }
 }
 $result.exact_about_support_raw_copy_buttons=$matches.Count;Need ($matches.Count -eq 1)
 $rectangles=@($matches[0]|ForEach-Object {$_.BoundingRect});$left=($rectangles|ForEach-Object {$_.X}|Measure-Object -Minimum).Minimum;$right=($rectangles|ForEach-Object {$_.X+$_.Width}|Measure-Object -Maximum).Maximum
 $top=($rectangles|ForEach-Object {$_.Y}|Measure-Object -Minimum).Minimum;$bottom=($rectangles|ForEach-Object {$_.Y+$_.Height}|Measure-Object -Maximum).Maximum
 $point=[P09Point]::new();$point.X=$view.left+[int](($left+$right)/2);$point.Y=$view.top+[int](($top+$bottom)/2)
 $null=Owned-Point $point $window $owner;Need ([P09Access]::SetCursorPos($point.X,$point.Y));[Windows.Forms.Clipboard]::Clear()
 try{[P09Access]::mouse_event(2,0,0,0,[UIntPtr]::Zero)}finally{[P09Access]::mouse_event(4,0,0,0,[UIntPtr]::Zero)}
 $result.native_about_support_raw_copy_invoked=$true;$result.sandbox_source='ABOUT_SUPPORT_NATIVE_OCR_RAW_COPY'
}
