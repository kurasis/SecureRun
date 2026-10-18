#ifndef Payload
  #error Payload directory is required
#endif
#ifndef PackageVersion
  #define PackageVersion "0.3.0.11"
#endif
[Setup]
AppId={{8D1CCF8A-EF24-4B6F-B041-45935A1868B3}
AppName=SecureRun Development
AppVersion={#PackageVersion}
AppPublisher=kurasis/SecureRun contributors
AppPublisherURL=https://github.com/kurasis/SecureRun
DefaultDirName={autopf}\SecureRun Development
UsePreviousAppDir=no
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed={#Architecture}
ArchitecturesInstallIn64BitMode={#Architecture}
MinVersion=10.0.22000
OutputDir={#Output}
OutputBaseFilename=SecureRun-Development-{#PackageVersion}-{#Architecture}
Compression=lzma2
SolidCompression=yes
CloseApplications=no
RestartApplications=no
UninstallDisplayName=SecureRun Development (UNSIGNED)
UninstallDisplayIcon={app}\securerun.exe
SetupLogging=yes
InfoBeforeFile={#Payload}\DEVELOPMENT.txt
InfoAfterFile={#Payload}\RETENTION.txt
[Files]
Source: "{#Payload}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#Bootstrapper}"; Flags: dontcopy
Source: "{#CRTDirectory}\vc_redist.x86.exe"; Flags: dontcopy
Source: "{#CRTDirectory}\vc_redist.x64.exe"; Flags: dontcopy
#if Architecture == "arm64"
Source: "{#CRTDirectory}\vc_redist.arm64.exe"; Flags: dontcopy
#endif
[Icons]
Name: "{commonprograms}\SecureRun Development"; Filename: "{app}\securerun.exe"; WorkingDir: "{app}"
[Code]
#include GuardDataFile
function NewerVersion(Existing, Candidate: String): Boolean;
var A, B: Int64;
begin
  Result := True;
  if StrToVersion(Existing, A) and StrToVersion(Candidate, B) then
    Result := ComparePackedVersion(A, B) > 0;
end;
function GetModuleHandle(Name: String): THandle;
  external 'GetModuleHandleW@kernel32.dll stdcall';
function Guard(): Boolean;
var Code, I: Integer; Hex: String; Data: AnsiString; FileName: String;
begin
  Hex := EmbeddedGuardHex(); SetLength(Data, Length(Hex) div 2);
  for I := 1 to Length(Data) do Data[I] := Chr(StrToInt('$' + Copy(Hex, I*2-1, 2)));
  FileName := ExpandConstant('{tmp}\securerun-trusted-install-guard.exe');
  Result := False;
  if GetSHA256OfString(Data) <> '{#GuardSHA256}' then begin Log('P11_GUARD_EMBEDDED_HASH_INVALID'); exit; end;
  if not SaveStringToFile(FileName, Data, False) then begin Log('P11_GUARD_EXTRACTION_FAILED'); exit; end;
  if GetSHA256OfFile(FileName) <> '{#GuardSHA256}' then begin Log('P11_GUARD_EXTRACTED_HASH_INVALID'); exit; end;
  Log('P11_GUARD_EXACT_BYTES_VERIFIED');
  Result := Exec(FileName, 'preflight',
    ExpandConstant('{sys}'), SW_HIDE, ewWaitUntilTerminated, Code) and (Code = 0);
  Log(Format('P11_GUARD_EXIT_%d', [Code]));
end;
function InitializeSetup(): Boolean;
begin
  Result := GetModuleHandle('SbieDll.dll') = 0;
end;
function RuntimeAvailable(Architecture: String): Boolean;
var Version, Key: String; Installed: Cardinal; View: Integer;
begin
  Result := False; Key := 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\' + Architecture;
  for View := 0 to 1 do begin
    if View = 0 then begin
      if not RegQueryDWordValue(HKLM32, Key, 'Installed', Installed) then continue;
      if not RegQueryStringValue(HKLM32, Key, 'Version', Version) then continue;
    end else begin
      if not RegQueryDWordValue(HKLM64, Key, 'Installed', Installed) then continue;
      if not RegQueryStringValue(HKLM64, Key, 'Version', Version) then continue;
    end;
    if (Installed = 1) and (not NewerVersion('{#MinimumCRT}', Copy(Version,2,Length(Version)-1))) then begin
      Result := True; exit;
    end;
  end;
end;
function EnsureCRT(Architecture: String; var NeedsRestart: Boolean): String;
var Code: Integer; FileName: String;
begin
  Result := ''; if RuntimeAvailable(Architecture) then begin Log('P11_CRT_AVAILABLE_' + Uppercase(Architecture)); exit; end;
  Log('P11_CRT_INSTALL_REQUIRED_' + Uppercase(Architecture));
  FileName := 'vc_redist.' + Architecture + '.exe'; ExtractTemporaryFile(FileName);
  if not Exec(ExpandConstant('{tmp}\') + FileName, '/install /quiet /norestart',
     ExpandConstant('{sys}'), SW_HIDE, ewWaitUntilTerminated, Code) then begin
    Result := 'Official Microsoft C++ runtime installation could not start.'; exit;
  end;
  if ((Code <> 0) and (Code <> 3010)) or (not RuntimeAvailable(Architecture)) then begin
    Log(Format('P11_CRT_FAILED_EXIT_%d', [Code]));
    Result := 'Suitable Microsoft C++ runtime is unavailable; manager installation refused.'; exit;
  end;
  if Code = 3010 then NeedsRestart := True;
end;
function PrepareToInstall(var NeedsRestart: Boolean): String;
var Installed, ExitCode: Integer; Version: String;
begin
  Result := '';
  if CompareText(ExpandConstant('{app}'), ExpandConstant('{autopf}\SecureRun Development')) <> 0 then begin
    Result := 'SecureRun requires its fixed administrator-controlled Program Files directory.'; exit;
  end;
  if not Guard() then begin
    Log('P11_SETUP_GUARD_REFUSED');
    Result := 'Installation refused: unsafe code directory, owner, ACL or reparse path.'; exit;
  end;
  if RegQueryStringValue(HKLM64, 'Software\SecureRun Development', 'PackageVersion', Version) then
    if NewerVersion(Version, '{#PackageVersion}') then begin
      Result := 'Package downgrade refused. Retained database schemas must never be blindly downgraded.'; exit;
    end;
  Result := EnsureCRT('x86', NeedsRestart); if Result <> '' then exit;
  Result := EnsureCRT('x64', NeedsRestart); if Result <> '' then exit;
#if Architecture == "arm64"
  Result := EnsureCRT('arm64', NeedsRestart); if Result <> '' then exit;
#endif
  { Only an administrator-controlled machine runtime satisfies this prerequisite.
    The application independently checks actual WebView2 availability on startup. }
  Installed := 0;
  if RegQueryStringValue(HKLM32, 'SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}', 'pv', Version) then
    Installed := StrToIntDef(Copy(Version, 1, Pos('.', Version)-1), 0);
  if Installed < 120 then begin
    Log('P11_WEBVIEW_INSTALL_REQUIRED');
    ExtractTemporaryFile('MicrosoftEdgeWebview2Setup.exe');
    if not Exec(ExpandConstant('{tmp}\MicrosoftEdgeWebview2Setup.exe'), '/silent /install',
       ExpandConstant('{sys}'), SW_HIDE, ewWaitUntilTerminated, ExitCode) then begin
      Result := 'Official Microsoft WebView2 installation could not start.'; exit;
    end;
    if (ExitCode <> 0) and (ExitCode <> 3010) then begin
      Log(Format('P11_WEBVIEW_FAILED_EXIT_%d', [ExitCode]));
      Result := 'Official WebView2 prerequisite installation failed. No manager files were installed.'; exit;
    end;
    if (not RegQueryStringValue(HKLM32, 'SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}', 'pv', Version)) or
       (StrToIntDef(Copy(Version,1,Pos('.',Version)-1),0) < 120) then
      Result := 'Machine WebView2 runtime is unavailable; installation refused.';
    if ExitCode = 3010 then NeedsRestart := True;
  end;
end;
function InitializeUninstall(): Boolean;
begin
  Result := (GetModuleHandle('SbieDll.dll') = 0) and Guard();
end;
[Registry]
Root: HKLM64; Subkey: "Software\SecureRun Development"; ValueType: string; ValueName: "PackageVersion"; ValueData: "{#PackageVersion}"; Flags: uninsdeletekey
