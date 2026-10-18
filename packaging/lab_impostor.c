/* Synthetic lab fixture only. Never included in the installed payload. */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <strsafe.h>
#include <wchar.h>
int wmain(void) {
    wchar_t path[32768];
    DWORD length=GetModuleFileNameW(NULL,path,32768);
    if(!length||length>=32768)return 2;
    wchar_t *slash=wcsrchr(path,L'\\');if(!slash)return 2;slash[1]=0;
    if(FAILED(StringCchCatW(path,32768,L"impostor-executed.txt")))return 2;
    HANDLE file=CreateFileW(path,GENERIC_WRITE,0,NULL,CREATE_NEW,FILE_ATTRIBUTE_NORMAL,NULL);
    if(file==INVALID_HANDLE_VALUE)return 3;
    const char data[]="P11_SYNTHETIC_IMPOSTOR_EXECUTED";DWORD written=0;
    BOOL ok=WriteFile(file,data,(DWORD)(sizeof(data)-1),&written,NULL);
    CloseHandle(file);return ok&&written==sizeof(data)-1?0:4;
}
