/* Disposable P05 cross-session fixture. No product helper or general launcher. */
#define WIN32_LEAN_AND_MEAN
#define _WIN32_WINNT 0x0A00
#include <windows.h>
#include <sddl.h>
#include <stdio.h>
#include <wchar.h>
#pragma comment(lib,"advapi32.lib")
typedef LONG (WINAPI *query_fn)(HANDLE,WCHAR*,WCHAR*,WCHAR*,ULONG*);
typedef LONG (WINAPI *conf_fn)(const WCHAR*,const WCHAR*,ULONG,WCHAR*,ULONG);
typedef BOOL (WINAPI *run_fn)(const WCHAR*,const WCHAR*,const WCHAR*,ULONG,STARTUPINFOW*,PROCESS_INFORMATION*);
static BOOL text(HANDLE pipe,WCHAR *value,DWORD capacity) {
    DWORD length=0,got=0,total=0;
    if(!ReadFile(pipe,&length,4,&got,NULL)||got!=4||!length||length>=capacity)return FALSE;
    while(total<length*2){if(!ReadFile(pipe,(BYTE*)value+total,length*2-total,&got,NULL)||!got)return FALSE;total+=got;}
    value[length]=0;return TRUE;
}
static BOOL uuid(const WCHAR *value) {
    if(wcslen(value)!=32)return FALSE;
    for(int i=0;i<32;i++)if(!((value[i]>=L'0'&&value[i]<=L'9')||(value[i]>=L'a'&&value[i]<=L'f')))return FALSE;
    return TRUE;
}
int wmain(int argc,WCHAR **argv) {
    WCHAR home[1024],dll[1200],box[40]={0},sid[184]={0};ULONG session=0;HMODULE module;query_fn query;
    if(!GetEnvironmentVariableW(L"ProgramFiles",home,1024)||wcscat_s(home,1024,L"\\Sandboxie-Plus")||swprintf_s(dll,1200,L"%s\\SbieDll.dll",home)<0)return 64;
    module=LoadLibraryExW(dll,NULL,LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR|LOAD_LIBRARY_SEARCH_SYSTEM32);if(!module)return 65;
    query=(query_fn)(void*)GetProcAddress(module,"SbieApi_QueryProcess");if(!query)return 65;
    if(argc==3&&wcscmp(argv[1],L"boxed-hold")==0){
        if(wcsncmp(argv[2],L"SR_",3)||!uuid(argv[2]+3)||query((HANDLE)(ULONG_PTR)GetCurrentProcessId(),box,NULL,sid,&session)||wcscmp(box,argv[2])||session!=0)return 66;
        Sleep(60000);return 0;
    }
    if(argc==3&&wcscmp(argv[1],L"facade")==0){
        WCHAR owner[184],expected[256],marker[256],exe[1024],command[2200];HANDLE token=NULL;BYTE data[256];DWORD got=0;LPWSTR userSid=NULL;BOOL ok;STARTUPINFOW startup={0};PROCESS_INFORMATION receipt={0};
        conf_fn conf=(conf_fn)(void*)GetProcAddress(module,"SbieApi_QueryConf");run_fn run=(run_fn)(void*)GetProcAddress(module,"SbieDll_RunSandboxed");
        if(wcsncmp(argv[2],L"SR_",3)||!uuid(argv[2]+3)||!conf||!run||(ULONG)query((HANDLE)(ULONG_PTR)GetCurrentProcessId(),box,NULL,NULL,&session)!=0xc000000bUL||session!=0||!OpenProcessToken(GetCurrentProcess(),TOKEN_QUERY,&token))return 66;
        ok=GetTokenInformation(token,TokenUser,data,sizeof(data),&got)&&ConvertSidToStringSidW(((TOKEN_USER*)data)->User.Sid,&userSid);CloseHandle(token);
        if(!ok)return 67;wcscpy_s(owner,184,userSid);LocalFree(userSid);
        if(wcscmp(owner,L"S-1-5-18")==0||swprintf_s(expected,256,L"v1:%s:%s",owner,argv[2]+3)<0||conf(argv[2],L"SecureRunOwner",0x70000000UL,marker,sizeof(marker))||wcscmp(marker,expected))return 67;
        if(!GetModuleFileNameW(NULL,exe,1024)||swprintf_s(command,2200,L"\"%s\" boxed-hold %s",exe,argv[2])<0)return 64;
        startup.cb=sizeof(startup);if(!run(argv[2],command,home,CREATE_NO_WINDOW,&startup,&receipt))return 68;
        WaitForSingleObject(receipt.hProcess,65000);CloseHandle(receipt.hThread);CloseHandle(receipt.hProcess);return 0;
    }
    if(argc==3&&wcscmp(argv[1],L"logon-fixture")==0){
        WCHAR pipePath[256],user[64]={0},password[128]={0},claimed[184]={0},base[1024]={0},selected[40]={0},exe[1024],command[2200],prefix[1024];HANDLE current=NULL,token=NULL,pipe;BYTE data[256];DWORD got=0,size=SECURITY_MAX_SID_SIZE;BYTE systemSid[SECURITY_MAX_SID_SIZE];BOOL ok;LPWSTR actual=NULL;STARTUPINFOW startup={0};PROCESS_INFORMATION child={0};
        const size_t pipePrefix=wcslen(L"SecureRunP02Logon_");
        if(wcsncmp(argv[2],L"SecureRunP02Logon_",pipePrefix)||!uuid(argv[2]+pipePrefix)||(ULONG)query((HANDLE)(ULONG_PTR)GetCurrentProcessId(),box,NULL,NULL,&session)!=0xc000000bUL||!OpenProcessToken(GetCurrentProcess(),TOKEN_QUERY,&current))return 66;
        ok=GetTokenInformation(current,TokenUser,data,sizeof(data),&got)&&CreateWellKnownSid(WinLocalSystemSid,NULL,systemSid,&size)&&EqualSid(((TOKEN_USER*)data)->User.Sid,systemSid);CloseHandle(current);if(!ok)return 66;
        if(swprintf_s(pipePath,256,L"\\\\.\\pipe\\%s",argv[2])<0)return 64;pipe=CreateFileW(pipePath,GENERIC_READ,0,NULL,OPEN_EXISTING,0,NULL);if(pipe==INVALID_HANDLE_VALUE)return 67;
        ok=text(pipe,user,64)&&text(pipe,password,128)&&text(pipe,claimed,184)&&text(pipe,base,1024)&&text(pipe,selected,40);CloseHandle(pipe);
        if(!GetEnvironmentVariableW(L"ProgramData",prefix,1024)||wcscat_s(prefix,1024,L"\\SecureRunLab\\p02-")||!ok||wcsncmp(user,L"SRP02S_",7)||wcspbrk(user,L"\\/:.\" ")||wcsncmp(selected,L"SR_",3)||!uuid(selected+3)||_wcsnicmp(base,prefix,wcslen(prefix))||wcspbrk(base,L"%\r\n\"")||wcsstr(base,L"..")){SecureZeroMemory(password,sizeof(password));return 64;}
        ok=LogonUserW(user,L".",password,LOGON32_LOGON_INTERACTIVE,LOGON32_PROVIDER_DEFAULT,&token);SecureZeroMemory(password,sizeof(password));if(!ok)return 69;
        ok=GetTokenInformation(token,TokenUser,data,sizeof(data),&got)&&ConvertSidToStringSidW(((TOKEN_USER*)data)->User.Sid,&actual)&&wcscmp(actual,claimed)==0;if(actual)LocalFree(actual);
        if(!ok){CloseHandle(token);return 70;}
        if(!GetModuleFileNameW(NULL,exe,1024)||swprintf_s(command,2200,L"\"%s\" facade %s",exe,selected)<0){CloseHandle(token);return 64;}
        startup.cb=sizeof(startup);ok=CreateProcessAsUserW(token,exe,command,NULL,NULL,FALSE,CREATE_NO_WINDOW,NULL,home,&startup,&child);CloseHandle(token);if(!ok)return 71;
        WaitForSingleObject(child.hProcess,70000);CloseHandle(child.hThread);CloseHandle(child.hProcess);return 0;
    }
    return 64;
}
