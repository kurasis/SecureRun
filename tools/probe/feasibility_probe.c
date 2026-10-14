/* Original P02 benign probe. Fixed synthetic canaries only, never a user launcher. */
#define WIN32_LEAN_AND_MEAN
#define _WIN32_WINNT 0x0A00
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <stdio.h>
#include <wchar.h>
#include <stdlib.h>
#include <string.h>
#pragma comment(lib,"ws2_32.lib")
#pragma comment(lib,"advapi32.lib")
/* The pinned Win32 build uses /Gz; its .def exports the legacy undecorated aliases. */
typedef LONG (WINAPI *query_fn)(HANDLE,WCHAR*,WCHAR*,WCHAR*,ULONG*);
typedef ULONG (WINAPI *map_fn)(HANDLE,WCHAR*,BOOLEAN*);
typedef BOOL (WINAPI *run_fn)(const WCHAR*,const WCHAR*,const WCHAR*,ULONG,STARTUPINFOW*,PROCESS_INFORMATION*);

static BOOL path(WCHAR *out,const WCHAR *base,const WCHAR *suffix) {
    return swprintf_s(out,1024,L"%s\\%s",base,suffix)>=0;
}
static BOOL valid_base(const WCHAR *base) {
    WCHAR expected[MAX_PATH];
    DWORD size=GetEnvironmentVariableW(L"ProgramData",expected,MAX_PATH);
    if(!size || size>=MAX_PATH)return FALSE;
    wcscat_s(expected,MAX_PATH,L"\\SecureRunLab\\p02-");
    return _wcsnicmp(base,expected,wcslen(expected))==0 && wcschr(base,L'%')==NULL && wcschr(base,L'"')==NULL && wcsstr(base,L"..") == NULL;
}
static DWORD read_error(const WCHAR *file) {
    HANDLE h=CreateFileW(file,GENERIC_READ,FILE_SHARE_READ,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,NULL);
    if(h==INVALID_HANDLE_VALUE)return GetLastError();
    CloseHandle(h);return 0;
}
static int socket_probe(int family,int type,int port) {
    SOCKET s=socket(family,type,0);struct sockaddr_storage storage;int length;char byte='P',answer=0;DWORD timeout=700;
    if(s==INVALID_SOCKET)return 0;
    ZeroMemory(&storage,sizeof(storage));
    if(family==AF_INET){struct sockaddr_in *a=(struct sockaddr_in*)&storage;a->sin_family=AF_INET;a->sin_port=htons((u_short)port);a->sin_addr.s_addr=htonl(INADDR_LOOPBACK);length=sizeof(*a);}
    else {struct sockaddr_in6 *a=(struct sockaddr_in6*)&storage;a->sin6_family=AF_INET6;a->sin6_port=htons((u_short)port);a->sin6_addr=in6addr_loopback;length=sizeof(*a);}
    setsockopt(s,SOL_SOCKET,SO_RCVTIMEO,(const char*)&timeout,sizeof(timeout));
    setsockopt(s,SOL_SOCKET,SO_SNDTIMEO,(const char*)&timeout,sizeof(timeout));
    if(type==SOCK_STREAM){
        u_long nonblock=1;fd_set ready;struct timeval wait={0,700000};int error=0,errorLength=sizeof(error);
        ioctlsocket(s,FIONBIO,&nonblock);
        if(connect(s,(struct sockaddr*)&storage,length)!=0 && WSAGetLastError()!=WSAEWOULDBLOCK){closesocket(s);return 0;}
        FD_ZERO(&ready);FD_SET(s,&ready);
        if(select(0,NULL,&ready,NULL,&wait)<=0){closesocket(s);return 0;}
        getsockopt(s,SOL_SOCKET,SO_ERROR,(char*)&error,&errorLength);
        if(error){closesocket(s);return 0;}
        nonblock=0;ioctlsocket(s,FIONBIO,&nonblock);
        if(send(s,&byte,1,0)!=1){closesocket(s);return 0;}
    } else {
        if(connect(s,(struct sockaddr*)&storage,length)!=0 || send(s,&byte,1,0)!=1){closesocket(s);return 0;}
    }
    {int result=recv(s,&answer,1,0)==1 && answer=='R';closesocket(s);return result;}
}
static BOOL spawn_child(const WCHAR *base,const WCHAR *box,const WCHAR *tag,const WCHAR *home,int depth,int *ports,PROCESS_INFORMATION *pi) {
    WCHAR exe[1024],cmd[4096];STARTUPINFOW si;
    if(!GetModuleFileNameW(NULL,exe,1024))return FALSE;
    if(swprintf_s(cmd,4096,L"\"%s\" child \"%s\" \"%s\" \"%s\" \"%s\" %d %d %d %d %d",exe,base,box,tag,home,depth,ports[0],ports[1],ports[2],ports[3])<0)return FALSE;
    ZeroMemory(&si,sizeof(si));si.cb=sizeof(si);ZeroMemory(pi,sizeof(*pi));
    return CreateProcessW(exe,cmd,NULL,NULL,FALSE,0,NULL,base,&si,pi);
}
static BOOL write_report(const WCHAR *base,const WCHAR *tag,const char *data) {
    WCHAR output[1024],suffix[160];DWORD written;HANDLE file;
    if(wcslen(tag)>80 || wcspbrk(tag,L"\\/:.\r\n")!=NULL)return FALSE;
    if(swprintf_s(suffix,160,L"results\\%s.json",tag)<0 || !path(output,base,suffix))return FALSE;
    file=CreateFileW(output,GENERIC_WRITE,0,NULL,CREATE_NEW,FILE_ATTRIBUTE_NORMAL,NULL);
    if(file==INVALID_HANDLE_VALUE)return FALSE;
    {BOOL ok=WriteFile(file,data,(DWORD)strlen(data),&written,NULL) && written==strlen(data);FlushFileBuffers(file);CloseHandle(file);return ok;}
}
int wmain(int argc,WCHAR **argv) {
    HMODULE module;query_fn query;map_fn mapping;WCHAR box[40]={0},file[1024],mapped[4096]={0};ULONG session=0;LONG context;
    int ports[4]={0},net[4]={0};BOOL host,child;WSADATA wsa;
    if(argc<2)return 64;
    if(wcscmp(argv[1],L"forbidden-host-marker")==0){
        if(argc==3 && valid_base(argv[2])){HANDLE marker;path(file,argv[2],L"FORBIDDEN-HOST-EXECUTION.txt");marker=CreateFileW(file,GENERIC_WRITE,0,NULL,CREATE_NEW,0,NULL);if(marker!=INVALID_HANDLE_VALUE)CloseHandle(marker);}
        return 99; /* synthetic failure detector, never normal-launch recovery */
    }
    if(wcscmp(argv[1],L"acl")==0){
        DWORD metadata,sibling;WCHAR suffix[160];
        if(argc!=4 || !valid_base(argv[2]) || wcslen(argv[3])>38 || wcspbrk(argv[3],L"\\/:.")!=NULL)return 64;
        path(file,argv[2],L"metadata\\manager.txt");metadata=read_error(file);
        swprintf_s(suffix,160,L"boxes\\%s\\private.txt",argv[3]);path(file,argv[2],suffix);sibling=read_error(file);
        printf("{\"metadata_read_error\":%lu,\"root_read_error\":%lu}\n",metadata,sibling);return 0;
    }
    host=wcscmp(argv[1],L"host")==0;child=wcscmp(argv[1],L"child")==0;
    if(argc<6 || !valid_base(argv[2]))return 64;
    module=GetModuleHandleW(L"SbieDll.dll");
    if(!module && (host || wcscmp(argv[1],L"session-launch")==0 || wcscmp(argv[1],L"user-launch")==0)){
        WCHAR dll[1024];const WCHAR *subdir=L"";
#if defined(_M_IX86)
        subdir=L"\\32";
#elif defined(_M_X64)
        {USHORT processMachine=0,nativeMachine=0;if(!IsWow64Process2(GetCurrentProcess(),&processMachine,&nativeMachine))return 41;if(nativeMachine==IMAGE_FILE_MACHINE_ARM64)subdir=L"\\64";}
#endif
        if(swprintf_s(dll,1024,L"%s%s\\SbieDll.dll",argv[5],subdir)<0)return 64;
        module=LoadLibraryExW(dll,NULL,LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR|LOAD_LIBRARY_SEARCH_SYSTEM32);
    }
    if(!module)return 41;
    query=(query_fn)(void*)GetProcAddress(module,"SbieApi_QueryProcess");
    mapping=(map_fn)(void*)GetProcAddress(module,"SbieDll_GetHandlePath");
    if(!query || !mapping)return 41;
    context=query((HANDLE)(ULONG_PTR)GetCurrentProcessId(),box,NULL,NULL,&session);
    if(wcscmp(argv[1],L"session-launch")==0 || wcscmp(argv[1],L"user-launch")==0){
        WCHAR exe[1024],command[4096];STARTUPINFOW startup={0};PROCESS_INFORMATION receipt={0};run_fn run;
        if(argc!=6 || (ULONG)context!=0xc000000bUL || !ProcessIdToSessionId(GetCurrentProcessId(),&session) || session!=0 || wcslen(argv[3])>38 || wcsncmp(argv[3],L"SRP02_",6)!=0 || wcspbrk(argv[3],L"\\/:.\" ")!=NULL)return 42;
        run=(run_fn)(void*)GetProcAddress(module,"SbieDll_RunSandboxed");
        if(!run || !GetModuleFileNameW(NULL,exe,1024))return 41;
        if(swprintf_s(command,4096,L"\"%s\" hold \"%s\" %s session-zero \"%s\"",exe,argv[2],argv[3],argv[5])<0)return 64;
        startup.cb=sizeof(startup);
        if(!run(argv[3],command,argv[2],0,&startup,&receipt))return 47;
        {DWORD result=WaitForSingleObject(receipt.hProcess,30000);CloseHandle(receipt.hThread);CloseHandle(receipt.hProcess);return result==WAIT_OBJECT_0?0:48;}
    }
    if(wcscmp(argv[1],L"guard")==0)return context==0 ? 43 : 44; /* boxed control plane refuses all mutation */
    if(host){if((ULONG)context!=0xc000000bUL)return 42;}
    else if(context!=0 || wcscmp(box,argv[3])!=0)return 42; /* check before canary operations */
    if(wcscmp(argv[1],L"exit-fast")==0)return 0;
    if(wcscmp(argv[1],L"workspace")==0){
        WCHAR exe[1024],descriptor[1024];HANDLE handle,out;DWORD size=0;BOOLEAN boxed=FALSE;ULONG status;
        if(argc!=6||!GetModuleFileNameW(NULL,exe,1024))return 64;
        path(file,argv[2],L"workspace");if(!CreateDirectoryW(file,NULL)&&GetLastError()!=ERROR_ALREADY_EXISTS)return 49;
        path(file,argv[2],L"workspace\\boxed-probe.exe");if(!CopyFileW(exe,file,TRUE))return 49;
        handle=CreateFileW(file,GENERIC_READ,FILE_SHARE_READ,NULL,OPEN_EXISTING,0,NULL);if(handle==INVALID_HANDLE_VALUE)return 49;
        status=mapping(handle,mapped,&boxed);CloseHandle(handle);
        if(status!=0||!boxed||wcslen(mapped)>4092)return 49;
        path(descriptor,argv[2],L"results\\workspace.mapping");
        out=CreateFileW(descriptor,GENERIC_WRITE,0,NULL,CREATE_NEW,0,NULL);if(out==INVALID_HANDLE_VALUE)return 49;
        {BOOL ok=WriteFile(out,mapped,(DWORD)(wcslen(mapped)*sizeof(WCHAR)),&size,NULL);CloseHandle(out);return ok?0:49;}
    }
    if(wcscmp(argv[1],L"hold")==0){Sleep(20000);return 0;}
    if(child){if(argc!=11)return 64;for(int i=0;i<4;i++)ports[i]=_wtoi(argv[7+i]);}
    else {if(argc!=15)return 64;for(int i=0;i<4;i++)ports[i]=_wtoi(argv[6+i]);}
    for(int i=0;i<4;i++)if(ports[i]<1 || ports[i]>65535)return 64;
    if(WSAStartup(MAKEWORD(2,2),&wsa)!=0)return 45;
    for(int i=0;i<4;i++)net[i]=socket_probe(i%2==0?AF_INET:AF_INET6,i<2?SOCK_STREAM:SOCK_DGRAM,ports[i]);
    WSACleanup();
    if(child){
        int depth=_wtoi(argv[6]);WCHAR tag[96];char output[512];PROCESS_INFORMATION pi={0};BOOL spawned=FALSE;
        if(depth!=0 && depth!=1)return 64;
        if(depth==1)spawned=spawn_child(argv[2],argv[3],argv[4],argv[5],0,ports,&pi);
        swprintf_s(tag,96,L"%s-child%d",argv[4],depth);
        sprintf_s(output,sizeof(output),"{\"member\":true,\"depth\":%d,\"bits\":%u,\"tcp4\":%s,\"tcp6\":%s,\"udp4\":%s,\"udp6\":%s,\"spawned\":%s}",depth,(unsigned)(sizeof(void*)*8),net[0]?"true":"false",net[1]?"true":"false",net[2]?"true":"false",net[3]?"true":"false",spawned?"true":"false");
        if(!write_report(argv[2],tag,output))return 46;
        Sleep(4000);
        if(spawned){WaitForSingleObject(pi.hProcess,6000);CloseHandle(pi.hThread);CloseHandle(pi.hProcess);}
        return 0;
    }
    {
        DWORD wrote=0,blocked,metadata,sibling;BOOL changed=FALSE,argsOk,writeOk=FALSE,childOk=FALSE;BOOLEAN isBoxed=FALSE;ULONG mapStatus=0xffffffff;char content[32]={0},output[1400];PROCESS_INFORMATION pi={0};HANDLE handle;
        if(!path(file,argv[2],L"canaries\\write.txt"))return 64;
        handle=CreateFileW(file,GENERIC_READ|GENERIC_WRITE,0,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,NULL);
        if(handle!=INVALID_HANDLE_VALUE){
            const char *change="P02_BOXED_CHANGE";
            writeOk=WriteFile(handle,change,(DWORD)strlen(change),&wrote,NULL);
            SetEndOfFile(handle);SetFilePointer(handle,0,NULL,FILE_BEGIN);
            if(ReadFile(handle,content,31,&wrote,NULL))changed=strncmp(content,change,strlen(change))==0;
            if(!host)mapStatus=mapping(handle,mapped,&isBoxed);
            CloseHandle(handle);
        }
        path(file,argv[2],L"blocked\\secret.txt");blocked=read_error(file);
        path(file,argv[2],L"metadata\\manager.txt");metadata=read_error(file);
        path(file,argv[2],L"sibling-probe.txt");
        {HANDLE input=CreateFileW(file,GENERIC_READ,FILE_SHARE_READ,NULL,OPEN_EXISTING,0,NULL);WCHAR siblingPath[1024]={0};DWORD size=0;
         if(input!=INVALID_HANDLE_VALUE){ReadFile(input,siblingPath,2046,&size,NULL);CloseHandle(input);sibling=read_error(siblingPath);}else sibling=GetLastError();}
        argsOk=wcscmp(argv[10],L"two words")==0&&wcscmp(argv[11],L"quote\"value")==0&&wcscmp(argv[12],L"trailing\\")==0&&wcscmp(argv[13],L"/terminate_all")==0&&wcscmp(argv[14],L"\x042e\x043d\x0438\x043a\x043e\x0434")==0;
        if(!host)childOk=spawn_child(argv[2],argv[3],argv[4],argv[5],1,ports,&pi);
        if(childOk){WaitForSingleObject(pi.hProcess,15000);CloseHandle(pi.hThread);CloseHandle(pi.hProcess);}
        sprintf_s(output,sizeof(output),"{\"member\":%s,\"bits\":%u,\"context_status\":\"%08lx\",\"write_ok\":%s,\"boxed_view_changed\":%s,\"blocked_read_error\":%lu,\"metadata_read_error\":%lu,\"sibling_read_error\":%lu,\"argument_round_trip\":%s,\"handle_map_status\":\"%08lx\",\"mapped_is_boxed\":%s,\"child_spawned\":%s,\"tcp4\":%s,\"tcp6\":%s,\"udp4\":%s,\"udp6\":%s}",host?"false":"true",(unsigned)(sizeof(void*)*8),(ULONG)context,writeOk?"true":"false",changed?"true":"false",blocked,metadata,sibling,argsOk?"true":"false",mapStatus,isBoxed?"true":"false",childOk?"true":"false",net[0]?"true":"false",net[1]?"true":"false",net[2]?"true":"false",net[3]?"true":"false");
        if(!write_report(argv[2],argv[4],output))return 46;
    }
    return 0;
}
