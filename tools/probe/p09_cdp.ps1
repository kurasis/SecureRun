# Test-only inspector transport. No production command or remote endpoint.
$script:cdp=$null;$script:cdpId=0
function Connect-P09Cdp([int]$Port){
 $clock=[Diagnostics.Stopwatch]::StartNew();$page=$null
 do{try{$pages=Invoke-RestMethod -Uri "http://127.0.0.1:$Port/json/list" -TimeoutSec 2;$page=@($pages|Where-Object {$_.type -eq 'page' -and $_.url -match '^https://tauri\.localhost/'}|Select-Object -First 1)}catch{$page=@()};if($page.Count -eq 1){break};Start-Sleep -Milliseconds 100}while($clock.ElapsedMilliseconds -lt 45000)
 if($page.Count -ne 1){throw 'P09_NORMAL_WEBVIEW_INSPECTOR_NOT_READY'}
 $uri=[Uri]$page[0].webSocketDebuggerUrl;if(-not $uri.IsLoopback -or $uri.Scheme -ne 'ws' -or $uri.Port -ne $Port){throw 'P09_INSPECTOR_SCOPE_REJECTED'}
 $script:cdp=[Net.WebSockets.ClientWebSocket]::new();$cancel=[Threading.CancellationTokenSource]::new(15000)
 try{$script:cdp.ConnectAsync($uri,$cancel.Token).GetAwaiter().GetResult()}finally{$cancel.Dispose()}
}
function Send-P09Cdp([string]$Method,[hashtable]$Parameters=@{}){
 if($null -eq $script:cdp){throw 'P09_INSPECTOR_NOT_CONNECTED'};$script:cdpId++;$id=$script:cdpId
 $json=ConvertTo-Json -InputObject @{id=$id;method=$Method;params=$Parameters} -Depth 32 -Compress;$bytes=[Text.Encoding]::UTF8.GetBytes($json);$cancel=[Threading.CancellationTokenSource]::new(300000)
 try{
  $script:cdp.SendAsync([ArraySegment[byte]]::new($bytes),[Net.WebSockets.WebSocketMessageType]::Text,$true,$cancel.Token).GetAwaiter().GetResult()
  for($messages=0;$messages -lt 512;$messages++){
   $stream=[IO.MemoryStream]::new()
   try{do{$buffer=[byte[]]::new(65536);$read=$script:cdp.ReceiveAsync([ArraySegment[byte]]::new($buffer),$cancel.Token).GetAwaiter().GetResult();if($read.MessageType -ne [Net.WebSockets.WebSocketMessageType]::Text){throw 'P09_INSPECTOR_MESSAGE_INVALID'};$stream.Write($buffer,0,$read.Count);if($stream.Length -gt 8388608){throw 'P09_INSPECTOR_RESPONSE_BOUND'}}while(-not $read.EndOfMessage)
    $response=[Text.Encoding]::UTF8.GetString($stream.ToArray())|ConvertFrom-Json -Depth 64
   }finally{$stream.Dispose()}
   if($response.PSObject.Properties['id'] -and $response.id -eq $id){if($response.PSObject.Properties['error']){throw 'P09_INSPECTOR_COMMAND_FAILED'};return $response.result}
  }
  throw 'P09_INSPECTOR_NOTIFICATION_BOUND'
 }finally{$cancel.Dispose()}
}
function Evaluate-P09([string]$Expression){
 $result=Send-P09Cdp 'Runtime.evaluate' @{expression=$Expression;awaitPromise=$true;returnByValue=$true}
 if($result.PSObject.Properties['exceptionDetails'] -or -not $result.result.PSObject.Properties['value']){throw 'P09_INSPECTOR_EVALUATION_FAILED'}
 return $result.result.value
}
function Invoke-P09Stage([string]$Stage,[hashtable]$Config=@{}){
 $stageJson=ConvertTo-Json -InputObject $Stage -Compress;$configJson=ConvertTo-Json -InputObject $Config -Depth 8 -Compress
 $r=Evaluate-P09 "window.__p09_run($stageJson,$configJson)";$script:lastUi=$r
 foreach($case in $r.cases){$script:uiCases.Add($case)}
 if($r.status -ne 'PASSED'){throw 'P09_REAL_PRODUCT_UI_FAILED'}
 return $r
}
function Close-P09Cdp {if($null -ne $script:cdp){$script:cdp.Dispose();$script:cdp=$null}}
