# Test-only inspector transport. No production command or remote endpoint.
$script:cdp=$null;$script:cdpId=0
function Connect-P09Cdp([int]$Port){
 $clock=[Diagnostics.Stopwatch]::StartNew();$page=$null
 do{try{$pages=Invoke-RestMethod -Uri "http://127.0.0.1:$Port/json/list" -TimeoutSec 2;$page=@($pages|Where-Object {$_.type -eq 'page' -and $_.url -match '^https://tauri\.localhost/'}|Select-Object -First 1)}catch{$page=@()};if($page.Count -eq 1){break};Start-Sleep -Milliseconds 100}while($clock.ElapsedMilliseconds -lt 45000)
 if($page.Count -ne 1){throw 'P09_NORMAL_WEBVIEW_INSPECTOR_NOT_READY'}
 $uri=[Uri]$page[0].webSocketDebuggerUrl;if(-not $uri.IsLoopback -or $uri.Scheme -ne 'ws' -or $uri.Port -ne $Port){throw 'P09_INSPECTOR_SCOPE_REJECTED'}
 $script:cdp=[Net.WebSockets.ClientWebSocket]::new();$cancel=[Threading.CancellationTokenSource]::new(15000)
 try{$null=$script:cdp.ConnectAsync($uri,$cancel.Token).GetAwaiter().GetResult()}finally{$cancel.Dispose()}
}
function Send-P09Cdp([string]$Method,[hashtable]$Parameters=@{},[ValidateSet(300000,660000)][int]$TimeoutMs=300000){
 if($null -eq $script:cdp){throw 'P09_INSPECTOR_NOT_CONNECTED'};$script:cdpId++;$id=$script:cdpId
 $json=ConvertTo-Json -InputObject @{id=$id;method=$Method;params=$Parameters} -Depth 32 -Compress;$bytes=[Text.Encoding]::UTF8.GetBytes($json);$cancel=[Threading.CancellationTokenSource]::new($TimeoutMs)
 try{
  $null=$script:cdp.SendAsync([ArraySegment[byte]]::new($bytes),[Net.WebSockets.WebSocketMessageType]::Text,$true,$cancel.Token).GetAwaiter().GetResult()
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
function Evaluate-P09([string]$Expression,[ValidateSet(300000,660000)][int]$TimeoutMs=300000){
 $result=Send-P09Cdp 'Runtime.evaluate' @{expression=$Expression;awaitPromise=$true;returnByValue=$true} $TimeoutMs
 if($result.PSObject.Properties['exceptionDetails']){
  $detail=$result.exceptionDetails;$code='P09_INSPECTOR_EVALUATION_FAILED'
  if($detail.PSObject.Properties['exception'] -and $detail.exception.PSObject.Properties['description']){
   $description=[string]$detail.exception.description
   if($description.Contains('window.__p09_run is not a function')){$code='P09_BOOTSTRAP_FUNCTION_MISSING'}
   elseif($description.Contains('unsafe-eval')){$code='P09_INSPECTOR_EVALUATION_CSP_REFUSED'}
  }
  if(Get-Variable results -ErrorAction SilentlyContinue){@{code=$code;line=$detail.lineNumber;column=$detail.columnNumber;raw_exception_withheld=$true}|ConvertTo-Json|Set-Content (Join-Path $results 'inspector-evaluation.json') -Encoding utf8}
  throw $code
 }
 if(-not $result.PSObject.Properties['result'] -or -not $result.result.PSObject.Properties['value']){throw 'P09_INSPECTOR_RESULT_VALUE_MISSING'}
 return $result.result.value
}
function Wait-P09Document {
 $clock=[Diagnostics.Stopwatch]::StartNew()
 do{if(Evaluate-P09 "document.readyState==='complete' && !!document.querySelector('nav button') && typeof window.__TAURI_INTERNALS__?.invoke==='function'"){return};Start-Sleep -Milliseconds 100}while($clock.ElapsedMilliseconds -lt 45000)
 throw 'P09_NORMAL_DOCUMENT_NOT_READY'
}
function Invoke-P09Stage([string]$Stage,[hashtable]$Config=@{}){
 $stageJson=ConvertTo-Json -InputObject $Stage -Compress;$configJson=ConvertTo-Json -InputObject $Config -Depth 8 -Compress
 $deadline=if($Stage -in @('STOP_AND_APPLY','FILE_LIST')){660000}else{300000}
 $r=Evaluate-P09 "window.__p09_run($stageJson,$configJson)" $deadline;$script:lastUi=$r
 foreach($case in $r.cases){$script:uiCases.Add($case)}
 if($r.status -ne 'PASSED'){$r|ConvertTo-Json -Depth 12|Set-Content (Join-Path $results 'ui-failure.json') -Encoding utf8;if($r.code -cmatch '^P09_[A-Z0-9_]{1,100}$'){throw $r.code};throw 'P09_REAL_PRODUCT_UI_FAILED'}
 return $r
}
function Close-P09Cdp {if($null -ne $script:cdp){$script:cdp.Dispose();$script:cdp=$null}}
