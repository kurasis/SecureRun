/* Disposable synthetic view fixture, never shipped or used by product diagnostics. */
#include <windows.h>
#include <stdio.h>
#include <wchar.h>
#include <stdlib.h>
#include <string.h>
typedef LONG (__cdecl *query_fn)(HANDLE,ULONG,WCHAR*,WCHAR*,WCHAR*,ULONG*,ULONG64*);
int wmain(int argc,WCHAR **argv) {
    WCHAR box[40]={0},base[1024],prefix[1024],input[1200],output[1200];
    char content[64]={0},json[256];DWORD count=0;ULONG session=0;BOOL written=FALSE;HANDLE file;HMODULE module;query_fn query;
    if(argc!=6||wcslen(argv[2])>900||wcslen(argv[4])!=32)return 64;
    for(int i=0;i<32;i++)if(!((argv[4][i]>=L'0'&&argv[4][i]<=L'9')||(argv[4][i]>=L'a'&&argv[4][i]<=L'f')))return 64;
    module=GetModuleHandleW(L"SbieDll.dll");if(!module)return 71;
    query=(query_fn)(void*)GetProcAddress(module,"SbieApi_QueryProcessEx2");if(!query||query((HANDLE)(ULONG_PTR)GetCurrentProcessId(),0,box,NULL,NULL,&session,NULL)!=0||wcscmp(box,argv[3])!=0)return 71;
    if(!GetEnvironmentVariableW(L"ProgramData",base,1024)||swprintf_s(prefix,1024,L"%s\\SecureRunLab\\p02-",base)<0||_wcsnicmp(argv[2],prefix,wcslen(prefix))!=0||wcspbrk(argv[2],L"%\r\n")!=NULL)return 64;
    if(swprintf_s(input,1200,L"%s\\input\\view-%s.txt",argv[2],argv[4])<0||swprintf_s(output,1200,L"%s\\results\\view-%s-%s.json",argv[2],argv[4],argv[5])<0)return 64;
    if(wcscmp(argv[5],L"before")&&wcscmp(argv[5],L"readonly")&&wcscmp(argv[5],L"restored"))return 64;
    if(wcscmp(argv[1],L"shadow")==0){WCHAR image[1200];if(!GetModuleFileNameW(NULL,image,1200))return 74;WCHAR *name=wcsrchr(image,L'\\');if(!name)return 74;wcscpy_s(name+1,1200-(size_t)(name+1-image),L"securerun-policy-probe.exe");file=CreateFileW(image,GENERIC_WRITE,FILE_SHARE_READ,NULL,CREATE_ALWAYS,0,NULL);if(file==INVALID_HANDLE_VALUE)return 74;const char shadow[]="UNTRUSTED_SYNTHETIC_PROBE_SHADOW";written=WriteFile(file,shadow,(DWORD)strlen(shadow),&count,NULL)&&count==(DWORD)strlen(shadow);CloseHandle(file);if(!written)return 74;}
    else if(wcscmp(argv[1],L"write")==0){file=CreateFileW(input,GENERIC_WRITE,FILE_SHARE_READ,NULL,CREATE_ALWAYS,0,NULL);if(file!=INVALID_HANDLE_VALUE){written=WriteFile(file,"SYNTHETIC_BOX_VIEW",18,&count,NULL)&&count==18;CloseHandle(file);}}
    else if(wcscmp(argv[1],L"read")!=0)return 64;
    file=CreateFileW(input,GENERIC_READ,FILE_SHARE_READ,NULL,OPEN_EXISTING,0,NULL);if(file==INVALID_HANDLE_VALUE)return 73;
    if(!ReadFile(file,content,63,&count,NULL)){CloseHandle(file);return 73;}CloseHandle(file);
    const char *view=strcmp(content,"SYNTHETIC_HOST_VIEW")==0?"HOST":strcmp(content,"SYNTHETIC_BOX_VIEW")==0?"BOX":"INVALID";
    int length=sprintf_s(json,256,"{\"member\":true,\"view\":\"%s\",\"write_succeeded\":%s}",view,written?"true":"false");if(length<0)return 74;
    file=CreateFileW(output,GENERIC_WRITE,0,NULL,CREATE_NEW,0,NULL);if(file==INVALID_HANDLE_VALUE)return 74;
    BOOL ok=WriteFile(file,json,(DWORD)length,&count,NULL)&&count==(DWORD)length;CloseHandle(file);return ok?0:74;
}
